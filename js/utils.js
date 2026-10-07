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
  async audit(action, module, recordId) {
    const { data: { user } } = await db.auth.getUser();
    if (!user) return;
    await db.from("audit_logs").insert({ user_id: user.id, action, module, record_id: recordId ?? null });
  }
};
