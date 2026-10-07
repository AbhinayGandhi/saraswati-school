-- Phase 6: fees and accounts. Run once after Phase 5. Adds new tables only; nothing existing is changed.
create sequence receipt_seq;
create table fee_types (id uuid primary key default gen_random_uuid(), name text not null unique, is_active boolean not null default true);
insert into fee_types (name) values ('Admission Fee'),('Tuition Fee'),('Term Fee'),('Examination Fee'),('Activity Fee'),('Transport Fee'),('Library Fee'),('Computer/Lab Fee'),('Other Fee');
create table fee_structures (
  id uuid primary key default gen_random_uuid(),
  academic_year_id uuid not null references academic_years(id), class_id uuid not null references classes(id),
  division_id uuid references divisions(id), fee_type_id uuid not null references fee_types(id),
  amount numeric not null check (amount >= 0),
  frequency text not null check (frequency in ('monthly','quarterly','half_yearly','annual','one_time')),
  due_date date not null, notes text
);
create unique index fee_structures_uq on fee_structures (academic_year_id, class_id, coalesce(division_id,'00000000-0000-0000-0000-000000000000'::uuid), fee_type_id);
create table student_fees (
  id uuid primary key default gen_random_uuid(),
  enrollment_id uuid not null references student_enrollments(id),
  fee_structure_id uuid references fee_structures(id), fee_type_id uuid not null references fee_types(id),
  installment_no int not null default 1,
  assigned_amount numeric not null check (assigned_amount >= 0),
  concession_amount numeric not null default 0 check (concession_amount >= 0),
  paid_amount numeric not null default 0 check (paid_amount >= 0),
  balance numeric generated always as (assigned_amount - concession_amount - paid_amount) stored,
  due_date date not null,
  status text not null default 'pending' check (status in ('pending','partially_paid','paid','waived')),
  check (concession_amount <= assigned_amount),
  unique (enrollment_id, fee_structure_id, installment_no)
);
create index on student_fees (enrollment_id); create index on student_fees (due_date);
create table fee_payments (
  id uuid primary key default gen_random_uuid(),
  student_fee_id uuid not null references student_fees(id), amount numeric not null check (amount > 0),
  payment_date date not null default current_date,
  mode text not null check (mode in ('cash','upi','bank_transfer','cheque','other')),
  reference_no text, notes text,
  receipt_no text not null unique default ('R' || to_char(now(),'YY') || lpad(nextval('receipt_seq')::text, 6, '0')),
  recorded_by uuid references profiles(id), created_at timestamptz not null default now()
);
create unique index fee_payments_ref on fee_payments (mode, lower(reference_no)) where reference_no is not null and mode <> 'cash';
create index on fee_payments (payment_date); create index on fee_payments (student_fee_id);
create table fee_concessions (
  id uuid primary key default gen_random_uuid(),
  student_fee_id uuid not null references student_fees(id),
  concession_type text not null check (concession_type in ('fixed','percent')), value numeric not null check (value > 0),
  amount numeric not null default 0, reason text not null, approved_by uuid references profiles(id),
  concession_date date not null default current_date, notes text
);
create index on fee_concessions (student_fee_id);

create function fees_staff() returns boolean language sql stable security definer set search_path = public as
$$ select coalesce(current_role_name() in ('super_admin','school_admin','principal','accountant'), false) $$;
create function can_manage_fees() returns boolean language sql stable security definer set search_path = public as
$$ select coalesce(current_role_name() in ('super_admin','school_admin','accountant'), false) $$;
create function can_approve_concession() returns boolean language sql stable security definer set search_path = public as
$$ select coalesce(current_role_name() in ('super_admin','school_admin','principal'), false) $$;
create function is_guardian_of_enrollment(eid uuid) returns boolean language sql stable security definer set search_path = public as
$$ select exists (select 1 from student_enrollments e join student_guardians g on g.student_id = e.student_id where e.id = eid and g.user_id = auth.uid()) $$;
create function can_see_student_fee(fid uuid) returns boolean language sql stable security definer set search_path = public as
$$ select fees_staff() or exists (select 1 from student_fees f where f.id = fid and is_guardian_of_enrollment(f.enrollment_id)) $$;

-- Recalculates paid, concession and status from the payment and concession rows (single source of truth).
create function recalc_student_fee(fid uuid) returns void language plpgsql security definer set search_path = public as $$
declare r student_fees; net numeric;
begin
  update student_fees set
    concession_amount = coalesce((select sum(amount) from fee_concessions where student_fee_id = fid), 0),
    paid_amount = coalesce((select sum(amount) from fee_payments where student_fee_id = fid), 0) where id = fid;
  select * into r from student_fees where id = fid; net := r.assigned_amount - r.concession_amount;
  update student_fees set status = case when net <= 0 then 'waived' when r.paid_amount >= net then 'paid'
    when r.paid_amount > 0 then 'partially_paid' else 'pending' end where id = fid;
end $$;
revoke all on function recalc_student_fee(uuid) from public, anon, authenticated;

create function fee_payment_before() returns trigger language plpgsql security definer set search_path = public as $$
declare bal numeric;
begin
  select balance into bal from student_fees where id = new.student_fee_id for update;
  if not found then raise exception 'invalid fee'; end if;
  if new.amount > bal then raise exception 'amount exceeds balance'; end if;
  new.recorded_by = auth.uid(); return new;
end $$;
create function fee_payment_after() returns trigger language plpgsql security definer set search_path = public as $$
begin perform recalc_student_fee(new.student_fee_id); return new; end $$;
create trigger fp_before before insert on fee_payments for each row execute function fee_payment_before();
create trigger fp_after after insert on fee_payments for each row execute function fee_payment_after();

create function fee_concession_before() returns trigger language plpgsql security definer set search_path = public as $$
declare f student_fees; amt numeric;
begin
  select * into f from student_fees where id = new.student_fee_id for update;
  if not found then raise exception 'invalid fee'; end if;
  if new.concession_type = 'percent' and new.value > 100 then raise exception 'percentage above 100'; end if;
  amt := case when new.concession_type = 'percent' then round(f.assigned_amount * new.value / 100, 2) else new.value end;
  if f.assigned_amount - f.concession_amount - amt < f.paid_amount then raise exception 'concession exceeds unpaid amount'; end if;
  new.amount = amt; new.approved_by = auth.uid(); return new;
end $$;
create function fee_concession_after() returns trigger language plpgsql security definer set search_path = public as $$
begin perform recalc_student_fee(new.student_fee_id); return new; end $$;
create trigger fc_before before insert on fee_concessions for each row execute function fee_concession_before();
create trigger fc_after after insert on fee_concessions for each row execute function fee_concession_after();

-- Users cannot edit calculated fields directly; only the triggers above can.
create function student_fee_guard() returns trigger language plpgsql as $$
begin
  if current_user in ('authenticated','anon') and (new.paid_amount <> old.paid_amount or new.concession_amount <> old.concession_amount or new.status <> old.status) then
    raise exception 'calculated fields cannot be edited'; end if;
  return new;
end $$;
create trigger sf_guard before update on student_fees for each row execute function student_fee_guard();

create function fee_summary(p_year uuid) returns table (today_collection numeric, month_collection numeric, outstanding numeric,
  pending_students bigint, partial_students bigint, paid_students bigint) language sql stable as $$
  with per as (select sf.enrollment_id, sum(sf.balance) bal, sum(sf.paid_amount) paid from student_fees sf
    join student_enrollments e on e.id = sf.enrollment_id where e.academic_year_id = p_year group by sf.enrollment_id)
  select (select coalesce(sum(amount),0) from fee_payments where payment_date = current_date),
    (select coalesce(sum(amount),0) from fee_payments where date_trunc('month', payment_date) = date_trunc('month', current_date)),
    coalesce((select sum(bal) from per), 0),
    (select count(*) from per where bal > 0 and paid = 0), (select count(*) from per where bal > 0 and paid > 0), (select count(*) from per where bal <= 0) $$;

alter table fee_types enable row level security; alter table fee_structures enable row level security; alter table student_fees enable row level security;
alter table fee_payments enable row level security; alter table fee_concessions enable row level security;
create policy ft_read on fee_types for select to authenticated using (current_role_name() is not null);
create policy ft_write on fee_types for all to authenticated using (is_admin()) with check (is_admin());
create policy fs_read on fee_structures for select to authenticated using (fees_staff());
create policy fs_write on fee_structures for all to authenticated using (can_manage_fees()) with check (can_manage_fees());
create policy sf_read on student_fees for select to authenticated using (fees_staff() or is_guardian_of_enrollment(enrollment_id));
create policy sf_ins on student_fees for insert to authenticated with check (can_manage_fees());
create policy sf_upd on student_fees for update to authenticated using (can_manage_fees()) with check (can_manage_fees());
create policy fp_read on fee_payments for select to authenticated using (can_see_student_fee(student_fee_id));
create policy fp_ins on fee_payments for insert to authenticated with check (can_manage_fees());
create policy fc_read on fee_concessions for select to authenticated using (can_see_student_fee(student_fee_id));
create policy fc_ins on fee_concessions for insert to authenticated with check (can_approve_concession());
-- No update or delete policies on payments and concessions: financial records are permanent.
