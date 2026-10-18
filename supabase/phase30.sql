-- ============================================================================
-- phase30: flexibility switches. Safe to run again. Every default keeps today's behaviour.
-- 1) Attendance edit window (setting attendance_edit_days; empty = no limit; office/admin always allowed)
-- 2) Holiday / vacation / special school day can apply to the whole school or to ONE division
-- 3) Parent portal switches (setting portal_hidden), 4) report card text settings (rc_*)
-- ============================================================================
alter table school_calendar add column if not exists division_id uuid references divisions(id) on delete cascade;
alter table school_calendar drop constraint if exists school_calendar_day_kind_key;
create unique index if not exists school_calendar_uq on school_calendar (day, kind, coalesce(division_id, '00000000-0000-0000-0000-000000000000'::uuid));

-- whole-school view of a day (division-specific rows are ignored here)
create or replace function is_working_day(d date) returns boolean language plpgsql stable security definer set search_path = public as $$
declare wd text := coalesce(nullif(setting_text('working_days'), ''), '1,2,3,4,5,6');
begin
  if exists (select 1 from school_calendar where day = d and division_id is null and kind in ('holiday','vacation')) then return false; end if;
  if exists (select 1 from school_calendar where day = d and division_id is null and kind = 'special_day') then return true; end if;
  return extract(isodow from d)::int = any (string_to_array(wd, ',')::int[]);
end $$;
revoke all on function is_working_day(date) from public, anon; grant execute on function is_working_day(date) to authenticated;

-- view of a day for one division (whole-school rows and that division's own rows)
create or replace function is_working_day_div(d date, p_div uuid) returns boolean language plpgsql stable security definer set search_path = public as $$
declare wd text := coalesce(nullif(setting_text('working_days'), ''), '1,2,3,4,5,6');
begin
  if exists (select 1 from school_calendar where day = d and (division_id is null or division_id = p_div) and kind in ('holiday','vacation')) then return false; end if;
  if exists (select 1 from school_calendar where day = d and (division_id is null or division_id = p_div) and kind = 'special_day') then return true; end if;
  return extract(isodow from d)::int = any (string_to_array(wd, ',')::int[]);
end $$;
revoke all on function is_working_day_div(date, uuid) from public, anon; grant execute on function is_working_day_div(date, uuid) to authenticated;

drop function if exists day_status(date);
create or replace function day_status(p_day date, p_div uuid default null) returns text language sql stable security definer set search_path = public as $$
  select case when current_role_name() is null then null
    when exists (select 1 from school_calendar where day = p_day and (division_id is null or division_id = p_div) and kind in ('holiday','vacation')) then 'holiday'
    when exists (select 1 from school_calendar where day = p_day and (division_id is null or division_id = p_div) and kind = 'special_day') then 'special'
    when is_working_day_div(p_day, p_div) then 'working' else 'weekly_off' end $$;
revoke all on function day_status(date, uuid) from public, anon; grant execute on function day_status(date, uuid) to authenticated;

-- student attendance guard: calendar by division + optional edit window
create or replace function block_holiday_attendance() returns trigger language plpgsql as $$
declare dv uuid; lim text := nullif(trim(coalesce(setting_text('attendance_edit_days'), '')), '');
begin
  select division_id into dv from student_enrollments where id = new.enrollment_id;
  if exists (select 1 from school_calendar where day = new.att_date and (division_id is null or division_id = dv) and kind in ('holiday','vacation')) then
    raise exception 'holiday: attendance cannot be marked'; end if;
  if tg_op = 'INSERT' and not is_working_day_div(new.att_date, dv) then
    raise exception 'holiday: this is not a working day'; end if;
  if lim is not null and auth.uid() is not null and not coalesce(is_admin(), false)
     and new.att_date < (now() at time zone 'Asia/Kolkata')::date - lim::int then
    raise exception 'locked: attendance older than % days can be changed only by the school office', lim; end if;
  new.updated_at = now(); new.marked_by = auth.uid(); return new;
end $$;

-- teacher attendance guard: a special school day for ANY division opens the day for teachers
create or replace function teacher_att_guard() returns trigger language plpgsql as $$
begin
  if exists (select 1 from school_calendar where day = new.att_date and division_id is null and kind in ('holiday','vacation')) then
    raise exception 'holiday: attendance cannot be marked'; end if;
  if tg_op = 'INSERT' and not is_working_day(new.att_date)
     and not exists (select 1 from school_calendar where day = new.att_date and kind = 'special_day') then
    raise exception 'holiday: this is not a working day'; end if;
  new.updated_at = now(); new.marked_by = auth.uid(); return new;
end $$;

-- parent / student portal switches (read by any signed-in user; cosmetic, data rules stay in RLS)
create or replace function portal_hidden() returns text language sql stable security definer set search_path = public as $$
  select case when current_role_name() is null then '' else coalesce(setting_text('portal_hidden'), '') end $$;
revoke all on function portal_hidden() from public, anon; grant execute on function portal_hidden() to authenticated;

create or replace function settings_guard() returns trigger language plpgsql as $$
begin
  new.value := coalesce(trim(new.value), '');
  if length(new.value) > 4000 then raise exception 'invalid setting: too long'; end if;
  if new.key = 'working_days' and new.value !~ '^[1-7](,[1-7])*$' then raise exception 'invalid setting: working days'; end if;
  if new.key = 'receipt_prefix' and new.value !~ '^[A-Za-z0-9-]{1,6}$' then raise exception 'invalid setting: receipt prefix'; end if;
  if new.key = 'attendance_alert_percent' and (new.value !~ '^[0-9]{1,3}$' or new.value::int > 100) then raise exception 'invalid setting: attendance percent'; end if;
  if new.key = 'library_fine_per_day' and new.value !~ '^[0-9]{1,5}(\.[0-9]{1,2})?$' then raise exception 'invalid setting: fine'; end if;
  if new.key in ('school_start_time','school_end_time') and new.value <> '' and new.value !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then raise exception 'invalid setting: time'; end if;
  if new.key = 'upi_id' and new.value <> '' and new.value !~ '^[A-Za-z0-9._-]{2,64}@[A-Za-z0-9]{2,32}$' then raise exception 'invalid setting: UPI id'; end if;
  if new.key = 'bank_account_no' and new.value <> '' and new.value !~ '^[0-9]{6,20}$' then raise exception 'invalid setting: account number (digits only)'; end if;
  if new.key = 'bank_ifsc' and new.value <> '' and upper(new.value) !~ '^[A-Z]{4}0[A-Z0-9]{6}$' then raise exception 'invalid setting: IFSC'; end if;
  if new.key in ('bank_name','bank_account_name','bank_branch') and length(new.value) > 100 then raise exception 'invalid setting: too long'; end if;
  if new.key = 'bank_ifsc' then new.value := upper(new.value); end if;
  if new.key = 'upi_payee' and length(new.value) > 80 then raise exception 'invalid setting: payee name'; end if;
  if new.key in ('website','facebook','telegram') and new.value <> '' and new.value !~ '^https://[A-Za-z0-9._~:/?#@!$&''()*+,;=%-]{4,250}$' then raise exception 'invalid setting: link must start with https://'; end if;
  if new.key = 'attendance_edit_days' and new.value <> '' and new.value !~ '^[0-9]{1,3}$' then raise exception 'invalid setting: attendance edit days'; end if;
  if new.key = 'portal_hidden' and new.value !~ '^([a-z]+(,[a-z]+)*)?$' then raise exception 'invalid setting: portal switches'; end if;
  if new.key in ('rc_title','rc_sign1','rc_sign2','rc_sign3') and length(new.value) > 60 then raise exception 'invalid setting: too long'; end if;
  if new.key = 'rc_note' and length(new.value) > 300 then raise exception 'invalid setting: too long'; end if;
  new.is_public := new.key in ('rc_title','rc_sign1','rc_sign2','rc_sign3','rc_note','school_name','address','phone','email','website','principal','logo_path','school_start_time','school_end_time',
                               'home_tagline','about_text','vision','mission','principal_message',
                               'principal_title','registration','facebook','telegram');
  return new;
end $$;

insert into school_settings (key, value, is_public) values
  ('attendance_edit_days','',false),('portal_hidden','',false),
  ('rc_title','',true),('rc_sign1','',true),('rc_sign2','',true),('rc_sign3','',true),('rc_note','',true)
on conflict (key) do nothing;
