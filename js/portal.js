// Parent and student portal. Everything shown here is enforced by Row Level Security in the database; the page only asks for it.
const Portal = {
  async init(p, mode) {
    const $ = id => document.getElementById(id), pane = $("pane");
    const TABS = [["home", "Today"], ["profile", "Profile"], ["attendance", "Attendance"], ["results", "Results"], ["homework", "Homework"], ["timetable", "Timetable"]]
      .concat(mode === "parent" ? [["fees", "Fees"]] : [], [["activities", "Activities"]], mode === "parent" ? [["library", "Library"]] : [], [["notices", "Notices and events"]]);
    let kids = [], cur = null, tab = "home", rules = [], hwSub = "", hwFrom = "";
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
      async home(k) {
        if (!k.e) return noEnr;
        const td = Fee.today(), d30 = new Date(Date.now() - 29 * 864e5).toLocaleDateString("en-CA"), dow = (new Date().getDay() + 6) % 7 + 1, div = k.e.division_id, yr = k.e.academic_year_id;
        const [a, f, h, n, e, t] = await Promise.all([
          db.from("attendance").select("att_date,status").eq("enrollment_id", k.e.id).gte("att_date", d30),
          mode === "parent" ? db.from("student_fees").select("balance,due_date").eq("enrollment_id", k.e.id) : Promise.resolve({ data: [] }),
          db.from("homework").select("title,due_date,subjects(name)").eq("division_id", div).eq("academic_year_id", yr).eq("status", "active").gte("due_date", td).order("due_date").limit(4),
          db.from("notices").select("title,notice_date,priority").eq("status", "published").order("notice_date", { ascending: false }).limit(3),
          db.from("events").select("title,event_date").eq("status", "published").gte("event_date", td).order("event_date").limit(3),
          db.from("timetable_slots").select("period,start_time,end_time,subjects(name)").eq("division_id", div).eq("academic_year_id", yr).eq("is_active", true).eq("day", dow).order("period")]);
        const bad = [a, f, h, n, e, t].find(x => x.error); if (bad) throw bad.error;
        const today = a.data.find(r => r.att_date === td), lbl = { present: "Present", absent: "Absent", late: "Late", half_day: "Half day", leave: "On leave" };
        const att = a.data.filter(r => r.att_date <= td), ok = att.reduce((c, r) => c + (r.status === "present" || r.status === "late" ? 1 : r.status === "half_day" ? .5 : 0), 0), pc = att.length ? Math.round(ok * 100 / att.length) : null;
        const bal = f.data.reduce((c, x) => c + Number(x.balance), 0), over = f.data.filter(x => Number(x.balance) > 0 && x.due_date < td).reduce((c, x) => c + Number(x.balance), 0);
        const li = (arr, fn, empty) => arr.length ? "<ul>" + arr.map(x => "<li>" + fn(x) + "</li>").join("") + "</ul>" : `<p class="ch-note">${empty}</p>`;
        const links = [["track-bus.html", "Track the bus"], ["requests.html", "Leave and requests"], ["ptm.html", "Parent meetings"], ["ai.html", "Ask the school (AI)"]];
        return `<div class="kpis"><div class="card"><small>Today</small><b style="${today && today.status === "absent" ? "color:var(--bad)" : ""}">${today ? lbl[today.status] : "Not marked yet"}</b></div>
<div class="card"><small>Attendance, last 30 days</small><b>${pc === null ? "-" : pc + "%"}</b>${pc === null ? "" : `<div class="meter"><span style="width:${pc}%"></span></div>`}</div>
${mode === "parent" ? `<div class="card"><small>Fee outstanding</small><b>${Fee.inr(bal)}</b><small>${over > 0 ? U.esc(Fee.inr(over)) + " overdue" : bal > 0 ? "Nothing overdue" : "All paid"}</small></div>` : ""}</div>
${mode === "parent" ? `<div class="alerts">${links.map(l => `<a href="${l[0]}">${U.esc(l[1])}</a>`).join("")}</div>` : ""}
<div class="charts"><div class="chart-card"><h3>Today's timetable</h3>${li(t.data, x => "Period " + x.period + ": <b>" + U.esc(x.subjects.name) + "</b> " + T(x.start_time) + "-" + T(x.end_time), "No classes today.")}</div>
<div class="chart-card"><h3>Homework due soon</h3>${li(h.data, x => "<b>" + U.esc(x.subjects.name) + "</b>: " + U.esc(x.title) + " (due " + U.esc(x.due_date) + ")", "No homework due.")}</div>
<div class="chart-card"><h3>Latest notices</h3>${li(n.data, x => U.esc(x.title) + " <small>" + U.esc(x.notice_date) + "</small>", "No notices.")}</div>
<div class="chart-card"><h3>Upcoming events</h3>${li(e.data, x => U.esc(x.event_date) + " - " + U.esc(x.title), "No events soon.")}</div></div>`;
      },
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
        k.post = () => { if (typeof Charts === "undefined" || !$("achart")) return; Charts.series($("achart"), "Attendance by month", Object.entries(m).map(([mo, o]) => { const n = o.present + o.absent + o.late + o.half_day + o.leave; return { label: mo.slice(2), value: n ? Math.round((o.present + o.late + o.half_day * 0.5) / n * 100) : 0 }; }), { max: 100, fmt: v => v + "%", axisFmt: v => v + "%", valueHead: "Attendance %" }); };
        return `<div id="achart" style="margin-bottom:1rem"></div><div class="card"><b>${pct(tot)}</b>Attendance this year (${data.length} days marked)</div><div class="tw" style="margin-top:1rem"><table><thead><tr><th>Month</th><th>Present</th><th>Absent</th><th>Late</th><th>Half day</th><th>Leave</th><th>%</th></tr></thead><tbody>${Object.entries(m).map(([k2, o]) => `<tr><td>${U.esc(k2)}</td><td>${o.present}</td><td>${o.absent}</td><td>${o.late}</td><td>${o.half_day}</td><td>${o.leave}</td><td>${pct(o)}</td></tr>`).join("")}</tbody></table></div>${abs.length ? `<p><b>Recent absences:</b> ${abs.map(r => U.esc(r.att_date)).join(", ")}</p>` : ""}`;
      },
      async results(k) {
        if (!k.e) return noEnr;
        const { data: ex, error } = await db.from("exams").select("id,name").eq("academic_year_id", k.e.academic_year_id).eq("status", "published").order("created_at"); if (error) throw error;
        if (!ex.length) return none("No results have been published yet.");
        rules = rules.length ? rules : await Ex.rules();
        const { data: subs, error: e2 } = await db.from("exam_subjects").select("id,exam_id,max_marks,passing_marks,subjects(name,sort_order)").eq("division_id", k.e.division_id).in("exam_id", ex.map(x => x.id)); if (e2) throw e2;
        const { data: m, error: e3 } = subs.length ? await db.from("marks").select("exam_subject_id,enrollment_id,marks,absent").eq("enrollment_id", k.e.id).in("exam_subject_id", subs.map(x => x.id)) : { data: [] }; if (e3) throw e3;
        const mk = Object.fromEntries(m.map(x => [x.exam_subject_id + "|" + x.enrollment_id, x]));
        const trend = [];
        const html = ex.map(x => { const s = subs.filter(y => y.exam_id === x.id).sort((a, b) => a.subjects.sort_order - b.subjects.sort_order || a.subjects.name.localeCompare(b.subjects.name)); if (!s.length) return "";
          const r = Ex.calc(s, mk, k.e.id, rules);
          if (Number.isFinite(Number(r.pct))) trend.push({ label: x.name, value: Number(r.pct) });
          return `<div class="panel"><h3>${U.esc(x.name)}</h3><div class="tw"><table><thead><tr><th>Subject</th><th>Maximum</th><th>Obtained</th></tr></thead><tbody>${s.map((y, i) => `<tr><td>${U.esc(y.subjects.name)}</td><td>${y.max_marks}</td><td${r.cells[i].f ? ' style="color:var(--bad)"' : ""}>${U.esc(r.cells[i].v)}</td></tr>`).join("")}<tr><th>Total</th><th>${r.max}</th><th>${r.tot}</th></tr></tbody></table></div><p>Percentage: <b>${r.pct}%</b> | Grade: <b>${U.esc(r.grade)}</b> | Result: <b>${U.esc(r.result)}</b></p><a class="btn sm" href="report-card.html?exam=${x.id}&e=${k.e.id}">Open report card</a></div>`; }).join("") || none("No results to show.");
        k.post = () => { if (typeof Charts !== "undefined" && trend.length > 1 && $("rchart")) Charts.series($("rchart"), "Result percentage by exam", trend, { max: 100, fmt: v => v + "%", axisFmt: v => v + "%", valueHead: "Percentage", kind: "line" }); };
        return (trend.length > 1 ? '<div id="rchart" style="margin-bottom:1rem"></div>' : "") + html;
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
        let upi = ""; try {
          const [pi, cl] = await Promise.all([db.rpc("payment_info"), db.from("payment_claims").select("amount,paid_on,upi_ref,status,review_note,receipt_no,created_at").eq("enrollment_id", k.e.id).order("created_at", { ascending: false }).limit(20)]);
          if (pi.error || cl.error) throw pi.error || cl.error; const bal = sum("balance"), id = pi.data && pi.data.upi_id;
          if (id && bal > 0 || cl.data.length) {
            upi = `<h3 style="margin-top:1.5rem">Pay by UPI</h3>`;
            if (id && bal > 0) upi += `<p>Pay to UPI ID <b>${U.esc(id)}</b> (${U.esc(pi.data.payee)}) from any UPI app. <a class="btn sm" href="upi://pay?pa=${encodeURIComponent(id)}&pn=${encodeURIComponent(pi.data.payee)}&cu=INR&tn=${encodeURIComponent("School fee")}">Open my UPI app</a></p>
<form id="upif" class="panel row"><p style="grid-column:1/-1;margin:0">After paying, enter the UPI reference number (also called UTR or transaction ID). The school office checks it and then issues your receipt.</p><div><label for="ua">Amount paid (Rs.)</label><input id="ua" type="number" step="0.01" min="1" max="${bal}" value="${bal}" required></div><div><label for="ud">Payment date</label><input id="ud" type="date" max="${Fee.today()}" value="${Fee.today()}" required></div><div><label for="ur">UPI reference number</label><input id="ur" maxlength="30" pattern="[A-Za-z0-9]{6,30}" title="6 to 30 letters or digits" required></div><div><label for="un">Note (optional)</label><input id="un" maxlength="300"></div><div><button class="btn" id="ub">Send for verification</button></div></form>`;
            if (cl.data.length) upi += `<div class="tw"><table><thead><tr><th>Date</th><th>Amount</th><th>Reference</th><th>Status</th></tr></thead><tbody>${cl.data.map(x => `<tr><td>${U.esc(x.paid_on)}</td><td>${Fee.inr(x.amount)}</td><td>${U.esc(x.upi_ref)}</td><td>${x.status === "approved" ? `Confirmed${x.receipt_no ? ` (<a href="receipt.html?no=${encodeURIComponent(x.receipt_no)}">${U.esc(x.receipt_no)}</a>)` : ""}` : x.status === "rejected" ? `Not confirmed${x.review_note ? ": " + U.esc(x.review_note) : ""}` : "Waiting for verification"}</td></tr>`).join("")}</tbody></table></div>`;
          }
        } catch (e) { console.error(e); }
        return `<div class="grid"><div class="card"><b>${Fee.inr(sum("assigned_amount"))}</b>Total fee</div><div class="card"><b>${Fee.inr(sum("concession_amount"))}</b>Concession</div><div class="card"><b>${Fee.inr(sum("paid_amount"))}</b>Paid</div><div class="card"><b>${Fee.inr(sum("balance"))}</b>Outstanding</div></div>
<div class="tw" style="margin-top:1rem"><table><thead><tr><th>Fee</th><th>Amount</th><th>Concession</th><th>Paid</th><th>Balance</th><th>Last date</th><th>Status</th></tr></thead><tbody>${f.data.map(x => `<tr><td>${U.esc(x.fee_types.name)}</td><td>${Fee.inr(x.assigned_amount)}</td><td>${Fee.inr(x.concession_amount)}</td><td>${Fee.inr(x.paid_amount)}</td><td>${Fee.inr(x.balance)}</td><td>${U.esc(x.due_date)}</td><td>${U.esc(Fee.label(Fee.status(x)))}</td></tr>`).join("")}</tbody></table></div>
<h3 style="margin-top:1rem">Payment history</h3>${Object.keys(rc).length ? `<div class="tw"><table><thead><tr><th>Receipt</th><th>Date</th><th>Mode</th><th>Amount</th></tr></thead><tbody>${Object.entries(rc).map(([n, r]) => `<tr><td><a href="receipt.html?no=${encodeURIComponent(n)}">${U.esc(n)}</a></td><td>${U.esc(r.d)}</td><td>${U.esc(r.m.replace("_", " "))}</td><td>${Fee.inr(r.a)}</td></tr>`).join("")}</tbody></table></div>` : "<p>No payments yet.</p>"}${upi}`;
      },
      async activities(k) {
        if (!k.e) return noEnr;
        const [a, c] = await Promise.all([db.from("activity_participants").select("position,activities(title,category,activity_date)").eq("enrollment_id", k.e.id), db.from("achievements").select("title,category,achievement_date,position,event_name").eq("enrollment_id", k.e.id).eq("approval_status", "approved").order("achievement_date", { ascending: false })]);
        if (a.error || c.error) throw a.error || c.error;
        return `<h3>Activities</h3>${a.data.length ? `<div class="tw"><table><thead><tr><th>Activity</th><th>Category</th><th>Date</th><th>Result</th></tr></thead><tbody>${a.data.map(x => `<tr><td>${U.esc(x.activities.title)}</td><td>${U.esc(x.activities.category)}</td><td>${U.esc(x.activities.activity_date)}</td><td>${U.esc(x.position || "")}</td></tr>`).join("")}</tbody></table></div>` : "<p>No activities yet.</p>"}<h3 style="margin-top:1rem">Achievements</h3>${c.data.length ? c.data.map(x => `<div class="card" style="margin-bottom:.6rem"><b>${U.esc(x.title)}</b><br><small>${U.esc(x.category)} | ${U.esc(x.achievement_date)}${x.event_name ? " | " + U.esc(x.event_name) : ""}${x.position ? " | " + U.esc(x.position) : ""}</small></div>`).join("") : "<p>No achievements recorded yet.</p>"}`;
      },
      async library(k) {
        if (!k.e) return noEnr;
        const { data, error } = await db.from("book_transactions").select("issue_date,due_date,return_date,status,fine,fine_paid,books(title)").eq("enrollment_id", k.e.id).order("issue_date", { ascending: false }).limit(50); if (error) throw error;
        if (!data.length) return none("No library books issued.");
        return `<div class="tw"><table><thead><tr><th>Book</th><th>Issued</th><th>Due</th><th>Returned</th><th>Fine</th></tr></thead><tbody>${data.map(x => `<tr><td>${U.esc(x.books.title)}</td><td>${U.esc(x.issue_date)}</td><td${x.status === "issued" && x.due_date < Fee.today() ? ' style="color:var(--bad)"' : ""}>${U.esc(x.due_date)}</td><td>${U.esc(x.return_date || "Not returned")}</td><td>${Fee.inr(x.fine)}${x.fine > 0 ? (x.fine_paid ? " (paid)" : " (unpaid)") : ""}</td></tr>`).join("")}</tbody></table></div>`;
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
      try { cur.post = null; pane.innerHTML = await R[tab](cur); if (cur.post) { const f = cur.post; cur.post = null; f(); } } catch (e) { U.friendly(e); U.state(pane, "error", "Unable to load this section. Please try again."); }
    }
    $("tb").addEventListener("click", ev => { const b = ev.target.closest("button[data-t]"); if (b) { tab = b.dataset.t; render(); } });
    if ($("ks")) $("ks").onchange = () => { cur = kids[Number($("ks").value)]; hwSub = hwFrom = ""; render(); };
    pane.addEventListener("change", ev => { if (ev.target.id === "hs") { hwSub = ev.target.value; render(); } if (ev.target.id === "hf") { hwFrom = ev.target.value; render(); } });
    pane.addEventListener("submit", async ev => {
      if (ev.target.id !== "upif") return; ev.preventDefault();
      const amt = Number($("ua").value); if (!(amt > 0)) return U.toast("Enter the amount.", "err");
      $("ub").disabled = true;
      try {
        const { error } = await db.rpc("submit_payment_claim", { p_enrollment: cur.e.id, p_amount: amt, p_date: $("ud").value, p_ref: $("ur").value.trim(), p_note: $("un").value.trim() || null });
        if (error) { const m = error.message || ""; U.toast(/duplicate/.test(m) ? "This reference number was already sent." : /exceeds/.test(m) ? "The amount is more than the balance." : /too many/.test(m) ? "Several payments are already waiting. Please wait for the school to verify them." : /invalid/.test(m) ? "Please check the amount, date and reference number." : "Could not send. Please try again.", "err"); $("ub").disabled = false; return; }
        U.toast("Sent. The school will verify it and issue a receipt."); render();
      } catch (e) { U.friendly(e); U.toast("Could not send. Please try again.", "err"); $("ub").disabled = false; }
    });
    pane.addEventListener("click", async ev => {
      const b = ev.target.closest("button[data-hw],button[data-nt]"); if (!b) return;
      try { if (b.dataset.hw) await Gal.open("homework", cur.hw.find(x => x.id === b.dataset.hw).attachment_path); else await Gal.open("notices", Portal._n.find(x => x.id === b.dataset.nt).attachment_path); }
      catch (e) { U.friendly(e); U.toast("Could not open the file.", "err"); }
    });
    render();
  }
};
