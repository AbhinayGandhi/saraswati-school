/* Marathi / English switch. Translates fixed screen text only (menus, headings, buttons, table headings).
   Names, marks, amounts and anything typed by the school are never touched. The choice is remembered in the browser. */
(function () {
  var MR = {
    // menu (ERP)
    "Students per class": "वर्गनिहाय विद्यार्थी", "Boys and girls": "मुले आणि मुली", "Attendance, last 14 days": "उपस्थिती, गेले १४ दिवस", "Attendance today by class": "आजची उपस्थिती (वर्गनिहाय)", "Fee collection, last 6 months": "फी वसुली, गेले ६ महिने", "Fees this year": "या वर्षाची फी", "Upcoming events": "आगामी कार्यक्रम", "Collection by month": "महिन्यानुसार वसुली", "Outstanding by class": "वर्गनिहाय थकबाकी", "Overdue ageing": "थकबाकीचे वय", "Payment modes": "भरणा पद्धती", "Top 10 overdue students": "सर्वाधिक थकबाकी असलेले १० विद्यार्थी", "Detailed reports": "सविस्तर अहवाल", "Outstanding": "थकबाकी", "Collected today": "आज जमा", "Attendance today": "आजची उपस्थिती", "Table": "तक्ता", "Chart": "चार्ट",
    "School bus": "शाळेची बस", "Running": "चालू आहे", "Not running": "चालू नाही", "Drop trip": "घरी सोडण्याची फेरी", "Pickup trip": "घेण्याची फेरी", "see where": "कुठे आहे ते पाहा", "Unread notifications": "न वाचलेल्या सूचना", "open": "उघडा", "Message parents": "पालकांना संदेश", "Send app notification": "ॲप सूचना पाठवा", "Parents with app login": "ॲप लॉगिन असलेले पालक", "With a valid mobile for WhatsApp": "WhatsApp साठी योग्य मोबाईल असलेले", "Ready message": "तयार संदेश", "Write my own": "स्वतः लिहा", "Holiday": "सुट्टी", "Parent meeting": "पालक सभा", "Bus delay": "बस उशीर", "General notice": "सर्वसाधारण सूचना", "Download list (CSV)": "यादी डाउनलोड (CSV)", "Opened": "उघडले", "Title (shown in the app)": "शीर्षक (ॲपमध्ये दिसते)", "What to make": "काय बनवायचे", "Practice questions": "सराव प्रश्न", "Question paper (with marks)": "प्रश्नपत्रिका (गुणांसह)", "Homework sheet": "गृहपाठ पत्रक", "Copied.": "कॉपी झाले.", "Select": "निवडा", "Other (type it)": "इतर (टाइप करा)", "Choose the class and the subject.": "इयत्ता आणि विषय निवडा.", "Type the class": "इयत्ता टाइप करा", "Type the subject": "विषय टाइप करा", "Today": "आज", "Today's timetable": "आजचे वेळापत्रक", "Homework due soon": "लवकरच देय गृहपाठ", "Latest notices": "ताज्या सूचना", "Attendance by month": "महिन्यानुसार उपस्थिती", "Result percentage by exam": "परीक्षेनुसार निकाल टक्केवारी", "Track the bus": "बस ट्रॅक करा", "Leave and requests": "रजा आणि विनंत्या", "Parent meetings": "पालक सभा", "Ask the school (AI)": "शाळेला विचारा (AI)", "Not marked yet": "अजून नोंद नाही", "Fee outstanding": "थकित फी",
    /* Round 13: new home page and bus checklist */
    "LKG to Grade 10 | English Medium": "LKG ते इयत्ता 10वी | इंग्रजी माध्यम", "School photo": "शाळेचे छायाचित्र", "Admission": "प्रवेश", "Send an enquiry": "चौकशी पाठवा", "Parent login": "पालक लॉगिन", "Fees, attendance, bus": "फी, हजेरी, बस", "Notices": "सूचना", "Latest news": "ताज्या बातम्या", "Events": "कार्यक्रम", "Upcoming dates": "येणाऱ्या तारखा", "Contact": "संपर्क", "Find us": "आम्हाला शोधा",
    "A school that keeps parents connected": "पालकांशी जोडलेली शाळा", "Live school bus": "लाइव्ह स्कूल बस", "Parents see the bus on a map and get an alert when it is near the stop and when the child boards.": "पालकांना बस नकाशावर दिसते. बस थांब्याजवळ आल्यावर आणि मूल बसमध्ये चढल्यावर सूचना मिळते.",
    "Easy fee payment": "सोपी फी भरणा", "Pay by UPI QR or bank transfer and send the reference. The office confirms it and the receipt is ready.": "UPI QR किंवा बँक ट्रान्सफरने फी भरा आणि संदर्भ क्रमांक पाठवा. कार्यालय खात्री करते आणि पावती तयार होते.",
    "Daily attendance": "रोजची हजेरी", "Attendance alerts, homework, results and report cards in one place for each child.": "प्रत्येक मुलाची हजेरी सूचना, गृहपाठ, निकाल आणि प्रगतीपुस्तक एकाच ठिकाणी.",
    "Marathi and English": "मराठी आणि इंग्रजी", "The parent and school pages can be switched between Marathi and English.": "पालक आणि शाळेची पाने मराठी व इंग्रजी भाषेत बदलता येतात.",
    "Life at school": "शाळेतील जीवन", "Campus": "परिसर", "Classroom": "वर्ग", "Sports": "खेळ", "Activities": "उपक्रम", "More photos in the gallery": "दालनात आणखी छायाचित्रे",
    "Admissions open? Send an enquiry today": "प्रवेश सुरू? आजच चौकशी पाठवा", "The school office will contact you.": "शाळा कार्यालय तुमच्याशी संपर्क करेल.", "How admission works": "प्रवेश कसा होतो",
    "Children list / विद्यार्थी यादी": "विद्यार्थी यादी", "Stop not set / थांबा नाही": "थांबा नाही",
    /* Round 16: map */
    "Show my distance from the bus": "बस माझ्यापासून किती दूर ते दाखवा", "Hide my distance": "माझे अंतर लपवा", "Finding your location...": "तुमची जागा शोधत आहे...", "This phone or browser cannot give its location.": "या फोनवरून जागा मिळू शकत नाही.", "Location is off or not allowed. Turn on location for this page to see your distance.": "लोकेशन बंद आहे किंवा परवानगी नाही. अंतर पाहण्यासाठी या पानासाठी लोकेशन चालू करा.", "Your location is used only on your phone to work out the distance. It is not sent or saved.": "तुमची जागा फक्त तुमच्या फोनवर अंतर काढण्यासाठी वापरली जाते. ती पाठवली किंवा साठवली जात नाही.", "Stops": "थांबे", "Street View": "Street View (रस्त्यावरील दृश्य)", "Google Maps": "Google Maps", "(your stop)": "(तुमचा थांबा)", "Show live Google view": "Google दृश्य दाखवा (लाइव्ह)", "Hide Google view": "Google दृश्य लपवा", "Google map": "Google नकाशा", "Google satellite": "Google उपग्रह", "Google map centred on the bus (or on your stop when the bus is not running). It refreshes by itself while the bus moves.": "Google नकाशा बसच्या जागेवर (बस चालू नसेल तर तुमच्या थांब्यावर) मध्यभागी असतो. बस हलत असताना तो आपोआप ताजा होतो.", "Satellite + names": "उपग्रह + नावे", "Open in Google Maps": "Google Maps मध्ये उघडा", "School location on the map": "नकाशावर शाळेचे ठिकाण", "Latitude": "अक्षांश (Latitude)", "Longitude": "रेखांश (Longitude)",
    "In Google Maps right-click the school gate and click the two numbers shown on top to copy them (for example 17.701212, 74.174362). Put the first number in Latitude and the second in Longitude. They are shown as a map on the Contact page. Leave both empty to hide the map.": "Google Maps मध्ये शाळेच्या गेटवर उजवे क्लिक करा आणि वर दिसणारे दोन आकडे क्लिक करून कॉपी करा (उदा. 17.701212, 74.174362). पहिला आकडा Latitude मध्ये आणि दुसरा Longitude मध्ये टाका. ते संपर्क पानावर नकाशा म्हणून दिसतात. नकाशा लपवण्यासाठी दोन्ही रिकामे ठेवा.",
    /* Round 15: flexibility switches */
    "Weekly off day": "साप्ताहिक सुट्टी", "Holiday": "सुट्टी",
    "Flexibility": "लवचिकता", "Applies to": "लागू होते", "Whole school": "संपूर्ण शाळा", "One division": "एक तुकडी",
    "Teachers can change attendance up to (days back)": "शिक्षक किती दिवस मागपर्यंत हजेरी बदलू शकतात", "Show to parents and students": "पालक आणि विद्यार्थ्यांना काय दाखवायचे",
    "Fees and online payment": "फी आणि ऑनलाइन भरणा", "Report card wording": "गुणपत्रकातील मजकूर", "Lock marks": "गुण लॉक करा", "Reopen for correction": "दुरुस्तीसाठी पुन्हा उघडा",
    "This date is too old for you to change. Please ask the school office.": "ही तारीख तुम्हाला बदलण्यासाठी खूप जुनी आहे. कृपया शाळेच्या कार्यालयाला सांगा.",
    /* Round 14: admission form and report card */
    "1. Student": "1. विद्यार्थी", "2. Parent": "2. पालक", "3. Previous school": "3. आधीची शाळा", "Next": "पुढे", "Back": "मागे",
    "Documents usually asked at admission": "प्रवेशाच्या वेळी साधारण लागणारी कागदपत्रे", "Birth certificate": "जन्म दाखला", "Passport-size photographs of the child": "मुलाचे पासपोर्ट आकाराचे फोटो",
    "Admission enquiry receipt": "प्रवेश चौकशी पावती", "Print or save as PDF": "प्रिंट करा किंवा PDF जतन करा", "Application no": "अर्ज क्रमांक", "Class applied for": "कोणत्या वर्गासाठी अर्ज",
    "Parent / guardian": "पालक / संरक्षक", "Mobile": "मोबाईल", "Print all report cards": "सर्व गुणपत्रके छापा", "PROGRESS REPORT": "प्रगती अहवाल",
    /* Round 12: wider Marathi coverage */
    "Change language": "भाषा बदला", "Main": "मुख्य", "Sidebar": "बाजूचा मेनू",
    "Zoom in": "मोठे करा", "Zoom out": "लहान करा", "Bus map": "बसचा नकाशा",
    "Academic year": "शैक्षणिक वर्ष", "Export CSV": "CSV डाउनलोड करा", "Next": "पुढे",
    "Previous": "मागे", "Exam": "परीक्षा", "Attendance, last 30 days": "उपस्थिती, गेले 30 दिवस",
    "Description": "वर्णन", "Profile": "प्रोफाइल", "All divisions": "सर्व तुकड्या",
    "Class and division": "वर्ग आणि तुकडी", "From date": "पासून तारीख", "To date": "पर्यंत तारीख",
    "Nothing to show for your role yet.": "तुमच्या भूमिकेसाठी अजून काही दाखवण्यासारखे नाही.", "Save draft": "मसुदा जतन करा", "Audience": "कोणासाठी",
    "Everyone": "सर्वांसाठी", "Parents": "पालक", "Show report": "अहवाल दाखवा",
    "Name, admission no, GR no": "नाव, प्रवेश क्रमांक, GR क्रमांक", "Academic": "शैक्षणिक", "Attachment (PDF, JPG or PNG, up to 5 MB)": "जोडपत्र (PDF, JPG किंवा PNG, कमाल 5 MB)",
    "Cancelled": "रद्द", "Category": "प्रकार", "Competition": "स्पर्धा",
    "Cultural": "सांस्कृतिक", "Dance": "नृत्य", "Drawing": "चित्रकला",
    "End time": "समाप्ती वेळ", "Holiday": "सुट्टी", "Month": "महिना",
    "Music": "संगीत", "Notes": "टिपा", "Pending approval": "मंजुरीसाठी प्रलंबित",
    "Quiz": "प्रश्नमंजुषा", "Save attendance": "हजेरी जतन करा", "Science": "विज्ञान",
    "Search student": "विद्यार्थी शोधा", "Sports": "क्रीडा", "Start time": "सुरुवातीची वेळ",
    "View": "पहा", "Please bring the report card": "कृपया प्रगतीपुस्तक सोबत आणा", "Term 1 parent-teacher meeting": "पहिल्या सत्राची पालक-शिक्षक सभा",
    "A JavaScript library for interactive maps": "संवादी नकाशांसाठी JavaScript लायब्ररी", "AI is not available for your login.": "तुमच्या लॉगिनसाठी AI उपलब्ध नाही.", "Add note": "टीप जोडा",
    "Admission number": "प्रवेश क्रमांक", "Album": "अल्बम", "All albums": "सर्व अल्बम",
    "All classes": "सर्व वर्ग", "Annual Day": "वार्षिक स्नेहसंमेलन", "Assign": "नेमून द्या",
    "Bank transfer": "बँक ट्रान्सफर", "Calendar": "दिनदर्शिका", "Cancel edit": "संपादन रद्द करा",
    "Cash": "रोख", "Certificate (bonafide, etc.)": "दाखला (बोनाफाईड इ.)", "Cheque": "धनादेश",
    "Children's Day": "बालदिन", "Community Service": "समाजसेवा", "Control panel (admin)": "नियंत्रण पटल (अ‍ॅडमिन)",
    "Create album": "अल्बम तयार करा", "Create and tell parents": "तयार करा आणि पालकांना कळवा", "Cultural Program": "सांस्कृतिक कार्यक्रम",
    "Daily uses per parent": "प्रति पालक दररोजचा वापर", "Date of birth": "जन्मतारीख", "Date taken": "फोटो काढल्याची तारीख",
    "Description (optional)": "वर्णन (ऐच्छिक)", "Division (active year)": "तुकडी (चालू वर्ष)", "Drafts": "मसुदे",
    "Due date": "देय तारीख", "Emergency": "आणीबाणी", "Employee ID": "कर्मचारी क्रमांक",
    "Event name": "कार्यक्रमाचे नाव", "Expired": "मुदत संपलेले", "Expiry date": "मुदत संपण्याची तारीख",
    "Female": "स्त्री", "Field Trip": "सहल", "Gender": "लिंग",
    "General": "सामान्य", "Important": "महत्त्वाचे", "Independence Day": "स्वातंत्र्य दिन",
    "Information": "माहिती", "Joining date": "रुजू झाल्याची तारीख", "Leaflet": "Leaflet",
    "Leave (absence)": "रजा (गैरहजेरी)", "List": "यादी", "Logged-in users only": "फक्त लॉगिन केलेल्यांसाठी",
    "Male": "पुरुष", "Mark all present": "सर्वांना उपस्थित करा", "Minutes per parent": "प्रति पालक मिनिटे",
    "Mobile": "मोबाइल", "Monthly report": "मासिक अहवाल", "New album name": "नवीन अल्बमचे नाव",
    "New event (saved as draft until published)": "नवीन कार्यक्रम (प्रकाशित करेपर्यंत मसुदा म्हणून जतन)", "New notice (saved as draft until published)": "नवीन सूचना (प्रकाशित करेपर्यंत मसुदा म्हणून जतन)", "New request": "नवीन विनंती",
    "Next month": "पुढचा महिना", "No notifications yet.": "अजून कोणत्याही सूचना नाहीत.", "No photos to show yet.": "अजून दाखवण्यासाठी फोटो नाहीत.",
    "Normal": "सामान्य", "Note for parents (optional)": "पालकांसाठी टीप (ऐच्छिक)", "Nothing added yet. Use the form above.": "अजून काही जोडलेले नाही. वरचा फॉर्म वापरा.",
    "Notice date": "सूचनेची तारीख", "Notice type": "सूचनेचा प्रकार", "Off": "बंद",
    "Parent Meeting": "पालक सभा", "Past": "मागील", "Payment mode": "भरणा पद्धत",
    "Per admin": "अ‍ॅडमिननुसार", "Per teacher / staff": "शिक्षक / कर्मचाऱ्यानुसार", "Photos": "फोटो",
    "Plan a meeting": "सभा ठरवा", "Please note:": "कृपया लक्षात घ्या:", "Poster (PDF, JPG or PNG, up to 5 MB)": "पोस्टर (PDF, JPG किंवा PNG, कमाल 5 MB)",
    "Previous month": "मागचा महिना", "Priority": "प्राधान्य", "Prize Distribution": "बक्षीस वितरण",
    "Public website (after approval)": "सार्वजनिक वेबसाइट (मंजुरीनंतर)", "Published": "प्रकाशित", "Report": "अहवाल",
    "Republic Day": "प्रजासत्ताक दिन", "Roll number": "हजेरी क्रमांक", "Science Exhibition": "विज्ञान प्रदर्शन",
    "Send request": "विनंती पाठवा", "Set an active academic year first.": "आधी चालू शैक्षणिक वर्ष निश्चित करा.", "Show on the public website (text only)": "सार्वजनिक वेबसाइटवर दाखवा (फक्त मजकूर)",
    "Show on the public website (text only, no attachment)": "सार्वजनिक वेबसाइटवर दाखवा (फक्त मजकूर, जोडपत्र नाही)", "Specific class": "विशिष्ट वर्ग", "Specific division": "विशिष्ट तुकडी",
    "Start date": "सुरुवातीची तारीख", "Teachers Day": "शिक्षक दिन", "Title (optional)": "शीर्षक (ऐच्छिक)",
    "UPI": "UPI", "Until": "पर्यंत", "Upload": "अपलोड करा",
    "Upload photos (shrunk automatically, JPG/PNG/WebP)": "फोटो अपलोड करा (आपोआप लहान होतात, JPG/PNG/WebP)", "Urgent": "तातडीचे", "Use in the last 7 days": "गेल्या 7 दिवसांतील वापर",
    "Venue": "ठिकाण", "What the parent chat knows": "पालकांच्या चॅटला काय माहीत आहे", "Who can see it": "कोण पाहू शकते",
    "The parent chat answers": "पालकांच्या चॅटचे उत्तर", "© OpenStreetMap contributors": "© OpenStreetMap योगदानकर्ते", "Account holder name": "खातेधारकाचे नाव",
    "Account number (digits only)": "खाते क्रमांक (फक्त अंक)", "Achievement": "उपलब्धी", "Action contains": "कृतीमध्ये आहे",
    "Activity": "उपक्रम", "Add a new user": "नवीन वापरकर्ता जोडा", "Add activity": "उपक्रम जोडा",
    "Add book": "पुस्तक जोडा", "Add concession": "सवलत जोडा", "Add division": "तुकडी जोडा",
    "Add fee": "फी जोडा", "Add fee type": "फी प्रकार जोडा", "Add homework": "गृहपाठ जोडा",
    "Add participant": "सहभागी जोडा", "Add period": "तास जोडा", "Add period to the selected division": "निवडलेल्या तुकडीत तास जोडा",
    "Add route": "मार्ग जोडा", "Add row": "ओळ जोडा", "Add student": "विद्यार्थी जोडा",
    "Add subject": "विषय जोडा", "Add teachers and staff first.": "आधी शिक्षक आणि कर्मचारी जोडा.", "Add to all divisions of class": "वर्गाच्या सर्व तुकड्यांमध्ये जोडा",
    "Add year": "वर्ष जोडा", "Administrative Staff": "प्रशासकीय कर्मचारी", "Admission completed": "प्रवेश पूर्ण",
    "After approval, admission is completed at the school office.": "मंजुरीनंतर प्रवेश शाळेच्या कार्यालयात पूर्ण होतो.", "All divisions of the class": "वर्गाच्या सर्व तुकड्या", "All my divisions": "माझ्या सर्व तुकड्या",
    "All routes": "सर्व मार्ग", "All students": "सर्व विद्यार्थी", "All subjects": "सर्व विषय",
    "All teachers": "सर्व शिक्षक", "Alternate mobile": "पर्यायी मोबाइल", "Alumni (left after last class)": "माजी विद्यार्थी (शेवटच्या वर्गानंतर गेलेले)",
    "Amount received": "मिळालेली रक्कम", "An English-medium school for learners from LKG to Grade 10.": "LKG ते इयत्ता 10 वीपर्यंतच्या विद्यार्थ्यांसाठी इंग्रजी माध्यमाची शाळा.", "Annual Examination": "वार्षिक परीक्षा",
    "Apply promotion": "पदोन्नती लागू करा", "Apply to shown": "दाखवलेल्यांना लागू करा", "Applying for class": "कोणत्या वर्गासाठी अर्ज",
    "Approved leave summary (days)": "मंजूर रजेचा सारांश (दिवस)", "Ask the admin to create an academic year first.": "आधी अ‍ॅडमिनला शैक्षणिक वर्ष तयार करायला सांगा.", "Assign a student to a route": "विद्यार्थ्याला मार्ग नेमून द्या",
    "Assign roll numbers in new divisions": "नवीन तुकड्यांत हजेरी क्रमांक द्या", "Author": "लेखक", "Bank name": "बँकेचे नाव",
    "Book": "पुस्तक", "Book ID": "पुस्तक क्रमांक", "Books": "पुस्तके",
    "Borrower": "घेणारा", "Branch": "शाखा", "Cancel event": "कार्यक्रम रद्द करा",
    "Certificate or image (PDF, JPG, PNG, 5 MB)": "दाखला किंवा चित्र (PDF, JPG, PNG, 5 MB)", "Certificates": "दाखले", "A certificate number is given when you issue. The register below keeps every issued certificate.": "दाखला दिल्यावर क्रमांक मिळतो. खालील नोंदवहीत दिलेले सर्व दाखले राहतात.",
    "A student gets the grade of the highest row whose minimum percentage they reach.": "विद्यार्थी ज्या सर्वोच्च ओळीची किमान टक्केवारी गाठतो, त्या ओळीची श्रेणी त्याला मिळते.", "Choose a report and press Show report.": "अहवाल निवडा आणि 'अहवाल दाखवा' दाबा.", "Choose an exam and division.": "परीक्षा आणि तुकडी निवडा.",
    "Class / division": "वर्ग / तुकडी", "Class and subject": "वर्ग आणि विषय", "Class timetable": "वर्गाचे वेळापत्रक",
    "Classes will appear here.": "वर्ग इथे दिसतील.", "Close": "बंद करा", "Close academic year": "शैक्षणिक वर्ष बंद करा",
    "Close anyway (I understand some students or exams are not finished)": "तरीही बंद करा (काही विद्यार्थी किंवा परीक्षा अपूर्ण आहेत हे मला माहीत आहे)", "Code (optional)": "कोड (ऐच्छिक)", "Collection": "वसुली",
    "Community": "समुदाय", "Competition or event": "स्पर्धा किंवा कार्यक्रम", "Concessions": "सवलती",
    "Confirmation.": "पुष्टी.", "Contact page": "संपर्क पान", "Contacted": "संपर्क केला",
    "Create an academic year and divisions first.": "आधी शैक्षणिक वर्ष आणि तुकड्या तयार करा.", "Create an academic year first.": "आधी शैक्षणिक वर्ष तयार करा.", "Create exam": "परीक्षा तयार करा",
    "Create student": "विद्यार्थी तयार करा", "Create the next academic year first (Academic years page).": "आधी पुढचे शैक्षणिक वर्ष तयार करा (शैक्षणिक वर्षे पान).", "Create user": "वापरकर्ता तयार करा",
    "Daily attendance, visible to parents.": "रोजची उपस्थिती, पालकांना दिसते.", "Day": "दिवस", "Day (daily)": "दिवस (रोज)",
    "Deactivate": "निष्क्रिय करा", "Division (e.g. A)": "तुकडी (उदा. A)", "Division (optional)": "तुकडी (ऐच्छिक)",
    "Division (selected year)": "तुकडी (निवडलेले वर्ष)", "Division and subject": "तुकडी आणि विषय", "Download sample CSV": "नमुना CSV डाउनलोड करा",
    "Driver contact": "चालकाचा संपर्क", "Driver name": "चालकाचे नाव", "Drop time": "सोडण्याची वेळ",
    "Edit periods": "तास संपादित करा", "Edition": "आवृत्ती", "Email (optional)": "ईमेल (ऐच्छिक)",
    "Email (used to sign in)": "ईमेल (लॉगिनसाठी)", "End": "समाप्ती", "End date": "समाप्तीची तारीख",
    "Event": "कार्यक्रम", "Every academic year is already closed.": "सर्व शैक्षणिक वर्षे आधीच बंद आहेत.", "Exam date": "परीक्षेची तारीख",
    "Exam name": "परीक्षेचे नाव", "Exam results (totals)": "परीक्षेचे निकाल (एकूण)", "Export inventory CSV": "साठा CSV डाउनलोड करा",
    "Facebook page link (https://...)": "Facebook पानाची लिंक (https://...)", "Father name": "वडिलांचे नाव", "Fee and library reports:": "फी आणि ग्रंथालय अहवाल:",
    "Fee payment by bank transfer (NEFT / IMPS)": "बँक ट्रान्सफरने फी भरणा (NEFT / IMPS)", "Fee receipt": "फी पावती", "Fee receipt prefix (letters or digits, up to 6)": "फी पावतीचा उपसर्ग (अक्षरे किंवा अंक, कमाल 6)",
    "Fee type": "फी प्रकार", "Fee type name": "फी प्रकाराचे नाव", "Fill the online form with your child's details.": "ऑनलाइन फॉर्ममध्ये तुमच्या मुलाची माहिती भरा.",
    "Filter by name": "नावाने शोधा", "Find book": "पुस्तक शोधा", "First Term": "पहिले सत्र",
    "First name": "पहिले नाव", "Fixed amount": "ठराविक रक्कम", "Follow-up": "पाठपुरावा",
    "For": "कोणासाठी", "Fri": "शुक्र", "Friday": "शुक्रवार",
    "From year": "वर्षापासून", "Full name": "पूर्ण नाव", "Fully paid students": "पूर्ण फी भरलेले विद्यार्थी",
    "GR number": "GR क्रमांक", "Generate password": "पासवर्ड तयार करा", "Grading rules": "श्रेणी नियम",
    "Group collection by": "वसुलीचे गट करा", "High": "उच्च", "High only": "फक्त उच्च",
    "Home page tagline": "मुख्य पानाचे ब्रीदवाक्य", "Homework and timetable": "गृहपाठ आणि वेळापत्रक", "Homework date": "गृहपाठाची तारीख",
    "IFSC code": "IFSC कोड", "ISBN": "ISBN", "Import from CSV": "CSV मधून आयात करा",
    "Import valid rows": "योग्य ओळी आयात करा", "The AI can make mistakes, so always read and correct its text before using it. Do": "AI चुकू शकते, म्हणून त्याचा मजकूर वापरण्यापूर्वी नेहमी वाचून दुरुस्त करा. येथे", "The map updates by itself every few seconds while the bus is running. Time shown is an estimate. Map: OpenStreetMap contributors.": "बस चालू असताना नकाशा दर काही सेकंदांनी आपोआप अद्ययावत होतो. दाखवलेली वेळ अंदाजे आहे. नकाशा: OpenStreetMap योगदानकर्ते.",
    "from the school details in Settings and the notes below. Add admission steps, timings, rules, fee policy, holidays. Write only what is true.": "शाळेच्या तपशीलांवरून (Settings) आणि खालील टिपांवरून. प्रवेशाची प्रक्रिया, वेळा, नियम, फी धोरण, सुट्ट्या जोडा. फक्त खरे तेच लिहा.", "not": "कधीही", "only": "फक्त",
    "published": "प्रकाशित", "type names of students, phone numbers, addresses or any private details. Numbers and e-mails are removed automatically.": "विद्यार्थ्यांची नावे, फोन नंबर, पत्ते किंवा कोणतीही खाजगी माहिती लिहू नका. अंक आणि ईमेल आपोआप काढले जातात.", ", Principal": ", मुख्याध्यापक",
    ". Every flag shows its reason. This is a helper for teachers; please talk to the family before drawing any conclusion.": ". प्रत्येक सूचनेचे कारण दिसते. हे शिक्षकांसाठी सहायक साधन आहे; निष्कर्ष काढण्यापूर्वी कृपया कुटुंबाशी बोला.", ". Nothing is saved until you press Save.": ". तुम्ही 'जतन करा' दाबेपर्यंत काहीही जतन होत नाही.", ". Parents can pay any amount at any time; payments simply reduce the balance. Only one fee of each type is allowed per class and year.": ". पालक कधीही कोणतीही रक्कम भरू शकतात; भरणा फक्त शिल्लक कमी करतो. प्रत्येक वर्ग आणि वर्षासाठी प्रत्येक प्रकारची फी एकदाच ठेवता येते.",
    ". You see only the students your role is allowed to see.": ". तुमच्या भूमिकेला जे विद्यार्थी पाहण्याची परवानगी आहे तेच तुम्हाला दिसतात.", "Add subjects on the Subjects page first": "आधी 'विषय' पानावर विषय जोडा", "Name or admission no": "नाव किंवा प्रवेश क्रमांक",
    "Name, subject, ID": "नाव, विषय, क्रमांक", "Name, type, ID": "नाव, प्रकार, क्रमांक", "Student, parent, mobile, application no": "विद्यार्थी, पालक, मोबाइल, अर्ज क्रमांक",
    "Title, author, ISBN, Book ID": "शीर्षक, लेखक, ISBN, पुस्तक क्रमांक", "Type at least 2 letters": "किमान 2 अक्षरे लिहा", "Type title or Book ID": "शीर्षक किंवा पुस्तक क्रमांक लिहा",
    "https://": "https://", "Choose the division, start the camera and scan each student's ID card QR code. Scanned students are marked": "तुकडी निवडा, कॅमेरा सुरू करा आणि प्रत्येक विद्यार्थ्याच्या ओळखपत्रावरील QR कोड स्कॅन करा. स्कॅन केलेले विद्यार्थी असे नोंदवले जातात:", "Choose what happens to each student. Old records are never changed: promoted and repeating students get a": "प्रत्येक विद्यार्थ्याचे काय करायचे ते ठरवा. जुन्या नोंदी कधीही बदलत नाहीत: पदोन्नत आणि पुन्हा तोच वर्ग करणाऱ्या विद्यार्थ्यांना मिळते",
    "Closing a year never deletes anything. Students, fees, marks and attendance of the closed year stay available for reports and history. Move students to the new year first on the": "वर्ष बंद केल्याने काहीही पुसले जात नाही. बंद वर्षातील विद्यार्थी, फी, गुण आणि उपस्थिती अहवाल आणि इतिहासासाठी उपलब्ध राहतात. आधी विद्यार्थ्यांना नव्या वर्षात न्या:", "Connect each parent or student login to the right child. A parent with several children is linked once for each child. Create the login in Supabase first and set its role (Parent or Student) in Users and roles.": "प्रत्येक पालक किंवा विद्यार्थी लॉगिन योग्य मुलाशी जोडा. अनेक मुले असलेल्या पालकाला प्रत्येक मुलासाठी एकदा जोडा. आधी Supabase मध्ये लॉगिन तयार करा आणि 'वापरकर्ते आणि भूमिका' मध्ये त्याची भूमिका (पालक किंवा विद्यार्थी) ठरवा.", "Connect each teacher or staff member to their login. This lets teachers see their own leave and attendance and lets the system know which classes they teach. Create the login in Supabase first and set the role in Users and roles.": "प्रत्येक शिक्षक किंवा कर्मचारी त्याच्या लॉगिनशी जोडा. यामुळे शिक्षकांना स्वतःची रजा आणि उपस्थिती दिसते आणि ते कोणते वर्ग शिकवतात हे प्रणालीला कळते. आधी Supabase मध्ये लॉगिन तयार करा आणि 'वापरकर्ते आणि भूमिका' मध्ये भूमिका ठरवा.",
    "Counted per calendar year, working days only. Leave a type empty if it has no limit.": "कॅलेंडर वर्षानुसार, फक्त कामकाजाचे दिवस मोजले जातात. मर्यादा नसल्यास प्रकार रिकामा ठेवा.", "Edit this page to list your real facilities (library, laboratory, playground, transport and so on). Nothing here is invented.": "इथे तुमच्या खऱ्या सुविधा (ग्रंथालय, प्रयोगशाळा, मैदान, वाहतूक इ.) लिहा. इथे काहीही स्वतःहून लिहिलेले नाही.", "Grading rules (A+, A, B...) are managed on the": "श्रेणी नियम (A+, A, B...) इथे सांभाळले जातात:",
    "Holidays and vacations are not counted as absent, and attendance cannot be marked on them.": "सुट्ट्या आणि उन्हाळी/दिवाळी सुट्ट्या गैरहजर म्हणून मोजल्या जात नाहीत, आणि त्या दिवशी हजेरी नोंदवता येत नाही.", "Holidays and vacations in the School calendar are always off. A \"Special school day\" in the calendar makes a weekly off day a working day.": "शाळेच्या दिनदर्शिकेतील सुट्ट्या आणि सुट्टीचे दिवस नेहमी बंद असतात. दिनदर्शिकेतील 'विशेष शाळेचा दिवस' साप्ताहिक सुट्टीच्या दिवसाला कामकाजाचा दिवस करतो.", "If a student has no photo yet, the initials are printed. Add photos on the student's profile page.": "विद्यार्थ्याचा फोटो नसेल तर आद्याक्षरे छापली जातात. विद्यार्थ्याच्या प्रोफाइल पानावर फोटो जोडा.",
    "Imports into the academic year selected above.": "वर निवडलेल्या शैक्षणिक वर्षात आयात होते.", "Internal Assessment": "अंतर्गत मूल्यमापन", "Issue a book": "पुस्तक द्या",
    "Issue book": "पुस्तक द्या", "Issued": "दिलेले", "Issued, overdue and returned": "दिलेले, मुदत संपलेले आणि परत केलेले",
    "Keep this page open and the screen on while driving. Parents see the bus on the map only while a trip is running.": "गाडी चालवताना हे पान उघडे आणि स्क्रीन चालू ठेवा. ट्रिप सुरू असतानाच पालकांना बस नकाशावर दिसते.", "LKG, UKG and Grades 1 to 10.": "LKG, UKG आणि इयत्ता 1 ते 10.", "Last date to pay": "भरण्याची शेवटची तारीख",
    "Last name": "आडनाव", "Leave days per year (set by the school)": "वर्षातील रजेचे दिवस (शाळेने ठरवलेले)", "Leave this empty": "हे रिकामे ठेवा",
    "Library fine per day (Rs.)": "ग्रंथालय दंड प्रति दिवस (रु.)", "Logo (PNG, JPG or WebP, up to 1 MB)": "लोगो (PNG, JPG किंवा WebP, कमाल 1 MB)", "Low attendance alert below (%)": "या टक्केवारीखाली कमी उपस्थितीची सूचना (%)",
    "Mark all absent": "सर्वांना गैरहजर करा", "Mark present": "उपस्थित नोंदवा", "Mark remaining as absent": "उरलेल्यांना गैरहजर नोंदवा",
    "Maximum marks": "कमाल गुण", "Medium": "मध्यम", "Message": "संदेश",
    "Message (you can edit; {student} {class} {amount} {school} are filled in)": "संदेश (तुम्ही बदलू शकता; {student} {class} {amount} {school} आपोआप भरले जातात)", "Mid Term": "मध्य सत्र परीक्षा", "Middle name": "मधले नाव",
    "Minimum %": "किमान %", "Mobile number": "मोबाइल क्रमांक", "Module": "विभाग",
    "Mon": "सोम", "Monday": "सोमवार", "Mother name": "आईचे नाव",
    "Needs attention (medium and high)": "लक्ष द्यावे असे (मध्यम आणि उच्च)", "New": "नवीन", "Next year (becomes active)": "पुढचे वर्ष (चालू होईल)",
    "No academic years yet. Add the first one above.": "अजून शैक्षणिक वर्षे नाहीत. वर पहिले जोडा.", "No achievements found.": "कोणतीही उपलब्धी सापडली नाही.", "No active routes.": "कोणतेही चालू मार्ग नाहीत.",
    "No active teachers. Add teachers first.": "चालू शिक्षक नाहीत. आधी शिक्षक जोडा.", "No activities yet for this year.": "या वर्षासाठी अजून उपक्रम नाहीत.", "No approved leave in this selection.": "या निवडीत मंजूर रजा नाही.",
    "No books found.": "कोणतीही पुस्तके सापडली नाहीत.", "No camera? Type the admission number": "कॅमेरा नाही? प्रवेश क्रमांक लिहा", "No certificate issued yet.": "अजून कोणताही दाखला दिलेला नाही.",
    "No claims.": "कोणतेही दावे नाहीत.", "No dates added yet. Add holidays above.": "अजून तारखा जोडलेल्या नाहीत. वर सुट्ट्या जोडा.", "No diary entries in this period.": "या कालावधीत डायरीच्या नोंदी नाहीत.",
    "No division": "तुकडी नाही", "No enquiries found.": "कोणतीही चौकशी सापडली नाही.", "No exams in this year.": "या वर्षात परीक्षा नाहीत.",
    "No exams yet. Create the first one above.": "अजून परीक्षा नाहीत. वर पहिली तयार करा.", "No fees defined for this year yet.": "या वर्षासाठी अजून फी ठरवलेली नाही.", "No grouping": "गट नाही",
    "No later year. Create it first.": "पुढचे वर्ष नाही. आधी ते तयार करा.", "No leave requests.": "कोणत्याही रजेच्या विनंत्या नाहीत.", "No logo uploaded yet.": "अजून लोगो अपलोड केलेला नाही.",
    "No meetings are planned yet.": "अजून कोणत्याही सभा ठरलेल्या नाहीत.", "No meetings yet. Plan one above.": "अजून सभा नाहीत. वर एक ठरवा.", "No open year": "चालू वर्ष नाही",
    "No overdue fees. Nothing to remind.": "थकीत फी नाही. आठवण करून देण्यासारखे काही नाही.", "No problems found.": "कोणत्याही अडचणी आढळल्या नाहीत.", "No records match these filters.": "या फिल्टरशी जुळणाऱ्या नोंदी नाहीत.",
    "No requests.": "कोणत्याही विनंत्या नाहीत.", "No routes yet.": "अजून मार्ग नाहीत.", "No school bus is assigned to your child.": "तुमच्या मुलाला शाळेची बस नेमलेली नाही.",
    "No student is linked to your login. Please ask the school office.": "तुमच्या लॉगिनशी कोणताही विद्यार्थी जोडलेला नाही. कृपया शाळेच्या कार्यालयाला विचारा.", "No student selected.": "कोणताही विद्यार्थी निवडलेला नाही.", "No students assigned.": "कोणतेही विद्यार्थी नेमलेले नाहीत.",
    "No students to show for this choice.": "या निवडीसाठी दाखवायला विद्यार्थी नाहीत.", "No subject teachers assigned for this year yet.": "या वर्षासाठी अजून विषय शिक्षक नेमलेले नाहीत.", "No subjects yet. Add the first one above.": "अजून विषय नाहीत. वर पहिला जोडा.",
    "No subjects yet. Add them on the": "अजून विषय नाहीत. ते इथे जोडा:", "No teacher": "शिक्षक नाही", "No use yet.": "अजून वापर नाही.",
    "Non-Teaching Staff": "शिक्षकेतर कर्मचारी", "None.": "काही नाही.", "Not assigned": "नेमलेले नाही",
    "Nothing added yet.": "अजून काही जोडलेले नाही.", "Only Super Admin and School Admin can change these settings. Every change is recorded in the Audit logs.": "हे सेटिंग्ज फक्त सुपर अ‍ॅडमिन आणि स्कूल अ‍ॅडमिन बदलू शकतात. प्रत्येक बदल ऑडिट लॉगमध्ये नोंदवला जातो.", "Only available": "फक्त उपलब्ध",
    "Oral": "तोंडी", "Order number": "क्रम क्रमांक", "Overdue fees": "थकीत फी",
    "Page 1": "पान 1", "Parent meeting": "पालक सभा", "Parent mobile": "पालकाचा मोबाइल",
    "Parent or guardian name": "पालक किंवा पालकत्व घेणाऱ्याचे नाव", "Parents and students can see them after login.": "पालक आणि विद्यार्थ्यांना लॉगिननंतर दिसतात.", "Parents can send an admission enquiry online. The school office will contact you.": "पालक ऑनलाइन प्रवेश चौकशी पाठवू शकतात. शाळेचे कार्यालय तुमच्याशी संपर्क करेल.",
    "Parents report a UPI payment with its reference number. Check it in your bank or UPI app, then approve (a receipt is made) or reject.": "पालक UPI भरणा त्याच्या संदर्भ क्रमांकासह कळवतात. तुमच्या बँक किंवा UPI ॲपमध्ये तपासा, मग मंजूर करा (पावती तयार होते) किंवा नाकारा.", "Parents see this only after login, on the Fees tab. Leave empty to switch UPI payment off.": "पालकांना हे फक्त लॉगिननंतर 'Fees' टॅबवर दिसते. UPI भरणा बंद करण्यासाठी रिकामे ठेवा.", "Parents whose fee is overdue. The button opens WhatsApp with the message ready; you press Send yourself. Nothing is sent automatically.": "ज्या पालकांची फी थकीत आहे. बटण WhatsApp मध्ये संदेश तयार करून उघडते; पाठवा तुम्ही स्वतः दाबता. काहीही आपोआप पाठवले जात नाही.",
    "Partially paid": "अंशतः भरलेली", "Partially paid students": "अंशतः फी भरलेले विद्यार्थी", "Passing marks": "उत्तीर्ण गुण",
    "Payee name shown to parents": "पालकांना दाखवायचे प्राप्तकर्त्याचे नाव", "Payment date": "भरण्याची तारीख", "Pending fees": "प्रलंबित फी",
    "Percentage": "टक्केवारी", "Photos from school events and activities.": "शाळेच्या कार्यक्रमांचे आणि उपक्रमांचे फोटो.", "Pickup time": "घेण्याची वेळ",
    "Position or award": "पद किंवा पुरस्कार", "Position or result": "क्रमांक किंवा निकाल", "Practical": "प्रात्यक्षिक",
    "Preliminary": "प्राथमिक", "Previous class (if any)": "मागील वर्ग (असल्यास)", "Previous school": "मागील शाळा",
    "Previous school (if any)": "मागील शाळा (असल्यास)", "Price": "किंमत", "Principal / Headmaster name": "मुख्याध्यापक / मुख्याध्यापिकेचे नाव",
    "Promote to next class": "पुढच्या वर्गात पदोन्नती", "Public website text": "सार्वजनिक वेबसाइटवरील मजकूर", "Publisher": "प्रकाशक",
    "Purpose (for example: bank account, passport)": "कारण (उदा. बँक खाते, पासपोर्ट)", "Qualification": "पात्रता", "Quantity": "संख्या",
    "Recognition and registration details (one per line)": "मान्यता आणि नोंदणी तपशील (प्रत्येक एका ओळीत)", "Record an achievement (an admin must approve it)": "उपलब्धी नोंदवा (अ‍ॅडमिनने मंजूर करणे आवश्यक)", "Record payment": "भरणा नोंदवा",
    "Reference number": "संदर्भ क्रमांक", "Reopen for correction": "दुरुस्तीसाठी पुन्हा उघडा", "Repeat same class": "तोच वर्ग पुन्हा",
    "Report card": "प्रगतीपुस्तक", "Requests from parents. Class teachers handle leave requests for their own division. The office handles certificate requests.": "पालकांच्या विनंत्या. रजेच्या विनंत्या वर्गशिक्षक आपापल्या तुकडीसाठी हाताळतात. दाखल्यांच्या विनंत्या कार्यालय हाताळते.", "Returned": "परत केलेले",
    "Route": "मार्ग", "Route name": "मार्गाचे नाव", "Routes and stops": "मार्ग आणि थांबे",
    "Rules": "नियम", "Run check": "तपासणी चालवा", "Sat": "शनि",
    "Saturday": "शनिवार", "Save book": "पुस्तक जतन करा", "Save grading rules": "श्रेणी नियम जतन करा",
    "Save homework": "गृहपाठ जतन करा", "Save settings": "सेटिंग्ज जतन करा", "Save student": "विद्यार्थी जतन करा",
    "School UPI ID (for example school@bank)": "शाळेचा UPI ID (उदा. school@bank)", "School contact.": "शाळेचा संपर्क.", "School details": "शाळेचा तपशील",
    "School ends (HH:MM)": "शाळा सुटण्याची वेळ (HH:MM)", "School name": "शाळेचे नाव", "School starts (HH:MM)": "शाळा सुरू होण्याची वेळ (HH:MM)",
    "See the photo gallery": "फोटो गॅलरी पहा", "Send a leave application or ask for a certificate. The school will reply here and you will get a notification.": "रजेचा अर्ज पाठवा किंवा दाखला मागा. शाळा इथेच उत्तर देईल आणि तुम्हाला सूचना मिळेल.", "Send an enquiry.": "चौकशी पाठवा.",
    "Send overdue reminders to parents": "पालकांना थकबाकीची आठवण पाठवा", "Send your child's details online and the school will contact you.": "तुमच्या मुलाची माहिती ऑनलाइन पाठवा आणि शाळा तुमच्याशी संपर्क करेल.", "Set shown students to": "दाखवलेल्या विद्यार्थ्यांना असे ठेवा",
    "Set the": "हे ठेवा", "Shelf": "कप्पा", "Show on public website": "सार्वजनिक वेबसाइटवर दाखवा",
    "Shown to parents only after login, on the Fees tab, with a Copy button. Leave empty to hide. Double-check the account number: parents will send real money to it.": "पालकांना हे फक्त लॉगिननंतर 'Fees' टॅबवर, Copy बटणासह दिसते. लपवण्यासाठी रिकामे ठेवा. खाते क्रमांक दोनदा तपासा: पालक त्यावर खरे पैसे पाठवतील.", "Skip (decide later)": "वगळा (नंतर ठरवा)", "Special school day (working day on a weekly off)": "विशेष शाळेचा दिवस (साप्ताहिक सुट्टीला कामकाजाचा दिवस)",
    "Sports, cultural, academic, drawing, music, dance, science, quiz and community activities.": "क्रीडा, सांस्कृतिक, शैक्षणिक, चित्रकला, संगीत, नृत्य, विज्ञान, प्रश्नमंजुषा आणि समाजसेवा उपक्रम.", "Staff type": "कर्मचाऱ्याचा प्रकार", "Start camera": "कॅमेरा सुरू करा",
    "Stop": "थांबवा", "Stop camera": "कॅमेरा बंद करा", "Student ledger": "विद्यार्थी खतावणी",
    "Student list": "विद्यार्थी यादी", "Student name": "विद्यार्थ्याचे नाव", "Student profile": "विद्यार्थी प्रोफाइल",
    "Students checked": "तपासलेले विद्यार्थी", "Students who may need attention, found from": "ज्यांच्याकडे लक्ष द्यावे लागेल असे विद्यार्थी, यावरून शोधलेले:", "Students with pending fees": "फी प्रलंबित असलेले विद्यार्थी",
    "Subject name": "विषयाचे नाव", "Subject performance": "विषयनिहाय कामगिरी", "Submit marks": "गुण सादर करा",
    "Suggest for the public website (student shown as first name and last initial)": "सार्वजनिक वेबसाइटसाठी सुचवा (विद्यार्थ्याचे पहिले नाव आणि आडनावाचे पहिले अक्षर दाखवले जाते)", "Sun": "रवि", "Support Staff": "सहायक कर्मचारी",
    "Teacher timetable": "शिक्षकांचे वेळापत्रक", "Teachers approved for the public website": "सार्वजनिक वेबसाइटसाठी मंजूर शिक्षक", "Teaching Staff": "शिक्षक कर्मचारी",
    "Telegram link (https://...)": "Telegram लिंक (https://...)", "Temporary password (8 or more characters)": "तात्पुरता पासवर्ड (8 किंवा अधिक अक्षरे)", "The new user can sign in immediately and starts as Active with the role you choose. Tell them their email and temporary password. Existing users: change the role or Active box and press Save, or press Password to set a new one.": "नवीन वापरकर्ता लगेच लॉगिन करू शकतो आणि तुम्ही निवडलेल्या भूमिकेसह 'सक्रिय' म्हणून सुरू होतो. त्यांना त्यांचा ईमेल आणि तात्पुरता पासवर्ड सांगा. सध्याचे वापरकर्ते: भूमिका किंवा 'सक्रिय' चौकट बदला आणि 'जतन करा' दाबा, किंवा नवीन पासवर्डसाठी 'Password' दाबा.",
    "The order number decides the order of subjects on marks sheets, results and report cards. You can change any subject at any time.": "क्रम क्रमांक ठरवतो की गुणपत्रके, निकाल आणि प्रगतीपुस्तकांवर विषय कोणत्या क्रमाने येतील. कोणताही विषय कधीही बदलता येतो.", "The school office calls you to share details.": "शाळेचे कार्यालय तुम्हाला तपशील सांगण्यासाठी फोन करेल.", "This link is not complete. Ask the school office for your bus link.": "ही लिंक अपूर्ण आहे. तुमच्या बसच्या लिंकसाठी शाळेच्या कार्यालयाला विचारा.",
    "This month collection": "या महिन्याची वसुली", "This page checks the selected year for mistakes: a fee type given twice, fees from the wrong class, and old monthly rows. If the lower sections are empty, your fees are clean.": "हे पान निवडलेल्या वर्षातील चुका तपासते: दोनदा दिलेला फी प्रकार, चुकीच्या वर्गाची फी आणि जुन्या मासिक ओळी. खालील भाग रिकामे असतील तर तुमची फी स्वच्छ आहे.", "Thu": "गुरु",
    "Thursday": "गुरुवार", "Timings and working days": "वेळा आणि कामकाजाचे दिवस", "Title shown on the About page": "'आमच्याबद्दल' पानावर दाखवायचे शीर्षक",
    "To year": "वर्षापर्यंत", "Today collection": "आजची वसुली", "Total fee per student (year)": "प्रति विद्यार्थी एकूण फी (वर्ष)",
    "Total outstanding": "एकूण थकबाकी", "Transferred out": "बदली होऊन गेलेले", "Transport report": "वाहतूक अहवाल",
    "Tue": "मंगळ", "Tuesday": "मंगळवार", "Type at least 2 letters of the student name or admission number.": "विद्यार्थ्याच्या नावाची किंवा प्रवेश क्रमांकाची किमान 2 अक्षरे लिहा.",
    "Type the year name to confirm": "खात्री करण्यासाठी वर्षाचे नाव लिहा", "Unable to load fees. Please try again.": "फी लोड करता आली नाही. कृपया पुन्हा प्रयत्न करा.", "Unable to load homework. Please try again.": "गृहपाठ लोड करता आला नाही. कृपया पुन्हा प्रयत्न करा.",
    "Unable to load the overview. Please try again.": "आढावा लोड करता आला नाही. कृपया पुन्हा प्रयत्न करा.", "Unable to load this receipt. Please try again.": "ही पावती लोड करता आली नाही. कृपया पुन्हा प्रयत्न करा.", "Unable to load this report card. Please try again.": "हे प्रगतीपुस्तक लोड करता आले नाही. कृपया पुन्हा प्रयत्न करा.",
    "Unit Test": "घटक चाचणी", "Unit tests, term exams and annual examination, with printable report cards.": "घटक चाचण्या, सत्र परीक्षा आणि वार्षिक परीक्षा, छापण्यायोग्य प्रगतीपुस्तकांसह.", "User": "वापरकर्ता",
    "Vacation": "सुट्टी", "Value": "मूल्य", "Vehicle number": "वाहन क्रमांक",
    "Visit and documents.": "भेट आणि कागदपत्रे.", "Waived": "माफ", "Website": "वेबसाइट",
    "Wed": "बुध", "Wednesday": "बुधवार", "Whole school": "संपूर्ण शाळा",
    "Working days": "कामकाजाचे दिवस", "Works without internet too: open the division once while online, and later (even with no network) scan and Save; the attendance is sent automatically when the internet returns.": "इंटरनेटशिवायही चालते: एकदा ऑनलाइन असताना तुकडी उघडा, नंतर (नेटवर्क नसतानाही) स्कॅन करून जतन करा; इंटरनेट परत आल्यावर हजेरी आपोआप पाठवली जाते.", "Year to close": "बंद करायचे वर्ष",
    "Your login is not linked to an employee record yet. Ask the administrator to link it (Link logins to employees).": "तुमचे लॉगिन अजून कर्मचारी नोंदीशी जोडलेले नाही. अ‍ॅडमिनला ते जोडायला सांगा (लॉगिन कर्मचाऱ्यांशी जोडा).", "accountant": "लेखापाल", "admissions": "प्रवेश",
    "and": "आणि", "attendance": "उपस्थिती", "attendance (last 30 days)": "उपस्थिती (गेले 30 दिवस)",
    "class teacher": "वर्गशिक्षक", "enrollment in the new year, and the old year keeps its history. Nothing is saved until you press Apply.": "नवीन वर्षातील नोंदणी, आणि जुन्या वर्षाचा इतिहास राहतो. तुम्ही 'लागू करा' दाबेपर्यंत काहीही जतन होत नाही.", "exam marks": "परीक्षेचे गुण",
    "exams": "परीक्षा", "librarian": "ग्रंथपाल", "library": "ग्रंथालय",
    "marks": "गुण", "new": "नवीन", "notices": "सूचना",
    "overdue fees": "थकीत फी", "page first.": "पान आधी.", "page.": "पान.",
    "page. Admission and GR numbers are typed by the office when a student is admitted.": "पान. प्रवेश आणि GR क्रमांक विद्यार्थ्याला प्रवेश देताना कार्यालय टाइप करते.", "parent": "पालक", "present": "उपस्थित",
    "principal": "मुख्याध्यापक", "reception": "स्वागत", "school admin": "स्कूल अ‍ॅडमिन",
    "student": "विद्यार्थी", "students": "विद्यार्थी", "super admin": "सुपर अ‍ॅडमिन",
    "teacher": "शिक्षक", "total fee per student for the year": "वर्षासाठी प्रति विद्यार्थी एकूण फी", "[School Address]": "[शाळेचा पत्ता]",
    "[School Phone]": "[शाळेचा फोन]", "[School Email]": "[शाळेचा ईमेल]", "[Principal Name]": "[मुख्याध्यापकांचे नाव]",
    "[Mission statement – to be provided by the school]": "[ध्येय (Mission) – शाळेने द्यायचे आहे]", "[Vision statement – to be provided by the school]": "[दृष्टिकोन (Vision) – शाळेने द्यायचा आहे]", "[Principal message – to be provided by the school]": "[मुख्याध्यापकांचा संदेश – शाळेने द्यायचा आहे]",
    "[Admission dates and fee information – to be provided by the school]": "[प्रवेशाच्या तारखा आणि फी माहिती – शाळेने द्यायची आहे]", "[Curriculum, board and medium details – to be provided by the school]": "[अभ्यासक्रम, बोर्ड आणि माध्यम – शाळेने द्यायचे आहे]", "[Details – to be provided by the school]": "[तपशील – शाळेने द्यायचा आहे]",
    "[Documents required – to be provided by the school]": "[आवश्यक कागदपत्रे – शाळेने द्यायची आहेत]", "[Facilities – to be provided by the school]": "[सुविधा – शाळेने द्यायच्या आहेत]", "[Facility 1]": "[सुविधा 1]",
    "[Facility 2]": "[सुविधा 2]", "[Facility 3]": "[सुविधा 3]", "[Office hours – to be provided by the school]": "[कार्यालयीन वेळ – शाळेने द्यायची आहे]",
    "[Registration details – to be provided by the school]": "[नोंदणी तपशील – शाळेने द्यायचा आहे]", "[School history and introduction – to be provided by the school]": "[शाळेचा इतिहास आणि ओळख – शाळेने द्यायची आहे]", "[School introduction – to be provided by the school]": "[शाळेची ओळख – शाळेने द्यायची आहे]",
    "Name (e.g. 2026-27)": "नाव (उदा. 2026-27)", "Saraswati English Medium School teaches LKG, UKG and Grades 1 to 10.": "सरस्वती इंग्लिश मीडियम स्कूलमध्ये LKG, UKG आणि इयत्ता 1 ते 10 पर्यंत शिक्षण दिले जाते.",
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
    "Date of leaving": "शाळा सोडल्याची तारीख", "Total fee": "एकूण फी", "Outstanding": "थकबाकी", "Payment history": "भरणा इतिहास", "Pay by UPI": "UPI ने भरा", "Pay the school fee online": "शाळेची फी ऑनलाइन भरा", "Bank transfer (NEFT / IMPS)": "बँक ट्रान्सफर (NEFT / IMPS)", "Account name": "खातेधारकाचे नाव", "Account number": "खाते क्रमांक", "Copy": "कॉपी", "Copied": "कॉपी झाले", "Scan with any UPI app on another phone.": "दुसऱ्या फोनवरील कुठल्याही UPI ॲपने स्कॅन करा.", "Paid by": "कसे भरले", "UTR / reference number": "UTR / संदर्भ क्रमांक", "Receipt": "पावती",
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
