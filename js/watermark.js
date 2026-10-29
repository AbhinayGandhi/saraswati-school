/* Faint school-logo watermark on every page, including printed receipts and certificates.
   Uses the logo saved in Settings. No logo or Settings switch "off" = nothing is drawn. */
(function () {
  function go() {
    try {
      if (typeof db === "undefined" || document.getElementById("wm")) return;
      db.from("school_settings").select("key,value").in("key", ["logo_path", "watermark"]).then(function (r) {
        var m = {}; ((r && r.data) || []).forEach(function (x) { m[x.key] = x.value; });
        if (!m.logo_path || m.watermark === "off") return;
        var u = db.storage.from("branding").getPublicUrl(m.logo_path).data.publicUrl; if (!u) return;
        var st = document.createElement("style");
        st.textContent = "#wm{position:fixed;inset:0;z-index:0;pointer-events:none;display:flex;align-items:center;justify-content:center}#wm img{width:min(55vmin,420px);max-width:70%;opacity:.07;filter:grayscale(.2)}@media print{#wm{position:fixed;inset:0}#wm img{width:110mm;opacity:.09;-webkit-print-color-adjust:exact;print-color-adjust:exact}}main,.hero,header.sh,header.top{position:relative;z-index:1}";
        document.head.appendChild(st);
        var d = document.createElement("div"); d.id = "wm"; d.setAttribute("aria-hidden", "true");
        var i = document.createElement("img"); i.alt = ""; i.src = u; i.onerror = function () { d.remove(); };
        d.appendChild(i); document.body.appendChild(d);
      }, function () { });
    } catch (e) { }
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", go); else go();
})();
