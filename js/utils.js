const U = {
  esc(v) { const d = document.createElement("div"); d.textContent = v ?? ""; return d.innerHTML; },
  debounce(fn, ms = 300) { let t; return (...a) => { clearTimeout(t); t = setTimeout(() => fn(...a), ms); }; },
  toast(msg, type = "ok") {
    let box = document.getElementById("toasts");
    if (!box) { box = document.createElement("div"); box.id = "toasts"; box.setAttribute("aria-live", "polite"); document.body.appendChild(box); }
    const t = document.createElement("div"); t.className = "toast " + type; t.textContent = msg; box.appendChild(t);
    setTimeout(() => t.remove(), 4000);
  },
  // Never show raw database errors to users; log them for developers.
  friendly(err, fallback = "Something went wrong. Please try again.") { console.error(err); return fallback; },
  confirm(msg) { return Promise.resolve(window.confirm(msg)); },
  state(el, kind, msg) { el.innerHTML = `<div class="state ${kind}" role="${kind === "error" ? "alert" : "status"}">${U.esc(msg)}</div>`; },
  // Read every row of a query, 1000 at a time (the server never returns more than 1000 per request). mk = () => fresh query.
  async fetchAll(mk, page = 1000) {
    let out = [];
    for (let from = 0; ; from += page) {
      const { data, error } = await mk().range(from, from + page - 1);
      if (error) throw error;
      out = out.concat(data || []);
      if (!data || data.length < page) return out;
    }
  },
  // CSV: every field quoted, quotes doubled, and cells starting with = + - @ get a leading apostrophe so Excel cannot run them as formulas.
  csv(rows) {
    const cell = v => { let t = String(v ?? ""); if (/^[=+\-@\t\r]/.test(t) && !/^-?\d+(\.\d+)?$/.test(t)) t = "'" + t; return '"' + t.replace(/"/g, '""') + '"'; };
    return rows.map(r => r.map(cell).join(",")).join("\r\n");
  },
  // UTF-8 with BOM so Excel shows Marathi/Devanagari correctly.
  download(name, text) {
    const a = document.createElement("a");
    a.href = URL.createObjectURL(new Blob(["\ufeff" + text], { type: "text/csv;charset=utf-8" }));
    a.download = name; document.body.appendChild(a); a.click(); a.remove(); setTimeout(() => URL.revokeObjectURL(a.href), 1000);
  },
  async settings() {
    if (U._settings) return U._settings;
    const { data } = await db.rpc("app_settings");
    return (U._settings = data || {});
  },
  // Letterhead used at the top of every printed report.
  async letterhead(title, sub) {
    const s = await U.settings();
    return `<div class="lh"><strong>${U.esc(s.school_name || "School")}</strong><div>${U.esc(s.address || "")}${s.phone ? " | " + U.esc(s.phone) : ""}</div><h2>${U.esc(title)}</h2><div>${U.esc(sub || "")}</div></div>`;
  },
  async audit(action, module, recordId) {
    const { data: { user } } = await db.auth.getUser();
    if (!user) return;
    await db.from("audit_logs").insert({ user_id: user.id, action, module, record_id: recordId ?? null });
  }
};
