/* Public website helper: header, footer, school details and small DOM helpers. No secrets here. */
(function () {
  const PAGES = [["index.html","Home"],["about.html","About"],["academics.html","Academics"],["site-admissions.html","Admissions"],["faculty.html","Faculty"],["facilities.html","Facilities"],["site-activities.html","Activities"],["site-events.html","Events"],["gallery.html","Gallery"],["site-notices.html","Notices"],["contact.html","Contact"]];
  const here = location.pathname.split("/").pop() || "index.html";
  const el = (tag, txt, cls) => { const e = document.createElement(tag); if (txt != null) e.textContent = txt; if (cls) e.className = cls; return e; };
  const S = { home_tagline: "", about_text: "", vision: "", mission: "", principal_message: "", school_name: "Saraswati English Medium School", address: "[School Address]", phone: "[School Phone]", email: "[School Email]", principal: "[Principal Name]" };

  function header() {
    const h = document.getElementById("sh"); if (!h) return;
    h.className = "sh"; h.innerHTML = "";
    const inn = el("div", null, "in");
    const brand = el("a", null, "brand"); brand.href = "index.html";
    brand.append(el("span", "S", "logo"), el("span", "Saraswati English Medium School"));
    const btn = el("button", "Menu", "btn ghost"); btn.id = "pm"; btn.setAttribute("aria-expanded", "false"); btn.setAttribute("aria-controls", "pn");
    const nav = el("nav"); nav.id = "pn"; nav.setAttribute("aria-label", "Main");
    PAGES.forEach(([href, label]) => { const a = el("a", label); a.href = href; if (href === here) a.setAttribute("aria-current", "page"); nav.appendChild(a); });
    const login = el("a", "Login", "cta"); login.href = "login.html"; nav.appendChild(login);
    btn.onclick = () => { const o = nav.classList.toggle("open"); btn.setAttribute("aria-expanded", o); };
    inn.append(brand, btn, nav); h.appendChild(inn);
  }
  function footer() {
    const f = document.getElementById("sf"); if (!f) return;
    f.className = "pf"; f.innerHTML = "";
    const w = el("div", null, "wrap"), cols = el("div", null, "cols");
    const a = el("div"); a.append(el("h3", "Saraswati English Medium School"), el("p", "LKG to Grade 10"));
    const b = el("div"); b.append(el("h3", "Contact"), el("p", null)); b.lastChild.append(el("span", S.address, "d-address"), document.createElement("br"), el("span", S.phone, "d-phone"), document.createElement("br"), el("span", S.email, "d-email"));
    const c = el("div"); c.append(el("h3", "Quick links"));
    [["site-admissions.html","Admissions"],["apply.html","Admission enquiry"],["site-notices.html","Notices"],["login.html","Login"]].forEach(([h, t]) => { const l = el("a", t); l.href = h; c.append(l, document.createElement("br")); });
    cols.append(a, b, c); w.append(cols, el("small", "© Saraswati English Medium School")); f.appendChild(w);
  }
  function fill() {
    document.querySelectorAll("[data-set]").forEach(n => { const v = S[n.dataset.set]; if (v) { n.textContent = v; n.classList.remove("ph"); if (n.dataset.set === "about_text" || n.dataset.set === "principal_message") n.style.whiteSpace = "pre-wrap"; } });
    document.querySelectorAll(".d-address").forEach(n => n.textContent = S.address);
    document.querySelectorAll(".d-phone").forEach(n => n.textContent = S.phone);
    document.querySelectorAll(".d-email").forEach(n => n.textContent = S.email);
  }
  async function settings() {
    try { const { data, error } = await db.from("school_settings").select("key,value"); if (error) throw error; (data || []).forEach(r => { if (r.value) S[r.key] = r.value; }); } catch (e) { console.error(e); }
    fill();
  }
  // list(box, rows, drawFn, emptyText): safe rendering with loading, empty and error states
  function list(box, rows, draw, empty) {
    box.innerHTML = ""; if (!rows || !rows.length) { box.appendChild(el("div", empty || "Nothing to show yet.", "ph")); return; }
    rows.forEach(r => { const c = el("div", null, "pc"); draw(c, r); box.appendChild(c); });
  }
  async function load(box, query, draw, empty) {
    box.innerHTML = ""; box.appendChild(el("div", "Loading...", "ph"));
    try { const { data, error } = await query; if (error) throw error; list(box, data, draw, empty); }
    catch (e) { console.error(e); box.innerHTML = ""; box.appendChild(el("div", "This information is not available right now. Please try again later.", "state error")); }
  }
  window.P = { el, list, load, S };
  header(); footer(); fill(); settings();
})();
