# Going live: checklist for the school office

Do these in order. Tick each line. Nothing here needs programming.

## A. New installation (nothing set up yet)
1. Supabase (free): create a project. Choose a region near you (for India, Mumbai/Singapore). Save the database password in a safe place (not in GitHub).
2. SQL Editor: paste the whole of `supabase/schema.sql` and press Run. It already contains every phase up to Phase 12. (If you see "already exists" you are on an old project: use section B instead.)
3. Project Settings, API: copy **Project URL** and the **anon / publishable** key. Never use the `service_role` key anywhere in this website.
4. GitHub: create a repository, upload all files. Edit `js/config.js` and paste the two values.
5. Create the first admin (see README, Setup step 6).
6. Authentication, Providers, Email: **turn off "Allow new users to sign up"**. Authentication, URL Configuration: set Site URL to your GitHub Pages address.
7. GitHub, Settings, Pages: main branch, root folder.
8. Sign in as admin. Open **School settings** and fill in the school name, address, phone, email, principal, logo, timings, working days.
9. Create the academic year, classes and divisions, subjects, then staff logins on **Users and roles**.

## B. Existing project (you already ran earlier phases)
Run once each, in this order, only the ones you have not run yet, in the Supabase SQL Editor:
`phase6b, phase7, phase7b, phase7c, phase8, phase9, phase10, phase11, phase12` (all in the `supabase` folder).
Then upload the changed website files to GitHub (never overwrite your own `js/config.js`).

## C. Before you tell parents and teachers
- [ ] Sign in with each role (admin, teacher, class teacher, accountant, reception, librarian, parent, student) and check you see only what that person should.
- [ ] Take one test payment, print the receipt, then check Fee reports.
- [ ] Mark attendance on a normal day, and check that a holiday and a Sunday are refused.
- [ ] Download a backup (Backup page) and open the file.
- [ ] Open the site on a phone.
- [ ] Remove test students and test users (Users and roles: set inactive; students: use Inactive status). Do not delete academic records.

## D. Free plan limits to remember
- Database 500 MB, file storage 1 GB: photos are shrunk before upload, so this lasts years for a school. Check usage in Supabase, Reports.
- A free project **pauses after a week with no activity**. Open the site at least once a week, and open the Supabase dashboard if it says paused (Restore project).
- The free plan does not include automatic daily backups. Use the **Backup** page every month (see BACKUP.md).
- If an export has exactly 1000 rows or fewer than expected, raise **Max rows** in Supabase, Project Settings, API.

## E. Yearly routine
1. Create next academic year, classes and divisions for it.
2. Publish all exams, download a backup.
3. **Student promotion**, then **Academic year closing**.
4. Check **Reports** for the closed year; fees can still be collected after closing.
