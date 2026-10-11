# One-time setup: create users from the website (about 10 minutes)

After this, **Users and roles** has an "Add a new user" form and a **Password** button. You will never need Supabase, Authentication, Users again.

Why a setup is needed: creating a login needs a secret key that must never be placed in a website. So a tiny server program (an "Edge Function", free on Supabase) holds the key and does the work only for a signed-in Super Admin or School Admin.

## Steps
1. Open your project in Supabase. In the left menu click **Edge Functions**.
2. Click **Deploy a new function** and choose **Via Editor** (the option that lets you type or paste code in the browser).
3. Function name: `admin-users` (exactly this, small letters).
4. Delete the sample code. Open the file `supabase/functions/admin-users/index.ts` from this project (in GitHub click the file, then the copy button), copy **everything** and paste it into the editor.
5. Click **Deploy**.
6. Open the function's settings/details and **turn OFF "Verify JWT" / "Enforce JWT verification"** (the wording may differ slightly). This is safe: the program checks the signed-in user and their role itself, and refuses everyone except Super Admin and School Admin.
7. Nothing else. Supabase gives the function the service key automatically. Do not paste any key anywhere.

## Test
Sign in as Super Admin, open **Users and roles**, fill the form (use your own second email), press **Create user**. You should see the email and temporary password. Open the site in a private window and sign in with them.

## Rules built in
- Only Super Admin and School Admin can use it. A School Admin cannot create or change Super Admin or School Admin accounts.
- Passwords must be 8 to 72 characters. Give each person a temporary password and tell them privately.
- Every creation and password change is written to **Audit logs**.
- If the role cannot be saved, the new login is removed again, so no half-made accounts remain.

## If it says "service is not set up yet"
The function is missing or has another name. Repeat steps 1 to 5 and check the name is `admin-users`. If it says "Run ALL-IN-ONE.sql", run `supabase/ALL-IN-ONE.sql` once.

## Good to know
- Free Supabase email sending is very limited, so the "forgot password" email may not arrive. Use the **Password** button instead.
- The first Super Admin is still created once in Supabase (README, Setup step 6). Everyone after that is created here.
