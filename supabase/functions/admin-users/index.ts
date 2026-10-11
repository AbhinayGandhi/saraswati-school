// Edge Function "admin-users": lets a Super Admin or School Admin create logins and set passwords
// from the website, so nobody needs to open Supabase > Authentication.
// The service-role key stays here on the server (Supabase gives it to the function automatically).
import { createClient } from "npm:@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const ROLES = ["super_admin", "school_admin", "principal", "teacher", "class_teacher", "accountant", "librarian", "reception", "parent", "student"];
const ADMIN_LEVEL = ["super_admin", "school_admin"];

const reply = (status, body) => new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return reply(405, { error: "method" });
  try {
    const url = Deno.env.get("SUPABASE_URL");
    const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!url || !key) return reply(500, { error: "setup", message: "The function has no service key. See SETUP-USERS.md." });
    const admin = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });

    // 1. Who is calling? Check the signed-in token and the role in the database. Never trust the browser.
    const token = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
    if (!token) return reply(401, { error: "auth", message: "Please sign in again." });
    const { data: u, error: ue } = await admin.auth.getUser(token);
    if (ue || !u || !u.user) return reply(401, { error: "auth", message: "Please sign in again." });
    const { data: me } = await admin.from("profiles").select("id, role, is_active").eq("id", u.user.id).single();
    if (!me || !me.is_active || !ADMIN_LEVEL.includes(me.role)) return reply(403, { error: "forbidden", message: "Only Super Admin or School Admin can do this." });
    const isSuper = me.role === "super_admin";

    const body = await req.json().catch(() => ({}));
    const action = body.action;
    const password = typeof body.password === "string" ? body.password : "";
    if (password.length < 8 || password.length > 72) return reply(400, { error: "password", message: "Password must be 8 to 72 characters." });

    if (action === "create") {
      const email = String(body.email || "").trim().toLowerCase();
      const name = String(body.full_name || "").trim().slice(0, 80);
      const role = String(body.role || "");
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 120) return reply(400, { error: "email", message: "Enter a valid email address." });
      if (!name) return reply(400, { error: "name", message: "Enter the person's name." });
      if (!ROLES.includes(role)) return reply(400, { error: "role", message: "Choose a role." });
      if (ADMIN_LEVEL.includes(role) && !isSuper) return reply(403, { error: "forbidden", message: "Only a Super Admin can create admin accounts." });

      const { data: c, error: ce } = await admin.auth.admin.createUser({ email, password, email_confirm: true, user_metadata: { full_name: name } });
      if (ce || !c || !c.user) {
        const dup = /already|registered|exists/i.test((ce && ce.message) || "");
        return reply(dup ? 409 : 400, { error: dup ? "exists" : "create", message: dup ? "This email already has a login." : "Could not create the login. Check the email and password." });
      }
      // The database creates a profile automatically (inactive parent). Set the real role and activate.
      const { error: pe } = await admin.from("profiles").update({ full_name: name, role, is_active: true }).eq("id", c.user.id);
      if (pe) {
        await admin.auth.admin.deleteUser(c.user.id);   // undo, so no half-made account is left behind
        return reply(500, { error: "profile", message: "Could not set the role. Nothing was created. Run supabase/ALL-IN-ONE.sql and try again." });
      }
      await admin.from("audit_logs").insert({ user_id: me.id, action: "User created", module: "profiles", record_id: c.user.id });
      return reply(200, { ok: true, id: c.user.id });
    }

    if (action === "set_password") {
      const id = String(body.user_id || "");
      if (!/^[0-9a-f-]{36}$/i.test(id)) return reply(400, { error: "user", message: "Unknown user." });
      const { data: t } = await admin.from("profiles").select("id, role").eq("id", id).single();
      if (!t) return reply(404, { error: "user", message: "Unknown user." });
      if (ADMIN_LEVEL.includes(t.role) && !isSuper && t.id !== me.id) return reply(403, { error: "forbidden", message: "Only a Super Admin can change an admin's password." });
      const { error: se } = await admin.auth.admin.updateUserById(id, { password });
      if (se) return reply(400, { error: "password", message: "Could not change the password." });
      await admin.from("audit_logs").insert({ user_id: me.id, action: "Password reset by admin", module: "profiles", record_id: id });
      return reply(200, { ok: true });
    }

    return reply(400, { error: "action", message: "Unknown action." });
  } catch (_e) {
    return reply(500, { error: "server", message: "Something went wrong. Please try again." });
  }
});
