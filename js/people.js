// Generic add/list screen used by teachers.html and staff.html.
const People = { async init(cfg) {
  const form = document.getElementById("f"), list = document.getElementById("list"), q = document.getElementById("q"); let rows = [], pu = {};
  form.innerHTML = cfg.fields.map(f => `<div><label for="${f.id}">${U.esc(f.label)}</label>` + (f.options
    ? `<select id="${f.id}">${f.options.map(o => `<option>${U.esc(o)}</option>`).join("")}</select>`
    : `<input id="${f.id}" type="${f.type || "text"}" ${f.required ? "required" : ""}>`) + "</div>").join("") + '<button class="btn">Add</button>';
  function draw() {
    const t = q.value.trim().toLowerCase(), v = rows.filter(r => !t || JSON.stringify(r).toLowerCase().includes(t));
    if (!v.length) return U.state(list, "empty", rows.length ? "No matches." : "Nothing added yet. Use the form above.");
    list.innerHTML = "<table><thead><tr>" + cfg.cols.map(c => `<th>${U.esc(c[1])}</th>`).join("") + (cfg.photos ? "<th>Photo</th>" : "") + "<th>Status</th><th></th></tr></thead><tbody>" +
      v.map(r => "<tr>" + cfg.cols.map(c => `<td>${U.esc(r[c[0]] === true ? "Yes" : r[c[0]] === false ? "No" : r[c[0]] ?? "")}</td>`).join("") +
        (cfg.photos ? `<td>${pu[r.photo_path] ? `<img class="thumb" src="${U.esc(pu[r.photo_path])}" alt="">` : ""}<label class="btn sm ghost" for="ph-${r.id}">${r.photo_path ? "Change" : "Add"}</label><input id="ph-${r.id}" class="pfile" type="file" accept="image/*" data-ph="${r.id}"></td>` : "") + `<td><span class="badge ${r.status === "active" ? "on" : ""}">${U.esc(r.status)}</span></td><td><button class="btn sm ghost" data-id="${r.id}">${r.status === "active" ? "Deactivate" : "Activate"}</button></td></tr>`).join("") + "</tbody></table>";
  }
  async function load() {
    try { const { data, error } = await db.from(cfg.table).select("*").order("name").limit(500); if (error) throw error; rows = data; if (cfg.photos) { try { pu = await Photos.urls(rows.map(r => r.photo_path)); } catch (e) { pu = {}; } } draw(); }
    catch (e) { U.friendly(e); U.state(list, "error", "Unable to load the list. Please try again."); }
  }
  q.addEventListener("input", U.debounce(draw));
  list.addEventListener("change", async ev => {
    const i = ev.target.closest("input[data-ph]"); if (!i || !i.files[0]) return; const r = rows.find(x => x.id === i.dataset.ph);
    try { await Photos.set(cfg.table, cfg.table, r.id, i.files[0], r.photo_path); U.audit(cfg.label + " photo changed", cfg.table, r.id); U.toast("Photo saved."); load(); }
    catch (e) { U.friendly(e); U.toast(/Choose a photo/.test(e.message || "") ? e.message : "Could not save the photo.", "err"); }
  });
  list.addEventListener("click", async ev => {
    const b = ev.target.closest("button[data-id]"); if (!b) return; const r = rows.find(x => x.id === b.dataset.id);
    const to = r.status === "active" ? "inactive" : "active";
    if (!await U.confirm(`Mark ${r.name} as ${to}?`)) return;
    const { error } = await db.from(cfg.table).update({ status: to }).eq("id", r.id);
    if (error) { U.friendly(error); return U.toast("Could not save the change.", "err"); }
    U.audit(cfg.label + " status changed", cfg.table, r.id); load();
  });
  form.addEventListener("submit", async ev => {
    ev.preventDefault(); const row = {};
    cfg.fields.forEach(f => { const v = document.getElementById(f.id).value.trim(); row[f.id] = v === "" ? null : v; });
    const { data, error } = await db.from(cfg.table).insert(row).select("id").single();
    if (error) { U.friendly(error); return U.toast(error.code === "23505" ? "This employee ID already exists." : "Could not add. Check the details.", "err"); }
    U.audit(cfg.label + " added", cfg.table, data.id); form.reset(); U.toast("Added."); load();
  });
  load();
} };
