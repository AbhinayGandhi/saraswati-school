-- Phase 15 (round 2): UPI payment proof, leave balance, teacher diary. Safe to run more than once. Nothing is deleted.

------------------------------------------------------------------ 1. UPI settings (private keys; shown only through payment_info())
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
  if new.key = 'upi_payee' and length(new.value) > 80 then raise exception 'invalid setting: payee name'; end if;
  new.is_public := new.key in ('school_name','address','phone','email','website','principal','logo_path','school_start_time','school_end_time',
                               'home_tagline','about_text','vision','mission','principal_message');
  return new;
end $$;
insert into school_settings (key, value, is_public) values ('upi_id','',false), ('upi_payee','',false) on conflict (key) do nothing;

create or replace function payment_info() returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not (fees_staff() or exists (select 1 from student_guardians g where g.user_id = auth.uid())) then raise exception 'not allowed'; end if;
  return jsonb_build_object('upi_id', coalesce(setting_text('upi_id'), ''), 'payee', coalesce(nullif(setting_text('upi_payee'), ''), setting_text('school_name'), ''));
end $$;
revoke all on function payment_info() from public, anon; grant execute on function payment_info() to authenticated;

------------------------------------------------------------------ 2. Payment claims: a parent pays by UPI and reports the reference; the accountant verifies it
create table if not exists payment_claims (
  id uuid primary key default gen_random_uuid(),
  enrollment_id uuid not null references student_enrollments(id),
  amount numeric(12,2) not null check (amount > 0 and amount <= 10000000),
  paid_on date not null,
  upi_ref text not null check (upi_ref ~ '^[A-Za-z0-9]{6,30}$'),
  note text check (length(note) <= 300),
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  submitted_by uuid references profiles(id),
  reviewed_by uuid references profiles(id), reviewed_at timestamptz,
  review_note text check (length(review_note) <= 300),
  receipt_no text,
  created_at timestamptz not null default now()
);
create unique index if not exists payment_claims_ref_uq on payment_claims (lower(upi_ref)) where status <> 'rejected';
create index if not exists payment_claims_status_idx on payment_claims (status, created_at desc);
create index if not exists payment_claims_enr_idx on payment_claims (enrollment_id);
alter table payment_claims enable row level security;
drop policy if exists pc_read on payment_claims;
create policy pc_read on payment_claims for select to authenticated using (fees_staff() or is_guardian_of_enrollment(enrollment_id));
revoke insert, update, delete on payment_claims from authenticated, anon;

create or replace function submit_payment_claim(p_enrollment uuid, p_amount numeric, p_date date, p_ref text, p_note text default null)
returns payment_claims language plpgsql security definer set search_path = public as $$
declare total numeric; r payment_claims; ref text := trim(coalesce(p_ref, ''));
begin
  if not is_guardian_of_enrollment(p_enrollment) then raise exception 'not allowed'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'invalid amount'; end if;
  if p_date is null or p_date > current_date or p_date < current_date - 60 then raise exception 'invalid date'; end if;
  if ref !~ '^[A-Za-z0-9]{6,30}$' then raise exception 'invalid reference'; end if;
  select coalesce(sum(balance), 0) into total from student_fees where enrollment_id = p_enrollment and balance > 0;
  if p_amount > total then raise exception 'amount exceeds balance'; end if;
  if (select count(*) from payment_claims where enrollment_id = p_enrollment and status = 'pending') >= 5 then raise exception 'too many pending claims'; end if;
  begin
    insert into payment_claims (enrollment_id, amount, paid_on, upi_ref, note, submitted_by)
      values (p_enrollment, round(p_amount, 2), p_date, ref, nullif(trim(coalesce(p_note, '')), ''), auth.uid()) returning * into r;
  exception when unique_violation then raise exception 'duplicate reference';
  end;
  insert into notifications (user_id, title, message, type, related_module, related_record)
    select p.id, 'UPI payment waiting for verification', 'A parent reported a UPI payment of Rs. ' || round(p_amount, 2) || '. Please verify it.', 'fee', 'payment-claims', r.id::text
    from profiles p where p.is_active and p.role in ('accountant','school_admin');
  return r;
end $$;
revoke all on function submit_payment_claim(uuid, numeric, date, text, text) from public, anon;
grant execute on function submit_payment_claim(uuid, numeric, date, text, text) to authenticated;

create or replace function review_payment_claim(p_id uuid, p_approve boolean, p_note text default null)
returns payment_claims language plpgsql security definer set search_path = public as $$
declare c payment_claims; rc text;
begin
  if not can_manage_fees() then raise exception 'not allowed'; end if;
  select * into c from payment_claims where id = p_id for update;
  if not found then raise exception 'claim not found'; end if;
  if c.status <> 'pending' then raise exception 'already decided'; end if;
  if p_approve then
    rc := record_fee_payments(c.enrollment_id, c.amount, c.paid_on, 'upi', c.upi_ref, 'Approved from parent UPI claim');
  end if;
  update payment_claims set status = case when p_approve then 'approved' else 'rejected' end, reviewed_by = auth.uid(), reviewed_at = now(),
    review_note = nullif(trim(coalesce(p_note, '')), ''), receipt_no = rc where id = p_id returning * into c;
  if c.submitted_by is not null then
    insert into notifications (user_id, title, message, type, related_module, related_record)
    values (c.submitted_by, case when p_approve then 'Your UPI payment is confirmed' else 'Your UPI payment could not be confirmed' end,
      case when p_approve then 'Receipt number ' || rc || ' for Rs. ' || c.amount || '.' else coalesce('Reason: ' || c.review_note, 'Please contact the school office.') end, 'fee', 'fees', c.id::text);
  end if;
  insert into audit_logs (user_id, action, module, record_id) values (auth.uid(), 'Payment claim ' || c.status, 'fees', c.id::text);
  return c;
end $$;
revoke all on function review_payment_claim(uuid, boolean, text) from public, anon;
grant execute on function review_payment_claim(uuid, boolean, text) to authenticated;

------------------------------------------------------------------ 3. Leave balance (the school sets how many days each leave type gets)
create table if not exists leave_policy (
  leave_type text primary key check (leave_type in ('casual','sick','earned','maternity','unpaid','other')),
  days_per_year numeric(5,1) not null check (days_per_year >= 0 and days_per_year <= 366)
);
alter table leave_policy enable row level security;
drop policy if exists lp_read on leave_policy; drop policy if exists lp_write on leave_policy;
create policy lp_read on leave_policy for select to authenticated using (coalesce(current_role_name() not in ('parent','student'), false));
create policy lp_write on leave_policy for all to authenticated using (is_admin()) with check (is_admin());

create or replace function leave_balance(p_teacher uuid, p_staff uuid, p_year int default extract(year from current_date)::int)
returns table (leave_type text, allowed numeric, taken numeric, remaining numeric)
language plpgsql stable security definer set search_path = public as $$
begin
  if (p_teacher is null) = (p_staff is null) then raise exception 'choose one employee'; end if;
  if not (is_admin() or current_role_name() = 'reception' or is_my_employee(p_teacher, p_staff)) then raise exception 'not allowed'; end if;
  return query
  select t.lt, lp.days_per_year,
         coalesce((select count(*) from leave_requests l, generate_series(greatest(l.start_date, make_date(p_year, 1, 1)), least(l.end_date, make_date(p_year, 12, 31)), interval '1 day') d
                   where l.status = 'approved' and l.leave_type = t.lt and l.teacher_id is not distinct from p_teacher and l.staff_id is not distinct from p_staff
                     and l.end_date >= make_date(p_year, 1, 1) and l.start_date <= make_date(p_year, 12, 31) and is_working_day(d::date)), 0)::numeric,
         case when lp.days_per_year is null then null
              else lp.days_per_year - coalesce((select count(*) from leave_requests l, generate_series(greatest(l.start_date, make_date(p_year, 1, 1)), least(l.end_date, make_date(p_year, 12, 31)), interval '1 day') d
                   where l.status = 'approved' and l.leave_type = t.lt and l.teacher_id is not distinct from p_teacher and l.staff_id is not distinct from p_staff
                     and l.end_date >= make_date(p_year, 1, 1) and l.start_date <= make_date(p_year, 12, 31) and is_working_day(d::date)), 0) end::numeric
  from (values ('casual'),('sick'),('earned'),('maternity'),('unpaid'),('other')) t(lt)
  left join leave_policy lp on lp.leave_type = t.lt;
end $$;
revoke all on function leave_balance(uuid, uuid, int) from public, anon;
grant execute on function leave_balance(uuid, uuid, int) to authenticated;

------------------------------------------------------------------ 4. Teacher diary (what was taught each day)
create table if not exists teacher_diary (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid not null references profiles(id),
  division_id uuid not null references divisions(id),
  subject_id uuid not null references subjects(id),
  diary_date date not null default current_date,
  topic text not null check (length(trim(topic)) between 1 and 200),
  details text check (length(details) <= 2000),
  created_at timestamptz not null default now()
);
create index if not exists teacher_diary_teacher_idx on teacher_diary (teacher_id, diary_date desc);
create index if not exists teacher_diary_div_idx on teacher_diary (division_id, diary_date desc);
alter table teacher_diary enable row level security;
drop policy if exists td_read on teacher_diary; drop policy if exists td_ins on teacher_diary; drop policy if exists td_upd on teacher_diary; drop policy if exists td_del on teacher_diary;
create policy td_read on teacher_diary for select to authenticated using (is_admin() or teacher_id = auth.uid());
create policy td_ins on teacher_diary for insert to authenticated with check (teacher_id = auth.uid() and diary_date <= current_date and can_post_homework(division_id, subject_id));
create policy td_upd on teacher_diary for update to authenticated using (teacher_id = auth.uid()) with check (teacher_id = auth.uid() and diary_date <= current_date and can_post_homework(division_id, subject_id));
create policy td_del on teacher_diary for delete to authenticated using (teacher_id = auth.uid() or is_super_admin());
select 'phase15 finished' as result;
