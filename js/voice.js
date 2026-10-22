/* Ask by voice (or typing): answers about the parent's OWN child from the school data.
   No AI and no cost: the browser's speech recognition turns speech into text, then simple keyword rules pick the answer. */
const Voice = (() => {
  const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
  const mr = t => /[ऀ-ॿ]/.test(t);
  const INTENTS = [
    ["fee", /फी|फीस|शुल्क|बाकी|\bfees?\b|\bdue\b|pending|balance|pay/i],
    ["bus", /बस|\bbus\b|transport|वाहन/i],
    ["homework", /गृहपाठ|होमवर्क|अभ्यास|homework|\bhw\b/i],
    ["timetable", /वेळापत्रक|तास|पिरियड|timetable|period|schedule|class today/i],
    ["notice", /नोटीस|सूचना|परिपत्रक|notice|circular|announcement/i],
    ["event", /कार्यक्रम|सुट्टी|इव्हेंट|event|holiday|programme|program/i],
    ["attendance", /हजेरी|उपस्थित|गैरहजर|आला|आली|आज.*शाळ|attendance|present|absent|came|school today/i]
  ];
  const pick = q => { for (const [n, re] of INTENTS) if (re.test(q)) return n; return null; };
  const inr = v => "Rs. " + Number(v).toLocaleString("en-IN", { maximumFractionDigits: 2 });
  const T = {
    unknown: ["I can answer about attendance, homework, fees, the bus, today's timetable, notices and events. Please ask one of these.", "मी हजेरी, गृहपाठ, फी, बस, आजचे वेळापत्रक, नोटीस आणि कार्यक्रम याबद्दल सांगू शकतो. कृपया यापैकी विचारा."],
    err: ["Sorry, I could not get that right now. Please try again.", "क्षमस्व, आत्ता माहिती मिळाली नाही. कृपया पुन्हा प्रयत्न करा."]
  };
  const tr = (k, m) => T[k][m ? 1 : 0];

  async function answer(intent, k, m, HID) {
    const td = Fee.today(), e = k.e, name = k.s.first_name || "";
    if (!e) return m ? "हा विद्यार्थी अजून वर्गात नोंदवलेला नाही." : "This student is not enrolled in a class yet.";
    const L = (arr, f, none) => arr.length ? arr.map(f).join(m ? "; " : "; ") : none;
    if (intent === "attendance") {
      const d30 = new Date(Date.now() - 29 * 864e5).toLocaleDateString("en-CA");
      const { data, error } = await db.from("attendance").select("att_date,status").eq("enrollment_id", e.id).gte("att_date", d30); if (error) throw error;
      const t = data.find(r => r.att_date === td), ok = data.reduce((c, r) => c + (r.status === "present" || r.status === "late" ? 1 : r.status === "half_day" ? .5 : 0), 0), pc = data.length ? Math.round(ok * 100 / data.length) : null;
      const en = { present: "present", absent: "absent", late: "late", half_day: "present for half a day", leave: "on leave" }, mm = { present: "हजर", absent: "गैरहजर", late: "उशिरा आला", half_day: "अर्धा दिवस हजर", leave: "रजेवर" };
      const a = t ? (m ? `आज ${name} ${mm[t.status]} आहे.` : `${name} is ${en[t.status]} today.`) : (m ? "आजची हजेरी अजून नोंदवलेली नाही." : "Today's attendance is not marked yet.");
      const b = pc === null ? "" : (m ? ` गेल्या 30 दिवसांची हजेरी ${pc}% आहे.` : ` Attendance for the last 30 days is ${pc}%.`);
      return a + b;
    }
    if (intent === "homework") {
      if (HID.has("homework")) return m ? "गृहपाठ विभाग शाळेने बंद ठेवला आहे." : "The homework section is switched off by the school.";
      const { data, error } = await db.from("homework").select("title,due_date,subjects(name)").eq("division_id", e.division_id).eq("academic_year_id", e.academic_year_id).eq("status", "active").gte("due_date", td).order("due_date").limit(5); if (error) throw error;
      if (!data.length) return m ? "सध्या कोणताही गृहपाठ बाकी नाही." : "There is no homework due right now.";
      return (m ? "गृहपाठ: " : "Homework: ") + L(data, x => `${x.subjects.name}: ${x.title} (${m ? "शेवटची तारीख" : "due"} ${x.due_date})`, "");
    }
    if (intent === "fee") {
      if (HID.has("fees")) return m ? "फी विभाग शाळेने बंद ठेवला आहे." : "The fees section is switched off by the school.";
      const { data, error } = await db.from("student_fees").select("balance,due_date").eq("enrollment_id", e.id); if (error) throw error;
      const bal = data.reduce((c, x) => c + Number(x.balance), 0), over = data.filter(x => Number(x.balance) > 0 && x.due_date < td).reduce((c, x) => c + Number(x.balance), 0);
      if (bal <= 0) return m ? "सर्व फी भरलेली आहे. काही बाकी नाही." : "All fees are paid. Nothing is pending.";
      return m ? `एकूण फी बाकी ${inr(bal)} आहे.` + (over > 0 ? ` त्यापैकी ${inr(over)} मुदत उलटून गेली आहे.` : " मुदत उलटलेली रक्कम नाही.") : `Total fee pending is ${inr(bal)}.` + (over > 0 ? ` Of this, ${inr(over)} is overdue.` : " Nothing is overdue.");
    }
    if (intent === "bus") {
      if (HID.has("bus")) return m ? "बस विभाग शाळेने बंद ठेवला आहे." : "The bus section is switched off by the school.";
      const { data: as, error } = await db.from("transport_assignments").select("route_id,transport_routes(name)").eq("enrollment_id", e.id).eq("status", "active").limit(1); if (error) throw error;
      if (!as.length) return m ? "या विद्यार्थ्याला बस दिलेली नाही." : "No bus is assigned to this student.";
      const { data: bl } = await db.from("bus_live").select("trip,trip_active,updated_at").eq("route_id", as[0].route_id).maybeSingle();
      const live = bl && bl.trip_active && (Date.now() - new Date(bl.updated_at)) < 180000;
      return live ? (m ? "बस चालू आहे. नकाशावर पाहण्यासाठी Track the bus उघडा." : "The bus is running. Open Track the bus to see where it is.") : (m ? "बस सध्या चालू नाही." : "The bus is not running right now.");
    }
    if (intent === "timetable") {
      if (HID.has("timetable")) return m ? "वेळापत्रक विभाग शाळेने बंद ठेवला आहे." : "The timetable section is switched off by the school.";
      const dow = (new Date().getDay() + 6) % 7 + 1;
      const { data, error } = await db.from("timetable_slots").select("period,start_time,end_time,subjects(name)").eq("division_id", e.division_id).eq("academic_year_id", e.academic_year_id).eq("is_active", true).eq("day", dow).order("period"); if (error) throw error;
      if (!data.length) return m ? "आज वर्ग नाहीत." : "There are no classes today.";
      return (m ? "आजचे वेळापत्रक: " : "Today's timetable: ") + L(data, x => `${m ? "तास" : "period"} ${x.period} ${x.subjects.name}`, "");
    }
    if (intent === "notice") {
      const { data, error } = await db.from("notices").select("title,notice_date").eq("status", "published").order("notice_date", { ascending: false }).limit(3); if (error) throw error;
      if (!data.length) return m ? "सध्या कोणतीही नोटीस नाही." : "There are no notices.";
      return (m ? "ताज्या नोटीस: " : "Latest notices: ") + L(data, x => `${x.title} (${x.notice_date})`, "");
    }
    if (intent === "event") {
      const { data, error } = await db.from("events").select("title,event_date").eq("status", "published").gte("event_date", td).order("event_date").limit(3); if (error) throw error;
      if (!data.length) return m ? "जवळ कोणताही कार्यक्रम नाही." : "There are no upcoming events.";
      return (m ? "येणारे कार्यक्रम: " : "Upcoming events: ") + L(data, x => `${x.event_date} - ${x.title}`, "");
    }
    return tr("unknown", m);
  }

  function mount(box, k, HID) {
    if (!box) return;
    const heard = SR ? "" : '<small>Your browser cannot listen. Please type your question.</small>';
    box.innerHTML = `<div class="chart-card noprint"><h3>Ask by voice</h3>
<div class="row"><div><label for="vl">Language</label><select id="vl"><option value="mr-IN">Marathi</option><option value="en-IN">English</option><option value="hi-IN">Hindi</option></select></div>
<div><label for="vq">Your question</label><input id="vq" maxlength="200" placeholder="e.g. आज हजेरी?  Homework?  फी किती बाकी?"></div></div>
<p>${SR ? '<button class="btn" id="vm" type="button">Speak</button> ' : ""}<button class="btn ghost" id="vs" type="button">Ask</button> <label><input type="checkbox" id="vr"> Read the answer aloud</label></p>${heard}
<p id="va" role="status" aria-live="polite"></p><small>Answers are only about your own child, from the school records. Nothing you say is stored.</small></div>`;
    const $ = id => box.querySelector("#" + id);
    let busy = false;
    async function go() {
      if (busy) return; const q = $("vq").value.trim(); if (!q) return;
      busy = true; $("va").textContent = "...";
      let m = mr(q) || $("vl").value === "mr-IN" && !/[a-z]{3}/i.test(q), out;
      try { out = await answer(pick(q), k, m, HID); } catch (e) { out = tr("err", m); }
      $("va").textContent = out;
      if ($("vr").checked && window.speechSynthesis) { try { speechSynthesis.cancel(); const u = new SpeechSynthesisUtterance(out); u.lang = m ? "mr-IN" : "en-IN"; speechSynthesis.speak(u); } catch (e) { } }
      busy = false;
    }
    $("vs").onclick = go; $("vq").addEventListener("keydown", ev => { if (ev.key === "Enter") go(); });
    if (SR && $("vm")) $("vm").onclick = () => {
      const r = new SR(); r.lang = $("vl").value; r.interimResults = false; r.maxAlternatives = 1;
      $("vm").disabled = true; $("va").textContent = "Listening...";
      r.onresult = ev => { $("vq").value = ev.results[0][0].transcript; go(); };
      r.onerror = ev => { $("va").textContent = ev.error === "not-allowed" ? "Microphone permission is needed. Please allow it or type your question." : "I could not hear that. Please try again or type."; };
      r.onend = () => { $("vm").disabled = false; if ($("va").textContent === "Listening...") $("va").textContent = ""; };
      try { r.start(); } catch (e) { $("vm").disabled = false; }
    };
  }
  return { mount, answer, pick };
})();
