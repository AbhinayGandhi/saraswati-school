const Auth = {
  async login(email, password) {
    const { error } = await db.auth.signInWithPassword({ email, password });
    if (error) {
      console.error(error);
      // Wrong password and unknown user are the normal cases; anything else is a server problem, so show its real message.
      if (error.status === 400 && /invalid login|invalid_credentials/i.test((error.code || "") + " " + (error.message || ""))) throw new Error("Incorrect email or password.");
      throw new Error("Sign-in problem: " + (error.message || "unknown error") + (error.status ? " (code " + error.status + ")" : ""));
    }
  },
  async logout() { if (typeof Offline !== "undefined") Offline.clear(); try { await db.auth.signOut(); } catch (e) { } location.href = "login.html"; },
  async resetPassword(email) {
    const redirectTo = location.origin + location.pathname.replace(/[^/]*$/, "") + "login.html";
    const { error } = await db.auth.resetPasswordForEmail(email, { redirectTo });
    if (error) throw new Error("Could not send the reset email. Check the address and try again.");
  },
  async profile() {
    // Offline: the last signed-in profile is reused so offline attendance pages can open. Real access is still enforced by the server (RLS) when data is sent.
    let session = null;
    try { const r = await db.auth.getSession(); session = r.data && r.data.session; } catch (e) { }
    const cached = typeof Offline !== "undefined" ? Offline.get("prof") : null;
    if (!session) return cached && navigator.onLine === false ? cached : null;
    const { data, error } = await db.from("profiles").select("id, full_name, role, is_active").eq("id", session.user.id).single();
    if (error && cached && cached.id === session.user.id && typeof Offline !== "undefined" && Offline.isNet(error)) return cached;
    if (error || !data || !data.is_active) return null;
    if (typeof Offline !== "undefined") Offline.set("prof", data);
    return data;
  },
  // Call at the top of every protected page. Redirects if not signed in or role not allowed.
  async require(allowed = "*") {
    const p = await Auth.profile();
    if (!p) { location.href = "login.html"; return new Promise(() => {}); }
    if (!Perm.can(p.role, allowed)) { location.href = "dashboard.html"; return new Promise(() => {}); }
    return p;
  },
  // Parent/student portal switches set by the school (settings "Show to parents and students"). Cosmetic only; data rules stay in RLS.
  async hidden() {
    if (Auth._hid) return Auth._hid;
    try { const { data } = await db.rpc("portal_hidden"); Auth._hid = new Set(String(data || "").split(",").filter(Boolean)); } catch (e) { Auth._hid = new Set(); }
    return Auth._hid;
  },
  // Builds sidebar and top bar; wires mobile drawer.
  shell(p) {
    const links = Perm.navFor(p.role).map(n => `<a href="${n.href}"${location.pathname.endsWith(n.href) ? ' aria-current="page"' : ""}>${U.esc(n.label)}</a>`).join("");
    document.getElementById("sidebar").innerHTML = `<div class="brand">${U.esc(SCHOOL_NAME)}</div><nav aria-label="Main">${links}</nav>`;
    if (p.role === "parent" || p.role === "student") Auth.hidden().then(h => { if (h.has("bus")) document.querySelectorAll('#sidebar a[href="track-bus.html"]').forEach(a => a.remove()); });
    document.getElementById("who").textContent = `${p.full_name || "User"} (${p.role.replace("_", " ")})`;
    const sb = document.getElementById("sidebar"), btn = document.getElementById("menu");
    btn.addEventListener("click", () => { const o = sb.classList.toggle("open"); btn.setAttribute("aria-expanded", o); });
    document.getElementById("logout").addEventListener("click", Auth.logout);
    const nb = document.createElement("a"); nb.href = "notifications.html"; nb.className = "btn ghost"; nb.textContent = "Notifications";
    document.querySelector(".top").insertBefore(nb, document.getElementById("logout"));
    db.from("notifications").select("id", { count: "exact", head: true }).eq("is_read", false).then(({ count }) => { if (count) nb.textContent = "Notifications (" + count + ")"; });
  }
};
