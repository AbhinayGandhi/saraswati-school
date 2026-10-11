# Backup and recovery

## What can go wrong
Someone deletes data by mistake, a password leaks, or the free project is paused or lost. A backup that sits on the same account is not enough: keep a copy somewhere else.

## Monthly (5 minutes, no tools)
1. Sign in as Super Admin, open **Backup**, press **Download full backup**.
2. You get `school-backup-YYYY-MM-DD.json` with all 43 tables. Single tables can be downloaded as CSV (opens in Excel).
3. Store the file in two places (for example your own Google Drive that only you can open, and a pen drive). Keep the last 6 monthly files and one file per closed academic year.
4. The file holds personal data: never share it in WhatsApp groups or public folders.

The Backup page does not include uploaded photos and attachments. They are in Supabase, Storage; download important ones from there occasionally.

## Full database copy (once a term, needs a computer)
1. Supabase dashboard, Project Settings, Database: copy the connection string (Session pooler) and put your database password in it.
2. Install PostgreSQL client tools, then run: `pg_dump "<connection string>" --no-owner --no-privileges -f school-full.sql`
3. This gives a file that can recreate the whole database. Keep it as carefully as the JSON.

## If something is deleted by mistake
Do not panic and do not try to fix by deleting more. Academic records are never deleted by the website (only Super Admin can delete some rows). Check **Audit logs** to see who changed what and when. Then restore the specific rows from the latest backup: ask a technical person to import the needed table from the JSON/CSV or the SQL file into a fresh Supabase project first, and copy the rows across.

## Test your backup
Once a year, create a new free Supabase project, run `supabase/schema.sql`, and load the dump to prove it works.
