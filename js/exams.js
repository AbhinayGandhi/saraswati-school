const Ex = {
  async rules() { const { data, error } = await db.from("grading_rules").select("*").order("min_pct", { ascending: false }); if (error) throw error; return data; },
  grade(rules, pct) { for (const r of rules) if (pct >= Number(r.min_pct)) return r.grade; return "F"; },
  // subs: exam_subjects rows; mk: map "esId|enrId" -> {marks, absent}
  calc(subs, mk, enr, rules) {
    let tot = 0, max = 0, pass = true, incomplete = false;
    const cells = subs.map(s => { const m = mk[s.id + "|" + enr]; max += Number(s.max_marks);
      if (!m) { incomplete = true; return { v: "-", f: false }; }
      if (m.absent) { pass = false; return { v: "AB", f: true }; }
      if (m.marks === null) { incomplete = true; return { v: "-", f: false }; }
      tot += Number(m.marks); const f = Number(m.marks) < Number(s.passing_marks); if (f) pass = false; return { v: Number(m.marks), f }; });
    const pct = max ? Math.round(tot / max * 10000) / 100 : 0;
    return { cells, tot, max, pct, grade: Ex.grade(rules, pct), result: incomplete ? "Incomplete" : pass ? "Pass" : "Fail" };
  },
  async yearSelect(el) { const { data, error } = await db.from("academic_years").select("id,name,is_active").order("start_date", { ascending: false }); if (error) throw error;
    el.innerHTML = data.map(a => `<option value="${a.id}"${a.is_active ? " selected" : ""}>${U.esc(a.name)}</option>`).join(""); return data; },
  async examSelect(el, year) { const { data, error } = await db.from("exams").select("id,name,status").eq("academic_year_id", year).order("created_at"); if (error) throw error;
    el.innerHTML = data.map(a => `<option value="${a.id}">${U.esc(a.name)}${a.status === "published" ? " (published)" : ""}</option>`).join(""); return data; }
};
