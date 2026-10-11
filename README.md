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
