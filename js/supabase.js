// Requires the supabase-js UMD script and config.js to load first.
const db = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: { persistSession: true, autoRefreshSession: true, detectSessionInUrl: true }
});
