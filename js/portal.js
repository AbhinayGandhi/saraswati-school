// Parent and student portal. Everything shown here is enforced by Row Level Security in the database; the page only asks for it.
const Portal = {
  async init(p, mode) {
    const $ = id => document.getElementById(id), pane = $("pane");
    const TABS = [["profile", "Profile"], ["attendance", "Attendance"], ["results", "Results"], ["homework", "Homework"], ["timetable", "Timetable"]]
      .concat(mode === "parent" ? [["fees", "Fees"]] : [], [["activities", "Activities"]], mode === "parent" ? [["library", "Library"]] : [], [["notices", "Notices and events"]]);
    let kids = [], cur = null, tab = "profile", rules = [], hwSub = "", hwFrom = "";
    const nm = s => [s.first_name, s.middle_name, s.last_name].filter(Boolean).join(" ");
    const none = m => `<div class="state">${U.esc(m)}</div>`, noEnr = none("This student is not enrolled in a class yet.");
    try {
      const { data, error } = await db.from("students").select("id,first_name,middle_name,last_name,admission_no,gr_no,gender,dob,blood_group,house,student_enrollments(id,roll_no,division_id,academic_year_id,academic_years(name,is_active,start_date),divisions(name,classes(name)))");
      if (error) throw error;
      kids = data.map(s => { const es = [...s.student_enrollments].sort((a, b) => (b.academic_years.is_active - a.academic_years.is_active) || b.academic_years.start_date.localeCompare(a.academic_years.start_date)); return { s, e: es[0] || null }; });
    } catch (e) { U.friendly(e); return U.state(pane, "error", "Unable to load. Please try again."); }
    if (!kids.length) return U.state(pane, "empty", "No student is linked to your login yet. Please contact the school office.");
    cur = kids[0];
    $("kw").innerHTML = kids.length > 1 ? `<div><label for="ks">Child</label><select id="ks">${kids.map((k, i) => `<option value="${i}">${U.esc(nm(k.s))}</option>`).join("")}</select></div>` : `<h2>${U.esc(nm(cur.s))}</h2>`;
    $("tb").innerHTML = TABS.map(t => `<button class="btn ${t[0] === tab ? "" : "ghost"} sm" data-t="${t[0]}">${t[1]}</button>`).join("");
    const T = v => String(v || "").slice(0, 5), DAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
    const R = {
      async profile(k) {
        const { data: g, error } = await db.from("student_guardians").select("relation,name,mobile,email,address").eq("student_id", k.s.id); if (error) throw error;
        return `<div class="panel"><h2>${U.esc(nm(k.s))}</h2><p>Admission no: ${U.esc(k.s.admission_no)} | GR no: ${U.esc(k.s.gr_no || "-")} | Class: ${U.esc(k.e ? k.e.divisions.classes.name + " - " + k.e.divisions.name : "-")} | Roll no: ${U.esc(k.e?.roll_no ?? "-")}<br>Date of birth: ${U.esc(k.s.dob)} | Gender: ${U.esc(k.s.gender)}${k.s.blood_group ? " | Blood group: " + U.esc(k.s.blood_group) : ""}${k.s.house ? " | House: " + U.esc(k.s.house) : ""}</p></div>
<div class="panel"><h3>Parents and guardians</h3>${g.length ? g.map(x => `<p><b>${U.esc(x.relation)}</b>: ${U.esc(x.name)} ${U.esc(x.mobile || "")} ${U.esc(x.email || "")}<br>${U.esc(x.address || "")}</p>`).join("") : "<p>No details recorded.</p>"}</div>`;
      },
      async attendance(k) {
        if (!k.e) return noEnr;
        const { data, error } = await db.from("attendance").select("att_date,status").eq("enrollment_id", k.e.id).order("att_date").limit(400); if (error) throw error;
        if (!data.length) return none("No attendance has been marked yet.");
        const m = {}; data.forEach(r => { const o = m[r.att_date.slice(0, 7)] = m[r.att_date.slice(0, 7)] || { present: 0, absent: 0, late: 0, half_day: 0, leave: 0 }; o[r.status]++; });
        const pct = o => { const n = o.present + o.absent + o.late + o.half_day + o.leave; return n ? Math.round((o.present + o.late + o.half_day * 0.5) / n * 100) + "%" : "-"; };
        const tot = { present: 0, absent: 0, late: 0, half_day: 0, leave: 0 }; Object.values(m).forEach(o => Object.keys(tot).forEach(x => tot[x] += o[x]));
        const abs = data.filter(r => r.status === "absent").slice(-10).reverse();
        return `<div class="card"><b>${pct(tot)}</b>Attendance this year (${data.length} days marked)</div><div class="tw" style="margin-top:1rem"><table><thead><tr><th>Month</th><th>Present</th><th>Absent</th><th>Late</th><th>Half day</th><th>Leave</th><th>%</th></tr></thead><tbody>${Object.entries(m).map(([k2, o]) => `<tr><td>${U.esc(k2)}</td><td>${o.present}</td><td>${o.absent}</td><td>${o.late}</td><td>${o.half_day}</td><td>${o.leave}</td><td>${pct(o)}</td></tr>`).join("")}</tbody></table></div>${abs.length ? `<p><b>Recent absences:</b> ${abs.map(r => U.esc(r.att_date)).join(", ")}</p>` : ""}`;
      },
      async results(k) {
        if (!k.e) return noEnr;
        const { data: ex, error } = await db.from("exams").select("id,name").eq("academic_year_id", k.e.academic_year_id).eq("status", "published").order("created_at"); if (error) throw error;
        if (!ex.length) return none("No results have been published yet.");
        rules = rules.length ? rules : await Ex.rules();
        const { data: subs, error: e2 } = await db.from("exam_subjects").select("id,exam_id,max_marks,passing_marks,subjects(name,sort_order)").eq("division_id", k.e.division_id).in("exam_id", ex.map(x => x.id)); if (e2) throw e2;
        const { data: m, error: e3 } = subs.length ? await db.from("marks").select("exam_subject_id,enrollment_id,marks,absent").eq("enrollment_id", k.e.id).in("exam_subject_id", subs.map(x => x.id)) : { data: [] }; if (e3) throw e3;
        const mk = Object.fromEntries(m.map(x => [x.exam_subject_id + "|" + x.enrollment_id, x]));
        return ex.map(x => { const s = subs.filter(y => y.exam_id === x.id).sort((a, b) => a.subjects.sort_order - b.subjects.sort_order || a.subjects.name.localeCompare(b.subjects.name)); if (!s.length) return "";
          const r = Ex.calc(s, mk, k.e.id, rules);
          return `<div class="panel"><h3>${U.esc(x.name)}</h3><div class="tw"><table><thead><tr><th>Subject</th><th>Maximum</th><th>Obtained</th></tr></thead><tbody>${s.map((y, i) => `<tr><td>${U.esc(y.subjects.name)}</td><td>${y.max_marks}</td><td${r.cells[i].f ? ' style="color:var(--bad)"' : ""}>${U.esc(r.cells[i].v)}</td></tr>`).join("")}<tr><th>Total</th><th>${r.max}</th><th>${r.tot}</th></tr></tbody></table></div><p>Percentage: <b>${r.pct}%</b> | Grade: <b>${U.esc(r.grade)}</b> | Result: <b>${U.esc(r.result)}</b></p><a class="btn sm" href="report-card.html?exam=${x.id}&e=${k.e.id}">Open report card</a></div>`; }).join("") || none("No results to show.");
      },
      async homework(k) {
        if (!k.e) return noEnr;
        const { data, error } = await db.from("homework").select("id,title,description,homework_date,due_date,attachment_path,subjects(name)").eq("division_id", k.e.division_id).eq("academic_year_id", k.e.academic_year_id).eq("status", "active").order("homework_date", { ascending: false }).limit(60); if (error) throw error;
        k.hw = data; const subs = [...new Set(data.map(x => x.subjects.name))].sort(), v = data.filter(x => (!hwSub || x.subjects.name === hwSub) && (!hwFrom || x.homework_date >= hwFrom));
        return `<div class="row"><div><label for="hs">Subject</label><select id="hs"><option value="">All</option>${subs.map(s => `<option${s === hwSub ? " selected" : ""}>${U.esc(s)}</option>`).join("")}</select></div><div><label for="hf">From date</label><input id="hf" type="date" value="${U.esc(hwFrom)}"></div></div>` +
          (v.length ? v.map(h => `<div class="card" style="margin-bottom:.8rem"><h3>${U.esc(h.title)}</h3><p><b>${U.esc(h.subjects.name)}</b> | Given ${U.esc(h.homework_date)} | Due ${U.esc(h.due_date)}</p><p style="white-space:pre-wrap">${U.esc(h.description || "")}</p>${h.attachment_path ? `<button class="btn sm ghost" data-hw="${h.id}">Open attachment</button>` : ""}</div>`).join("") : none("No homework found."));
      },
      async timetable(k) {
        if (!k.e) return noEnr;
        const [s, t] = await Promise.all([db.from("timetable_slots").select("day,period,start_time,end_time,room,teacher_id,subjects(name)").eq("division_id", k.e.division_id).eq("academic_year_id", k.e.academic_year_id).eq("is_active", true), db.from("teacher_names").select("id,full_name")]);
        if (s.error || t.error) throw s.error || t.error; if (!s.data.length) return none("The timetable has not been set yet.");
        const per = [...new Set(s.data.map(x => x.period))].sort((a, b) => a - b), tn = id => t.data.find(x => x.id === id)?.full_name || "";
        return `<div class="tw"><table><thead><tr><th>Period</th>${DAYS.map(d => `<th>${d}</th>`).join("")}</tr></thead><tbody>${per.map(n => `<tr><th>${n}</th>${DAYS.map((d, i) => { const x = s.data.find(y => y.period === n && y.day === i + 1); return x ? `<td><b>${U.esc(x.subjects.name)}</b><br><small>${U.esc(tn(x.teacher_id))}${x.room ? " | Room " + U.esc(x.room) : ""}<br>${T(x.start_time)}-${T(x.end_time)}</small></td>` : "<td></td>"; }).join("")}</tr>`).join("")}</tbody></table></div>`;
      },
      async fees(k) {
        if (!k.e) return noEnr;
        const [f, pay] = await Promise.all([db.from("student_fees").select("assigned_amount,concession_amount,paid_amount,balance,due_date,status,fee_types(name)").eq("enrollment_id", k.e.id), db.from("fee_payments").select("receipt_no,amount,payment_date,mode,student_fees!inner(enrollment_id)").eq("student_fees.enrollment_id", k.e.id).order("payment_date", { ascending: false }).limit(100)]);
        if (f.error || pay.error) throw f.error || pay.error; if (!f.data.length) return none("No fees have been assigned yet.");
        const sum = c => f.data.reduce((a, x) => a + Number(x[c]), 0), rc = {}; pay.data.forEach(x => { const r = rc[x.receipt_no] = rc[x.receipt_no] || { d: x.payment_date, m: x.mode, a: 0 }; r.a += Number(x.amount); });
        return `<div class="grid"><div class="card"><b>${Fee.inr(sum("assigned_amount"))}</b>Total fee</div><div class="card"><b>${Fee.inr(sum("concession_amount"))}</b>Concession</div><div class="card"><b>${Fee.inr(sum("paid_amount"))}</b>Paid</div><div class="card"><b>${Fee.inr(sum("balance"))}</b>Outstanding</div></div>
<div class="tw" style="margin-top:1rem"><table><thead><tr><th>Fee</th><th>Amount</th><th>Concession</th><th>Paid</th><th>Balance</th><th>Last date</th><th>Status</th></tr></thead><tbody>${f.data.map(x => `<tr><td>${U.esc(x.fee_types.name)}</td><td>${Fee.inr(x.assigned_amount)}</td><td>${Fee.inr(x.concession_amount)}</td><td>${Fee.inr(x.paid_amount)}</td><td>${Fee.inr(x.balance)}</td><td>${U.esc(x.due_date)}</td><td>${U.esc(Fee.label(Fee.status(x)))}</td></tr>`).join("")}</tbody></table></div>
<h3 style="margin-top:1rem">Payment history</h3>${Object.keys(rc).length ? `<div class="tw"><table><thead><tr><th>Receipt</th><th>Date</th><th>Mode</th><th>Amount</th></tr></thead><tbody>${Object.entries(rc).map(([n, r]) => `<tr><td><a href="receipt.html?no=${encodeURIComponent(n)}">${U.esc(n)}</a></td><td>${U.esc(r.d)}</td><td>${U.esc(r.m.replace("_", " "))}</td><td>${Fee.inr(r.a)}</td></tr>`).join("")}</tbody></table></div>` : "<p>No payments yet.</p>"}`;
      },
      async activities(k) {
        if (!k.e) return noEnr;
        const [a, c] = await Promise.all([db.from("activity_participants").select("position,activities(title,category,activity_date)").eq("enrollment_id", k.e.id), db.from("achievements").select("title,category,achievement_date,position,event_name").eq("enrollment_id", k.e.id).eq("approval_status", "approved").order("achievement_date", { ascending: false })]);
        if (a.error || c.error) throw a.error || c.error;
        return `<h3>Activities</h3>${a.data.length ? `<div class="tw"><table><thead><tr><th>Activity</th><th>Category</th><th>Date</th><th>Result</th></tr></thead><tbody>${a.data.map(x => `<tr><td>${U.esc(x.activities.title)}</td><td>${U.esc(x.activities.category)}</td><td>${U.esc(x.activities.activity_date)}</td><td>${U.esc(x.position || "")}</td></tr>`).join("")}</tbody></table></div>` : "<p>No activities yet.</p>"}<h3 style="margin-top:1rem">Achievements</h3>${c.data.length ? c.data.map(x => `<div class="card" style="margin-bottom:.6rem"><b>${U.esc(x.title)}</b><br><small>${U.esc(x.category)} | ${U.esc(x.achievement_date)}${x.event_name ? " | " + U.esc(x.event_name) : ""}${x.position ? " | " + U.esc(x.position) : ""}</small></div>`).join("") : "<p>No achievements recorded yet.</p>"}`;
      },
      async library(k) {
        if (!k.e) return noEnr;
        const { data, error } = await db.from("book_transactions").select("issue_date,due_date,return_date,status,fine,books(title)").eq("enrollment_id", k.e.id).order("issue_date", { ascending: false }).limit(50); if (error) throw error;
        if (!data.length) return none("No library books issued.");
        return `<div class="tw"><table><thead><tr><th>Book</th><th>Issued</th><th>Due</th><th>Returned</th><th>Fine</th></tr></thead><tbody>${data.map(x => `<tr><td>${U.esc(x.books.title)}</td><td>${U.esc(x.issue_date)}</td><td${x.status === "issued" && x.due_date < Fee.today() ? ' style="color:var(--bad)"' : ""}>${U.esc(x.due_date)}</td><td>${U.esc(x.return_date || "Not returned")}</td><td>${Fee.inr(x.fine)}</td></tr>`).join("")}</tbody></table></div>`;
      },
      async notices() {
        const [n, e] = await Promise.all([db.from("notices").select("id,title,description,notice_date,priority,attachment_path").eq("status", "published").order("notice_date", { ascending: false }).limit(10), db.from("events").select("title,event_type,event_date,venue,status").eq("status", "published").gte("event_date", Fee.today()).order("event_date").limit(8)]);
        if (n.error || e.error) throw n.error || e.error; Portal._n = n.data;
        return `<h3>Notices</h3>${n.data.length ? n.data.map(x => `<div class="card" style="margin-bottom:.6rem"><b>${U.esc(x.title)}</b>${x.priority !== "normal" ? ` <span class="badge">${U.esc(x.priority)}</span>` : ""}<br><small>${U.esc(x.notice_date)}</small><p style="white-space:pre-wrap">${U.esc(x.description)}</p>${x.attachment_path ? `<button class="btn sm ghost" data-nt="${x.id}">Open attachment</button>` : ""}</div>`).join("") : "<p>No notices.</p>"}<h3 style="margin-top:1rem">Upcoming events</h3>${e.data.length ? `<div class="tw"><table><thead><tr><th>Date</th><th>Event</th><th>Venue</th></tr></thead><tbody>${e.data.map(x => `<tr><td>${U.esc(x.event_date)}</td><td>${U.esc(x.title)}</td><td>${U.esc(x.venue || "")}</td></tr>`).join("")}</tbody></table></div>` : "<p>No upcoming events.</p>"}`;
      }
    };
    async function render() {
      $("tb").querySelectorAll("button").forEach(b => b.className = "btn sm" + (b.dataset.t === tab ? "" : " ghost"));
      pane.innerHTML = '<div class="state">Loading...</div>';
      try { pane.innerHTML = await R[tab](cur); } catch (e) { U.friendly(e); U.state(pane, "error", "Unable to load this section. Please try again."); }
    }
    $("tb").addEventListener("click", ev => { const b = ev.target.closest("button[data-t]"); if (b) { tab = b.dataset.t; render(); } });
    if ($("ks")) $("ks").onchange = () => { cur = kids[Number($("ks").value)]; hwSub = hwFrom = ""; render(); };
    pane.addEventListener("change", ev => { if (ev.target.id === "hs") { hwSub = ev.target.value; render(); } if (ev.target.id === "hf") { hwFrom = ev.target.value; render(); } });
    pane.addEventListener("click", async ev => {
      const b = ev.target.closest("button[data-hw],button[data-nt]"); if (!b) return;
      try { if (b.dataset.hw) await Gal.open("homework", cur.hw.find(x => x.id === b.dataset.hw).attachment_path); else await Gal.open("notices", Portal._n.find(x => x.id === b.dataset.nt).attachment_path); }
      catch (e) { U.friendly(e); U.toast("Could not open the file.", "err"); }
    });
    render();
  }
};
