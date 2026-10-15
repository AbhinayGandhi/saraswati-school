# Security summary (what is enforced where)

**In the database (cannot be bypassed from the browser)**
- Row Level Security is ON for every table (43 of 43). A parent sees only their own children; a teacher only their own divisions and subjects; an accountant fees; reception admissions and student details.
- Marks of an exam are hidden from parents and students until the exam is published. Locked marks cannot be edited.
- Role changes cannot be done by the user themselves. Only admins change roles, and every role change is logged.
- Audit logs can be read only by Super Admin and School Admin. The time and role are written by the database; the browser cannot forge them.
- Fee payments, year closing, promotion, settings and roll numbers are done by database functions that check the role again.
- The public (not signed in) visitor can read only: public notices and events, approved public gallery photos, public teacher profiles and achievements, public school settings, and submit the admission form. The admission form has limits per mobile number and overall (100 per hour).
- Private files (homework, notices, events, achievements, gallery) are in private storage and are opened with short-lived links. Only the school logo is in a public bucket.

**In the website**
- Every value that comes from the database is escaped before being shown (no script injection).
- `js/config.js` holds only the public anon key. Never place the service_role key or database password in GitHub.
- Hiding a menu item is only a convenience. The real check is the database.

- Creating logins is done by a server function that checks the caller's role in the database; the service key never reaches the browser.

**Known limits (please read)**
- GitHub Pages cannot send extra security headers, so the site has no Content Security Policy.
- Accountant and Librarian can read basic student details (needed for fees and library). Teachers who teach a division can see that division's students.
- Sign-ups must be turned off in Supabase (DEPLOYMENT.md step A6), otherwise strangers can create an account (they would still have no access, but it clutters Users).
- The anon key is public by design. Its safety depends on Row Level Security, which is why you must run every SQL phase file.
- Any function you add later must be granted to `authenticated` and revoked from `anon` explicitly (see `phase12.sql`).
- Two-factor login is not offered by this website. Use strong, unique passwords for Super Admin and School Admin; change them if a person leaves.

## Final audit (Round 10)
Checked: RLS on every table (all enabled; `ai_usage`, `bus_alerts`, `certificate_counters` intentionally have no policies = no direct access), all SECURITY DEFINER functions have a fixed search_path, anon can run only `submit_enquiry`, `driver_ping`, `driver_board` (token-gated) plus harmless helpers, per-role write tests (teacher: only own divisions; parent: only own notifications; fee payments immutable), no secrets in the repo, page output escaped.
Fixed in `phase22.sql`: the helper views `teacher_names` and `teachers_public` were writable by any signed-in user (they bypass RLS); now read-only, and `teacher_names` is no longer public. Anonymous role can no longer write to any table directly. The public enquiry form now also has an hourly global cap.
Known and accepted: reception can see driver tokens (needed to share the driver link); unsent offline attendance stays on the phone after sign-out so it is not lost (refused/unauthorised rows are rejected by the server); GitHub Pages cannot set CSP headers.
