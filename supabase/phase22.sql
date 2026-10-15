-- Phase 22: security hardening (found in final audit)
-- 1) Public/helper views must be read-only. They run with the owner's rights, so write access through them bypassed RLS.
revoke insert, update, delete, truncate, references, trigger on teacher_names, teachers_public, achievements_public from anon, authenticated, public;
-- 2) teacher_names lists all teacher logins: only signed-in users may read it, never the public.
revoke all on teacher_names from anon, public;
grant select on teacher_names to authenticated;
revoke all on teachers_public, achievements_public from public;
grant select on teachers_public, achievements_public to anon, authenticated;
-- 3) The public (not signed in) role never needs to change data directly. Public forms use submit_enquiry() and driver_* functions.
revoke insert, update, delete, truncate on all tables in schema public from anon;
-- 4) Public enquiry form: also cap total submissions per hour (stops spam that varies the mobile number).
create or replace function submit_enquiry(p_student_name text, p_dob date, p_gender text, p_class uuid, p_parent text, p_mobile text, p_email text, p_address text, p_prev_school text, p_prev_class text, p_message text)
returns text language plpgsql security definer set search_path = public as $$
declare no text;
begin
  if p_dob is null or p_dob >= current_date then raise exception 'invalid date of birth'; end if;
  if (select count(*) from admission_enquiries where created_at > now() - interval '1 hour') >= 60 then raise exception 'too many'; end if;
  if exists (select 1 from admission_enquiries where mobile = trim(p_mobile) and lower(student_name) = lower(trim(p_student_name)) and created_at > now() - interval '24 hours') then raise exception 'duplicate'; end if;
  if (select count(*) from admission_enquiries where mobile = trim(p_mobile) and created_at > now() - interval '24 hours') >= 5 then raise exception 'too many'; end if;
  insert into admission_enquiries (student_name, dob, gender, applying_class_id, parent_name, mobile, email, address, previous_school, previous_class, message)
  values (trim(p_student_name), p_dob, p_gender, p_class, trim(p_parent), trim(p_mobile), nullif(trim(p_email),''), nullif(trim(p_address),''), nullif(trim(p_prev_school),''), nullif(trim(p_prev_class),''), nullif(trim(p_message),''))
  returning application_no into no;
  return no;
end $$;
revoke all on function submit_enquiry(text,date,text,uuid,text,text,text,text,text,text,text) from public;
grant execute on function submit_enquiry(text,date,text,uuid,text,text,text,text,text,text,text) to anon, authenticated;
