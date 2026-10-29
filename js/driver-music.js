/* Driver page music: the driver keeps his own albums (folders) of songs.
   A song is a link: YouTube video/playlist, Spotify track/album/playlist, or a direct audio / radio stream link.
   Songs play inside this page, so the screen stays on and tracking keeps running. Albums are saved only on this phone. */
const DMusic = (() => {
  const KEY = "ses_music";
  let data = { albums: [{ id: "a1", name: "My songs", items: [] }], a: "a1", i: -1 }, box, yt = null, ytReady = null, audio = null;
  const load = () => { try { const d = JSON.parse(localStorage.getItem(KEY) || "null"); if (d && Array.isArray(d.albums) && d.albums.length) data = d; } catch (e) { } };
  const save = () => { try { localStorage.setItem(KEY, JSON.stringify(data)); } catch (e) { } };
  const E = (tag, txt, cls) => { const x = document.createElement(tag); if (txt != null) x.textContent = txt; if (cls) x.className = cls; return x; };
  const album = () => data.albums.find(a => a.id === data.a) || data.albums[0];

  function parse(u) {
    u = String(u || "").trim(); let m;
    if (!/^https:\/\//i.test(u)) return null;
    let url; try { url = new URL(u); } catch (e) { return null; }
    const h = url.hostname.replace(/^www\.|^m\./, "");
    if (h === "youtu.be") { const v = url.pathname.slice(1); return /^[\w-]{6,20}$/.test(v) ? { k: "yt", v, l: url.searchParams.get("list") } : null; }
    if (h === "youtube.com" || h === "music.youtube.com") {
      const v = url.searchParams.get("v"), l = url.searchParams.get("list");
      if (v && /^[\w-]{6,20}$/.test(v)) return { k: "yt", v, l: l && /^[\w-]{6,60}$/.test(l) ? l : null };
      if (l && /^[\w-]{6,60}$/.test(l)) return { k: "yt", v: null, l };
      return null;
    }
    if (h === "open.spotify.com" && (m = url.pathname.match(/\/(track|album|playlist|episode|show)\/([A-Za-z0-9]{10,30})/))) return { k: "sp", t: m[1], id: m[2] };
    return { k: "au", u: url.href };
  }
  function stop() {
    try { if (audio) { audio.pause(); audio.removeAttribute("src"); audio = null; } } catch (e) { }
    try { if (yt && yt.destroy) { yt.destroy(); } } catch (e) { } yt = null;
    const p = box.querySelector("#mpl"); if (p) p.textContent = "";
  }
  function needYT() {
    if (ytReady) return ytReady;
    ytReady = new Promise((ok, no) => {
      if (window.YT && YT.Player) return ok();
      const prev = window.onYouTubeIframeAPIReady; window.onYouTubeIframeAPIReady = () => { try { if (prev) prev(); } catch (e) { } ok(); };
      const s = document.createElement("script"); s.src = "https://www.youtube.com/iframe_api"; s.onerror = () => { ytReady = null; no(); }; document.head.appendChild(s);
    });
    return ytReady;
  }
  function msg(t) { const m = box.querySelector("#mmsg"); if (m) m.textContent = t || ""; }
  async function play(i) {
    const al = album(), it = al.items[i]; if (!it) return;
    stop(); msg(""); data.i = i; save(); draw();
    const t = parse(it.u), p = box.querySelector("#mpl");
    if (!t) return msg("This link cannot be played. / ही लिंक चालत नाही.");
    if (t.k === "au") {
      audio = new Audio(t.u); audio.controls = true; audio.style.width = "100%"; p.appendChild(audio);
      audio.onended = () => next(); audio.onerror = () => msg("Could not play this link. / ही लिंक वाजली नाही.");
      audio.play().catch(() => msg("Tap play on the player. / प्लेयरवर Play दाबा."));
    } else if (t.k === "sp") {
      const f = document.createElement("iframe"); f.src = "https://open.spotify.com/embed/" + t.t + "/" + t.id; f.style.cssText = "width:100%;height:" + (t.t === "track" || t.t === "episode" ? "152" : "352") + "px;border:0;border-radius:12px"; f.allow = "autoplay; clipboard-write; encrypted-media; fullscreen; picture-in-picture"; f.loading = "lazy"; p.appendChild(f);
    } else {
      const d = E("div"); d.id = "ytp"; p.appendChild(d);
      try { await needYT(); } catch (e) { return msg("YouTube could not load. Check the internet. / YouTube उघडले नाही. इंटरनेट तपासा."); }
      const vars = { playsinline: 1, autoplay: 1, rel: 0 }; if (t.l) vars.list = t.l;
      yt = new YT.Player("ytp", { width: "100%", height: "220", videoId: t.v || undefined, playerVars: vars, events: { onStateChange: e => { if (e.data === 0 && !t.l) next(); }, onError: () => msg("This video cannot be played here. Try another. / हा व्हिडिओ इथे चालत नाही. दुसरा लावा.") } });
    }
  }
  function next(d) { const n = album().items.length; if (!n) return; play(((data.i < 0 ? -1 : data.i) + (d || 1) + n) % n); }

  function draw() {
    const al = album(), sel = box.querySelector("#msel"), ls = box.querySelector("#mls");
    sel.textContent = ""; data.albums.forEach(a => { const o = E("option", a.name + " (" + a.items.length + ")"); o.value = a.id; if (a.id === al.id) o.selected = true; sel.appendChild(o); });
    ls.textContent = "";
    if (!al.items.length) ls.appendChild(E("p", "No songs yet. Add a link below. / अजून गाणी नाहीत. खाली लिंक टाका."));
    al.items.forEach((it, i) => {
      const r = E("div", null, "mrow"); r.style.cssText = "display:flex;gap:.4rem;align-items:center;margin:.25rem 0";
      const b = E("button", (i === data.i ? "▶ " : "") + (it.t || it.u), "btn ghost sm"); b.type = "button"; b.style.cssText = "flex:1;text-align:left;overflow:hidden;text-overflow:ellipsis;white-space:nowrap"; b.onclick = () => play(i);
      const x = E("button", "✕", "btn ghost sm"); x.type = "button"; x.setAttribute("aria-label", "Remove"); x.onclick = () => { if (!confirm("Remove this song? / हे गाणे काढायचे?")) return; al.items.splice(i, 1); if (data.i === i) { stop(); data.i = -1 } else if (data.i > i) data.i--; save(); draw(); };
      r.append(b, x); ls.appendChild(r);
    });
  }
  function mount(el) {
    box = el; load();
    box.innerHTML = '<details><summary style="font-weight:700;cursor:pointer;font-size:1.05rem">Music / संगीत</summary>' +
      '<p style="font-size:.9rem;margin:.4rem 0"><b>Set the music before you start driving. Do not use the phone while the bus is moving.</b><br>गाडी चालू करण्यापूर्वी संगीत लावा. बस चालू असताना फोन वापरू नका.</p>' +
      '<label for="msel">Album (your folder) / अल्बम</label><div style="display:flex;gap:.4rem"><select id="msel" style="flex:1"></select><button class="btn ghost sm" id="mdel" type="button">Delete album</button></div>' +
      '<div style="display:flex;gap:.4rem;margin:.4rem 0"><input id="mnew" maxlength="30" placeholder="New album name / नवा अल्बम" style="flex:1"><button class="btn ghost sm" id="madd" type="button">Create</button></div>' +
      '<div id="mls"></div><div id="mpl" style="margin:.5rem 0"></div><div id="mmsg" class="st" role="status" aria-live="polite"></div>' +
      '<div style="display:flex;gap:.4rem;margin:.4rem 0"><button class="btn ghost sm" id="mpv" type="button">⏮ Previous</button><button class="btn ghost sm" id="mst" type="button">Stop</button><button class="btn ghost sm" id="mnx" type="button">Next ⏭</button></div>' +
      '<label for="mt">Song name (optional) / गाण्याचे नाव</label><input id="mt" maxlength="80">' +
      '<label for="mu">Link: YouTube, Spotify or radio/audio link / लिंक</label><input id="mu" inputmode="url" maxlength="300" placeholder="https://...">' +
      '<p><button class="btn" id="mad" type="button">Add to this album / अल्बममध्ये टाका</button></p>' +
      '<p style="font-size:.85rem">Find songs in your own app, copy the link and paste it here. / आपल्या ॲपमध्ये गाणे शोधून लिंक कॉपी करा आणि इथे टाका.<br><a href="https://m.youtube.com/" target="_blank" rel="noopener">YouTube</a> | <a href="https://music.youtube.com/" target="_blank" rel="noopener">YouTube Music</a> | <a href="https://open.spotify.com/" target="_blank" rel="noopener">Spotify</a></p></details>';
    const $ = id => box.querySelector("#" + id);
    $("msel").onchange = () => { stop(); data.a = $("msel").value; data.i = -1; save(); draw(); };
    $("madd").onclick = () => { const n = $("mnew").value.trim(); if (!n) return; const id = "a" + Date.now(); data.albums.push({ id, name: n.slice(0, 30), items: [] }); data.a = id; data.i = -1; $("mnew").value = ""; stop(); save(); draw(); };
    $("mdel").onclick = () => { if (data.albums.length < 2) return msg("Keep at least one album. / किमान एक अल्बम ठेवा."); if (!confirm("Delete this album and its songs? / हा अल्बम आणि त्यातील गाणी काढायची?")) return; stop(); data.albums = data.albums.filter(a => a.id !== data.a); data.a = data.albums[0].id; data.i = -1; save(); draw(); };
    $("mad").onclick = () => { const u = $("mu").value.trim(); if (!parse(u)) return msg("Paste a full link starting with https:// / https:// ने सुरू होणारी पूर्ण लिंक टाका."); const al = album(); if (al.items.length >= 100) return msg("Album is full (100 songs)."); al.items.push({ t: $("mt").value.trim().slice(0, 80), u: u.slice(0, 300) }); $("mu").value = ""; $("mt").value = ""; msg(""); save(); draw(); };
    $("mnx").onclick = () => next(1); $("mpv").onclick = () => next(-1); $("mst").onclick = () => { stop(); data.i = -1; draw(); };
    draw();
  }
  return { mount, parse };
})();
