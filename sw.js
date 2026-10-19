/* Service worker: lets the site be installed on a phone and shows a friendly page when offline.
   It handles files from this website and the supabase-js library (so attendance pages open offline). School data comes from Supabase (another address) and is never stored here. */
const CACHE = "ses-v10";
const SHELL = ["offline.html", "css/style.css", "css/public.css", "css/print.css", "images/icon-192.png"];
self.addEventListener("install", e => {
  e.waitUntil(caches.open(CACHE).then(c => Promise.all(SHELL.map(u => c.add(u).catch(() => null)))).then(() => self.skipWaiting()));
});
self.addEventListener("activate", e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener("fetch", e => {
  const r = e.request, u = new URL(r.url);
  const cdn = u.hostname === "cdn.jsdelivr.net" || u.hostname === "cdnjs.cloudflare.com";
  if (r.method !== "GET" || (u.origin !== self.location.origin && !cdn)) return;
  e.respondWith(fetch(r).then(res => {
    if (res && (res.ok || (cdn && res.type === "opaque"))) { const copy = res.clone(); caches.open(CACHE).then(c => c.put(r, copy)).catch(() => null); }
    return res;
  }).catch(() => caches.match(r, { ignoreSearch: true }).then(hit => hit || (r.mode === "navigate" ? caches.match("offline.html") : Response.error()))));
});
