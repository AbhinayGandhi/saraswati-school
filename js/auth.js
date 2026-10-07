const Auth = {
  async login(email, password) {
    const { error } = await db.auth.signInWithPassword({ email, password });
    if (error) throw new Error("Incorrect email or password.");
  },
  async logout() { await db.auth.signOut(); location.href = "login.html"; },
  async resetPassword(email) {
    const redirectTo = location.origin + location.pathname.replace(/[^/]*$/, "") + "login.html";
    const { error } = await db.auth.resetPasswordForEmail(email, { redirectTo });
    if (error) throw new Error("Could not send the reset email. Check the address and try again.");
  },
  async profile() {
    const { data: { session } } = await db.auth.getSession();
    if (!session) return null;
    const { data, error } = await db.from("profiles").select("id, full_name, role, is_active").eq("id", session.user.id).single();
    if (error || !data || !data.is_active) return null;
    return data;
  },
  // Call at the top of every protected page. Redirects if not signed in or role not allowed.
  async require(allowed = "*") {
    const p = await Auth.profile();
    if (!p) { location.href = "login.html"; return new Promise(() => {}); }
    if (!Perm.can(p.role, allowed)) { location.href = "dashboard.html"; return new Promise(() => {}); }
    return p;
  },
  // Builds sidebar and top bar; wires mobile drawer.
  shell(p) {
    const links = Perm.navFor(p.role).map(n => `<a href="${n.href}"${location.pathname.endsWith(n.href) ? ' aria-current="page"' : ""}>${U.esc(n.label)}</a>`).join("");
    document.getElementById("sidebar").innerHTML = `<div class="brand">${U.esc(SCHOOL_NAME)}</div><nav aria-label="Main">${links}</nav>`;
    document.getElementById("who").textContent = `${p.full_name || "User"} (${p.role.replace("_", " ")})`;
    const sb = document.getElementById("sidebar"), btn = document.getElementById("menu");
    btn.addEventListener("click", () => { const o = sb.classList.toggle("open"); btn.setAttribute("aria-expanded", o); });
    document.getElementById("logout").addEventListener("click", Auth.logout);
  }
};
