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

## Not built yet
Phase 2 admin screens (academic years, classes, subjects pages), then students, teachers, staff, attendance, exams, results, report cards, fees, and the rest of your spec. The schema already holds the Phase 2 tables with security rules.
