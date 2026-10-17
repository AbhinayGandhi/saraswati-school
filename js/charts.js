// Dependency-free SVG charts (bars, line, stacked) with tooltip + table view. Colours come from CSS variables in style.css.
const Charts = (() => {
  const NS = "http://www.w3.org/2000/svg";
  const esc = s => String(s).replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
  const compact = n => { n = Number(n) || 0; const a = Math.abs(n); return a >= 1e7 ? (n / 1e7).toFixed(1).replace(/\.0$/, "") + "Cr" : a >= 1e5 ? (n / 1e5).toFixed(1).replace(/\.0$/, "") + "L" : a >= 1e3 ? (n / 1e3).toFixed(1).replace(/\.0$/, "") + "K" : String(Math.round(n * 10) / 10) };
  let tip;
  function tipEl() { if (!tip) { tip = document.createElement("div"); tip.className = "ch-tip"; tip.hidden = true; document.body.appendChild(tip) } return tip }
  function showTip(ev, html) { const t = tipEl(); t.innerHTML = html; t.hidden = false; const x = Math.min(ev.clientX + 12, innerWidth - t.offsetWidth - 8); t.style.left = Math.max(4, x) + "px"; t.style.top = Math.max(4, ev.clientY - t.offsetHeight - 10) + "px" }
  function hideTip() { if (tip) tip.hidden = true }
  function hover(node, html) {
    node.addEventListener("mousemove", e => showTip(e, html)); node.addEventListener("mouseleave", hideTip);
    node.addEventListener("focus", () => { const r = node.getBoundingClientRect(); showTip({ clientX: r.left + r.width / 2, clientY: r.top }, html) }); node.addEventListener("blur", hideTip);
    node.setAttribute("tabindex", "0");
  }
  function mk(tag, attrs, parent) { const n = document.createElementNS(NS, tag); for (const k in attrs) n.setAttribute(k, attrs[k]); if (parent) parent.appendChild(n); return n }
  function table(head, rows) { return '<div class="tw"><table><thead><tr>' + head.map(h => "<th>" + esc(h) + "</th>").join("") + "</tr></thead><tbody>" + rows.map(r => "<tr>" + r.map(v => "<td>" + esc(v) + "</td>").join("") + "</tr>").join("") + "</tbody></table></div>" }
  // Wraps a chart in a titled card with a Chart / Table toggle.
  function frame(el, title, note, drawFn, head, rows) {
    el.innerHTML = ""; el.classList.add("chart-card");
    const h = document.createElement("div"); h.className = "ch-head";
    h.innerHTML = "<h3>" + esc(title) + "</h3>" + (note ? '<span class="ch-note">' + esc(note) + "</span>" : "");
    const tg = document.createElement("button"); tg.type = "button"; tg.className = "btn ghost ch-tg noprint"; tg.textContent = "Table"; tg.setAttribute("aria-pressed", "false"); h.appendChild(tg);
    const body = document.createElement("div"); body.className = "ch-body"; const tb = document.createElement("div"); tb.hidden = true; tb.innerHTML = table(head, rows);
    el.append(h, body, tb); drawFn(body);
    tg.onclick = () => { const on = tb.hidden; tb.hidden = !on; body.hidden = on; tg.textContent = on ? "Chart" : "Table"; tg.setAttribute("aria-pressed", on) }
  }
  function empty(el, title) { el.classList.add("chart-card"); el.innerHTML = "<h3>" + esc(title) + '</h3><div class="state">No data yet.</div>' }
  // items: [{label, value, note?}]; horizontal bars, value at the tip. opts: fmt, color (css var name), max
  function bars(el, title, items, o = {}) {
    if (!items.length) return empty(el, title);
    const fmt = o.fmt || compact, max = o.max || Math.max(1, ...items.map(i => i.value)), rowH = 30, left = o.left || 92, W = 420, right = 56, H = items.length * rowH + 6;
    frame(el, title, o.note, body => {
      const s = mk("svg", { viewBox: `0 0 ${W} ${H}`, class: "ch-svg", role: "img", "aria-label": title }, body);
      items.forEach((it, i) => { const y = i * rowH + 3, w = Math.max(it.value > 0 ? 2 : 0, (W - left - right) * it.value / max);
        const t = mk("text", { x: left - 8, y: y + 15, "text-anchor": "end", class: "ch-l" }, s); t.textContent = it.label.length > 14 ? it.label.slice(0, 13) + "…" : it.label;
        const g = mk("g", { class: "ch-hit" }, s); mk("rect", { x: left, y, width: W - left, height: rowH - 4, fill: "transparent" }, g);
        mk("rect", { x: left, y: y + 3, width: w, height: 18, rx: 4, fill: `var(${it.color || o.color || "--c1"})` }, g);
        const v = mk("text", { x: left + w + 6, y: y + 16, class: "ch-v" }, s); v.textContent = fmt(it.value);
        hover(g, "<b>" + esc(it.label) + "</b><br>" + esc(fmt(it.value)) + (it.note ? "<br>" + esc(it.note) : "")) });
    }, [o.labelHead || "Item", o.valueHead || "Value"], items.map(i => [i.label, fmt(i.value)]));
  }
  // columns for time series: points [{label, value}] -> vertical columns (months) or line (days). opts.kind = "col"|"line"
  function series(el, title, pts, o = {}) {
    if (!pts.length) return empty(el, title);
    const fmt = o.fmt || compact, W = 420, H = 190, L = 44, R = 12, T = 12, B = 30, max = o.max || niceMax(Math.max(1, ...pts.map(p => p.value))), min = 0;
    const px = i => L + (pts.length === 1 ? (W - L - R) / 2 : (W - L - R) * (i + .5) / pts.length), py = v => T + (H - T - B) * (1 - (v - min) / (max - min));
    frame(el, title, o.note, body => {
      const s = mk("svg", { viewBox: `0 0 ${W} ${H}`, class: "ch-svg", role: "img", "aria-label": title }, body);
      for (let k = 0; k <= 4; k++) { const v = min + (max - min) * k / 4, y = py(v); mk("line", { x1: L, x2: W - R, y1: y, y2: y, class: "ch-grid" }, s); const t = mk("text", { x: L - 6, y: y + 4, "text-anchor": "end", class: "ch-l" }, s); t.textContent = (o.axisFmt || compact)(v) }
      const step = Math.ceil(pts.length / 8);
      pts.forEach((p, i) => { if ((pts.length - 1 - i) % step === 0) { const t = mk("text", { x: px(i), y: H - 10, "text-anchor": "middle", class: "ch-l" }, s); t.textContent = p.label } });
      if ((o.kind || "col") === "col") {
        const bw = Math.min(24, (W - L - R) / pts.length * .6);
        pts.forEach((p, i) => { const g = mk("g", {}, s); mk("rect", { x: px(i) - (W - L - R) / pts.length / 2, y: T, width: (W - L - R) / pts.length, height: H - T - B, fill: "transparent" }, g);
          const y = py(p.value); mk("rect", { x: px(i) - bw / 2, y, width: bw, height: Math.max(0, H - B - y), rx: 4, fill: `var(${o.color || "--c1"})` }, g);
          hover(g, "<b>" + esc(p.label) + "</b><br>" + esc(fmt(p.value)) + (p.note ? "<br>" + esc(p.note) : "")) });
        const last = pts[pts.length - 1], t = mk("text", { x: px(pts.length - 1), y: py(last.value) - 6, "text-anchor": "middle", class: "ch-v" }, s); t.textContent = fmt(last.value);
      } else {
        const d = pts.map((p, i) => (i ? "L" : "M") + px(i).toFixed(1) + " " + py(p.value).toFixed(1)).join("");
        mk("path", { d: d + `L${px(pts.length - 1)} ${H - B}L${px(0)} ${H - B}Z`, fill: `var(${o.color || "--c1"})`, opacity: ".1" }, s);
        mk("path", { d, fill: "none", stroke: `var(${o.color || "--c1"})`, "stroke-width": 2, "stroke-linejoin": "round", "stroke-linecap": "round" }, s);
        pts.forEach((p, i) => { const g = mk("g", {}, s); const w = (W - L - R) / pts.length; mk("rect", { x: px(i) - w / 2, y: T, width: w, height: H - T - B, fill: "transparent" }, g);
          mk("circle", { cx: px(i), cy: py(p.value), r: i === pts.length - 1 ? 4 : 2.5, fill: `var(${o.color || "--c1"})`, stroke: "var(--card)", "stroke-width": 2 }, g);
          hover(g, "<b>" + esc(p.label) + "</b><br>" + esc(fmt(p.value)) + (p.note ? "<br>" + esc(p.note) : "")) });
      }
    }, [o.labelHead || "Period", o.valueHead || "Value"], pts.map(p => [p.label, fmt(p.value)]));
  }
  function niceMax(m) { const p = Math.pow(10, Math.floor(Math.log10(m))), f = m / p; return (f <= 1 ? 1 : f <= 2 ? 2 : f <= 5 ? 5 : 10) * p }
  // single stacked bar (part-to-whole) with legend. parts: [{label, value, color}]
  function split(el, title, parts, o = {}) {
    const tot = parts.reduce((a, p) => a + p.value, 0); if (!tot) return empty(el, title);
    const fmt = o.fmt || compact;
    frame(el, title, o.note, body => {
      const bar = document.createElement("div"); bar.className = "ch-split"; bar.setAttribute("role", "img"); bar.setAttribute("aria-label", title);
      parts.filter(p => p.value > 0).forEach(p => { const s = document.createElement("span"); s.style.flex = p.value; s.style.background = `var(${p.color})`; hover(s, "<b>" + esc(p.label) + "</b><br>" + esc(fmt(p.value)) + " (" + Math.round(p.value * 100 / tot) + "%)"); bar.appendChild(s) });
      const lg = document.createElement("ul"); lg.className = "ch-legend"; parts.forEach(p => { const li = document.createElement("li"); li.innerHTML = `<i style="background:var(${p.color})"></i>${esc(p.label)} <b>${esc(fmt(p.value))}</b>`; lg.appendChild(li) });
      body.append(bar, lg);
    }, ["Part", "Value", "Share"], parts.map(p => [p.label, fmt(p.value), Math.round(p.value * 100 / tot) + "%"]));
  }
  return { bars, series, split, compact, hideTip };
})();
