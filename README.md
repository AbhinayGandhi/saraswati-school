# Saraswati English Medium School: website and ERP (Phase 1)

Phase 1 contains: project foundation, Supabase schema (roles, academic years, classes, divisions, subjects, settings, audit log, Row Level Security), login, password reset, protected dashboard with role-based menu.

## Setup (no programming needed)
1. Create a free account at github.com, make a new repository, and upload every file and folder from this project.
2. Create a free project at supabase.com.
3. In Supabase, open **SQL Editor**, paste the whole of `supabase/schema.sql`, and click **Run**.
4. In Supabase open **Project Settings > API**. Copy the **Project URL** and the **anon / publishable key**.
5. In GitHub, open `js/config.js`, click the pencil icon, paste both values, and save. Never paste a service-role key or database password anywhere.
6. **Create the first admin:** in Supabase open **Authentication > Users > Add user**, enter an email and a strong password of your own choice, and tick auto-confirm. Then open **SQL Editor** and run (use your email):
   `update profiles set role = 'super_admin', is_active = true, full_name = 'Your Name' where id = (select id from auth.users where email = 'you@example.com');`
7. In Supabase open **Authentication > Providers > Email** and turn off public sign-ups. Add other users from the Users page and activate them with the same kind of SQL or from the admin screens built in later phases.
8. In GitHub open **Settings > Pages**, choose the main branch and root folder, and save. After a minute your site is live at the address shown.
9. Open the site, click Login, and sign in with the admin account.

## Phase 2
If you already ran Phase 1, run `supabase/phase2.sql` once in the SQL Editor. New screens: Academic years, Classes and divisions, Subjects.

## Phase 3
Run `supabase/phase3.sql` once. New screens: Students (search, filter, add, CSV import and export), Teachers, Staff.

## Phase 4
Run `supabase/phase4.sql` once. New: Attendance (mark, edit, monthly report, CSV, print), School calendar (holidays block attendance), Student profile and edit.

## Phase 5
Run `supabase/phase5.sql` once. New: Subject teachers, Exams (subjects, grading rules, publish), Marks entry (draft, submit, reopen, lock), Results (percentage, grade, rank, CSV), printable Report card with remarks.

## Phase 6
Run `supabase/phase6.sql` once. New: Fee types, Fee structure (assign to students with installments), Fees and payments (record payments, concessions, dashboard), printable Receipt, Fee reports with CSV and print. Payments and concessions are permanent and cannot be edited or deleted.

## Update 6b
Run `supabase/phase6b.sql` once on an existing project. Adds subject order numbers and editing, multi-month fee payment with one receipt, and a Users and roles screen.

## Phase 7
Run `supabase/phase7.sql` once on an existing project. New: Timetable (conflict checks), Homework with attachments, Notices (drafts, publish, audience, public notices on the home page), Notifications with an unread badge.

## Update 7b
Run `supabase/phase7b.sql` once. Adds Remove unpaid on Fee structure (keeps anything already paid) and a duplicate warning when assigning a fee.

## Update 7c (simpler fees)
Run `supabase/phase7c.sql` once. One total fee per student per fee type; parents pay any amount at any time (Take payment). Old monthly rows are merged safely. Duplicate fee structures are blocked. The Fee check page lists mistakes.

## Phase 8
Run `supabase/phase8.sql` once. New: Events (list and calendar, publish, public events), Activities with participants, Achievements with approval, Gallery (private storage, approval, public gallery for approved public photos, photos shrunk before upload).

## Phase 9
Run `supabase/phase9.sql` once. New: Library (books, issue, return, overdue, fines, CSV), public Admission enquiry form and admin screen with convert-to-student, Transport (routes, stops, assignments, report), Staff leave with approval, Teacher attendance, and Link logins to employees.

## Phase 10
Run `supabase/phase10.sql` once. New: Parent portal (child switcher, profile, attendance, results, homework, timetable, fees, receipts, activities, library, notices), Student portal, Teacher portal, and Link parents and students. Students now see only their own records. Accountant and librarian can now see student names (fixes empty lists on the Fees and Library pages for those roles).

## Phase 11
Run `supabase/phase11.sql` once (after Phase 10). New pages: **Reports** (attendance, exam results, subject performance, student list, each with Print and CSV), **School settings** (details, logo, timings, working days, attendance alert, library fine, receipt prefix, public text), **Audit logs** (filters, CSV, print), **Student promotion** (promote, repeat, transfer, alumni, inactive; bulk, with confirmation) and **Academic year closing** (checks first; nothing is deleted). The School calendar now has a "Special school day". Attendance is refused on holidays, vacations and weekly-off days.
Notes: marks changed after submission, attendance edits, role changes and setting changes are recorded automatically by the database. Fee and library reports stay on their own pages (linked from Reports). If old exports stop at 1000 rows, raise "Max rows" in Supabase Settings, API.

## Creating users from the website
Follow `SETUP-USERS.md` once. Then **Users and roles** can create logins (name, email, role, temporary password) and set new passwords, no Supabase visit needed.

## ALL-IN-ONE database script
`supabase/ALL-IN-ONE.sql` contains Phase 1 to Phase 12 in one file and can be run on a new, partly set-up or complete project, any number of times. Use it if you are unsure which phase files you ran. `supabase/CHECK.sql` only reads and reports.

## Phase 12 (final)
Run `supabase/phase12.sql` once (after Phase 11). Closes functions to public visitors, hides empty gallery album names, adds an admission-form flood limit, speed indexes and gallery thumbnails. New: **Backup** page (Super Admin), mobile layout fix. Read these guides: `DEPLOYMENT.md` (go-live checklist), `BACKUP.md`, `SECURITY.md`, `TESTING.md`.

## Known limits
Admission and GR numbers are typed by the office. Roll numbers are assigned alphabetically per division (no one-by-one editing screen). Fee and library reports are on their own pages. No two-factor login and no Content Security Policy (GitHub Pages limitation).

## New features (after Phase 12)
Run `supabase/phase13.sql`, `phase14.sql` and `phase15.sql` once each (or just run ALL-IN-ONE.sql on a new project).
- Certificates (Bonafide, Transfer, Character) with a register, ID cards, exam hall tickets, fee reminder list, birthdays on the dashboard.
- Parents can report a UPI payment (set the school UPI ID in School settings). The accountant approves it on "UPI payment claims" and a receipt is made.
- Marathi / English switch (button in the top bar). It changes menus, headings and buttons only, not names or typed text.
- Leave balance (set days per year on the Staff leave page) and Teacher diary (what was taught each day).

## Round 3: Install as app, QR attendance, absence alerts
- **Install as app (PWA):** manifest.json, sw.js, offline.html, js/pwa.js. Icons in images/icon-192.png and icon-512.png are placeholders; replace with the school logo (same names and sizes).
- **QR attendance:** qr-attendance.html. ID cards carry a QR with `SES|<admission_no>`. Camera needs HTTPS (GitHub Pages is HTTPS). Manual admission-no entry is the fallback.
- **Absence alerts:** run supabase/phase16.sql. Marking a student absent (today or within 2 days) notifies active guardians in the portal. No SMS.

## Round 4: Live bus tracking (free)
- Run supabase/phase17.sql. On the Transport page: set each stop's map location (type lat/lng or press "Use my current location" while standing at the stop), then copy the **Driver link** for each bus and give it to that driver. "Make new link" cancels the old link.
- Driver opens the link on his phone, presses Start trip (pickup or drop). Phone GPS is sent every 10 seconds. Page must stay open with the screen on.
- Parents: menu "Track bus" shows the bus on an OpenStreetMap map, their child's stop, distance and a rough time. They also get in-portal notifications "Bus started" and "Bus is near <stop>" (within 500 m, once per trip).
- Cost: zero. Map tiles from OpenStreetMap (fine for a school; keep traffic light). Leaflet is vendored (BSD-2).

## Round 5A: Bus boarding scan, photos, insights
- Run supabase/phase18.sql (needs phase17 first). It creates the private `photos` bucket, boarding log and the insights function.
- **Boarding:** driver page now has a student QR scanner (ID card QR). Pickup trip: "boarded". Drop trip: "got off". Parents get a notification and see it on Track bus.
- **Photos:** student profile page and Teachers page have Add/Change photo (shrunk to ~400 px, max 1 MB, private). Photos print on ID cards.
- **Student insights:** menu "Student insights" lists students needing attention (attendance, marks trend, overdue fees) with the reason for every flag. Teachers see only their own division. Fees are shown only to fee staff.

## Round 5B: Meetings (PTM), parent requests, library reminders
- Run supabase/phase19.sql. Then use the new menu items **Meetings (PTM)** and **Requests**.
- **PTM:** a class teacher or the office plans a meeting (date, time range, minutes per parent). Time slots are made automatically and parents of that division are notified. A parent books one slot per child, can cancel, and the teacher gets a notification. Teacher notes are private (parents cannot read them).
- **Requests:** parents send leave or certificate requests. Class teacher decides leave requests for their own division; the office decides certificate requests. The parent is notified of the decision.
- **Library:** "Send overdue reminders to parents" (once per book per parent per 7 days), "Mark paid" for fines, and the parent portal Library tab shows paid/unpaid.
- Fix: elements with the `hidden` attribute are now really hidden (global CSS rule), so forms meant for staff are no longer shown to parents.

## Round 6: AI assistant
- Run supabase/phase20.sql, deploy supabase/functions/ai-assistant/index.ts as an Edge Function named `ai-assistant`, add the secret GEMINI_API_KEY. Full steps: AI-SETUP-GUIDE.md.
- Menu "AI assistant": notice writer, translator, report remarks, question maker (teachers/office/admin) and "Ask the school" (parents). Admin control panel: on/off switch, daily limits, school notes the parent chat may use.
- Safety: login required; students never get AI; phone numbers/e-mails removed before sending; AI only returns text; daily limits; nothing the user types is stored (only a use count).

## Round 7: dashboard charts and fee overview
- Run `supabase/phase21.sql` once (adds `dashboard_overview()` and `fee_overview()`; read-only, role-gated).
- `dashboard.html` now shows KPIs, "needs attention" links, attendance trend/by class, strength, gender split, fee collection (fee roles only).
- `fee-reports.html` has an overview (monthly collection, outstanding by class, ageing, payment modes, top 10 overdue) above the old detailed reports (unchanged).
- `js/charts.js`: dependency-free SVG charts with tooltips and a Table view for every chart.

## Round 8: offline QR attendance
- `qr-attendance.html` now uses `js/offline.js` like `attendance.html`: the roster is cached on the phone, Save queues records when there is no internet, and they are sent automatically (or via "Sync now") when it returns. The server still enforces holidays and permissions; refused rows are listed in the banner.
- Teachers should open each division once while online so it is available offline. `sw.js` cache bumped to `ses-v3`.

## Round 9: parent portal
- New default tab "Today" (parent and student portals): today's attendance, 30-day attendance %, fee outstanding/overdue (parents only), today's timetable, homework due soon, latest notices, upcoming events, quick links (bus, requests, meetings, AI).
- Attendance tab gets a monthly % chart; Results tab gets an exam-by-exam percentage trend. Uses only existing RLS-protected tables; no SQL needed.

## Round 10: security audit
- Run `supabase/phase22.sql` once (read-only views, anon write revoke, enquiry rate cap). See SECURITY.md "Final audit".

## Round 11: real school content
- CORRECTION: the first version of `REAL-CONTENT.sql` used details of the Marathi-medium school (Saraswati Vidyalaya, saraswativk.edu.in). Run `supabase/REAL-CONTENT-UNDO.sql` once to clear them. `REAL-CONTENT.sql` is now an empty template: fill in the English Medium School's own verified details, then run it (or type them in School settings).
- `phase23.sql`: new public settings keys (registration, principal_title, facebook, telegram) and https-only link check.
- Public footer shows social links; notices page has "Share on WhatsApp".

## Round 12: payments, Marathi, demo guide
- Run `supabase/phase24.sql` and `supabase/phase25.sql` (or the new ALL-IN-ONE.sql). Fee tab for parents now has UPI QR, bank transfer details with Copy buttons (set them in School settings), and approved bank-transfer claims keep mode "bank_transfer" on the receipt.
- `js/i18n.js`: about 580 more Marathi strings (all admin/teacher/parent screens). Names and data typed by the school are never translated.
- `DEMO-GUIDE.md`: Marathi presentation script and Q&A.

## Round 13 – new Home page and bus helper checklist

**Home page (public website).** New blue and orange look, hero with photo slot, quick-action strip, "keeps parents connected" feature cards, "Life at school" photo grid, admission call-to-action band, soft scroll animation (works on old Chrome; switches off for people who prefer reduced motion). The ERP pages keep their own colours; only public pages changed.

**Adding real photos and the logo later (no code needed).** Put these files in the `images` folder of the repo:
- `images/logo.png` – round/square school logo (shows in the header instead of the letter S)
- `images/hero.jpg` – big photo in the hero (landscape, about 1200x900, under 300 KB)
- `images/photo1.jpg` … `images/photo5.jpg` – Campus, Classroom, Sports, Events, Activities (landscape, under 300 KB each)
Until a file exists, a coloured placeholder is shown. Get the school's written permission before publishing photos of children.

**Bus helper checklist.** On the driver page, after a trip is started, "Load list" shows the children on this bus grouped by stop. Tap a child to note "boarded" (pickup) or "got off" (drop). Parents get the same notification as with the QR scan. Needs `supabase/phase26.sql` (already inside `ALL-IN-ONE.sql`). Only the bus secret link can read this list; it shows first name, last initial, admission number and stop.

**Undo a wrong tick (phase27).** On the checklist, tap a green (already noted) name and confirm to remove the note. Parents get a short "correction" notification. Works only while the trip is running. Included in `ALL-IN-ONE.sql`.

## Round 14 – admission form, PDF report cards, demo extras
- `apply.html`: 3-step admission enquiry (student, parent, previous school), a "documents usually asked" box, and a printable receipt (Print or save as PDF) after sending. No database change.
- `report-card.html`: new layout with school header (address, phone and principal from School settings), subject grades, grading scale and signature lines. `report-card.html?exam=...&dv=...` prints every report card of a division (one per page). Results page has a **Print all report cards** button.
- `supabase/DEMO-EXTRA.sql` / `DEMO-EXTRA-UNDO.sql`: fake UPI/bank, bus-stop map positions and two pending payment claims for the demo. Run only after `DEMO-DATA.sql`.
- `PRESENTATION-STEPS.md`: timed step-by-step plan (in Marathi) for presenting the project.

**RESET-DATA.sql fix.** If a demo login had saved something that points to it (for example an AI knowledge note), the reset stopped with a "foreign key constraint ... on table profiles" error. The reset now detaches (or removes, where a login is required) such rows before deleting the demo logins. Tested with an AI note saved by the demo principal.

**Round 14b – fixes found on the live demo.**
- `DEMO-DATA.sql`: the first version made every demo attendance "present" (100% everywhere) because the random number was computed once. Now each student/day gets its own value (about 88% present). If you already loaded the old demo data, run `supabase/DEMO-ATTENDANCE-FIX.sql` once instead of reloading.
- Dashboard: the "Outstanding" amount was cut off on 1366px screens. Money tiles now show whole rupees and never wrap; chart date labels no longer overlap.

**Round 14c – from live screenshots.** Public header stays on one row on 1366px screens (menu button below 1180px; the Install app button in the header is hidden between 1181 and 1499px, the browser's own install icon still works). The admission form and login page now use the same blue and orange colours as the public site.

**Round 14d – from live screenshots (principal).** (1) The side menu now stays in place and scrolls by itself on wide screens, so short pages no longer end with a long empty area. (2) `phase28.sql` (also in `ALL-IN-ONE.sql`): the dashboard says "divisions not marked today" only on working days (not on Sundays, holidays or vacations).

**Round 14e – report card print.** The print layout is now fixed (school name always black and bold, student details always in two columns) so it prints the same on old and new Chrome. Tip for printing: in the Chrome print window untick "Headers and footers" so the web address and date are not printed on the report card.
