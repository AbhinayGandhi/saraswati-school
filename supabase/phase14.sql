-- Phase 14 (round 1): certificates register, fee-reminder list, birthdays. Safe to run more than once. Nothing is deleted.

------------------------------------------------------------------ 1. Certificates (Bonafide, Transfer, Character)
create table if not exists certificates_issued (
  id uuid primary key default gen_random_uuid(),
  cert_no text not null unique,
  cert_type text not null check (cert_type in ('bonafide','transfer','character')),
  student_id uuid not null references students(id),
  issued_date date not null default current_date,
  details jsonb not null default '{}'::jsonb check (octet_length(details::text) <= 4000),
  issued_by uuid references profiles(id),
  created_at timestamptz not null default now()
);
create index if not exists certificates_student_idx on certificates_issued (student_id);
create table if not exists certificate_counters (cert_type text not null, yr int not null, last_no int not null default 0, primary key (cert_type, yr));
alter table certificates_issued enable row level security;
alter table certificate_counters enable row level security;      -- no policy: only the function below can touch it

create or replace function can_issue_certificates() returns boolean language sql stable security definer set search_path = public as
$$ select coalesce(current_role_name() in ('super_admin','school_admin','principal','reception'), false) $$;

drop policy if exists cert_read on certificates_issued;
create policy cert_read on certificates_issued for select to authenticated using (can_issue_certificates());
revoke insert, update, delete on certificates_issued from authenticated, anon;

create or replace function issue_certificate(p_student uuid, p_type text, p_details jsonb default '{}'::jsonb)
returns certificates_issued language plpgsql security definer set search_path = public as $$
declare y int := extract(year from current_date); n int; pre text; r certificates_issued;
begin
  if not can_issue_certificates() then raise exception 'not allowed'; end if;
  if p_type not in ('bonafide','transfer','character') then raise exception 'unknown certificate type'; end if;
  if not exists (select 1 from students where id = p_student) then raise exception 'student not found'; end if;
  insert into certificate_counters (cert_type, yr, last_no) values (p_type, y, 1)
    on conflict (cert_type, yr) do update set last_no = certificate_counters.last_no + 1 returning last_no into n;
  pre := case p_type when 'bonafide' then 'BON' when 'transfer' then 'TC' else 'CHR' end;
  insert into certificates_issued (cert_no, cert_type, student_id, details, issued_by)
    values (pre || '/' || y || '/' || lpad(n::text, 4, '0'), p_type, p_student, coalesce(p_details, '{}'::jsonb), auth.uid()) returning * into r;
  insert into audit_logs (user_id, action, module, record_id) values (auth.uid(), 'Certificate issued: ' || r.cert_no, 'certificates', r.id::text);
  return r;
end $$;
revoke all on function issue_certificate(uuid, text, jsonb) from public, anon;
grant execute on function issue_certificate(uuid, text, jsonb) to authenticated;

------------------------------------------------------------------ 2. Fee reminder list (overdue fees with the parent's mobile)
create or replace function fee_defaulters(p_class uuid default null)
returns table (enrollment_id uuid, student_name text, admission_no text, class_name text, division_name text,
               overdue numeric, total_balance numeric, oldest_due date, guardian_name text, guardian_mobile text)
language plpgsql stable security definer set search_path = public as $$
begin
  if not fees_staff() then raise exception 'not allowed'; end if;
  return query
  select e.id,
         trim(concat_ws(' ', s.first_name, s.middle_name, s.last_name)), s.admission_no, c.name, d.name,
         coalesce(sum(f.balance) filter (where f.due_date < current_date), 0),
         coalesce(sum(f.balance), 0),
         min(f.due_date) filter (where f.due_date < current_date),
         g.name, g.mobile
  from student_fees f
  join student_enrollments e on e.id = f.enrollment_id and e.status = 'active'
  join academic_years y on y.id = e.academic_year_id and y.is_active
  join students s on s.id = e.student_id
  join divisions d on d.id = e.division_id
  join classes c on c.id = d.class_id
  left join lateral (select sg.name, sg.mobile from student_guardians sg where sg.student_id = s.id
                     order by (sg.relation = 'father') desc, (sg.relation = 'mother') desc limit 1) g on true
  where f.balance > 0 and f.due_date < current_date and (p_class is null or c.id = p_class)
  group by e.id, s.first_name, s.middle_name, s.last_name, s.admission_no, c.name, c.sort_order, d.name, g.name, g.mobile
  order by c.sort_order, d.name, 2;
end $$;
revoke all on function fee_defaulters(uuid) from public, anon;
grant execute on function fee_defaulters(uuid) to authenticated;

------------------------------------------------------------------ 3. Birthdays (today and the next 7 days)
create or replace function upcoming_birthdays(p_days int default 7)
returns table (student_name text, class_name text, division_name text, birthday date, days_ahead int)
language plpgsql stable security definer set search_path = public as $$
begin
  if current_role_name() is null or current_role_name() in ('parent','student') then raise exception 'not allowed'; end if;
  return query
  with b as (
    select s.first_name, s.middle_name, s.last_name, c.name cn, d.name dn,
      (case when extract(month from s.dob) = 2 and extract(day from s.dob) = 29
              and not (extract(year from current_date)::int % 4 = 0 and (extract(year from current_date)::int % 100 <> 0 or extract(year from current_date)::int % 400 = 0))
            then make_date(extract(year from current_date)::int, 2, 28)
            else make_date(extract(year from current_date)::int, extract(month from s.dob)::int, extract(day from s.dob)::int) end) as this_year
    from students s
    join student_enrollments e on e.student_id = s.id and e.status = 'active'
    join academic_years y on y.id = e.academic_year_id and y.is_active
    join divisions d on d.id = e.division_id join classes c on c.id = d.class_id
    where s.dob is not null and s.status = 'active')
  select trim(concat_ws(' ', b.first_name, b.middle_name, b.last_name)), b.cn, b.dn, b.this_year, (b.this_year - current_date)::int
  from b where b.this_year between current_date and current_date + greatest(least(p_days, 31), 0)
  order by b.this_year, b.cn, 1;
end $$;
revoke all on function upcoming_birthdays(int) from public, anon;
grant execute on function upcoming_birthdays(int) to authenticated;
select 'phase14 finished' as result;
