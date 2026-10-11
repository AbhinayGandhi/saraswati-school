-- Phase 11: settings, audit trail, working days, year closing, promotion, report functions.
-- Run ONCE on your existing project (after update 10). Nothing existing is deleted or renamed.

------------------------------------------------------------------ 1. AUDIT TRAIL
alter table audit_logs add column if not exists role text;
alter table audit_logs add column if not exists metadata jsonb;
alter table audit_logs alter column user_id drop not null;
create index if not exists audit_logs_module_idx on audit_logs (module, created_at desc);
create index if not exists audit_logs_user_idx on audit_logs (user_id, created_at desc);

-- The database (not the browser) stamps the time and the role, and strips browser-supplied details.
create or replace function audit_before_insert() returns trigger language plpgsql as $$
begin
  new.created_at := now();
  new.role := coalesce((select p.role::text from profiles p where p.id = new.user_id), 'system');
  if current_user in ('authenticated','anon') then new.metadata := null; end if;
  new.action := left(new.action, 200); new.module := left(new.module, 60); new.record_id := left(new.record_id, 80);
  return new;
end $$;
drop trigger if exists audit_fill on audit_logs;
create trigger audit_fill before insert on audit_logs for each row execute function audit_before_insert();

create or replace function audit_write(p_action text, p_module text, p_record text, p_meta jsonb) returns void
language plpgsql security definer set search_path = public as $$
begin insert into audit_logs (user_id, action, module, record_id, metadata) values (auth.uid(), p_action, p_module, p_record, p_meta); end $$;
revoke all on function audit_write(text, text, text, jsonb) from public, anon, authenticated;

create or replace function audit_marks_change() returns trigger language plpgsql security definer set search_path = public as $$
declare st text;
begin
  if old.marks is distinct from new.marks or old.absent is distinct from new.absent then
    select status into st from exam_subjects where id = new.exam_subject_id;
    if st is distinct from 'open' then   -- only corrections after submission or lock are audited here; draft typing is not
      perform audit_write('Marks changed after submission', 'marks', new.id::text, jsonb_build_object('exam_subject_id', new.exam_subject_id,
        'enrollment_id', new.enrollment_id, 'old_marks', old.marks, 'new_marks', new.marks, 'old_absent', old.absent, 'new_absent', new.absent));
    end if;
  end if;
  return new;
end $$;
drop trigger if exists marks_audit on marks;
create trigger marks_audit after update on marks for each row execute function audit_marks_change();

create or replace function audit_attendance_change() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if old.status is distinct from new.status then
    perform audit_write('Attendance modified', 'attendance', new.id::text, jsonb_build_object('enrollment_id', new.enrollment_id, 'date', new.att_date, 'old', old.status, 'new', new.status));
  end if;
  return new;
end $$;
drop trigger if exists attendance_audit on attendance;
create trigger attendance_audit after update on attendance for each row execute function audit_attendance_change();

create or replace function audit_teacher_attendance_change() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if old.status is distinct from new.status then
    perform audit_write('Teacher attendance modified', 'teacher_attendance', new.id::text, jsonb_build_object('teacher_id', new.teacher_id, 'date', new.att_date, 'old', old.status, 'new', new.status));
  end if;
  return new;
end $$;
drop trigger if exists teacher_attendance_audit on teacher_attendance;
create trigger teacher_attendance_audit after update on teacher_attendance for each row execute function audit_teacher_attendance_change();

create or replace function audit_profile_change() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if old.role is distinct from new.role or old.is_active is distinct from new.is_active then
    perform audit_write('User role or status changed', 'profiles', new.id::text, jsonb_build_object('name', new.full_name,
      'old_role', old.role, 'new_role', new.role, 'old_active', old.is_active, 'new_active', new.is_active));
  end if;
  return new;
end $$;
drop trigger if exists profiles_audit on profiles;
create trigger profiles_audit after update on profiles for each row execute function audit_profile_change();

------------------------------------------------------------------ 2. SETTINGS
create or replace function settings_guard() returns trigger language plpgsql as $$
begin
  new.value := coalesce(trim(new.value), '');
  if length(new.value) > 4000 then raise exception 'invalid setting: too long'; end if;
  if new.key = 'working_days' and new.value !~ '^[1-7](,[1-7])*$' then raise exception 'invalid setting: working days'; end if;
  if new.key = 'receipt_prefix' and new.value !~ '^[A-Za-z0-9-]{1,6}$' then raise exception 'invalid setting: receipt prefix'; end if;
  if new.key = 'attendance_alert_percent' and (new.value !~ '^[0-9]{1,3}$' or new.value::int > 100) then raise exception 'invalid setting: attendance percent'; end if;
  if new.key = 'library_fine_per_day' and new.value !~ '^[0-9]{1,5}(\.[0-9]{1,2})?$' then raise exception 'invalid setting: fine'; end if;
  if new.key in ('school_start_time','school_end_time') and new.value <> '' and new.value !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then raise exception 'invalid setting: time'; end if;
  -- Only these keys may ever be public. Everything else stays private, whatever the browser sends.
  new.is_public := new.key in ('school_name','address','phone','email','website','principal','logo_path','school_start_time','school_end_time',
                               'home_tagline','about_text','vision','mission','principal_message');
  return new;
end $$;
drop trigger if exists settings_guard_trg on school_settings;
create trigger settings_guard_trg before insert or update on school_settings for each row execute function settings_guard();

insert into school_settings (key, value, is_public) values
  ('working_days','1,2,3,4,5,6',false), ('receipt_prefix','R',false), ('attendance_alert_percent','75',false),
  ('website','',true), ('logo_path','',true), ('school_start_time','',true), ('school_end_time','',true),
  ('home_tagline','',true), ('about_text','',true), ('vision','',true), ('mission','',true), ('principal_message','',true)
on conflict (key) do nothing;

create or replace function audit_setting_change() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' or old.value is distinct from new.value then
    perform audit_write('Setting changed', 'school_settings', new.key, jsonb_build_object('old', case when tg_op = 'UPDATE' then left(old.value, 200) end, 'new', left(new.value, 200)));
  end if;
  return new;
end $$;
drop trigger if exists settings_audit on school_settings;
create trigger settings_audit after insert or update on school_settings for each row execute function audit_setting_change();

-- Only Super Admin and School Admin may change settings (Principal can still read them).
drop policy if exists set_admin_write on school_settings;
drop policy if exists set_write on school_settings;
create policy set_write on school_settings for all to authenticated
  using (current_role_name() in ('super_admin','school_admin')) with check (current_role_name() in ('super_admin','school_admin'));

create or replace function setting_text(k text) returns text language sql stable security definer set search_path = public as
$$ select value from school_settings where key = k $$;
revoke all on function setting_text(text) from public, anon; grant execute on function setting_text(text) to authenticated;

-- Settings that every signed-in user's pages need (public ones plus working days and the attendance alert level).
create or replace function app_settings() returns jsonb language sql stable security definer set search_path = public as $$
  select case when current_role_name() is null then '{}'::jsonb
    else coalesce((select jsonb_object_agg(key, value) from school_settings where is_public or key in ('working_days','attendance_alert_percent')), '{}'::jsonb) end $$;
revoke all on function app_settings() from public, anon; grant execute on function app_settings() to authenticated;

-- Public bucket used ONLY for the school logo. No student or private file may ever go here.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  values ('branding','branding',true,1048576,array['image/png','image/jpeg','image/webp']) on conflict (id) do nothing;
drop policy if exists branding_write on storage.objects;
create policy branding_write on storage.objects for insert to authenticated
  with check (bucket_id = 'branding' and current_role_name() in ('super_admin','school_admin'));

-- Receipt numbers now use the prefix from settings (for example SCH26000001).
create or replace function record_fee_payments(p_enrollment uuid, p_amount numeric, p_date date, p_mode text, p_ref text, p_notes text)
returns text language plpgsql security definer set search_path = public as $$
declare rcpt text; remaining numeric := p_amount; r record; pay numeric; first_row boolean := true; total numeric;
begin
  if not can_manage_fees() then raise exception 'not allowed'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'invalid amount'; end if;
  if p_mode not in ('cash','upi','bank_transfer','cheque','other') then raise exception 'invalid mode'; end if;
  if p_mode <> 'cash' and coalesce(trim(p_ref), '') = '' then raise exception 'reference required'; end if;
  select coalesce(sum(balance), 0) into total from student_fees where enrollment_id = p_enrollment and balance > 0;
  if p_amount > total then raise exception 'amount exceeds balance'; end if;
  rcpt := coalesce(nullif(setting_text('receipt_prefix'), ''), 'R') || to_char(now(),'YY') || lpad(nextval('receipt_seq')::text, 6, '0');
  for r in select id, balance from student_fees where enrollment_id = p_enrollment and balance > 0 order by due_date, installment_no, id for update loop
    exit when remaining <= 0;
    pay := least(r.balance, remaining);
    insert into fee_payments (student_fee_id, amount, payment_date, mode, reference_no, notes, receipt_no, is_first)
      values (r.id, pay, coalesce(p_date, current_date), p_mode, nullif(trim(p_ref), ''), p_notes, rcpt, first_row);
    first_row := false; remaining := remaining - pay;
  end loop;
  return rcpt;
end $$;

------------------------------------------------------------------ 3. WORKING DAYS AND SPECIAL DAYS
alter table school_calendar drop constraint if exists school_calendar_kind_check;
alter table school_calendar add constraint school_calendar_kind_check
  check (kind in ('holiday','vacation','exam','event','parent_meeting','special_day'));

create or replace function is_working_day(d date) returns boolean language plpgsql stable security definer set search_path = public as $$
declare wd text := coalesce(nullif(setting_text('working_days'), ''), '1,2,3,4,5,6');
begin
  if exists (select 1 from school_calendar where day = d and kind in ('holiday','vacation')) then return false; end if;
  if exists (select 1 from school_calendar where day = d and kind = 'special_day') then return true; end if;
  return extract(isodow from d)::int = any (string_to_array(wd, ',')::int[]);
end $$;
revoke all on function is_working_day(date) from public, anon; grant execute on function is_working_day(date) to authenticated;

create or replace function day_status(p_day date) returns text language sql stable security definer set search_path = public as $$
  select case when current_role_name() is null then null
    when exists (select 1 from school_calendar where day = p_day and kind in ('holiday','vacation')) then 'holiday'
    when exists (select 1 from school_calendar where day = p_day and kind = 'special_day') then 'special'
    when is_working_day(p_day) then 'working' else 'weekly_off' end $$;
revoke all on function day_status(date) from public, anon; grant execute on function day_status(date) to authenticated;

-- New attendance rows are refused on holidays, vacations and weekly-off days (unless a special school day is set).
-- Editing an already saved row is refused only on holidays and vacations, as before.
create or replace function block_holiday_attendance() returns trigger language plpgsql as $$
begin
  if exists (select 1 from school_calendar where day = new.att_date and kind in ('holiday','vacation')) then
    raise exception 'holiday: attendance cannot be marked'; end if;
  if tg_op = 'INSERT' and not is_working_day(new.att_date) then
    raise exception 'holiday: this is not a working day'; end if;
  new.updated_at = now(); new.marked_by = auth.uid(); return new;
end $$;
create or replace function teacher_att_guard() returns trigger language plpgsql as $$
begin
  if exists (select 1 from school_calendar where day = new.att_date and kind in ('holiday','vacation')) then
    raise exception 'holiday: attendance cannot be marked'; end if;
  if tg_op = 'INSERT' and not is_working_day(new.att_date) then
    raise exception 'holiday: this is not a working day'; end if;
  new.updated_at = now(); new.marked_by = auth.uid(); return new;
end $$;

------------------------------------------------------------------ 4. YEAR CLOSING AND PROMOTION
alter table student_enrollments drop constraint if exists student_enrollments_status_check;
alter table student_enrollments add constraint student_enrollments_status_check
  check (status in ('active','promoted','repeated','transferred','alumni','inactive'));

create or replace function year_closing_check(p_year uuid) returns table (active_enrollments bigint, total_enrollments bigint, draft_exams bigint, open_marks bigint, outstanding numeric)
language sql stable as $$
  select (select count(*) from student_enrollments where academic_year_id = p_year and status = 'active'),
         (select count(*) from student_enrollments where academic_year_id = p_year),
         (select count(*) from exams where academic_year_id = p_year and status = 'draft'),
         (select count(*) from exam_subjects x join exams e on e.id = x.exam_id where e.academic_year_id = p_year and x.status = 'open'),
         coalesce((select sum(f.balance) from student_fees f join student_enrollments e on e.id = f.enrollment_id where e.academic_year_id = p_year), 0) $$;
revoke all on function year_closing_check(uuid) from public, anon; grant execute on function year_closing_check(uuid) to authenticated;

create or replace function close_academic_year(p_old uuid, p_new uuid default null, p_force boolean default false) returns jsonb
language plpgsql security definer set search_path = public as $$
declare yo academic_years; yn academic_years; unproc bigint; unpub bigint;
begin
  if coalesce(current_role_name() in ('super_admin','school_admin'), false) is not true then raise exception 'not allowed'; end if;
  select * into yo from academic_years where id = p_old for update;
  if not found then raise exception 'year not found'; end if;
  if yo.status in ('closed','archived') then raise exception 'already closed'; end if;
  if yo.is_active and p_new is null then raise exception 'choose the next year'; end if;
  select count(*) into unproc from student_enrollments where academic_year_id = p_old and status = 'active';
  select count(*) into unpub from exams where academic_year_id = p_old and status = 'draft';
  if (unproc > 0 or unpub > 0) and not coalesce(p_force, false) then
    raise exception 'not ready: % students not processed, % exams not published', unproc, unpub; end if;
  if p_new is not null then
    select * into yn from academic_years where id = p_new for update;
    if not found or yn.id = yo.id or yn.status <> 'upcoming' or yn.start_date <= yo.start_date then raise exception 'invalid next year'; end if;
  end if;
  update academic_years set status = 'closed', is_active = false where id = p_old;
  if p_new is not null then update academic_years set status = 'active', is_active = true where id = p_new; end if;
  perform audit_write('Academic year closed', 'academic_years', p_old::text, jsonb_build_object('next_year', p_new, 'forced', coalesce(p_force, false),
    'unprocessed_students', unproc, 'unpublished_exams', unpub));
  return jsonb_build_object('unprocessed', unproc, 'unpublished', unpub);
end $$;
revoke all on function close_academic_year(uuid, uuid, boolean) from public, anon; grant execute on function close_academic_year(uuid, uuid, boolean) to authenticated;

-- Promotion never edits history: the old enrollment only gets a final status, and a NEW enrollment is created for the new year.
create or replace function promote_students(p_from uuid, p_to uuid, p_items jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare yf academic_years; yt academic_years; it jsonb; v_enr uuid; v_act text; v_div uuid; e record; t record;
  done int := 0; failed jsonb := '[]'::jsonb; counts jsonb := '{}'::jsonb;
begin
  if coalesce(current_role_name() in ('super_admin','school_admin'), false) is not true then raise exception 'not allowed'; end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'nothing to process'; end if;
  if jsonb_array_length(p_items) > 1500 then raise exception 'too many students at once'; end if;
  select * into yf from academic_years where id = p_from;
  if not found then raise exception 'invalid source year'; end if;
  select * into yt from academic_years where id = p_to;
  if not found or yt.status not in ('upcoming','active') or yt.start_date <= yf.start_date then raise exception 'invalid target year'; end if;
  for it in select value from jsonb_array_elements(p_items) loop
    begin
      v_enr := (it->>'enrollment_id')::uuid; v_act := it->>'action'; v_div := nullif(it->>'division_id', '')::uuid;
      select en.id, en.student_id, en.status, d.class_id, c.sort_order as ord into e
        from student_enrollments en join divisions d on d.id = en.division_id join classes c on c.id = d.class_id
        where en.id = v_enr and en.academic_year_id = p_from for update of en;
      if not found then raise exception 'student is not in the source year'; end if;
      if e.status <> 'active' then raise exception 'already processed'; end if;
      if v_act in ('promote','retain') then
        select d.id, d.class_id, c.sort_order as ord into t from divisions d join classes c on c.id = d.class_id where d.id = v_div and d.academic_year_id = p_to;
        if not found then raise exception 'choose a division of the new year'; end if;
        if v_act = 'promote' and t.ord <= e.ord then raise exception 'new class must be higher'; end if;
        if v_act = 'retain' and t.class_id <> e.class_id then raise exception 'repeat must stay in the same class'; end if;
        insert into student_enrollments (student_id, academic_year_id, division_id, status) values (e.student_id, p_to, v_div, 'active');
        update student_enrollments set status = case v_act when 'promote' then 'promoted' else 'repeated' end where id = v_enr;
      elsif v_act in ('transfer','alumni','inactive') then
        update student_enrollments set status = case v_act when 'transfer' then 'transferred' when 'alumni' then 'alumni' else 'inactive' end where id = v_enr;
        update students set status = case v_act when 'transfer' then 'transferred' when 'alumni' then 'alumni' else 'inactive' end where id = e.student_id;
      else
        raise exception 'invalid action';
      end if;
      done := done + 1;
      counts := jsonb_set(counts, array[v_act], to_jsonb(coalesce((counts->>v_act)::int, 0) + 1));
    exception
      when unique_violation then failed := failed || jsonb_build_object('enrollment_id', v_enr, 'reason', 'already enrolled in the new year');
      when others then failed := failed || jsonb_build_object('enrollment_id', v_enr, 'reason', sqlerrm);
    end;
  end loop;
  perform audit_write('Student promotion', 'student_enrollments', p_to::text, jsonb_build_object('from_year', p_from, 'to_year', p_to,
    'done', done, 'failed', jsonb_array_length(failed), 'actions', counts));
  return jsonb_build_object('done', done, 'failed', failed, 'actions', counts);
end $$;
revoke all on function promote_students(uuid, uuid, jsonb) from public, anon; grant execute on function promote_students(uuid, uuid, jsonb) to authenticated;

-- Numbers every active student of a division from 1, in alphabetical order (surname, then first name).
create or replace function assign_roll_numbers(p_division uuid) returns int language plpgsql security definer set search_path = public as $$
declare n int;
begin
  if not can_edit_students() then raise exception 'not allowed'; end if;
  with ranked as (
    select en.id, row_number() over (order by lower(s.last_name), lower(s.first_name), s.admission_no) as rn
    from student_enrollments en join students s on s.id = en.student_id where en.division_id = p_division and en.status = 'active')
  update student_enrollments en set roll_no = r.rn from ranked r where en.id = r.id;
  get diagnostics n = row_count;
  perform audit_write('Roll numbers assigned', 'student_enrollments', p_division::text, jsonb_build_object('count', n));
  return n;
end $$;
revoke all on function assign_roll_numbers(uuid) from public, anon; grant execute on function assign_roll_numbers(uuid) to authenticated;

------------------------------------------------------------------ 5. REPORT FUNCTIONS (run with the caller's own permissions, so Row Level Security still applies)
create or replace function report_attendance(p_year uuid, p_from date, p_to date, p_class uuid default null, p_division uuid default null)
returns table (enrollment_id uuid, roll_no int, admission_no text, student_name text, class_name text, class_order int, division_name text,
  n_present bigint, n_absent bigint, n_late bigint, n_half bigint, n_leave bigint, n_total bigint)
language sql stable as $$
  select e.id, e.roll_no, s.admission_no, s.first_name || ' ' || s.last_name, c.name, c.sort_order, d.name,
    count(a.id) filter (where a.status = 'present'), count(a.id) filter (where a.status = 'absent'), count(a.id) filter (where a.status = 'late'),
    count(a.id) filter (where a.status = 'half_day'), count(a.id) filter (where a.status = 'leave'), count(a.id)
  from student_enrollments e join students s on s.id = e.student_id join divisions d on d.id = e.division_id join classes c on c.id = d.class_id
  left join attendance a on a.enrollment_id = e.id and a.att_date between p_from and p_to
  where e.academic_year_id = p_year and (p_class is null or d.class_id = p_class) and (p_division is null or d.id = p_division)
  group by e.id, e.roll_no, s.admission_no, s.first_name, s.last_name, c.name, c.sort_order, d.name $$;
revoke all on function report_attendance(uuid, date, date, uuid, uuid) from public, anon; grant execute on function report_attendance(uuid, date, date, uuid, uuid) to authenticated;

create or replace function report_exam_results(p_exam uuid, p_class uuid default null, p_division uuid default null)
returns table (enrollment_id uuid, roll_no int, admission_no text, student_name text, class_name text, class_order int, division_name text,
  total numeric, max_total numeric, n_subjects bigint, n_entered bigint, n_failed bigint)
language sql stable as $$
  select e.id, e.roll_no, s.admission_no, s.first_name || ' ' || s.last_name, c.name, c.sort_order, d.name,
    coalesce(sum(m.marks) filter (where not m.absent), 0), sum(x.max_marks), count(x.id),
    count(m.id) filter (where m.absent or m.marks is not null), count(m.id) filter (where m.absent or m.marks < x.passing_marks)
  from exams ex join exam_subjects x on x.exam_id = ex.id join divisions d on d.id = x.division_id
  join student_enrollments e on e.division_id = d.id and e.academic_year_id = ex.academic_year_id
  join students s on s.id = e.student_id join classes c on c.id = d.class_id
  left join marks m on m.exam_subject_id = x.id and m.enrollment_id = e.id
  where ex.id = p_exam and (p_class is null or d.class_id = p_class) and (p_division is null or d.id = p_division)
  group by e.id, e.roll_no, s.admission_no, s.first_name, s.last_name, c.name, c.sort_order, d.name $$;
revoke all on function report_exam_results(uuid, uuid, uuid) from public, anon; grant execute on function report_exam_results(uuid, uuid, uuid) to authenticated;

create or replace function report_subject_performance(p_exam uuid, p_class uuid default null, p_division uuid default null)
returns table (subject_name text, sort_order int, n_appeared bigint, n_absent bigint, avg_pct numeric, highest_pct numeric, lowest_pct numeric, n_passed bigint, n_failed bigint)
language sql stable as $$
  select s.name, s.sort_order,
    count(m.id) filter (where not m.absent and m.marks is not null), count(m.id) filter (where m.absent),
    round(avg(m.marks / x.max_marks * 100) filter (where not m.absent and m.marks is not null), 2),
    round(max(m.marks / x.max_marks * 100) filter (where not m.absent and m.marks is not null), 2),
    round(min(m.marks / x.max_marks * 100) filter (where not m.absent and m.marks is not null), 2),
    count(m.id) filter (where not m.absent and m.marks >= x.passing_marks), count(m.id) filter (where m.absent or m.marks < x.passing_marks)
  from exam_subjects x join subjects s on s.id = x.subject_id join divisions d on d.id = x.division_id
  left join marks m on m.exam_subject_id = x.id
  where x.exam_id = p_exam and (p_class is null or d.class_id = p_class) and (p_division is null or d.id = p_division)
  group by s.id, s.name, s.sort_order $$;
revoke all on function report_subject_performance(uuid, uuid, uuid) from public, anon; grant execute on function report_subject_performance(uuid, uuid, uuid) to authenticated;
