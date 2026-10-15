/* Marathi / English switch. Translates fixed screen text only (menus, headings, buttons, table headings).
   Names, marks, amounts and anything typed by the school are never touched. The choice is remembered in the browser. */
(function () {
  var MR = {
    // menu (ERP)
    "Students per class": "वर्गनिहाय विद्यार्थी", "Boys and girls": "मुले आणि मुली", "Attendance, last 14 days": "उपस्थिती, गेले १४ दिवस", "Attendance today by class": "आजची उपस्थिती (वर्गनिहाय)", "Fee collection, last 6 months": "फी वसुली, गेले ६ महिने", "Fees this year": "या वर्षाची फी", "Upcoming events": "आगामी कार्यक्रम", "Collection by month": "महिन्यानुसार वसुली", "Outstanding by class": "वर्गनिहाय थकबाकी", "Overdue ageing": "थकबाकीचे वय", "Payment modes": "भरणा पद्धती", "Top 10 overdue students": "सर्वाधिक थकबाकी असलेले १० विद्यार्थी", "Detailed reports": "सविस्तर अहवाल", "Outstanding": "थकबाकी", "Collected today": "आज जमा", "Attendance today": "आजची उपस्थिती", "Table": "तक्ता", "Chart": "चार्ट",
    "Today": "आज", "Today's timetable": "आजचे वेळापत्रक", "Homework due soon": "लवकरच देय गृहपाठ", "Latest notices": "ताज्या सूचना", "Attendance by month": "महिन्यानुसार उपस्थिती", "Result percentage by exam": "परीक्षेनुसार निकाल टक्केवारी", "Track the bus": "बस ट्रॅक करा", "Leave and requests": "रजा आणि विनंत्या", "Parent meetings": "पालक सभा", "Ask the school (AI)": "शाळेला विचारा (AI)", "Not marked yet": "अजून नोंद नाही", "Fee outstanding": "थकित फी",
    "Share on WhatsApp": "WhatsApp वर शेअर करा",
    "Dashboard": "डॅशबोर्ड", "Academic years": "शैक्षणिक वर्षे", "Classes and divisions": "वर्ग आणि तुकड्या", "Subjects": "विषय", "Teachers": "शिक्षक", "Staff": "कर्मचारी",
    "Attendance": "हजेरी", "School calendar": "शाळेची दिनदर्शिका", "Subject teachers": "विषय शिक्षक", "Exams": "परीक्षा", "Marks entry": "गुण नोंदणी", "Results": "निकाल",
    "Timetable": "वेळापत्रक", "Homework": "गृहपाठ", "Notices": "सूचना", "Notifications": "संदेश", "Events": "कार्यक्रम", "Activities": "उपक्रम", "Achievements": "यश",
    "Gallery": "छायाचित्रे", "Library": "ग्रंथालय", "Admission enquiries": "प्रवेश चौकशी", "Transport": "वाहतूक", "Staff leave": "कर्मचारी रजा", "Teacher attendance": "शिक्षक हजेरी",
    "Link logins to employees": "लॉगिन कर्मचाऱ्यांशी जोडा", "My children": "माझी मुले", "My school": "माझी शाळा", "Teacher portal": "शिक्षक पोर्टल", "Link parents and students": "पालक आणि विद्यार्थी जोडा",
    "Students": "विद्यार्थी", "Fees and payments": "फी आणि भरणा", "Fee types": "फी प्रकार", "Fee structure": "फी रचना", "Fee check": "फी तपासणी", "Fee reminders": "फी आठवण",
    "UPI payment claims": "UPI भरणा दावे", "Fee reports": "फी अहवाल", "Reports": "अहवाल", "Student promotion": "विद्यार्थी पदोन्नती", "Academic year closing": "शैक्षणिक वर्ष समाप्ती",
    "School settings": "शाळा सेटिंग्ज", "Users and roles": "वापरकर्ते आणि भूमिका", "Backup": "बॅकअप", "Audit logs": "ऑडिट नोंदी", "Certificates (TC, Bonafide)": "प्रमाणपत्रे (TC, बोनाफाईड)",
    "ID cards and hall tickets": "ओळखपत्रे आणि हॉल तिकिटे", "Teacher diary": "शिक्षक नोंदवही",
    "QR attendance": "QR हजेरी", "Track bus": "बस ट्रॅक करा", "AI assistant": "AI सहाय्यक", "Meetings (PTM)": "पालक-शिक्षक भेट", "Requests": "अर्ज", "Parent-teacher meetings": "पालक-शिक्षक भेटी", "Student insights": "विद्यार्थी विश्लेषण", "Bus route": "बस मार्ग", "Install app": "अॅप इन्स्टॉल करा", "Fee reminders": "फी आठवण", "Certificates (TC, Bonafide)": "प्रमाणपत्रे (TC, बोनाफाईड)",
    // public site
    "Home": "मुख्यपृष्ठ", "About": "शाळेबद्दल", "Academics": "शैक्षणिक", "Admissions": "प्रवेश", "Faculty": "शिक्षकवृंद", "Facilities": "सुविधा", "Contact": "संपर्क", "Login": "लॉगिन",
    "LKG to Grade 10": "LKG ते इयत्ता 10वी", "Admission enquiry": "प्रवेश चौकशी", "About the school": "शाळेबद्दल", "Parent / Teacher login": "पालक / शिक्षक लॉगिन", "Welcome": "स्वागत",
    "Read more": "अधिक वाचा", "Message from the Principal": "मुख्याध्यापकांचा संदेश", "Principal's message": "मुख्याध्यापकांचा संदेश", "Vision": "दृष्टी", "Mission": "ध्येय",
    "Vision and Mission": "दृष्टी आणि ध्येय", "Latest notices": "ताज्या सूचना", "All notices": "सर्व सूचना", "Upcoming events": "आगामी कार्यक्रम", "All events": "सर्व कार्यक्रम",
    "Academic highlights": "शैक्षणिक वैशिष्ट्ये", "Classes": "वर्ग", "Photo gallery": "छायाचित्र दालन", "Send enquiry": "चौकशी पाठवा", "Send admission enquiry": "प्रवेश चौकशी पाठवा",
    "How admission works": "प्रवेश प्रक्रिया कशी आहे", "Quick links": "जलद दुवे", "Skip to content": "मजकुराकडे जा", "Our faculty": "आमचे शिक्षक", "Our school": "आमची शाळा",
    "Past events": "मागील कार्यक्रम", "Upcoming": "आगामी", "School office": "शाळा कार्यालय", "Address": "पत्ता", "Phone": "फोन", "How we track progress": "प्रगती कशी तपासतो",
    "What students take part in": "विद्यार्थी कशात भाग घेतात", "No notices at the moment.": "सध्या कोणतीही सूचना नाही.", "No upcoming events at the moment.": "सध्या कोणतेही कार्यक्रम नाहीत.",
    "Nothing to show yet.": "अजून दाखवण्यासारखे काही नाही.", "Achievements will appear here.": "यश येथे दिसेल.", "Faculty details will appear here.": "शिक्षकांची माहिती येथे दिसेल.",
    "View photo gallery": "छायाचित्रे पाहा", "Send admission enquiry": "प्रवेश चौकशी पाठवा", "Admission enquiry": "प्रवेश चौकशी",
    // common words
    "Status": "स्थिती", "Class": "वर्ग", "Student": "विद्यार्थी", "Subject": "विषय", "Roll": "रोल नं.", "Date": "दिनांक", "Type": "प्रकार", "Teacher": "शिक्षक", "Name": "नाव", "Total": "एकूण",
    "ID": "आयडी", "Role": "भूमिका", "Period": "तास", "Grade": "श्रेणी", "Absent": "गैरहजर", "Year": "वर्ष", "Title": "शीर्षक", "Room": "खोली", "Result": "निकाल", "Remarks": "शेरा",
    "Reason": "कारण", "Present": "हजर", "Marks": "गुण", "Leave": "रजा", "Late": "उशीर", "Half day": "अर्धा दिवस", "Fee": "फी", "Fee amount": "फी रक्कम", "Employee": "कर्मचारी", "Due": "देय",
    "Division": "तुकडी", "Details": "तपशील", "Concession": "सवलत", "Balance": "बाकी", "Attendance %": "हजेरी %", "Admission no": "प्रवेश क्र.", "Action": "कृती", "Amount": "रक्कम", "Paid": "भरलेले",
    "Remaining": "शिल्लक", "Taken": "घेतलेले", "Reference": "संदर्भ क्र.", "Topic": "शिकवलेला विषय", "Time": "वेळ", "Start": "सुरुवात", "From": "पासून", "To": "पर्यंत", "Allowed": "मंजूर दिवस",
    "Date of leaving": "शाळा सोडल्याची तारीख", "Total fee": "एकूण फी", "Outstanding": "थकबाकी", "Payment history": "भरणा इतिहास", "Pay by UPI": "UPI ने भरा", "Receipt": "पावती",
    "Total balance": "एकूण बाकी", "Overdue": "थकलेली", "Oldest due": "सर्वात जुनी देय तारीख", "Parent": "पालक", "Reminder": "आठवण", "Student": "विद्यार्थी", "Created": "तयार केले",
    "Birthdays": "वाढदिवस", "Today": "आज", "Tomorrow": "उद्या", "Class teacher": "वर्गशिक्षक", "Principal": "मुख्याध्यापक", "School seal": "शाळेचा शिक्का",
    // buttons and form words
    "Save": "जतन करा", "Cancel": "रद्द करा", "Delete": "काढून टाका", "Edit": "बदला", "Add": "जोडा", "Print": "छापा", "Sign in": "लॉगिन करा", "Sign out": "बाहेर पडा", "Menu": "मेनू",
    "Search": "शोधा", "Show": "दाखवा", "Approve": "मंजूर करा", "Reject": "नाकारा", "Copy": "कॉपी", "Download CSV": "CSV डाउनलोड करा", "Print or save as PDF": "छापा किंवा PDF म्हणून जतन करा",
    "Publish": "प्रसिद्ध करा", "Back": "मागे", "Loading...": "लोड होत आहे...", "Email": "ईमेल", "Password": "पासवर्ड", "Forgot password?": "पासवर्ड विसरलात?", "Back to website": "वेबसाईटवर परत",
    "Submit": "सादर करा", "Reprint": "पुन्हा छापा", "Issue and print": "जारी करा आणि छापा", "Send for verification": "तपासणीसाठी पाठवा", "Open my UPI app": "माझे UPI अॅप उघडा",
    "All": "सर्व", "Pending": "प्रलंबित", "Approved": "मंजूर", "Rejected": "नाकारलेले", "Active": "सक्रिय", "Inactive": "निष्क्रिय", "Waiting": "प्रतीक्षेत", "Show": "दाखवा",
    "Waiting for verification": "तपासणीच्या प्रतीक्षेत", "Class and division (active year)": "वर्ग आणि तुकडी (चालू वर्ष)", "What to print": "काय छापायचे", "Student ID cards": "विद्यार्थी ओळखपत्रे",
    "Exam hall tickets": "परीक्षा हॉल तिकिटे", "Message language": "संदेशाची भाषा", "Marathi": "मराठी", "English": "इंग्रजी", "Find student (name or admission no)": "विद्यार्थी शोधा (नाव किंवा प्रवेश क्र.)",
    "Certificate": "प्रमाणपत्र", "Bonafide certificate": "बोनाफाईड प्रमाणपत्र", "Transfer certificate (TC)": "शाळा सोडल्याचा दाखला (TC)", "Character certificate": "चारित्र्य प्रमाणपत्र",
    "Issued certificates": "दिलेली प्रमाणपत्रे", "UPI payment claims": "UPI भरणा दावे", "What did you teach?": "तुम्ही काय शिकवले?", "Topic taught": "शिकवलेला विषय", "Details (optional)": "तपशील (ऐच्छिक)",
    "Fee payment by UPI": "UPI ने फी भरणा", "Apply for leave": "रजेसाठी अर्ज", "Leave type": "रजेचा प्रकार", "Casual": "नैमित्तिक", "Sick": "आजारपण", "Earned": "अर्जित", "Maternity": "प्रसूती", "Unpaid": "बिनपगारी", "Other": "इतर",
    "casual": "नैमित्तिक", "sick": "आजारपण", "earned": "अर्जित", "maternity": "प्रसूती", "unpaid": "बिनपगारी", "other": "इतर", "No limit set": "मर्यादा नाही",
    "Fees": "फी", "Library": "ग्रंथालय", "Notices and events": "सूचना आणि कार्यक्रम", "Results": "निकाल", "Timetable": "वेळापत्रक", "Overview": "थोडक्यात", "Homework": "गृहपाठ",
    "No payments yet.": "अजून कोणताही भरणा नाही.", "No fees have been assigned yet.": "अजून फी लावलेली नाही.", "No library books issued.": "ग्रंथालयाचे कोणतेही पुस्तक दिलेले नाही.",
    "Parents and guardians": "पालक आणि पालकत्व", "Notifications": "संदेश", "Mark all as read": "सर्व वाचले म्हणून चिन्हांकित करा", "Choose": "निवडा"
  };
  var KEY = "ses_lang", orig = new WeakMap(), attrs = ["placeholder", "title", "aria-label"];
  var lang = "en"; try { lang = localStorage.getItem(KEY) === "mr" ? "mr" : "en"; } catch (e) { }

  function tr(t) { var k = t.trim(); return (k && Object.prototype.hasOwnProperty.call(MR, k)) ? t.replace(k, MR[k]) : null; }
  function skip(n) { var p = n.parentNode; return !p || /^(SCRIPT|STYLE|TEXTAREA|CODE)$/.test(p.nodeName); }
  function textNode(n) {
    if (skip(n)) return;
    if (lang === "mr") { var r = tr(n.nodeValue); if (r !== null && r !== n.nodeValue) { if (!orig.has(n)) orig.set(n, n.nodeValue); n.nodeValue = r; } }
    else if (orig.has(n)) { n.nodeValue = orig.get(n); orig.delete(n); }
  }
  function attrNode(el) {
    attrs.forEach(function (a) {
      var v = el.getAttribute(a); if (v === null) return; var key = "data-en-" + a;
      if (lang === "mr") { var r = tr(v); if (r !== null && r !== v) { if (!el.hasAttribute(key)) el.setAttribute(key, v); el.setAttribute(a, r); } }
      else if (el.hasAttribute(key)) { el.setAttribute(a, el.getAttribute(key)); el.removeAttribute(key); }
    });
  }
  function walk(root) {
    if (!root) return;
    if (root.nodeType === 3) return textNode(root);
    if (root.nodeType !== 1 && root.nodeType !== 9) return;
    var w = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, null, false), n, list = [];
    while ((n = w.nextNode())) list.push(n);
    list.forEach(textNode);
    if (root.nodeType === 1) attrNode(root);
    var els = root.querySelectorAll ? root.querySelectorAll("[placeholder],[title],[aria-label]") : [];
    for (var i = 0; i < els.length; i++) attrNode(els[i]);
  }
  var busy = false, mo = null;
  function apply() { busy = true; try { walk(document.body); } finally { busy = false; } document.documentElement.lang = lang === "mr" ? "mr" : "en"; var b = document.getElementById("langbtn"); if (b) b.textContent = lang === "mr" ? "English" : "मराठी"; }
  function button() {
    if (document.getElementById("langbtn")) return;
    var b = document.createElement("button"); b.id = "langbtn"; b.type = "button"; b.className = "btn ghost noprint"; b.setAttribute("aria-label", "Change language");
    b.onclick = function () { lang = lang === "mr" ? "en" : "mr"; try { localStorage.setItem(KEY, lang); } catch (e) { } apply(); };
    var host = document.querySelector("header.top") || document.querySelector("#sh .in");
    if (host) { var who = host.querySelector("#who"); who ? host.insertBefore(b, who) : host.appendChild(b); }
    else { b.style.cssText = "position:fixed;right:12px;top:12px;z-index:40"; document.body.appendChild(b); }
  }
  function start() {
    try {
      button(); apply();
      mo = new MutationObserver(function (list) {
        if (busy || lang !== "mr") { if (!busy) button(); return; }
        busy = true; try { list.forEach(function (m) { m.addedNodes.forEach(walk); if (m.type === "characterData") textNode(m.target); }); } finally { busy = false; }
        button();
      });
      mo.observe(document.body, { childList: true, subtree: true });
    } catch (e) { console.error(e); }
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start); else start();
})();
/* Load the install / offline helper on every page. */
(function () { try { var p = document.createElement("script"); p.src = "js/pwa.js"; document.head.appendChild(p); } catch (e) { } })();
