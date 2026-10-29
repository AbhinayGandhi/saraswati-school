// Saraswati bus GPS receiver (Supabase Edge Function, Deno).
// Phones or devices that send their location in the background (Traccar Client for Android and iPhone, OwnTracks, ...)
// send it here. The secret bus key goes in the "id" (device identifier). This function only passes the position to the
// database function gps_ingest(), which checks the key and starts/ends the trip by itself.
// Deploy with "Verify JWT" switched OFF (these apps cannot send a login token). The anon key is read from the function's own environment.

type Env = Record<string, string | undefined>;
const CORS = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "*", "Access-Control-Allow-Methods": "GET, POST, OPTIONS" };
const T = (status: number, body: string) => new Response(body, { status, headers: { ...CORS, "Content-Type": "text/plain" } });

const num = (v: unknown): number | null => { if (v === undefined || v === null || v === "") return null; const n = Number(v); return Number.isFinite(n) ? n : null; };

// Reads the message from the URL, a form body or a JSON body (OwnTracks).
export async function readFields(req: Request): Promise<Record<string, unknown>> {
  const f: Record<string, unknown> = {};
  new URL(req.url).searchParams.forEach((v, k) => { f[k.toLowerCase()] = v; });
  if (req.method === "POST") {
    const raw = (await req.text()).slice(0, 20_000);
    const ct = req.headers.get("content-type") ?? "";
    if (raw) {
      if (ct.includes("json") || raw.trim().startsWith("{")) {
        try { const j = JSON.parse(raw); if (j && typeof j === "object") { for (const [k, v] of Object.entries(j as Record<string, unknown>)) f[k.toLowerCase()] = v; const loc = (j as Record<string, unknown>).location; if (loc && typeof loc === "object") { const c = ((loc as Record<string, unknown>).coords ?? loc) as Record<string, unknown>; for (const [k, v] of Object.entries(c)) f[k.toLowerCase()] = v; } } } catch { /* ignore */ }
      } else { new URLSearchParams(raw).forEach((v, k) => { if (!(k.toLowerCase() in f)) f[k.toLowerCase()] = v; }); }
    }
  }
  return f;
}

// Works out latitude, longitude, speed (km/h), heading and accuracy from the different app formats.
export function normalise(f: Record<string, unknown>) {
  const lat = num(f.lat ?? f.latitude), lng = num(f.lon ?? f.lng ?? f.longitude);
  let kmh: number | null = null;
  if (f.vel !== undefined) kmh = num(f.vel);                                   // OwnTracks: km/h
  else if (f.speed !== undefined) {
    const s = num(f.speed), unit = String(f.speed_unit ?? f.unit ?? "kn").toLowerCase();  // Traccar Client sends knots
    if (s !== null) kmh = unit.startsWith("k") && unit !== "kn" && unit !== "knots" ? s : unit === "ms" || unit === "m/s" ? s * 3.6 : s * 1.852;
  }
  const heading = num(f.bearing ?? f.heading ?? f.cog ?? f.course), acc = num(f.accuracy ?? f.acc ?? f.hdop);
  const token = String(f.id ?? f.token ?? f.key ?? f.deviceid ?? f.tid ?? "").trim();
  return { token, lat, lng, kmh, heading, acc };
}

export async function handle(req: Request, env: Env): Promise<Response> {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "GET" && req.method !== "POST") return T(405, "method");
  const supa = env.SUPABASE_URL, anon = env.SUPABASE_ANON_KEY;
  if (!supa || !anon) return T(500, "setup");
  let f: Record<string, unknown>;
  try { f = await readFields(req); } catch { return T(400, "bad request"); }
  // OwnTracks sends other message types (waypoints, status): accept and ignore them.
  if (f._type !== undefined && f._type !== "location") return T(200, "[]");
  const p = normalise(f);
  if (p.token.length < 32 || p.token.length > 80 || !/^[A-Za-z0-9_-]+$/.test(p.token)) return T(401, "bad key");
  if (p.lat === null || p.lng === null) return T(400, "no position");
  try {
    const r = await fetch(`${supa}/rest/v1/rpc/gps_ingest`, {
      method: "POST", headers: { "Content-Type": "application/json", apikey: anon, Authorization: `Bearer ${anon}` },
      body: JSON.stringify({ p_token: p.token, p_lat: p.lat, p_lng: p.lng, p_speed_kmh: p.kmh, p_heading: p.heading, p_acc: p.acc }),
    });
    if (!r.ok) return T(502, "upstream");
    const d = await r.json();
    if (d && d.ok === false) return T(d.error === "bad_key" ? 401 : 400, String(d.error));
    return T(200, f._type !== undefined ? "[]" : "OK");
  } catch { return T(502, "upstream"); }
}

// deno-lint-ignore no-explicit-any
const D = (globalThis as any).Deno;
if (D && D.serve && !D.env.get("GPS_NO_SERVE")) D.serve((req: Request) => handle(req, D.env.toObject()));
