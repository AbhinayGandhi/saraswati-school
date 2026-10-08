const Gal = {
  // Shrinks photos in the browser before upload to save free-tier storage.
  async resize(file, max = 1600, q = 0.8) {
    const bmp = await createImageBitmap(file); const s = Math.min(1, max / Math.max(bmp.width, bmp.height));
    const c = document.createElement("canvas"); c.width = Math.round(bmp.width * s); c.height = Math.round(bmp.height * s);
    c.getContext("2d").drawImage(bmp, 0, 0, c.width, c.height);
    const blob = await new Promise(r => c.toBlob(r, "image/jpeg", q)); if (!blob) throw new Error("resize failed"); return blob;
  },
  async urls(paths) { if (!paths.length) return {}; const { data, error } = await db.storage.from("gallery").createSignedUrls(paths, 3600); if (error) throw error;
    return Object.fromEntries(data.filter(x => x.signedUrl).map(x => [x.path, x.signedUrl])); },
  async open(bucket, path) { const w = window.open("", "_blank"); const { data, error } = await db.storage.from(bucket).createSignedUrl(path, 300);
    if (error) { w && w.close(); throw error; } w ? (w.location = data.signedUrl) : (location.href = data.signedUrl); }
};
