// Student and teacher photos. Shrinks the picture in the browser (about 400 px) so free storage lasts long.
const Photos = {
  async shrink(file, max = 400) {
    const bmp = await createImageBitmap(file), s = Math.min(1, max / Math.max(bmp.width, bmp.height));
    const c = document.createElement("canvas"); c.width = Math.round(bmp.width * s); c.height = Math.round(bmp.height * s);
    c.getContext("2d").drawImage(bmp, 0, 0, c.width, c.height);
    const b = await new Promise(r => c.toBlob(r, "image/jpeg", 0.82)); if (!b) throw new Error("resize failed"); return b;
  },
  async urls(paths) {
    paths = [...new Set((paths || []).filter(Boolean))]; if (!paths.length) return {};
    const { data, error } = await db.storage.from("photos").createSignedUrls(paths, 3600); if (error) throw error;
    const m = {}; (data || []).forEach(x => { if (x.signedUrl) m[x.path] = x.signedUrl; }); return m;
  },
  async set(table, kind, id, file, old) {
    if (!file || !/^image\//.test(file.type)) throw new Error("Choose a photo (JPG or PNG).");
    const blob = await this.shrink(file), path = `${kind}/${id}-${Date.now()}.jpg`;
    const { error } = await db.storage.from("photos").upload(path, blob, { contentType: "image/jpeg", upsert: false }); if (error) throw error;
    const r = await db.from(table).update({ photo_path: path }).eq("id", id);
    if (r.error) { await db.storage.from("photos").remove([path]); throw r.error; }
    if (old) await db.storage.from("photos").remove([old]);
    return path;
  }
};
