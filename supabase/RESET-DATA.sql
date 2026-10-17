-- ============================================================================
-- RESET-DATA.sql : erase ALL sample / test data from the school database
-- ============================================================================
-- READ BEFORE RUNNING
-- * This DELETES for good: students, parents' records, teachers, staff, classes' divisions,
--   academic years, attendance, exams, marks, fees, payments, receipts, notices, events,
--   library, admissions, transport, leave, timetable, homework, notifications, audit logs,
--   and the demo logins made by DEMO-DATA.sql (@demo.example.com).
-- * It KEEPS: your own login accounts (Super Admin, etc.), School settings, the 12 classes
--   (LKG to Grade 10), grading rules, fee types and the gallery album names.
-- * Uploaded files (photos, attachments) are NOT removed. Empty the Storage buckets by hand if you want.
-- * Use it ONLY on the SCHOOL project (check the project name at the top of Supabase,
--   NOT the Patsanstha project). Never use it after the school has started real work.
-- * Download a backup first (website, Backup page) if there is anything you may need.
--
-- HOW TO RUN
-- 1. In the line below that starts with  do $guard$  change 'NO' to 'YES'  (capital letters).
-- 2. Press Run. If you see "RESET finished" you are done.
-- ============================================================================

do $guard$ begin
  if 'NO' <> 'YES' then
    raise exception 'SAFETY STOP: nothing was deleted. Read the warning at the top, then change NO to YES in this line and run again.';
  end if;
end $guard$;

truncate table
  academic_years, achievements, activities, activity_participants, admission_enquiries, attendance, audit_logs,
  book_transactions, books, class_subjects, divisions, events, exam_subjects, exams, fee_concessions, fee_payments,
  fee_structures, gallery_images, homework, leave_requests, marks, notices, notifications, report_remarks,
  school_calendar, staff, student_enrollments, student_fees, student_guardians, students, subjects,
  teacher_attendance, teachers, timetable_slots, transport_assignments, transport_routes, transport_stops
  restart identity cascade;

alter sequence receipt_seq restart;
alter sequence enquiry_seq restart;
do $c$ begin if to_regclass('public.certificate_counters') is not null then truncate table certificate_counters; end if; end $c$;

-- Before removing the demo logins: anything that still points to a demo login (for example the AI knowledge notes or a payment claim they saved)
-- is detached (set to empty) or, where a login is required, removed. Without this step the database refuses to delete the login.
do $f$ declare r record;
begin
  for r in select c.conrelid::regclass as t, a.attname as col, a.attnotnull as nn
           from pg_constraint c join pg_attribute a on a.attrelid = c.conrelid and a.attnum = c.conkey[1]
           where c.contype = 'f' and c.confrelid = 'public.profiles'::regclass and array_length(c.conkey, 1) = 1 and c.conrelid <> 'public.profiles'::regclass loop
    if r.nn then
      execute format('delete from %s where %I in (select id from auth.users where email like %L)', r.t, r.col, '%@demo.example.com');
    else
      execute format('update %s set %I = null where %I in (select id from auth.users where email like %L)', r.t, r.col, r.col, '%@demo.example.com');
    end if;
  end loop;
end $f$;

-- Remove the demo logins (profiles go with them). Your own users are not touched.
delete from auth.users where email like '%@demo.example.com';

insert into audit_logs (user_id, action, module, record_id) values (null, 'Sample data reset', 'maintenance', null);

select 'RESET finished' as result,
       (select count(*) from profiles) as logins_kept,
       (select count(*) from classes) as classes_kept,
       (select count(*) from students) as students_now;
