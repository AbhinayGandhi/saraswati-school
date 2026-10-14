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
