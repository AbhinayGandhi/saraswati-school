/* Makes the site installable ("Add to Home screen") and registers the service worker. Loaded from i18n.js on every page. */
(function () {
  try {
    var h = document.head;
    if (!document.querySelector('link[rel="manifest"]')) { var m = document.createElement("link"); m.rel = "manifest"; m.href = "manifest.json"; h.appendChild(m); }
    if (!document.querySelector('meta[name="theme-color"]')) { var t = document.createElement("meta"); t.name = "theme-color"; t.content = "#16233b"; h.appendChild(t); }
    if (!document.querySelector('link[rel="apple-touch-icon"]')) { var a = document.createElement("link"); a.rel = "apple-touch-icon"; a.href = "images/icon-192.png"; h.appendChild(a); }
    if ("serviceWorker" in navigator && (location.protocol === "https:" || location.hostname === "localhost" || location.hostname === "127.0.0.1")) {
      window.addEventListener("load", function () { navigator.serviceWorker.register("sw.js").catch(function () { }); });
    }
    var deferred = null;
    window.addEventListener("beforeinstallprompt", function (e) {
      e.preventDefault(); deferred = e;
      var bar = document.querySelector(".top") || document.querySelector(".sh .in"); if (!bar || document.getElementById("installbtn")) return;
      var b = document.createElement("button"); b.id = "installbtn"; b.type = "button"; b.className = "btn ghost"; b.textContent = "Install app";
      b.onclick = function () { if (!deferred) return; deferred.prompt(); deferred.userChoice.then(function () { deferred = null; b.remove(); }); };
      bar.appendChild(b);
    });
  } catch (e) { }
})();
