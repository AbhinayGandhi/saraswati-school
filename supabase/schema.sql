-- Saraswati English Medium School: Phase 1 and 2 schema (foundation, roles, academic structure).
-- Run in Supabase SQL Editor. Later phases add students, attendance, exams, fees, etc.
create extension if not exists pgcrypto;

create type user_role as enum ('super_admin','school_admin','principal','teacher','class_teacher',
  'accountant','librarian','reception','parent','student');

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text, role user_role not null default 'parent',
  is_active boolean not null default false, created_at timestamptz not null default now()
);

-- New sign-ups get the least-privileged role and are inactive until an admin activates them.
create function handle_new_user() returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, full_name) values (new.id, coalesce(new.raw_user_meta_data->>'full_name', new.email));
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function handle_new_user();

create function current_role_name() returns user_role language sql stable security definer set search_path = public as
$$ select role from profiles where id = auth.uid() and is_active $$;
create function is_admin() returns boolean language sql stable security definer set search_path = public as
$$ select coalesce(current_role_name() in ('super_admin','school_admin','principal'), false) $$;
create function is_super_admin() returns boolean language sql stable security definer set search_path = public as
$$ select coalesce(current_role_name() = 'super_admin', false) $$;

create table academic_years (
  id uuid primary key default gen_random_uuid(),
  name text not null unique check (name ~ '^\d{4}-\d{2}$'),
  start_date date not null, end_date date not null check (end_date > start_date),
  status text not null default 'upcoming' check (status in ('upcoming','active','closed','archived')),
  is_active boolean not null default false, created_at timestamptz not null default now()
);
create unique index one_active_year on academic_years ((true)) where is_active;

create table classes (
  id uuid primary key default gen_random_uuid(),
  name text not null unique, sort_order int not null unique
);
insert into classes (name, sort_order) values ('LKG',1),('UKG',2),('Grade 1',3),('Grade 2',4),('Grade 3',5),
 ('Grade 4',6),('Grade 5',7),('Grade 6',8),('Grade 7',9),('Grade 8',10),('Grade 9',11),('Grade 10',12);

create table divisions (
  id uuid primary key default gen_random_uuid(),
  academic_year_id uuid not null references academic_years(id),
  class_id uuid not null references classes(id),
  name text not null check (length(name) between 1 and 5),
  class_teacher_id uuid references profiles(id),
  unique (academic_year_id, class_id, name)
);
create index on divisions (academic_year_id, class_id);

create table subjects (
  id uuid primary key default gen_random_uuid(),
  name text not null unique, code text unique, is_active boolean not null default true
);
create table class_subjects (
  id uuid primary key default gen_random_uuid(),
  academic_year_id uuid not null references academic_years(id),
  division_id uuid not null references divisions(id),
  subject_id uuid not null references subjects(id),
  teacher_id uuid references profiles(id),
  unique (academic_year_id, division_id, subject_id)
);

create table school_settings (
  key text primary key, value text, is_public boolean not null default false
);
insert into school_settings (key, value, is_public) values
 ('school_name','Saraswati English Medium School',true),('address','[School Address]',true),
 ('phone','[School Phone]',true),('email','[School Email]',true),('principal','[Principal Name]',true);

create table audit_logs (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id), action text not null, module text not null,
  record_id text, created_at timestamptz not null default now()
);
create index on audit_logs (created_at desc);

-- Row Level Security
alter table profiles enable row level security;
alter table academic_years enable row level security;
alter table classes enable row level security;
alter table divisions enable row level security;
alter table subjects enable row level security;
alter table class_subjects enable row level security;
alter table school_settings enable row level security;
alter table audit_logs enable row level security;

create policy profiles_read on profiles for select to authenticated using (id = auth.uid() or is_admin());
create policy profiles_admin_write on profiles for all to authenticated using (is_admin()) with check (is_admin());
-- Only super admin may grant admin-level roles (prevents school_admin escalating itself).
create policy profiles_no_escalation on profiles as restrictive for update to authenticated
  using (true) with check (is_super_admin() or role not in ('super_admin','school_admin'));

create policy ay_read on academic_years for select to authenticated using (current_role_name() is not null);
create policy ay_write on academic_years for all to authenticated using (is_admin()) with check (is_admin());
create policy cls_read on classes for select to authenticated using (current_role_name() is not null);
create policy cls_write on classes for all to authenticated using (is_admin()) with check (is_admin());
create policy div_read on divisions for select to authenticated using (current_role_name() is not null);
create policy div_write on divisions for all to authenticated using (is_admin()) with check (is_admin());
create policy sub_read on subjects for select to authenticated using (current_role_name() is not null);
create policy sub_write on subjects for all to authenticated using (is_admin()) with check (is_admin());
create policy cs_read on class_subjects for select to authenticated using (current_role_name() is not null);
create policy cs_write on class_subjects for all to authenticated using (is_admin()) with check (is_admin());

create policy set_public_read on school_settings for select to anon, authenticated using (is_public);
create policy set_admin_read on school_settings for select to authenticated using (is_admin());
create policy set_admin_write on school_settings for all to authenticated using (is_admin()) with check (is_admin());

create policy audit_read on audit_logs for select to authenticated using (current_role_name() in ('super_admin','school_admin'));
create policy audit_insert on audit_logs for insert to authenticated with check (user_id = auth.uid() and current_role_name() is not null);
-- No update/delete policies on audit_logs: records are append-only.
create or replace function set_active_year(p_id uuid) returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_admin() then raise exception 'not allowed'; end if;
  update academic_years set is_active = false, status = 'closed' where is_active and id <> p_id;
  update academic_years set is_active = true, status = 'active' where id = p_id;
end $$;
revoke all on function set_active_year(uuid) from public, anon;
grant execute on function set_active_year(uuid) to authenticated;
-- Phase 3: students, guardians, enrollments, teachers, staff. Run once after Phase 1 and 2.
create table students (
  id uuid primary key default gen_random_uuid(),
  admission_no text not null unique, gr_no text unique,
  first_name text not null, middle_name text, last_name text not null,
  gender text not null check (gender in ('Male','Female','Other')), dob date not null,
  blood_group text, admission_date date not null default current_date, photo_path text,
  status text not null default 'active' check (status in ('active','inactive','transferred','alumni')),
  previous_school text, previous_class text, admission_class text, house text, student_type text,
  created_at timestamptz not null default now()
);
create table student_guardians (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references students(id),
  relation text not null check (relation in ('father','mother','guardian')),
  name text not null, mobile text, alt_mobile text, email text, address text,
  user_id uuid references profiles(id)
);
create index on student_guardians (student_id);
create index on student_guardians (user_id);
create table student_enrollments (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references students(id),
  academic_year_id uuid not null references academic_years(id),
  division_id uuid not null references divisions(id),
  roll_no int,
  status text not null default 'active' check (status in ('active','promoted','repeated','transferred','alumni')),
  unique (student_id, academic_year_id)
);
create index on student_enrollments (academic_year_id, division_id);
create table teachers (
  id uuid primary key default gen_random_uuid(),
  employee_id text not null unique, profile_id uuid references profiles(id),
  name text not null, qualification text, subject text, mobile text, email text, joining_date date,
  status text not null default 'active' check (status in ('active','inactive')),
  is_public boolean not null default false
);
create table staff (
  id uuid primary key default gen_random_uuid(),
  employee_id text not null unique, name text not null,
  staff_type text not null check (staff_type in ('Teaching Staff','Non-Teaching Staff','Administrative Staff','Support Staff')),
  mobile text, email text, joining_date date,
  status text not null default 'active' check (status in ('active','inactive'))
);
-- Who may see a student's private record
create function can_view_student(sid uuid) returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(current_role_name() in ('super_admin','school_admin','principal','reception'), false)
  or exists (select 1 from student_guardians g where g.student_id = sid and g.user_id = auth.uid())
  or exists (select 1 from student_enrollments e join divisions d on d.id = e.division_id
      where e.student_id = sid and (d.class_teacher_id = auth.uid()
        or exists (select 1 from class_subjects cs where cs.division_id = d.id and cs.teacher_id = auth.uid()))) $$;
create function can_edit_students() returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(current_role_name() in ('super_admin','school_admin','reception'), false) $$;
alter table students enable row level security; alter table student_guardians enable row level security;
alter table student_enrollments enable row level security; alter table teachers enable row level security; alter table staff enable row level security;
create policy st_read on students for select to authenticated using (can_view_student(id));
create policy st_ins on students for insert to authenticated with check (can_edit_students());
create policy st_upd on students for update to authenticated using (can_edit_students()) with check (can_edit_students());
create policy st_del on students for delete to authenticated using (is_super_admin());
create policy sg_read on student_guardians for select to authenticated using (can_view_student(student_id));
create policy sg_ins on student_guardians for insert to authenticated with check (can_edit_students());
create policy sg_upd on student_guardians for update to authenticated using (can_edit_students()) with check (can_edit_students());
create policy sg_del on student_guardians for delete to authenticated using (is_super_admin());
create policy se_read on student_enrollments for select to authenticated using (can_view_student(student_id));
create policy se_ins on student_enrollments for insert to authenticated with check (can_edit_students());
create policy se_upd on student_enrollments for update to authenticated using (can_edit_students()) with check (can_edit_students());
create policy se_del on student_enrollments for delete to authenticated using (is_super_admin());
create policy t_admin on teachers for all to authenticated using (is_admin()) with check (is_admin());
create policy t_self on teachers for select to authenticated using (profile_id = auth.uid());
create policy sf_admin on staff for all to authenticated using (is_admin()) with check (is_admin());
-- Public website sees only approved name, qualification and subject (never phone or email).
create view teachers_public as select id, name, qualification, subject from teachers where is_public and status = 'active';
grant select on teachers_public to anon, authenticated;
-- Phase 4: attendance and school calendar. Run once after Phase 3.
create table school_calendar (
  id uuid primary key default gen_random_uuid(),
  day date not null, kind text not null check (kind in ('holiday','vacation','exam','event','parent_meeting')),
  title text not null, unique (day, kind)
);
create table attendance (
  id uuid primary key default gen_random_uuid(),
  enrollment_id uuid not null references student_enrollments(id),
  att_date date not null,
  status text not null check (status in ('present','absent','late','half_day','leave')),
  remarks text, marked_by uuid references profiles(id), updated_at timestamptz not null default now(),
  unique (enrollment_id, att_date)
);
create index on attendance (att_date);
create function can_mark_attendance(eid uuid) returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(current_role_name() in ('super_admin','school_admin'), false)
  or exists (select 1 from student_enrollments e join divisions d on d.id = e.division_id where e.id = eid
      and (d.class_teacher_id = auth.uid() or exists (select 1 from class_subjects cs where cs.division_id = d.id and cs.teacher_id = auth.uid()))) $$;
create function block_holiday_attendance() returns trigger language plpgsql as $$
begin
  if exists (select 1 from school_calendar where day = new.att_date and kind in ('holiday','vacation')) then
    raise exception 'holiday: attendance cannot be marked'; end if;
  new.updated_at = now(); new.marked_by = auth.uid(); return new;
end $$;
create trigger attendance_guard before insert or update on attendance for each row execute function block_holiday_attendance();
alter table school_calendar enable row level security; alter table attendance enable row level security;
create policy cal_read on school_calendar for select to authenticated using (current_role_name() is not null);
create policy cal_write on school_calendar for all to authenticated using (is_admin()) with check (is_admin());
create policy att_read on attendance for select to authenticated using (
  can_mark_attendance(enrollment_id) or exists (select 1 from student_enrollments e where e.id = enrollment_id and can_view_student(e.student_id)));
create policy att_ins on attendance for insert to authenticated with check (can_mark_attendance(enrollment_id));
create policy att_upd on attendance for update to authenticated using (can_mark_attendance(enrollment_id)) with check (can_mark_attendance(enrollment_id));
-- No delete policy: attendance records are kept.
-- Phase 5: exams, marks, grading, report remarks. Run once after Phase 4.
create table grading_rules (id uuid primary key default gen_random_uuid(), min_pct numeric not null unique check (min_pct between 0 and 100), grade text not null);
insert into grading_rules (min_pct, grade) values (91,'A+'),(81,'A'),(71,'B+'),(61,'B'),(51,'C+'),(41,'C'),(33,'D'),(0,'F');
create table exams (
  id uuid primary key default gen_random_uuid(),
  academic_year_id uuid not null references academic_years(id), name text not null,
  exam_type text not null check (exam_type in ('Unit Test','First Term','Mid Term','Preliminary','Annual Examination','Oral','Practical','Internal Assessment')),
  status text not null default 'draft' check (status in ('draft','published')), created_at timestamptz not null default now(),
  unique (academic_year_id, name)
);
create table exam_subjects (
  id uuid primary key default gen_random_uuid(),
  exam_id uuid not null references exams(id), division_id uuid not null references divisions(id), subject_id uuid not null references subjects(id),
  max_marks numeric not null check (max_marks > 0), passing_marks numeric not null check (passing_marks >= 0), exam_date date,
  status text not null default 'open' check (status in ('open','submitted','locked')),
  check (passing_marks <= max_marks), unique (exam_id, division_id, subject_id)
);
create table marks (
  id uuid primary key default gen_random_uuid(),
  exam_subject_id uuid not null references exam_subjects(id), enrollment_id uuid not null references student_enrollments(id),
  marks numeric check (marks >= 0), absent boolean not null default false, remarks text,
  unique (exam_subject_id, enrollment_id)
);
create index on marks (enrollment_id);
create table report_remarks (
  id uuid primary key default gen_random_uuid(), exam_id uuid not null references exams(id),
  enrollment_id uuid not null references student_enrollments(id), teacher_remark text, principal_remark text,
  unique (exam_id, enrollment_id)
);
create function can_enter_marks(esid uuid) returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(current_role_name() in ('super_admin','school_admin'), false)
  or exists (select 1 from exam_subjects x join class_subjects cs on cs.division_id = x.division_id and cs.subject_id = x.subject_id
      where x.id = esid and cs.teacher_id = auth.uid()) $$;
create function marks_readable(esid uuid, eid uuid) returns boolean language sql stable security definer set search_path = public as $$
  select is_admin() or can_enter_marks(esid)
  or exists (select 1 from exam_subjects x join exams m on m.id = x.exam_id join student_enrollments e on e.id = eid
      where x.id = esid and m.status = 'published' and can_view_student(e.student_id)) $$;
create function marks_writable(esid uuid) returns boolean language sql stable security definer set search_path = public as $$
  select is_super_admin() or (can_enter_marks(esid) and exists (select 1 from exam_subjects where id = esid and status = 'open')) $$;
create function check_marks() returns trigger language plpgsql as $$
begin
  if new.marks is not null and new.marks > (select max_marks from exam_subjects where id = new.exam_subject_id) then
    raise exception 'marks exceed maximum'; end if;
  return new;
end $$;
create trigger marks_check before insert or update on marks for each row execute function check_marks();
create function publish_exam(p_id uuid) returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_admin() then raise exception 'not allowed'; end if;
  update exam_subjects set status = 'locked' where exam_id = p_id;
  update exams set status = 'published' where id = p_id;
end $$;
revoke all on function publish_exam(uuid) from public, anon; grant execute on function publish_exam(uuid) to authenticated;
alter table grading_rules enable row level security; alter table exams enable row level security; alter table exam_subjects enable row level security;
alter table marks enable row level security; alter table report_remarks enable row level security;
create policy gr_read on grading_rules for select to authenticated using (current_role_name() is not null);
create policy gr_write on grading_rules for all to authenticated using (is_admin()) with check (is_admin());
create policy ex_read on exams for select to authenticated using (current_role_name() is not null);
create policy ex_write on exams for all to authenticated using (is_admin()) with check (is_admin());
create policy es_read on exam_subjects for select to authenticated using (current_role_name() is not null);
create policy es_admin on exam_subjects for all to authenticated using (is_admin()) with check (is_admin());
create policy es_submit on exam_subjects for update to authenticated using (can_enter_marks(id) and status = 'open') with check (status in ('open','submitted'));
create policy mk_read on marks for select to authenticated using (marks_readable(exam_subject_id, enrollment_id));
create policy mk_ins on marks for insert to authenticated with check (marks_writable(exam_subject_id));
create policy mk_upd on marks for update to authenticated using (marks_writable(exam_subject_id)) with check (marks_writable(exam_subject_id));
create policy rr_read on report_remarks for select to authenticated using (exists (select 1 from student_enrollments e where e.id = enrollment_id and can_view_student(e.student_id)));
create policy rr_ins on report_remarks for insert to authenticated with check (can_mark_attendance(enrollment_id));
create policy rr_upd on report_remarks for update to authenticated using (can_mark_attendance(enrollment_id)) with check (can_mark_attendance(enrollment_id));
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

-- Update 6b
alter table subjects add column if not exists sort_order int not null default 0;
update subjects s set sort_order = r.n from (select id, row_number() over (order by name) as n from subjects) r where r.id = s.id and s.sort_order = 0;

alter table fee_payments drop constraint if exists fee_payments_receipt_no_key;
alter table fee_payments add constraint fee_payments_receipt_fee_uq unique (receipt_no, student_fee_id);
alter table fee_payments add column if not exists is_first boolean not null default true;
drop index if exists fee_payments_ref;
create unique index fee_payments_ref on fee_payments (mode, lower(reference_no)) where reference_no is not null and mode <> 'cash' and is_first;

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
  rcpt := 'R' || to_char(now(),'YY') || lpad(nextval('receipt_seq')::text, 6, '0');
  for r in select id, balance from student_fees where enrollment_id = p_enrollment and balance > 0 order by due_date, installment_no, id for update loop
    exit when remaining <= 0;
    pay := least(r.balance, remaining);
    insert into fee_payments (student_fee_id, amount, payment_date, mode, reference_no, notes, receipt_no, is_first)
      values (r.id, pay, coalesce(p_date, current_date), p_mode, nullif(trim(p_ref), ''), p_notes, rcpt, first_row);
    first_row := false; remaining := remaining - pay;
  end loop;
  return rcpt;
end $$;
revoke all on function record_fee_payments(uuid, numeric, date, text, text, text) from public, anon;
grant execute on function record_fee_payments(uuid, numeric, date, text, text, text) to authenticated;
-- Phase 7: timetable, homework, notices, notifications. Run ONCE on your existing project (not schema.sql again).
create function teaches_division(did uuid) returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from divisions d where d.id = did and (d.class_teacher_id = auth.uid()
    or exists (select 1 from class_subjects cs where cs.division_id = d.id and cs.teacher_id = auth.uid()))) $$;
create function guardian_of_division(did uuid) returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from student_enrollments e join student_guardians g on g.student_id = e.student_id
    where e.division_id = did and g.user_id = auth.uid() and e.status = 'active') $$;
create function can_manage_notices() returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(current_role_name() in ('super_admin','school_admin','principal','reception'), false) $$;

create view teacher_names as select id, full_name from profiles where is_active and role in ('teacher','class_teacher');
grant select on teacher_names to authenticated;

create table timetable_slots (
  id uuid primary key default gen_random_uuid(),
  academic_year_id uuid not null references academic_years(id), division_id uuid not null references divisions(id),
  day smallint not null check (day between 1 and 6), period smallint not null check (period between 1 and 12),
  subject_id uuid not null references subjects(id), teacher_id uuid references profiles(id),
  start_time time not null, end_time time not null, room text, is_active boolean not null default true,
  check (end_time > start_time)
);
create unique index timetable_div_uq on timetable_slots (academic_year_id, division_id, day, period) where is_active;
create unique index timetable_teacher_uq on timetable_slots (academic_year_id, teacher_id, day, period) where is_active and teacher_id is not null;
alter table timetable_slots enable row level security;
create policy tt_read on timetable_slots for select to authenticated using (current_role_name() is not null);
create policy tt_write on timetable_slots for all to authenticated using (is_admin()) with check (is_admin());

create table homework (
  id uuid primary key default gen_random_uuid(),
  academic_year_id uuid not null references academic_years(id), division_id uuid not null references divisions(id),
  subject_id uuid not null references subjects(id), teacher_id uuid references profiles(id) default auth.uid(),
  homework_date date not null default current_date, due_date date not null, title text not null, description text,
  attachment_path text, status text not null default 'active' check (status in ('active','inactive')),
  created_at timestamptz not null default now(), check (due_date >= homework_date)
);
create index on homework (division_id, homework_date desc);
create function can_post_homework(did uuid, sid uuid) returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(current_role_name() in ('super_admin','school_admin'), false)
  or exists (select 1 from class_subjects cs where cs.division_id = did and cs.subject_id = sid and cs.teacher_id = auth.uid()) $$;
alter table homework enable row level security;
create policy hw_read on homework for select to authenticated using (is_admin() or teaches_division(division_id) or (status = 'active' and guardian_of_division(division_id)));
create policy hw_ins on homework for insert to authenticated with check (can_post_homework(division_id, subject_id));
create policy hw_upd on homework for update to authenticated using (can_post_homework(division_id, subject_id) and (teacher_id = auth.uid() or is_admin()))
  with check (can_post_homework(division_id, subject_id));
-- No delete: homework is deactivated, not removed.

create table notices (
  id uuid primary key default gen_random_uuid(),
  title text not null, description text not null, notice_date date not null default current_date, expiry_date date,
  priority text not null default 'normal' check (priority in ('normal','important','urgent')),
  audience text not null default 'everyone' check (audience in ('everyone','parents','students','teachers','staff','class','division')),
  class_id uuid references classes(id), division_id uuid references divisions(id),
  is_public boolean not null default false, attachment_path text,
  status text not null default 'draft' check (status in ('draft','published')),
  created_by uuid references profiles(id) default auth.uid(), created_at timestamptz not null default now(),
  check (audience <> 'class' or class_id is not null), check (audience <> 'division' or division_id is not null),
  check (expiry_date is null or expiry_date >= notice_date)
);
create function notice_audience_ok(aud text, cid uuid, did uuid) returns boolean language sql stable security definer set search_path = public as $$
  select case
    when current_role_name() is null then false
    when aud = 'everyone' then true
    when aud = 'parents' then current_role_name() = 'parent'
    when aud = 'students' then current_role_name() = 'student'
    when aud = 'teachers' then current_role_name() in ('teacher','class_teacher')
    when aud = 'staff' then current_role_name() in ('teacher','class_teacher','accountant','librarian','reception')
    when aud = 'class' then exists (select 1 from divisions d where d.class_id = cid and (teaches_division(d.id) or guardian_of_division(d.id)))
    when aud = 'division' then teaches_division(did) or guardian_of_division(did)
    else false end $$;
alter table notices enable row level security;
create policy nt_read on notices for select to authenticated using (can_manage_notices() or created_by = auth.uid()
  or (status = 'published' and (expiry_date is null or expiry_date >= current_date) and notice_audience_ok(audience, class_id, division_id)));
create policy nt_public on notices for select to anon using (is_public and status = 'published' and (expiry_date is null or expiry_date >= current_date));
create policy nt_ins on notices for insert to authenticated with check (can_manage_notices());
create policy nt_upd on notices for update to authenticated using (can_manage_notices()) with check (can_manage_notices());
create policy nt_del on notices for delete to authenticated using (is_super_admin());

create table notifications (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references profiles(id) on delete cascade,
  title text not null, message text, type text not null default 'notice' check (type in ('notice','exam','fee','homework','event','announcement')),
  related_module text, related_record text, is_read boolean not null default false, created_at timestamptz not null default now()
);
create index on notifications (user_id, is_read, created_at desc);
alter table notifications enable row level security;
create policy nf_read on notifications for select to authenticated using (user_id = auth.uid());
create policy nf_upd on notifications for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create function notification_guard() returns trigger language plpgsql as $$
begin
  if new.user_id <> old.user_id or new.title <> old.title or new.message is distinct from old.message or new.type <> old.type then
    raise exception 'only the read flag can change'; end if;
  return new;
end $$;
create trigger nf_guard before update on notifications for each row execute function notification_guard();

create function publish_notice(p_id uuid) returns void language plpgsql security definer set search_path = public as $$
declare n notices;
begin
  if not can_manage_notices() then raise exception 'not allowed'; end if;
  select * into n from notices where id = p_id for update;
  if not found then raise exception 'not found'; end if;
  if n.status = 'published' then raise exception 'already published'; end if;
  update notices set status = 'published' where id = p_id;
  insert into notifications (user_id, title, message, type, related_module, related_record)
  select u.id, n.title, left(n.description, 200), 'notice', 'notices', p_id::text from profiles u
  where u.is_active and case n.audience
    when 'everyone' then true
    when 'parents' then u.role = 'parent'
    when 'students' then u.role = 'student'
    when 'teachers' then u.role in ('teacher','class_teacher')
    when 'staff' then u.role in ('teacher','class_teacher','accountant','librarian','reception')
    when 'class' then exists (select 1 from divisions d where d.class_id = n.class_id and (
        d.class_teacher_id = u.id or exists (select 1 from class_subjects cs where cs.division_id = d.id and cs.teacher_id = u.id)
        or exists (select 1 from student_enrollments e join student_guardians g on g.student_id = e.student_id where e.division_id = d.id and g.user_id = u.id and e.status = 'active')))
    when 'division' then exists (select 1 from divisions d where d.id = n.division_id and (
        d.class_teacher_id = u.id or exists (select 1 from class_subjects cs where cs.division_id = d.id and cs.teacher_id = u.id)
        or exists (select 1 from student_enrollments e join student_guardians g on g.student_id = e.student_id where e.division_id = d.id and g.user_id = u.id and e.status = 'active')))
    else false end;
end $$;
revoke all on function publish_notice(uuid) from public, anon; grant execute on function publish_notice(uuid) to authenticated;

-- Private file buckets (5 MB, PDF/JPG/PNG). Files are readable only if the linked homework or notice row is visible to the user.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('homework','homework',false,5242880,array['application/pdf','image/jpeg','image/png']),
  ('notices','notices',false,5242880,array['application/pdf','image/jpeg','image/png']) on conflict (id) do nothing;
create policy hw_files_read on storage.objects for select to authenticated using (bucket_id = 'homework' and exists (select 1 from homework h where h.attachment_path = name));
create policy hw_files_write on storage.objects for insert to authenticated with check (bucket_id = 'homework' and current_role_name() in ('super_admin','school_admin','teacher','class_teacher'));
create policy nt_files_read on storage.objects for select to authenticated using (bucket_id = 'notices' and exists (select 1 from notices n where n.attachment_path = name));
create policy nt_files_write on storage.objects for insert to authenticated with check (bucket_id = 'notices' and can_manage_notices());

-- Update 7b
create or replace function remove_fee_structure(p_id uuid) returns text language plpgsql security definer set search_path = public as $$
declare removed int; kept int;
begin
  if not can_manage_fees() then raise exception 'not allowed'; end if;
  delete from student_fees sf where sf.fee_structure_id = p_id and sf.paid_amount = 0 and sf.concession_amount = 0
    and not exists (select 1 from fee_payments fp where fp.student_fee_id = sf.id)
    and not exists (select 1 from fee_concessions fc where fc.student_fee_id = sf.id);
  get diagnostics removed = row_count;
  select count(*) into kept from student_fees where fee_structure_id = p_id;
  if kept = 0 then delete from fee_structures where id = p_id; end if;
  return removed || ',' || kept;
end $$;
revoke all on function remove_fee_structure(uuid) from public, anon;
grant execute on function remove_fee_structure(uuid) to authenticated;

-- Update 7c: simpler fee model. A student has ONE total fee per fee type per year; parents may pay any amount at any time.
-- Run ONCE on your existing project. Safe: it checks that totals match before and after, and stops (rolls back) if anything differs.
alter table fee_payments drop constraint if exists fee_payments_receipt_fee_uq;
create index if not exists fee_payments_receipt_idx on fee_payments (receipt_no);

create temp table _fee_before as
  select enrollment_id, fee_structure_id, sum(assigned_amount) a, sum(paid_amount) p, sum(concession_amount) c
  from student_fees where fee_structure_id is not null group by 1, 2;

do $$
declare g record; keep uuid; tot numeric; last_due date;
begin
  for g in select enrollment_id, fee_structure_id from student_fees where fee_structure_id is not null group by 1, 2 having count(*) > 1 loop
    select id into keep from student_fees where enrollment_id = g.enrollment_id and fee_structure_id = g.fee_structure_id order by installment_no, id limit 1;
    select sum(assigned_amount), max(due_date) into tot, last_due from student_fees where enrollment_id = g.enrollment_id and fee_structure_id = g.fee_structure_id;
    update fee_payments set student_fee_id = keep where student_fee_id in
      (select id from student_fees where enrollment_id = g.enrollment_id and fee_structure_id = g.fee_structure_id and id <> keep);
    update fee_concessions set student_fee_id = keep where student_fee_id in
      (select id from student_fees where enrollment_id = g.enrollment_id and fee_structure_id = g.fee_structure_id and id <> keep);
    delete from student_fees where enrollment_id = g.enrollment_id and fee_structure_id = g.fee_structure_id and id <> keep;
    update student_fees set assigned_amount = tot, due_date = last_due, installment_no = 1 where id = keep;
    perform recalc_student_fee(keep);
  end loop;
end $$;

do $$
begin
  if exists (select 1 from _fee_before b join (select enrollment_id, fee_structure_id, sum(assigned_amount) a, sum(paid_amount) p, sum(concession_amount) c
        from student_fees where fee_structure_id is not null group by 1, 2) n using (enrollment_id, fee_structure_id)
      where b.a <> n.a or b.p <> n.p or b.c <> n.c) then
    raise exception 'Totals changed during the merge. Nothing was saved.'; end if;
end $$;

update fee_structures set
  amount = amount * case frequency when 'monthly' then 12 when 'quarterly' then 4 when 'half_yearly' then 2 else 1 end,
  due_date = (due_date + (case frequency when 'monthly' then 11 when 'quarterly' then 9 when 'half_yearly' then 6 else 0 end) * interval '1 month')::date,
  frequency = 'annual';
alter table fee_structures alter column frequency set default 'annual';

create or replace function fee_structure_guard() returns trigger language plpgsql as $$
begin
  if exists (select 1 from fee_structures x where x.academic_year_id = new.academic_year_id and x.class_id = new.class_id
      and x.fee_type_id = new.fee_type_id and x.id <> new.id) then
    raise exception 'duplicate fee structure'; end if;
  return new;
end $$;
drop trigger if exists fs_guard on fee_structures;
create trigger fs_guard before insert or update on fee_structures for each row execute function fee_structure_guard();

create or replace function student_fee_dup_guard() returns trigger language plpgsql as $$
begin
  if exists (select 1 from student_fees f where f.enrollment_id = new.enrollment_id and f.fee_type_id = new.fee_type_id) then
    raise exception 'duplicate fee for student'; end if;
  return new;
end $$;
drop trigger if exists sf_dup_guard on student_fees;
create trigger sf_dup_guard before insert on student_fees for each row execute function student_fee_dup_guard();

create or replace function assign_fee_structure(p_id uuid) returns text language plpgsql security definer set search_path = public as $$
declare s fee_structures; ins_n bigint; tot_n bigint;
begin
  if not can_manage_fees() then raise exception 'not allowed'; end if;
  select * into s from fee_structures where id = p_id;
  if not found then raise exception 'not found'; end if;
  select count(*) into tot_n from student_enrollments e join divisions d on d.id = e.division_id
    where e.academic_year_id = s.academic_year_id and e.status = 'active' and d.class_id = s.class_id and (s.division_id is null or d.id = s.division_id);
  with ins as (
    insert into student_fees (enrollment_id, fee_structure_id, fee_type_id, installment_no, assigned_amount, due_date)
    select e.id, s.id, s.fee_type_id, 1, s.amount, s.due_date from student_enrollments e join divisions d on d.id = e.division_id
    where e.academic_year_id = s.academic_year_id and e.status = 'active' and d.class_id = s.class_id and (s.division_id is null or d.id = s.division_id)
      and not exists (select 1 from student_fees f where f.enrollment_id = e.id and f.fee_type_id = s.fee_type_id)
    returning 1)
  select count(*) into ins_n from ins;
  return ins_n || ',' || tot_n;
end $$;
revoke all on function assign_fee_structure(uuid) from public, anon;
grant execute on function assign_fee_structure(uuid) to authenticated;

-- Built-in checker for the Fee check page.
create or replace function fee_integrity_check(p_year uuid) returns table (section text, detail text, n bigint) language plpgsql stable security definer set search_path = public as $$
begin
  if not fees_staff() then raise exception 'not allowed'; end if;
  return query
  select 'Fee structure'::text, (c.name || coalesce(' - ' || dv.name, ' (all divisions)') || ' | ' || ft.name || ' | ' || s.amount::text)::text,
    (select count(*) from student_fees f where f.fee_structure_id = s.id)
  from fee_structures s join classes c on c.id = s.class_id join fee_types ft on ft.id = s.fee_type_id left join divisions dv on dv.id = s.division_id
  where s.academic_year_id = p_year
  union all
  select 'Student has the same fee more than once'::text, (st.first_name || ' ' || st.last_name || ' (' || st.admission_no || ') | ' || ft.name)::text, count(*)
  from student_fees f join student_enrollments e on e.id = f.enrollment_id join students st on st.id = e.student_id join fee_types ft on ft.id = f.fee_type_id
  where e.academic_year_id = p_year group by st.id, st.first_name, st.last_name, st.admission_no, ft.id, ft.name having count(*) > 1
  union all
  select 'Fee belongs to a different class than the student'::text, (st.first_name || ' ' || st.last_name || ' (' || st.admission_no || ') is in ' || c1.name || ' but has ' || ft.name || ' of ' || c2.name)::text, 1::bigint
  from student_fees f join student_enrollments e on e.id = f.enrollment_id join divisions d on d.id = e.division_id join classes c1 on c1.id = d.class_id
    join students st on st.id = e.student_id join fee_structures s on s.id = f.fee_structure_id join classes c2 on c2.id = s.class_id join fee_types ft on ft.id = f.fee_type_id
  where e.academic_year_id = p_year and s.class_id <> d.class_id
  union all
  select 'Old installment rows still present'::text, 'rows with installment number above 1'::text, count(*)
  from student_fees f join student_enrollments e on e.id = f.enrollment_id where e.academic_year_id = p_year and f.installment_no > 1 having count(*) > 0;
end $$;
revoke all on function fee_integrity_check(uuid) from public, anon;
grant execute on function fee_integrity_check(uuid) to authenticated;
-- Phase 8: events, activities, achievements, gallery. Run ONCE on your existing project (after update 7c).
create table events (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  event_type text not null check (event_type in ('Annual Day','Sports Day','Independence Day','Republic Day','Teachers Day','Children''s Day','Cultural Program','Science Exhibition','Field Trip','Parent Meeting','Prize Distribution','Other')),
  description text, event_date date not null, start_time time, end_time time, venue text,
  audience text not null default 'everyone' check (audience in ('everyone','parents','students','teachers','staff')),
  is_public boolean not null default false,
  status text not null default 'draft' check (status in ('draft','published','cancelled')),
  image_path text, created_by uuid references profiles(id) default auth.uid(), created_at timestamptz not null default now(),
  check (end_time is null or start_time is null or end_time > start_time)
);
create index on events (event_date);
alter table events enable row level security;
create policy ev_read on events for select to authenticated using (can_manage_notices() or created_by = auth.uid()
  or (status in ('published','cancelled') and notice_audience_ok(audience, null, null)));
create policy ev_public on events for select to anon using (is_public and status = 'published');
create policy ev_ins on events for insert to authenticated with check (can_manage_notices());
create policy ev_upd on events for update to authenticated using (can_manage_notices()) with check (can_manage_notices());
create policy ev_del on events for delete to authenticated using (is_super_admin());
create function publish_event(p_id uuid) returns void language plpgsql security definer set search_path = public as $$
declare ev events;
begin
  if not can_manage_notices() then raise exception 'not allowed'; end if;
  select * into ev from events where id = p_id for update;
  if not found then raise exception 'not found'; end if;
  if ev.status <> 'draft' then raise exception 'already published'; end if;
  update events set status = 'published' where id = p_id;
  insert into notifications (user_id, title, message, type, related_module, related_record)
  select u.id, ev.title, 'Event on ' || ev.event_date::text || coalesce(' at ' || ev.venue, ''), 'event', 'events', p_id::text from profiles u
  where u.is_active and case ev.audience when 'everyone' then true when 'parents' then u.role = 'parent' when 'students' then u.role = 'student'
    when 'teachers' then u.role in ('teacher','class_teacher') when 'staff' then u.role in ('teacher','class_teacher','accountant','librarian','reception') else false end;
end $$;
revoke all on function publish_event(uuid) from public, anon; grant execute on function publish_event(uuid) to authenticated;

create table activities (
  id uuid primary key default gen_random_uuid(),
  academic_year_id uuid not null references academic_years(id), title text not null,
  category text not null check (category in ('Sports','Cultural','Academic','Drawing','Music','Dance','Science','Quiz','Competition','Community Service','Other')),
  activity_date date not null, division_id uuid references divisions(id), teacher_id uuid references profiles(id) default auth.uid(),
  result text, achievement text, notes text, is_active boolean not null default true, created_at timestamptz not null default now()
);
create table activity_participants (
  id uuid primary key default gen_random_uuid(), activity_id uuid not null references activities(id),
  enrollment_id uuid not null references student_enrollments(id), position text, unique (activity_id, enrollment_id)
);
create index on activity_participants (enrollment_id);
create function can_run_activities() returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(current_role_name() in ('super_admin','school_admin','principal','teacher','class_teacher'), false) $$;
alter table activities enable row level security; alter table activity_participants enable row level security;
create policy ac_read on activities for select to authenticated using (current_role_name() is not null and (is_admin() or teacher_id = auth.uid() or division_id is null
  or teaches_division(division_id) or guardian_of_division(division_id)));
create policy ac_ins on activities for insert to authenticated with check (can_run_activities());
create policy ac_upd on activities for update to authenticated using (can_run_activities() and (teacher_id = auth.uid() or is_admin())) with check (can_run_activities());
create policy ap_read on activity_participants for select to authenticated using (exists (select 1 from activities a where a.id = activity_id)
  and (is_admin() or exists (select 1 from activities a where a.id = activity_id and a.teacher_id = auth.uid())
       or exists (select 1 from student_enrollments e where e.id = enrollment_id and can_view_student(e.student_id))));
create policy ap_ins on activity_participants for insert to authenticated with check (exists (select 1 from activities a where a.id = activity_id and (a.teacher_id = auth.uid() or is_admin())));
create policy ap_upd on activity_participants for update to authenticated using (exists (select 1 from activities a where a.id = activity_id and (a.teacher_id = auth.uid() or is_admin())));
create policy ap_del on activity_participants for delete to authenticated using (exists (select 1 from activities a where a.id = activity_id and (a.teacher_id = auth.uid() or is_admin())));

create table achievements (
  id uuid primary key default gen_random_uuid(),
  subject_type text not null check (subject_type in ('student','teacher')),
  enrollment_id uuid references student_enrollments(id), teacher_id uuid references profiles(id),
  category text not null check (category in ('Sports','Cultural','Academic','Drawing','Music','Dance','Science','Quiz','Competition','Community Service','Other')),
  title text not null, description text, achievement_date date not null, event_name text, position text, certificate_path text,
  approval_status text not null default 'pending' check (approval_status in ('pending','approved','rejected')),
  is_public boolean not null default false, created_by uuid references profiles(id) default auth.uid(), created_at timestamptz not null default now(),
  check ((subject_type = 'student' and enrollment_id is not null) or (subject_type = 'teacher' and teacher_id is not null))
);
create function can_record_achievement() returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(current_role_name() in ('super_admin','school_admin','principal','reception','teacher','class_teacher'), false) $$;
alter table achievements enable row level security;
create policy ach_read on achievements for select to authenticated using (is_admin() or created_by = auth.uid()
  or (approval_status = 'approved' and (teacher_id = auth.uid() or exists (select 1 from student_enrollments e where e.id = enrollment_id and can_view_student(e.student_id)))));
create policy ach_ins on achievements for insert to authenticated with check (can_record_achievement() and (approval_status = 'pending' or is_admin()));
create policy ach_upd on achievements for update to authenticated using (is_admin()) with check (is_admin());
create policy ach_del on achievements for delete to authenticated using (is_super_admin());
-- Public website sees only approved, public achievements, with the student shown as first name and last initial.
create view achievements_public as
  select a.id, a.title, a.category, a.description, a.achievement_date, a.event_name, a.position,
    case when a.subject_type = 'student' then st.first_name || ' ' || left(st.last_name, 1) || '. (' || c.name || ')' else tp.full_name end as who
  from achievements a left join student_enrollments e on e.id = a.enrollment_id left join students st on st.id = e.student_id
    left join divisions d on d.id = e.division_id left join classes c on c.id = d.class_id left join profiles tp on tp.id = a.teacher_id
  where a.approval_status = 'approved' and a.is_public;
grant select on achievements_public to anon, authenticated;

create table gallery_albums (id uuid primary key default gen_random_uuid(), name text not null unique, description text, sort_order int not null default 0, is_active boolean not null default true);
insert into gallery_albums (name, sort_order) values ('School Events',1),('Sports',2),('Annual Day',3),('Cultural',4),('Independence Day',5),('Republic Day',6),('Activities',7),('Infrastructure',8);
create table gallery_images (
  id uuid primary key default gen_random_uuid(), album_id uuid not null references gallery_albums(id),
  title text not null, description text, storage_path text not null unique, event_id uuid references events(id), taken_on date,
  visibility text not null default 'school' check (visibility in ('public','school')),
  approval_status text not null default 'pending' check (approval_status in ('pending','approved','rejected')),
  is_active boolean not null default true, uploaded_by uuid references profiles(id) default auth.uid(), created_at timestamptz not null default now()
);
create index on gallery_images (album_id, created_at desc);
create function can_upload_gallery() returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(current_role_name() in ('super_admin','school_admin','principal','reception','teacher','class_teacher'), false) $$;
alter table gallery_albums enable row level security; alter table gallery_images enable row level security;
create policy ga_read on gallery_albums for select to anon, authenticated using (is_active or is_admin());
create policy ga_write on gallery_albums for all to authenticated using (is_admin()) with check (is_admin());
create policy gi_public on gallery_images for select to anon using (approval_status = 'approved' and visibility = 'public' and is_active);
create policy gi_read on gallery_images for select to authenticated using (is_admin() or uploaded_by = auth.uid()
  or (approval_status = 'approved' and is_active and current_role_name() is not null));
create policy gi_ins on gallery_images for insert to authenticated with check (can_upload_gallery() and (approval_status = 'pending' or is_admin()));
create policy gi_upd on gallery_images for update to authenticated using (is_admin()) with check (is_admin());
create policy gi_del on gallery_images for delete to authenticated using (is_super_admin());

-- Private buckets only. The gallery bucket is readable (through signed links) only for images the caller's role may see,
-- so unapproved or school-only photos can never be opened by the public.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('events','events',false,5242880,array['application/pdf','image/jpeg','image/png']),
  ('achievements','achievements',false,5242880,array['application/pdf','image/jpeg','image/png']),
  ('gallery','gallery',false,3145728,array['image/jpeg','image/png','image/webp']) on conflict (id) do nothing;
create policy ev_files_read on storage.objects for select to authenticated using (bucket_id = 'events' and exists (select 1 from events x where x.image_path = name));
create policy ev_files_write on storage.objects for insert to authenticated with check (bucket_id = 'events' and can_manage_notices());
create policy ach_files_read on storage.objects for select to authenticated using (bucket_id = 'achievements' and exists (select 1 from achievements x where x.certificate_path = name));
create policy ach_files_write on storage.objects for insert to authenticated with check (bucket_id = 'achievements' and can_record_achievement());
create policy gal_files_read on storage.objects for select to anon, authenticated using (bucket_id = 'gallery' and exists (select 1 from gallery_images g where g.storage_path = name));
create policy gal_files_write on storage.objects for insert to authenticated with check (bucket_id = 'gallery' and can_upload_gallery());
-- Phase 9: library, admissions, transport, staff leave, teacher attendance. Run ONCE on your existing project (after update 8).
create function can_manage_library() returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(current_role_name() in ('super_admin','school_admin','librarian'), false) $$;
create function can_front_office() returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(current_role_name() in ('super_admin','school_admin','reception'), false) $$;

-- LIBRARY
create table books (
  id uuid primary key default gen_random_uuid(), book_code text not null unique, isbn text, title text not null, author text, publisher text,
  category text, edition text, quantity int not null default 1 check (quantity >= 0), available_quantity int not null default 1,
  shelf text, price numeric check (price >= 0), status text not null default 'active' check (status in ('active','inactive')),
  check (available_quantity >= 0 and available_quantity <= quantity)
);
create index on books (title);
create table book_transactions (
  id uuid primary key default gen_random_uuid(), book_id uuid not null references books(id),
  borrower_type text not null check (borrower_type in ('student','teacher')),
  enrollment_id uuid references student_enrollments(id), teacher_id uuid references profiles(id),
  issue_date date not null default current_date, due_date date not null, return_date date,
  status text not null default 'issued' check (status in ('issued','returned')), fine numeric not null default 0,
  issued_by uuid references profiles(id) default auth.uid(),
  check ((borrower_type = 'student' and enrollment_id is not null) or (borrower_type = 'teacher' and teacher_id is not null)),
  check (due_date >= issue_date)
);
create index on book_transactions (status, due_date); create index on book_transactions (book_id);
insert into school_settings (key, value, is_public) values ('library_fine_per_day','0',false) on conflict (key) do nothing;
create function book_guard() returns trigger language plpgsql as $$
begin
  if new.quantity <> old.quantity then new.available_quantity = old.available_quantity + (new.quantity - old.quantity);
    if new.available_quantity < 0 then raise exception 'quantity below issued copies'; end if;
  elsif current_user in ('authenticated','anon') and new.available_quantity <> old.available_quantity then raise exception 'available copies are calculated'; end if;
  return new;
end $$;
create trigger books_guard before update on books for each row execute function book_guard();
alter table books enable row level security; alter table book_transactions enable row level security;
create policy bk_read on books for select to authenticated using (current_role_name() is not null);
create policy bk_ins on books for insert to authenticated with check (can_manage_library());
create policy bk_upd on books for update to authenticated using (can_manage_library()) with check (can_manage_library());
create policy bk_del on books for delete to authenticated using (is_super_admin());
create policy bt_read on book_transactions for select to authenticated using (can_manage_library() or current_role_name() = 'principal'
  or teacher_id = auth.uid() or (enrollment_id is not null and is_guardian_of_enrollment(enrollment_id)));
create function issue_book(p_book uuid, p_type text, p_enrollment uuid, p_teacher uuid, p_due date) returns uuid language plpgsql security definer set search_path = public as $$
declare b books; tid uuid;
begin
  if not can_manage_library() then raise exception 'not allowed'; end if;
  if p_due is null or p_due < current_date then raise exception 'invalid due date'; end if;
  select * into b from books where id = p_book for update;
  if not found or b.status <> 'active' then raise exception 'book unavailable'; end if;
  if b.available_quantity <= 0 then raise exception 'no copies available'; end if;
  insert into book_transactions (book_id, borrower_type, enrollment_id, teacher_id, due_date)
    values (p_book, p_type, case when p_type = 'student' then p_enrollment end, case when p_type = 'teacher' then p_teacher end, p_due) returning id into tid;
  update books set available_quantity = available_quantity - 1 where id = p_book;
  return tid;
end $$;
create function return_book(p_tx uuid) returns numeric language plpgsql security definer set search_path = public as $$
declare t book_transactions; f numeric;
begin
  if not can_manage_library() then raise exception 'not allowed'; end if;
  select * into t from book_transactions where id = p_tx for update;
  if not found or t.status <> 'issued' then raise exception 'not issued'; end if;
  f := greatest(0, current_date - t.due_date) * coalesce((select nullif(value,'')::numeric from school_settings where key = 'library_fine_per_day'), 0);
  update book_transactions set status = 'returned', return_date = current_date, fine = f where id = p_tx;
  update books set available_quantity = available_quantity + 1 where id = t.book_id;
  return f;
end $$;
revoke all on function issue_book(uuid,text,uuid,uuid,date), return_book(uuid) from public, anon;
grant execute on function issue_book(uuid,text,uuid,uuid,date), return_book(uuid) to authenticated;

-- ADMISSIONS (public form talks only to submit_enquiry; nobody outside the school can read enquiries)
create sequence enquiry_seq;
create table admission_enquiries (
  id uuid primary key default gen_random_uuid(),
  application_no text not null unique default ('ENQ' || to_char(now(),'YY') || lpad(nextval('enquiry_seq')::text, 5, '0')),
  student_name text not null check (length(student_name) between 3 and 100), dob date not null,
  gender text not null check (gender in ('Male','Female','Other')), applying_class_id uuid references classes(id),
  parent_name text not null check (length(parent_name) between 2 and 100), mobile text not null check (mobile ~ '^[0-9+ -]{8,15}$'),
  email text check (email is null or length(email) <= 120), address text check (length(address) <= 300),
  previous_school text check (length(previous_school) <= 150), previous_class text check (length(previous_class) <= 50), message text check (length(message) <= 1000),
  status text not null default 'new' check (status in ('new','contacted','follow_up','approved','rejected','admission_completed')),
  notes text, student_id uuid references students(id), created_at timestamptz not null default now()
);
create index on admission_enquiries (status, created_at desc);
alter table admission_enquiries enable row level security;
create policy aq_read on admission_enquiries for select to authenticated using (is_admin() or current_role_name() = 'reception');
create policy aq_upd on admission_enquiries for update to authenticated using (can_front_office() or current_role_name() = 'principal') with check (can_front_office() or current_role_name() = 'principal');
create policy aq_del on admission_enquiries for delete to authenticated using (is_super_admin());
create policy cls_public on classes for select to anon using (true);
create function submit_enquiry(p_student_name text, p_dob date, p_gender text, p_class uuid, p_parent text, p_mobile text, p_email text, p_address text, p_prev_school text, p_prev_class text, p_message text)
returns text language plpgsql security definer set search_path = public as $$
declare no text;
begin
  if p_dob is null or p_dob >= current_date then raise exception 'invalid date of birth'; end if;
  if exists (select 1 from admission_enquiries where mobile = trim(p_mobile) and lower(student_name) = lower(trim(p_student_name)) and created_at > now() - interval '24 hours') then raise exception 'duplicate'; end if;
  if (select count(*) from admission_enquiries where mobile = trim(p_mobile) and created_at > now() - interval '24 hours') >= 5 then raise exception 'too many'; end if;
  insert into admission_enquiries (student_name, dob, gender, applying_class_id, parent_name, mobile, email, address, previous_school, previous_class, message)
  values (trim(p_student_name), p_dob, p_gender, p_class, trim(p_parent), trim(p_mobile), nullif(trim(p_email),''), nullif(trim(p_address),''), nullif(trim(p_prev_school),''), nullif(trim(p_prev_class),''), nullif(trim(p_message),''))
  returning application_no into no;
  return no;
end $$;
revoke all on function submit_enquiry(text,date,text,uuid,text,text,text,text,text,text,text) from public;
grant execute on function submit_enquiry(text,date,text,uuid,text,text,text,text,text,text,text) to anon, authenticated;
create function convert_enquiry(p_id uuid, p_admission_no text, p_division uuid, p_roll int) returns uuid language plpgsql security definer set search_path = public as $$
declare q admission_enquiries; parts text[]; fn text; mn text; ln text; sid uuid; ay uuid; n int;
begin
  if not can_front_office() then raise exception 'not allowed'; end if;
  select * into q from admission_enquiries where id = p_id for update;
  if not found then raise exception 'not found'; end if;
  if q.status <> 'approved' then raise exception 'enquiry not approved'; end if;
  if q.student_id is not null then raise exception 'already converted'; end if;
  select academic_year_id into ay from divisions where id = p_division;
  if not found then raise exception 'invalid division'; end if;
  parts := regexp_split_to_array(trim(q.student_name), '\s+'); n := array_length(parts, 1);
  fn := parts[1]; ln := case when n > 1 then parts[n] else '-' end; mn := case when n > 2 then array_to_string(parts[2:n-1], ' ') end;
  if exists (select 1 from students where lower(first_name) = lower(fn) and lower(last_name) = lower(ln) and dob = q.dob) then raise exception 'possible duplicate student'; end if;
  insert into students (admission_no, first_name, middle_name, last_name, gender, dob, previous_school, previous_class, admission_class)
    values (trim(p_admission_no), fn, mn, ln, q.gender, q.dob, q.previous_school, q.previous_class, (select name from classes where id = q.applying_class_id)) returning id into sid;
  insert into student_guardians (student_id, relation, name, mobile, email, address) values (sid, 'guardian', q.parent_name, q.mobile, q.email, q.address);
  insert into student_enrollments (student_id, academic_year_id, division_id, roll_no) values (sid, ay, p_division, p_roll);
  update admission_enquiries set student_id = sid, status = 'admission_completed' where id = p_id;
  return sid;
end $$;
revoke all on function convert_enquiry(uuid,text,uuid,int) from public, anon; grant execute on function convert_enquiry(uuid,text,uuid,int) to authenticated;

-- TRANSPORT
create function can_manage_transport() returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(current_role_name() in ('super_admin','school_admin','principal','reception'), false) $$;
create table transport_routes (
  id uuid primary key default gen_random_uuid(), name text not null unique, vehicle_no text, driver_name text, driver_contact text,
  pickup_time time, drop_time time, status text not null default 'active' check (status in ('active','inactive'))
);
create table transport_stops (id uuid primary key default gen_random_uuid(), route_id uuid not null references transport_routes(id), name text not null, stop_order int not null default 1, unique (route_id, name));
create table transport_assignments (
  id uuid primary key default gen_random_uuid(), enrollment_id uuid not null references student_enrollments(id),
  route_id uuid not null references transport_routes(id), stop_id uuid references transport_stops(id),
  start_date date not null default current_date, end_date date, status text not null default 'active' check (status in ('active','inactive')),
  check (end_date is null or end_date >= start_date)
);
create unique index transport_one_active on transport_assignments (enrollment_id) where status = 'active';
alter table transport_routes enable row level security; alter table transport_stops enable row level security; alter table transport_assignments enable row level security;
create policy tr_read on transport_routes for select to authenticated using (can_manage_transport() or exists (select 1 from transport_assignments a where a.route_id = id and a.status = 'active' and is_guardian_of_enrollment(a.enrollment_id)));
create policy tr_write on transport_routes for all to authenticated using (can_front_office()) with check (can_front_office());
create policy ts_read on transport_stops for select to authenticated using (can_manage_transport() or exists (select 1 from transport_assignments a where a.route_id = route_id and a.status = 'active' and is_guardian_of_enrollment(a.enrollment_id)));
create policy ts_write on transport_stops for all to authenticated using (can_front_office()) with check (can_front_office());
create policy ta_read on transport_assignments for select to authenticated using (can_manage_transport() or is_guardian_of_enrollment(enrollment_id));
create policy ta_write on transport_assignments for all to authenticated using (can_front_office()) with check (can_front_office());

-- STAFF LEAVE and TEACHER ATTENDANCE
alter table staff add column if not exists profile_id uuid references profiles(id);
create unique index if not exists teachers_profile_uq on teachers (profile_id) where profile_id is not null;
create unique index if not exists staff_profile_uq on staff (profile_id) where profile_id is not null;
create function is_my_employee(tid uuid, sid uuid) returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from teachers where id = tid and profile_id = auth.uid()) or exists (select 1 from staff where id = sid and profile_id = auth.uid()) $$;
create table leave_requests (
  id uuid primary key default gen_random_uuid(), teacher_id uuid references teachers(id), staff_id uuid references staff(id),
  leave_type text not null check (leave_type in ('casual','sick','earned','maternity','unpaid','other')),
  start_date date not null, end_date date not null, reason text check (length(reason) <= 500), applied_date date not null default current_date,
  status text not null default 'pending' check (status in ('pending','approved','rejected','cancelled')),
  approved_by uuid references profiles(id), remarks text, created_at timestamptz not null default now(),
  check (end_date >= start_date), check ((teacher_id is not null) <> (staff_id is not null))
);
create index on leave_requests (status, start_date);
alter table leave_requests enable row level security;
create policy lv_read on leave_requests for select to authenticated using (is_admin() or current_role_name() = 'reception' or is_my_employee(teacher_id, staff_id));
create policy lv_ins on leave_requests for insert to authenticated with check (status = 'pending' and (is_admin() or current_role_name() = 'reception' or is_my_employee(teacher_id, staff_id)));
create function set_leave_status(p_id uuid, p_status text, p_remarks text) returns void language plpgsql security definer set search_path = public as $$
declare l leave_requests; applicant uuid;
begin
  select * into l from leave_requests where id = p_id for update;
  if not found or l.status <> 'pending' then raise exception 'not pending'; end if;
  if p_status in ('approved','rejected') then
    if not (is_admin()) then raise exception 'not allowed'; end if;
  elsif p_status = 'cancelled' then
    if not (is_admin() or is_my_employee(l.teacher_id, l.staff_id)) then raise exception 'not allowed'; end if;
  else raise exception 'invalid status'; end if;
  update leave_requests set status = p_status, remarks = p_remarks, approved_by = case when p_status in ('approved','rejected') then auth.uid() end where id = p_id;
  select coalesce((select profile_id from teachers where id = l.teacher_id), (select profile_id from staff where id = l.staff_id)) into applicant;
  if applicant is not null and p_status in ('approved','rejected') then
    insert into notifications (user_id, title, message, type, related_module, related_record)
    values (applicant, 'Leave ' || p_status, l.start_date::text || ' to ' || l.end_date::text, 'announcement', 'leave', p_id::text);
  end if;
end $$;
revoke all on function set_leave_status(uuid,text,text) from public, anon; grant execute on function set_leave_status(uuid,text,text) to authenticated;

create table teacher_attendance (
  id uuid primary key default gen_random_uuid(), teacher_id uuid not null references teachers(id), att_date date not null,
  status text not null check (status in ('present','absent','late','half_day','leave')), remarks text,
  marked_by uuid references profiles(id), updated_at timestamptz not null default now(), unique (teacher_id, att_date)
);
create index on teacher_attendance (att_date);
create function teacher_att_guard() returns trigger language plpgsql as $$
begin
  if exists (select 1 from school_calendar where day = new.att_date and kind in ('holiday','vacation')) then raise exception 'holiday: attendance cannot be marked'; end if;
  new.updated_at = now(); new.marked_by = auth.uid(); return new;
end $$;
create trigger tatt_guard before insert or update on teacher_attendance for each row execute function teacher_att_guard();
alter table teacher_attendance enable row level security;
create policy ta2_read on teacher_attendance for select to authenticated using (is_admin() or current_role_name() = 'reception' or exists (select 1 from teachers t where t.id = teacher_id and t.profile_id = auth.uid()));
create policy ta2_ins on teacher_attendance for insert to authenticated with check (can_front_office());
create policy ta2_upd on teacher_attendance for update to authenticated using (can_front_office()) with check (can_front_office());
-- Phase 10: portals. Run ONCE on your existing project (after update 9).
-- 1) Students can have their own login. 2) Students see only their own records. 3) Accountant and librarian can see student names (needed for fees and library).
alter table students add column if not exists user_id uuid references profiles(id);
create unique index if not exists students_user_uq on students (user_id) where user_id is not null;

create or replace function can_view_student(sid uuid) returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(current_role_name() in ('super_admin','school_admin','principal','reception'), false)
  or exists (select 1 from student_guardians g where g.student_id = sid and g.user_id = auth.uid())
  or exists (select 1 from students s where s.id = sid and s.user_id = auth.uid())
  or exists (select 1 from student_enrollments e join divisions d on d.id = e.division_id
      where e.student_id = sid and (d.class_teacher_id = auth.uid()
        or exists (select 1 from class_subjects cs where cs.division_id = d.id and cs.teacher_id = auth.uid()))) $$;
create or replace function guardian_of_division(did uuid) returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from student_enrollments e join student_guardians g on g.student_id = e.student_id
    where e.division_id = did and g.user_id = auth.uid() and e.status = 'active')
  or exists (select 1 from student_enrollments e join students s on s.id = e.student_id
    where e.division_id = did and s.user_id = auth.uid() and e.status = 'active') $$;

-- Accountant and librarian need names and classes to work with fees and the library. They still cannot see attendance, marks or parent details.
create policy st_fin on students for select to authenticated using (current_role_name() in ('accountant','librarian'));
create policy se_fin on student_enrollments for select to authenticated using (current_role_name() in ('accountant','librarian'));

create or replace function linkable_users() returns table (id uuid, full_name text, role user_role) language sql stable security definer set search_path = public as $$
  select p.id, p.full_name, p.role from profiles p where can_edit_students() and p.is_active and p.role in ('parent','student') order by p.full_name $$;
revoke all on function linkable_users() from public, anon; grant execute on function linkable_users() to authenticated;

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

-- Phase 12: final hardening, speed and gallery thumbnails. Run ONCE after Phase 11. Nothing is deleted.

------------------------------------------------------------------ 1. Public visitors may call only the functions the public site needs
do $$
declare f record; had boolean;
begin
  for f in
    select p.oid, p.oid::regprocedure as sig, p.proname
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prokind = 'f' and p.prorettype <> 'trigger'::regtype
      and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')   -- skip functions owned by extensions
  loop
    had := has_function_privilege('authenticated', f.oid, 'execute');   -- keep signed-in access exactly as it is; never widen it
    execute format('revoke execute on function %s from public, anon', f.sig);
    if had then execute format('grant execute on function %s to authenticated', f.sig); end if;
    if f.proname in ('submit_enquiry', 'is_admin', 'can_upload_gallery') then
      execute format('grant execute on function %s to anon', f.sig);   -- needed by the public enquiry form and the public gallery rules
    end if;
  end loop;
end $$;

------------------------------------------------------------------ 2. Public gallery: do not reveal the names of albums that hold no public photo
drop policy if exists ga_read on gallery_albums;
create policy ga_read on gallery_albums for select to anon, authenticated using (
  is_admin() or can_upload_gallery()
  or (is_active and exists (select 1 from gallery_images i where i.album_id = gallery_albums.id)));   -- the inner check obeys the caller's own photo permissions

------------------------------------------------------------------ 3. Gallery thumbnails (small copy of each photo for fast pages)
alter table gallery_images add column if not exists thumb_path text;
drop policy if exists gal_files_read on storage.objects;
create policy gal_files_read on storage.objects for select to anon, authenticated using (
  bucket_id = 'gallery' and exists (select 1 from gallery_images g where g.storage_path = objects.name or g.thumb_path = objects.name));

------------------------------------------------------------------ 4. Admission form: overall flood limit and field lengths (protects the free database)
create or replace function enquiry_guard() returns trigger language plpgsql as $$
begin
  if (select count(*) from admission_enquiries where created_at > now() - interval '1 hour') >= 100 then
    raise exception 'too many enquiries right now'; end if;
  if length(new.student_name) > 120 or length(new.parent_name) > 120 or length(coalesce(new.address, '')) > 400
     or length(coalesce(new.message, '')) > 2000 or length(coalesce(new.previous_school, '')) > 200 or length(coalesce(new.email, '')) > 150 then
    raise exception 'text too long'; end if;
  return new;
end $$;
drop trigger if exists enquiry_guard_trg on admission_enquiries;
create trigger enquiry_guard_trg before insert on admission_enquiries for each row execute function enquiry_guard();

------------------------------------------------------------------ 5. Indexes for the screens that filter by these columns
create index if not exists class_subjects_division_idx on class_subjects (division_id);
create index if not exists class_subjects_teacher_idx on class_subjects (teacher_id);
create index if not exists class_subjects_subject_idx on class_subjects (subject_id);
create index if not exists divisions_class_idx on divisions (class_id);
create index if not exists divisions_class_teacher_idx on divisions (class_teacher_id);
create index if not exists enrollments_division_idx on student_enrollments (division_id);
create index if not exists exam_subjects_division_idx on exam_subjects (division_id);
create index if not exists exam_subjects_subject_idx on exam_subjects (subject_id);
create index if not exists timetable_division_idx on timetable_slots (division_id);
create index if not exists timetable_teacher_idx on timetable_slots (teacher_id);
create index if not exists homework_teacher_idx on homework (teacher_id);
create index if not exists homework_subject_idx on homework (subject_id);
create index if not exists notices_class_idx on notices (class_id);
create index if not exists notices_division_idx on notices (division_id);
create index if not exists book_tx_enrollment_idx on book_transactions (enrollment_id);
create index if not exists book_tx_teacher_idx on book_transactions (teacher_id);
create index if not exists fee_structures_class_idx on fee_structures (class_id);
create index if not exists fee_structures_type_idx on fee_structures (fee_type_id);
create index if not exists student_fees_type_idx on student_fees (fee_type_id);
create index if not exists transport_assign_route_idx on transport_assignments (route_id);
create index if not exists leave_teacher_idx on leave_requests (teacher_id);
create index if not exists leave_staff_idx on leave_requests (staff_id);
create index if not exists activities_division_idx on activities (division_id);
create index if not exists report_remarks_enrollment_idx on report_remarks (enrollment_id);
create index if not exists achievements_enrollment_idx on achievements (enrollment_id);
create index if not exists enquiries_class_idx on admission_enquiries (applying_class_id);
create index if not exists enquiries_created_idx on admission_enquiries (created_at desc);

-- Phase 13 (gaps vs master prompt)
-- Phase 13: closes small gaps against the master prompt. Safe to run more than once. Nothing is deleted.
alter table notices add column if not exists notice_type text not null default 'General';
do $$ begin
  alter table notices add constraint notices_type_chk check (notice_type in ('General','Holiday','Exam','Fee','Parent','Student','Teacher','Emergency'));
exception when duplicate_object then null; end $$;
alter table teachers add column if not exists photo_path text;

-- Phase 14 (certificates, fee reminders, birthdays)
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

-- Phase 15 (UPI claims, leave policy, teacher diary)
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

-- Phase 16 (absence alerts to parents)
-- Phase 16 (round 3): absence alerts to parents. Safe to run more than once. Nothing is deleted.
-- When a student is marked absent for today (or the last 2 days), every linked parent login gets a notification.
create or replace function notify_absence() returns trigger language plpgsql security definer set search_path = public as $$
declare nm text; cls text; dt text;
begin
  if new.status <> 'absent' or new.att_date < current_date - 2 then return new; end if;
  if tg_op = 'UPDATE' and old.status = 'absent' then return new; end if;
  select trim(concat_ws(' ', s.first_name, s.last_name)), c.name || ' - ' || d.name into nm, cls
    from student_enrollments e join students s on s.id = e.student_id join divisions d on d.id = e.division_id join classes c on c.id = d.class_id
    where e.id = new.enrollment_id;
  if nm is null then return new; end if;
  dt := to_char(new.att_date, 'DD-MM-YYYY');
  begin
  insert into notifications (user_id, title, message, type, related_module, related_record)
  select distinct g.user_id, 'Absent: ' || nm, nm || ' (' || cls || ') was marked absent on ' || dt || '. If this is not expected, please contact the school. / '
         || nm || ' (' || cls || ') हे ' || dt || ' रोजी गैरहजर होते. हे अपेक्षित नसल्यास कृपया शाळेशी संपर्क साधा.', 'notice', 'attendance', new.id::text
  from student_guardians g join profiles p on p.id = g.user_id and p.is_active
  where g.student_id = (select student_id from student_enrollments where id = new.enrollment_id) and g.user_id is not null
    and not exists (select 1 from notifications n where n.user_id = g.user_id and n.related_module = 'attendance' and n.related_record = new.id::text);
  exception when others then null; -- attendance must never fail because of a notification problem
  end;
  return new;
end $$;
-- Principal is an admin everywhere else; allow marking attendance too (was missing, caused "Could not save").
create or replace function can_mark_attendance(eid uuid) returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(current_role_name() in ('super_admin','school_admin','principal'), false)
  or exists (select 1 from student_enrollments e join divisions d on d.id = e.division_id where e.id = eid
      and (d.class_teacher_id = auth.uid() or exists (select 1 from class_subjects cs where cs.division_id = d.id and cs.teacher_id = auth.uid()))) $$;
revoke all on function notify_absence() from public, anon, authenticated;
drop trigger if exists attendance_absence_notify on attendance;
create trigger attendance_absence_notify after insert or update of status on attendance for each row execute function notify_absence();


-- Phase 17 (round 4): live bus tracking. Safe to run more than once. Nothing is deleted.
-- Driver phone sends GPS using a secret per-bus link (no login). Parents see only their own child's bus.
alter table transport_stops add column if not exists lat double precision;
alter table transport_stops add column if not exists lng double precision;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'transport_stops_latlng_chk') then
    alter table transport_stops add constraint transport_stops_latlng_chk check ((lat is null and lng is null) or (lat between -90 and 90 and lng between -180 and 180 and lat is not null and lng is not null));
  end if;
end $$;

create table if not exists transport_driver_keys (
  route_id uuid primary key references transport_routes(id) on delete cascade,
  token text not null unique default replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''),
  created_at timestamptz not null default now()
);
alter table transport_driver_keys enable row level security;
drop policy if exists tdk_all on transport_driver_keys;
create policy tdk_all on transport_driver_keys for all to authenticated using (can_front_office()) with check (can_front_office());
insert into transport_driver_keys (route_id) select id from transport_routes on conflict do nothing;
create or replace function make_driver_key() returns trigger language plpgsql security definer set search_path = public as $$
begin insert into transport_driver_keys (route_id) values (new.id) on conflict do nothing; return new; end $$;
drop trigger if exists route_driver_key on transport_routes;
create trigger route_driver_key after insert on transport_routes for each row execute function make_driver_key();

create table if not exists bus_live (
  route_id uuid primary key references transport_routes(id) on delete cascade,
  lat double precision, lng double precision, speed_kmh real, heading real, accuracy_m real,
  trip text check (trip in ('pickup','drop')), trip_active boolean not null default false,
  started_at timestamptz, updated_at timestamptz not null default now()
);
alter table bus_live enable row level security;
drop policy if exists bl_read on bus_live;
create policy bl_read on bus_live for select to authenticated using (
  can_manage_transport() or exists (select 1 from transport_assignments a where a.route_id = bus_live.route_id and a.status = 'active' and is_guardian_of_enrollment(a.enrollment_id)));

create table if not exists bus_alerts (
  assignment_id uuid not null references transport_assignments(id) on delete cascade, alert_date date not null default current_date,
  trip text not null, kind text not null check (kind in ('near','start')), primary key (assignment_id, alert_date, trip, kind)
);
alter table bus_alerts enable row level security;

create or replace function haversine_m(a_lat double precision, a_lng double precision, b_lat double precision, b_lng double precision) returns double precision language sql immutable as $$
  select 2 * 6371000 * asin(sqrt(power(sin(radians(b_lat - a_lat) / 2), 2) + cos(radians(a_lat)) * cos(radians(b_lat)) * power(sin(radians(b_lng - a_lng) / 2), 2))) $$;

-- Admin: make a new secret link for one bus (old link stops working at once).
create or replace function reset_driver_key(p_route uuid) returns text language plpgsql security definer set search_path = public as $$
declare t text := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
begin
  if not can_front_office() then raise exception 'not allowed'; end if;
  insert into transport_driver_keys (route_id, token) values (p_route, t) on conflict (route_id) do update set token = excluded.token, created_at = now();
  return t;
end $$;
revoke all on function reset_driver_key(uuid) from public, anon;
grant execute on function reset_driver_key(uuid) to authenticated;

-- Driver phone: p_action = info | start | ping | end. Works with the secret token only.
create or replace function driver_ping(p_token text, p_action text default 'ping', p_trip text default null, p_lat double precision default null,
  p_lng double precision default null, p_speed real default null, p_heading real default null, p_acc real default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare rid uuid; rn text; vn text; b bus_live%rowtype; st record; d double precision;
begin
  if p_token is null or length(p_token) < 32 then return jsonb_build_object('ok', false, 'error', 'bad_key'); end if;
  select k.route_id, r.name, r.vehicle_no into rid, rn, vn from transport_driver_keys k join transport_routes r on r.id = k.route_id where k.token = p_token and r.status = 'active';
  if rid is null then return jsonb_build_object('ok', false, 'error', 'bad_key'); end if;
  select * into b from bus_live where route_id = rid;
  if p_action = 'info' then
    return jsonb_build_object('ok', true, 'route', rn, 'vehicle', vn, 'active', coalesce(b.trip_active, false), 'trip', b.trip);
  end if;
  if p_action = 'end' then
    update bus_live set trip_active = false, updated_at = now() where route_id = rid;
    return jsonb_build_object('ok', true, 'route', rn, 'active', false);
  end if;
  if p_lat is null or p_lng is null or p_lat not between -90 and 90 or p_lng not between -180 and 180 then return jsonb_build_object('ok', false, 'error', 'bad_position'); end if;
  if p_action = 'start' then
    if p_trip not in ('pickup','drop') then return jsonb_build_object('ok', false, 'error', 'bad_trip'); end if;
    insert into bus_live (route_id, lat, lng, speed_kmh, heading, accuracy_m, trip, trip_active, started_at, updated_at)
      values (rid, p_lat, p_lng, p_speed, p_heading, p_acc, p_trip, true, now(), now())
      on conflict (route_id) do update set lat = excluded.lat, lng = excluded.lng, speed_kmh = excluded.speed_kmh, heading = excluded.heading,
        accuracy_m = excluded.accuracy_m, trip = excluded.trip, trip_active = true, started_at = now(), updated_at = now();
    begin
      insert into bus_alerts (assignment_id, trip, kind) select a.id, p_trip, 'start' from transport_assignments a where a.route_id = rid and a.status = 'active' on conflict do nothing;
      insert into notifications (user_id, title, message, type, related_module, related_record)
      select distinct g.user_id, 'Bus started: ' || rn,
        case p_trip when 'pickup' then 'The school bus (' || rn || ') has started the morning pickup. You can track it live. / स्कूल बस सकाळच्या फेरीसाठी निघाली आहे. आपण ती लाइव्ह पाहू शकता.'
                    else 'The school bus (' || rn || ') has started the drop trip. You can track it live. / स्कूल बस घरी सोडण्यासाठी निघाली आहे. आपण ती लाइव्ह पाहू शकता.' end,
        'notice', 'transport', rid::text
      from transport_assignments a join student_enrollments e on e.id = a.enrollment_id join student_guardians g on g.student_id = e.student_id
      join profiles p on p.id = g.user_id and p.is_active
      where a.route_id = rid and a.status = 'active' and g.user_id is not null
        and not exists (select 1 from notifications n where n.user_id = g.user_id and n.related_module = 'transport' and n.related_record = rid::text and n.title like 'Bus started:%' and n.created_at::date = current_date and n.message like case p_trip when 'pickup' then '%morning pickup%' else '%drop trip%' end);
    exception when others then null; end;
    return jsonb_build_object('ok', true, 'route', rn, 'active', true, 'trip', p_trip);
  end if;
  -- ping
  if b.route_id is null or not b.trip_active then return jsonb_build_object('ok', false, 'error', 'no_trip'); end if;
  if b.updated_at > now() - interval '4 seconds' then return jsonb_build_object('ok', true, 'skipped', true); end if;
  update bus_live set lat = p_lat, lng = p_lng, speed_kmh = p_speed, heading = p_heading, accuracy_m = p_acc, updated_at = now() where route_id = rid;
  begin
    for st in select a.id as aid, s.name as sname, s.lat as slat, s.lng as slng, e.student_id from transport_assignments a join transport_stops s on s.id = a.stop_id
             join student_enrollments e on e.id = a.enrollment_id where a.route_id = rid and a.status = 'active' and s.lat is not null loop
      d := haversine_m(p_lat, p_lng, st.slat, st.slng);
      if d <= 500 and not exists (select 1 from bus_alerts x where x.assignment_id = st.aid and x.alert_date = current_date and x.trip = b.trip and x.kind = 'near') then
        insert into bus_alerts (assignment_id, trip, kind) values (st.aid, b.trip, 'near') on conflict do nothing;
        insert into notifications (user_id, title, message, type, related_module, related_record)
        select distinct g.user_id, 'Bus is near: ' || st.sname,
          'The school bus is about ' || greatest(round(d / 50) * 50, 50)::int || ' m from the stop "' || st.sname || '". Please be ready. / स्कूल बस "' || st.sname || '" थांब्यापासून सुमारे ' || greatest(round(d / 50) * 50, 50)::int || ' मीटरवर आहे. कृपया तयार रहा.',
          'notice', 'transport', rid::text
        from student_guardians g join profiles p on p.id = g.user_id and p.is_active where g.student_id = st.student_id and g.user_id is not null;
      end if;
    end loop;
  exception when others then null; end;
  return jsonb_build_object('ok', true);
end $$;
revoke all on function driver_ping(text, text, text, double precision, double precision, real, real, real) from public;
grant execute on function driver_ping(text, text, text, double precision, double precision, real, real, real) to anon, authenticated;



-- Phase 17 (round 4): live bus tracking. Safe to run more than once. Nothing is deleted.
-- Driver phone sends GPS using a secret per-bus link (no login). Parents see only their own child's bus.
alter table transport_stops add column if not exists lat double precision;
alter table transport_stops add column if not exists lng double precision;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'transport_stops_latlng_chk') then
    alter table transport_stops add constraint transport_stops_latlng_chk check ((lat is null and lng is null) or (lat between -90 and 90 and lng between -180 and 180 and lat is not null and lng is not null));
  end if;
end $$;

create table if not exists transport_driver_keys (
  route_id uuid primary key references transport_routes(id) on delete cascade,
  token text not null unique default replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''),
  created_at timestamptz not null default now()
);
alter table transport_driver_keys enable row level security;
drop policy if exists tdk_all on transport_driver_keys;
create policy tdk_all on transport_driver_keys for all to authenticated using (can_front_office()) with check (can_front_office());
insert into transport_driver_keys (route_id) select id from transport_routes on conflict do nothing;
create or replace function make_driver_key() returns trigger language plpgsql security definer set search_path = public as $$
begin insert into transport_driver_keys (route_id) values (new.id) on conflict do nothing; return new; end $$;
drop trigger if exists route_driver_key on transport_routes;
create trigger route_driver_key after insert on transport_routes for each row execute function make_driver_key();

create table if not exists bus_live (
  route_id uuid primary key references transport_routes(id) on delete cascade,
  lat double precision, lng double precision, speed_kmh real, heading real, accuracy_m real,
  trip text check (trip in ('pickup','drop')), trip_active boolean not null default false,
  started_at timestamptz, updated_at timestamptz not null default now()
);
alter table bus_live enable row level security;
drop policy if exists bl_read on bus_live;
create policy bl_read on bus_live for select to authenticated using (
  can_manage_transport() or exists (select 1 from transport_assignments a where a.route_id = bus_live.route_id and a.status = 'active' and is_guardian_of_enrollment(a.enrollment_id)));

create table if not exists bus_alerts (
  assignment_id uuid not null references transport_assignments(id) on delete cascade, alert_date date not null default current_date,
  trip text not null, kind text not null check (kind in ('near','start')), primary key (assignment_id, alert_date, trip, kind)
);
alter table bus_alerts enable row level security;

create or replace function haversine_m(a_lat double precision, a_lng double precision, b_lat double precision, b_lng double precision) returns double precision language sql immutable as $$
  select 2 * 6371000 * asin(sqrt(power(sin(radians(b_lat - a_lat) / 2), 2) + cos(radians(a_lat)) * cos(radians(b_lat)) * power(sin(radians(b_lng - a_lng) / 2), 2))) $$;

-- Admin: make a new secret link for one bus (old link stops working at once).
create or replace function reset_driver_key(p_route uuid) returns text language plpgsql security definer set search_path = public as $$
declare t text := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
begin
  if not can_front_office() then raise exception 'not allowed'; end if;
  insert into transport_driver_keys (route_id, token) values (p_route, t) on conflict (route_id) do update set token = excluded.token, created_at = now();
  return t;
end $$;
revoke all on function reset_driver_key(uuid) from public, anon;
grant execute on function reset_driver_key(uuid) to authenticated;

-- Driver phone: p_action = info | start | ping | end. Works with the secret token only.
create or replace function driver_ping(p_token text, p_action text default 'ping', p_trip text default null, p_lat double precision default null,
  p_lng double precision default null, p_speed real default null, p_heading real default null, p_acc real default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare rid uuid; rn text; vn text; b bus_live%rowtype; st record; d double precision;
begin
  if p_token is null or length(p_token) < 32 then return jsonb_build_object('ok', false, 'error', 'bad_key'); end if;
  select k.route_id, r.name, r.vehicle_no into rid, rn, vn from transport_driver_keys k join transport_routes r on r.id = k.route_id where k.token = p_token and r.status = 'active';
  if rid is null then return jsonb_build_object('ok', false, 'error', 'bad_key'); end if;
  select * into b from bus_live where route_id = rid;
  if p_action = 'info' then
    return jsonb_build_object('ok', true, 'route', rn, 'vehicle', vn, 'active', coalesce(b.trip_active, false), 'trip', b.trip);
  end if;
  if p_action = 'end' then
    update bus_live set trip_active = false, updated_at = now() where route_id = rid;
    return jsonb_build_object('ok', true, 'route', rn, 'active', false);
  end if;
  if p_lat is null or p_lng is null or p_lat not between -90 and 90 or p_lng not between -180 and 180 then return jsonb_build_object('ok', false, 'error', 'bad_position'); end if;
  if p_action = 'start' then
    if p_trip not in ('pickup','drop') then return jsonb_build_object('ok', false, 'error', 'bad_trip'); end if;
    insert into bus_live (route_id, lat, lng, speed_kmh, heading, accuracy_m, trip, trip_active, started_at, updated_at)
      values (rid, p_lat, p_lng, p_speed, p_heading, p_acc, p_trip, true, now(), now())
      on conflict (route_id) do update set lat = excluded.lat, lng = excluded.lng, speed_kmh = excluded.speed_kmh, heading = excluded.heading,
        accuracy_m = excluded.accuracy_m, trip = excluded.trip, trip_active = true, started_at = now(), updated_at = now();
    begin
      insert into bus_alerts (assignment_id, trip, kind) select a.id, p_trip, 'start' from transport_assignments a where a.route_id = rid and a.status = 'active' on conflict do nothing;
      insert into notifications (user_id, title, message, type, related_module, related_record)
      select distinct g.user_id, 'Bus started: ' || rn,
        case p_trip when 'pickup' then 'The school bus (' || rn || ') has started the morning pickup. You can track it live. / स्कूल बस सकाळच्या फेरीसाठी निघाली आहे. आपण ती लाइव्ह पाहू शकता.'
                    else 'The school bus (' || rn || ') has started the drop trip. You can track it live. / स्कूल बस घरी सोडण्यासाठी निघाली आहे. आपण ती लाइव्ह पाहू शकता.' end,
        'notice', 'transport', rid::text
      from transport_assignments a join student_enrollments e on e.id = a.enrollment_id join student_guardians g on g.student_id = e.student_id
      join profiles p on p.id = g.user_id and p.is_active
      where a.route_id = rid and a.status = 'active' and g.user_id is not null
        and not exists (select 1 from notifications n where n.user_id = g.user_id and n.related_module = 'transport' and n.related_record = rid::text and n.title like 'Bus started:%' and n.created_at::date = current_date and n.message like case p_trip when 'pickup' then '%morning pickup%' else '%drop trip%' end);
    exception when others then null; end;
    return jsonb_build_object('ok', true, 'route', rn, 'active', true, 'trip', p_trip);
  end if;
  -- ping
  if b.route_id is null or not b.trip_active then return jsonb_build_object('ok', false, 'error', 'no_trip'); end if;
  if b.updated_at > now() - interval '4 seconds' then return jsonb_build_object('ok', true, 'skipped', true); end if;
  update bus_live set lat = p_lat, lng = p_lng, speed_kmh = p_speed, heading = p_heading, accuracy_m = p_acc, updated_at = now() where route_id = rid;
  begin
    for st in select a.id as aid, s.name as sname, s.lat as slat, s.lng as slng, e.student_id from transport_assignments a join transport_stops s on s.id = a.stop_id
             join student_enrollments e on e.id = a.enrollment_id where a.route_id = rid and a.status = 'active' and s.lat is not null loop
      d := haversine_m(p_lat, p_lng, st.slat, st.slng);
      if d <= 500 and not exists (select 1 from bus_alerts x where x.assignment_id = st.aid and x.alert_date = current_date and x.trip = b.trip and x.kind = 'near') then
        insert into bus_alerts (assignment_id, trip, kind) values (st.aid, b.trip, 'near') on conflict do nothing;
        insert into notifications (user_id, title, message, type, related_module, related_record)
        select distinct g.user_id, 'Bus is near: ' || st.sname,
          'The school bus is about ' || greatest(round(d / 50) * 50, 50)::int || ' m from the stop "' || st.sname || '". Please be ready. / स्कूल बस "' || st.sname || '" थांब्यापासून सुमारे ' || greatest(round(d / 50) * 50, 50)::int || ' मीटरवर आहे. कृपया तयार रहा.',
          'notice', 'transport', rid::text
        from student_guardians g join profiles p on p.id = g.user_id and p.is_active where g.student_id = st.student_id and g.user_id is not null;
      end if;
    end loop;
  exception when others then null; end;
  return jsonb_build_object('ok', true);
end $$;
revoke all on function driver_ping(text, text, text, double precision, double precision, real, real, real) from public;
grant execute on function driver_ping(text, text, text, double precision, double precision, real, real, real) to anon, authenticated;
select 'phase17 finished' as result;

-- Phase 18 (round 5A): bus boarding scan, photo uploads, student insights. Safe to run more than once. Nothing is deleted.

-- 1) Bus boarding: driver scans the student's ID card QR. Pickup trip = "boarded", drop trip = "got off". Parents get a notification.
create table if not exists bus_boarding (
  id uuid primary key default gen_random_uuid(), route_id uuid not null references transport_routes(id) on delete cascade,
  enrollment_id uuid not null references student_enrollments(id) on delete cascade,
  trip text not null check (trip in ('pickup','drop')), event text not null check (event in ('board','alight')),
  event_date date not null default current_date, at timestamptz not null default now(),
  unique (enrollment_id, event_date, trip, event)
);
create index if not exists bus_boarding_route_day on bus_boarding (route_id, event_date);
alter table bus_boarding enable row level security;
drop policy if exists bb_read on bus_boarding;
create policy bb_read on bus_boarding for select to authenticated using (can_manage_transport() or is_guardian_of_enrollment(enrollment_id));

create or replace function driver_board(p_token text, p_admission text) returns jsonb language plpgsql security definer set search_path = public as $$
declare rid uuid; rn text; b bus_live%rowtype; eid uuid; sid uuid; fn text; ev text; ins int; total int; done int; tm text;
begin
  if p_token is null or length(p_token) < 32 or p_admission is null or length(p_admission) > 40 then return jsonb_build_object('ok', false, 'error', 'bad_request'); end if;
  select k.route_id, r.name into rid, rn from transport_driver_keys k join transport_routes r on r.id = k.route_id where k.token = p_token and r.status = 'active';
  if rid is null then return jsonb_build_object('ok', false, 'error', 'bad_key'); end if;
  select * into b from bus_live where route_id = rid;
  if b.route_id is null or not b.trip_active then return jsonb_build_object('ok', false, 'error', 'no_trip'); end if;
  select e.id, s.id, s.first_name into eid, sid, fn
    from students s join student_enrollments e on e.student_id = s.id and e.status = 'active'
    join transport_assignments a on a.enrollment_id = e.id and a.route_id = rid and a.status = 'active'
    where s.admission_no = trim(p_admission) limit 1;
  if eid is null then return jsonb_build_object('ok', false, 'error', 'not_on_route'); end if;
  ev := case b.trip when 'pickup' then 'board' else 'alight' end;
  insert into bus_boarding (route_id, enrollment_id, trip, event) values (rid, eid, b.trip, ev) on conflict do nothing;
  get diagnostics ins = row_count;
  if ins = 1 then
    tm := to_char(now() at time zone 'Asia/Kolkata', 'HH12:MI AM');
    begin
      insert into notifications (user_id, title, message, type, related_module, related_record)
      select distinct g.user_id,
        case ev when 'board' then fn || ' boarded the bus' else fn || ' got off the bus' end,
        case ev when 'board' then fn || ' boarded the school bus (' || rn || ') at ' || tm || '. / ' || fn || ' स्कूल बसमध्ये ' || tm || ' वाजता चढले.'
                else fn || ' got off the school bus (' || rn || ') at ' || tm || '. / ' || fn || ' स्कूल बसमधून ' || tm || ' वाजता उतरले.' end,
        'notice', 'transport', rid::text
      from student_guardians g join profiles p on p.id = g.user_id and p.is_active where g.student_id = sid and g.user_id is not null;
    exception when others then null; end;
  end if;
  select count(*) into total from transport_assignments where route_id = rid and status = 'active';
  select count(*) into done from bus_boarding where route_id = rid and event_date = current_date and trip = b.trip;
  return jsonb_build_object('ok', true, 'name', fn, 'event', ev, 'repeat', ins = 0, 'done', done, 'total', total);
end $$;
revoke all on function driver_board(text, text) from public;
grant execute on function driver_board(text, text) to anon, authenticated;

-- 2) Photos: private bucket, small JPEG/PNG/WebP (max 1 MB). A photo can be opened only by people who may already see that student or teacher row.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('photos','photos',false,1048576,array['image/jpeg','image/png','image/webp']) on conflict (id) do nothing;
drop policy if exists ph_read on storage.objects;
drop policy if exists ph_write on storage.objects;
drop policy if exists ph_delete on storage.objects;
create policy ph_read on storage.objects for select to authenticated using (bucket_id = 'photos' and (
  exists (select 1 from students s where s.photo_path = name) or exists (select 1 from teachers t where t.photo_path = name)));
create policy ph_write on storage.objects for insert to authenticated with check (bucket_id = 'photos' and (is_admin() or can_front_office()));
create policy ph_delete on storage.objects for delete to authenticated using (bucket_id = 'photos' and (is_admin() or can_front_office()));

-- 3) Insights: simple, explainable risk flags from attendance (last 30 days), marks trend and overdue fees. No guessing, no outside service.
drop function if exists student_insights(uuid);
create function student_insights(p_division uuid default null)
returns table (enrollment_id uuid, student_id uuid, student_name text, admission_no text, class_name text, division_name text, att_pct numeric, absent_streak int,
               last_exam text, last_pct numeric, prev_pct numeric, overdue numeric, risk_score int, reasons text[])
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare staff boolean := is_admin(); show_fees boolean := fees_staff();
begin
  if not staff and current_role_name() not in ('teacher','class_teacher') then raise exception 'not allowed'; end if;
  return query
  with en as (
    select e.id eid, s.id sid, trim(concat_ws(' ', s.first_name, s.last_name)) nm, s.admission_no adm, c.name cn, d.name dn, c.sort_order so
    from student_enrollments e join academic_years y on y.id = e.academic_year_id and y.is_active
    join students s on s.id = e.student_id join divisions d on d.id = e.division_id join classes c on c.id = d.class_id
    where e.status = 'active' and (p_division is null or d.id = p_division) and (staff or d.class_teacher_id = auth.uid())),
  att as (
    select a.enrollment_id eid, count(*) n, count(*) filter (where a.status in ('present','late','half_day')) ok
    from attendance a join en on en.eid = a.enrollment_id where a.att_date >= current_date - 30 group by a.enrollment_id),
  streak as (
    select en.eid, coalesce(
      (select min(t.rn) - 1 from (select a.status, row_number() over (order by a.att_date desc) rn from attendance a
         where a.enrollment_id = en.eid and a.att_date >= current_date - 30) t where t.status <> 'absent'),
      (select count(*) from attendance a where a.enrollment_id = en.eid and a.att_date >= current_date - 30)) st from en),
  ex as (
    select m.enrollment_id eid, x.id xid, x.name xn, x.created_at xc,
           100.0 * sum(m.marks) / nullif(sum(es.max_marks), 0) pct
    from marks m join exam_subjects es on es.id = m.exam_subject_id join exams x on x.id = es.exam_id
    join en on en.eid = m.enrollment_id where m.marks is not null and not m.absent group by m.enrollment_id, x.id, x.name, x.created_at),
  rk as (select ex.*, row_number() over (partition by eid order by xc desc) r from ex),
  fee as (select f.enrollment_id eid, sum(f.balance) ov from student_fees f join en on en.eid = f.enrollment_id where f.balance > 0 and f.due_date < current_date group by f.enrollment_id),
  base as (
    select en.*, case when att.n >= 5 then round(100.0 * att.ok / att.n, 1) end ap, coalesce(streak.st, 0)::int stk,
           l.xn lxn, round(l.pct, 1) lp, round(p.pct, 1) pp, case when show_fees then coalesce(fee.ov, 0) end ovd
    from en left join att on att.eid = en.eid left join streak on streak.eid = en.eid
    left join rk l on l.eid = en.eid and l.r = 1 left join rk p on p.eid = en.eid and p.r = 2 left join fee on fee.eid = en.eid)
  select b.eid, b.sid, b.nm, b.adm, b.cn, b.dn, b.ap, b.stk, b.lxn, b.lp, b.pp, b.ovd,
    (case when b.ap < 75 then 2 when b.ap < 85 then 1 else 0 end + case when b.stk >= 3 then 2 else 0 end
     + case when b.lp is not null and b.lp < 35 then 2 when b.lp is not null and b.lp < 50 then 1 else 0 end
     + case when b.lp is not null and b.pp is not null and b.pp - b.lp >= 15 then 2 else 0 end + case when coalesce(b.ovd, 0) > 0 then 1 else 0 end)::int,
    array_remove(array[
      case when b.ap < 85 then 'Attendance ' || b.ap || '% in the last 30 days' end,
      case when b.stk >= 3 then 'Absent ' || b.stk || ' school days in a row' end,
      case when b.lp is not null and b.lp < 50 then 'Low marks in ' || b.lxn || ' (' || b.lp || '%)' end,
      case when b.lp is not null and b.pp is not null and b.pp - b.lp >= 15 then 'Marks fell from ' || b.pp || '% to ' || b.lp || '%' end,
      case when coalesce(b.ovd, 0) > 0 then 'Overdue fees Rs ' || b.ovd end], null)
  from base b order by 12 desc, b.so, b.dn, b.nm;
end $$;
revoke all on function student_insights(uuid) from public, anon;
grant execute on function student_insights(uuid) to authenticated;
select 'phase18 finished' as result;

-- Phase 19 (round 5B): parent-teacher meeting booking, parent requests (leave / certificate), library overdue reminders and fine paid.
-- Safe to run more than once. Nothing is deleted.

-- ===== A) Parent-teacher meetings =====
create table if not exists ptm_events (
  id uuid primary key default gen_random_uuid(), title text not null check (length(title) between 3 and 120),
  division_id uuid not null references divisions(id), ptm_date date not null, start_time time not null, end_time time not null,
  slot_minutes int not null check (slot_minutes between 5 and 60), note text check (note is null or length(note) <= 500),
  status text not null default 'open' check (status in ('open','closed')), created_by uuid default auth.uid() references profiles(id), created_at timestamptz not null default now(),
  check (end_time > start_time)
);
create table if not exists ptm_slots (
  id uuid primary key default gen_random_uuid(), event_id uuid not null references ptm_events(id) on delete cascade,
  slot_start time not null, slot_end time not null, enrollment_id uuid references student_enrollments(id), booked_by uuid references profiles(id), booked_at timestamptz,
  unique (event_id, slot_start)
);
create unique index if not exists ptm_one_per_child on ptm_slots (event_id, enrollment_id) where enrollment_id is not null;
create table if not exists ptm_notes (slot_id uuid primary key references ptm_slots(id) on delete cascade, note text not null check (length(note) <= 1000), written_by uuid default auth.uid() references profiles(id), written_at timestamptz not null default now());
create or replace function ptm_event_division(eid uuid) returns uuid language sql stable security definer set search_path = public as $$
  select division_id from ptm_events where id = eid $$;
alter table ptm_events enable row level security; alter table ptm_slots enable row level security; alter table ptm_notes enable row level security;

create or replace function can_run_ptm(div uuid) returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(is_admin() or can_front_office(), false) or exists (select 1 from divisions d where d.id = div and d.class_teacher_id = auth.uid()) $$;
create or replace function is_parent_in_division(div uuid) returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from student_enrollments e where e.division_id = div and e.status = 'active' and is_guardian_of_enrollment(e.id)) $$;

drop policy if exists pe_read on ptm_events; drop policy if exists ps_read on ptm_slots; drop policy if exists pn_read on ptm_notes;
create policy pe_read on ptm_events for select to authenticated using (can_run_ptm(division_id) or is_parent_in_division(division_id));
create policy ps_read on ptm_slots for select to authenticated using (can_run_ptm(ptm_event_division(event_id))
  or (enrollment_id is null and is_parent_in_division(ptm_event_division(event_id))) or (enrollment_id is not null and is_guardian_of_enrollment(enrollment_id)));
create policy pn_read on ptm_notes for select to authenticated using (can_run_ptm(ptm_event_division((select s.event_id from ptm_slots s where s.id = slot_id))));

create or replace function create_ptm(p_title text, p_division uuid, p_date date, p_start time, p_end time, p_slot int, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare eid uuid; n int; dn text;
begin
  if not can_run_ptm(p_division) then raise exception 'not allowed'; end if;
  if p_date is null or p_date < current_date then raise exception 'date must be today or later'; end if;
  if p_start is null or p_end is null or p_end <= p_start or p_slot is null or p_slot not between 5 and 60 then raise exception 'invalid time'; end if;
  n := floor(extract(epoch from (p_end - p_start)) / 60 / p_slot);
  if n < 1 or n > 60 then raise exception 'between 1 and 60 slots please'; end if;
  insert into ptm_events (title, division_id, ptm_date, start_time, end_time, slot_minutes, note) values (trim(p_title), p_division, p_date, p_start, p_end, p_slot, nullif(trim(p_note), '')) returning id into eid;
  insert into ptm_slots (event_id, slot_start, slot_end) select eid, p_start + (g * p_slot) * interval '1 minute', p_start + ((g + 1) * p_slot) * interval '1 minute' from generate_series(0, n - 1) g;
  begin
    insert into notifications (user_id, title, message, type, related_module, related_record)
    select distinct g.user_id, 'Parent-teacher meeting: ' || trim(p_title),
      'A meeting is planned on ' || to_char(p_date, 'DD-MM-YYYY') || '. Please book a time slot in the Meetings page. / ' || to_char(p_date, 'DD-MM-YYYY') || ' रोजी पालक-शिक्षक भेट आहे. कृपया "Meetings" पेजवर वेळ निवडा.',
      'event', 'ptm', eid::text
    from student_enrollments e join student_guardians g on g.student_id = e.student_id join profiles p on p.id = g.user_id and p.is_active
    where e.division_id = p_division and e.status = 'active' and g.user_id is not null;
  exception when others then null; end;
  return eid;
end $$;

create or replace function book_ptm_slot(p_slot uuid, p_enrollment uuid) returns void language plpgsql security definer set search_path = public as $$
declare s ptm_slots; ev ptm_events; nm text; ct uuid;
begin
  select * into s from ptm_slots where id = p_slot for update; if not found then raise exception 'slot not found'; end if;
  select * into ev from ptm_events where id = s.event_id;
  if ev.status <> 'open' or ev.ptm_date < current_date then raise exception 'this meeting is closed'; end if;
  if not is_guardian_of_enrollment(p_enrollment) then raise exception 'not allowed'; end if;
  if not exists (select 1 from student_enrollments e where e.id = p_enrollment and e.division_id = ev.division_id and e.status = 'active') then raise exception 'wrong class'; end if;
  if s.enrollment_id is not null then raise exception 'slot already taken'; end if;
  if exists (select 1 from ptm_slots x where x.event_id = s.event_id and x.enrollment_id = p_enrollment) then raise exception 'already booked'; end if;
  update ptm_slots set enrollment_id = p_enrollment, booked_by = auth.uid(), booked_at = now() where id = p_slot;
  begin
    select trim(concat_ws(' ', st.first_name, st.last_name)) into nm from student_enrollments e join students st on st.id = e.student_id where e.id = p_enrollment;
    select class_teacher_id into ct from divisions where id = ev.division_id;
    if ct is not null then
      insert into notifications (user_id, title, message, type, related_module, related_record)
      values (ct, 'Meeting booked: ' || nm, 'A parent of ' || nm || ' booked ' || to_char(s.slot_start, 'HH12:MI AM') || ' on ' || to_char(ev.ptm_date, 'DD-MM-YYYY') || '.', 'event', 'ptm', ev.id::text);
    end if;
  exception when others then null; end;
end $$;

create or replace function cancel_ptm_slot(p_slot uuid) returns void language plpgsql security definer set search_path = public as $$
declare s ptm_slots; ev ptm_events; who uuid;
begin
  select * into s from ptm_slots where id = p_slot for update; if not found then raise exception 'slot not found'; end if;
  select * into ev from ptm_events where id = s.event_id;
  if s.enrollment_id is null then return; end if;
  if not (is_guardian_of_enrollment(s.enrollment_id) or can_run_ptm(ev.division_id)) then raise exception 'not allowed'; end if;
  if ev.ptm_date < current_date then raise exception 'this meeting is over'; end if;
  who := s.booked_by;
  update ptm_slots set enrollment_id = null, booked_by = null, booked_at = null where id = p_slot;
  delete from ptm_notes where slot_id = p_slot;
  begin
    if who is not null and who <> auth.uid() then
      insert into notifications (user_id, title, message, type, related_module, related_record)
      values (who, 'Meeting slot cancelled', 'Your meeting slot on ' || to_char(ev.ptm_date, 'DD-MM-YYYY') || ' at ' || to_char(s.slot_start, 'HH12:MI AM') || ' was cancelled by the school. Please book another slot. / तुमची भेटीची वेळ शाळेने रद्द केली आहे. कृपया दुसरी वेळ निवडा.', 'event', 'ptm', ev.id::text);
    end if;
  exception when others then null; end;
end $$;

create or replace function save_ptm_note(p_slot uuid, p_note text) returns void language plpgsql security definer set search_path = public as $$
declare d uuid;
begin
  select ptm_event_division(event_id) into d from ptm_slots where id = p_slot;
  if d is null or not can_run_ptm(d) then raise exception 'not allowed'; end if;
  if p_note is null or length(trim(p_note)) = 0 then delete from ptm_notes where slot_id = p_slot; return; end if;
  insert into ptm_notes (slot_id, note) values (p_slot, left(trim(p_note), 1000)) on conflict (slot_id) do update set note = excluded.note, written_by = auth.uid(), written_at = now();
end $$;

create or replace function close_ptm(p_event uuid) returns void language plpgsql security definer set search_path = public as $$
begin
  if not can_run_ptm(ptm_event_division(p_event)) then raise exception 'not allowed'; end if;
  update ptm_events set status = 'closed' where id = p_event;
end $$;

-- ===== B) Parent requests (leave, certificate, other) =====
create table if not exists parent_requests (
  id uuid primary key default gen_random_uuid(), enrollment_id uuid not null references student_enrollments(id),
  kind text not null check (kind in ('leave','certificate','other')), subject text not null check (length(subject) between 3 and 120),
  details text check (details is null or length(details) <= 1000), from_date date, to_date date,
  status text not null default 'pending' check (status in ('pending','approved','rejected','cancelled')),
  response text check (response is null or length(response) <= 500), created_by uuid not null default auth.uid() references profiles(id),
  reviewed_by uuid references profiles(id), reviewed_at timestamptz, created_at timestamptz not null default now(),
  check (to_date is null or from_date is null or to_date >= from_date)
);
create index if not exists parent_requests_enr on parent_requests (enrollment_id, created_at desc);
create index if not exists parent_requests_status on parent_requests (status, created_at desc);
alter table parent_requests enable row level security;
create or replace function enrollment_class_teacher(eid uuid) returns uuid language sql stable security definer set search_path = public as $$
  select d.class_teacher_id from student_enrollments e join divisions d on d.id = e.division_id where e.id = eid $$;
create or replace function can_review_request(eid uuid, k text) returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(is_admin() or can_front_office(), false) or (k in ('leave','other') and enrollment_class_teacher(eid) = auth.uid()) $$;
drop policy if exists pr_read on parent_requests;
create policy pr_read on parent_requests for select to authenticated using (is_guardian_of_enrollment(enrollment_id) or can_review_request(enrollment_id, kind));

create or replace function submit_parent_request(p_enrollment uuid, p_kind text, p_subject text, p_details text, p_from date, p_to date) returns uuid
language plpgsql security definer set search_path = public as $$
declare rid uuid; nm text; ct uuid;
begin
  if not is_guardian_of_enrollment(p_enrollment) then raise exception 'not allowed'; end if;
  if p_kind not in ('leave','certificate','other') then raise exception 'invalid kind'; end if;
  if p_kind = 'leave' and (p_from is null or p_to is null) then raise exception 'leave needs dates'; end if;
  if p_from is not null and p_to is not null and p_to < p_from then raise exception 'end date before start date'; end if;
  if p_from is not null and p_from < current_date - 7 then raise exception 'start date too old'; end if;
  if (select count(*) from parent_requests where enrollment_id = p_enrollment and status = 'pending') >= 5 then raise exception 'too many pending requests'; end if;
  insert into parent_requests (enrollment_id, kind, subject, details, from_date, to_date)
    values (p_enrollment, p_kind, trim(p_subject), nullif(trim(coalesce(p_details, '')), ''), p_from, p_to) returning id into rid;
  begin
    select trim(concat_ws(' ', st.first_name, st.last_name)) into nm from student_enrollments e join students st on st.id = e.student_id where e.id = p_enrollment;
    ct := enrollment_class_teacher(p_enrollment);
    insert into notifications (user_id, title, message, type, related_module, related_record)
    select distinct u, 'New request: ' || trim(p_subject), 'A parent sent a ' || p_kind || ' request for ' || nm || '. Open the Requests page.', 'notice', 'requests', rid::text
    from (select ct as u where ct is not null and p_kind <> 'certificate'
          union select pr.id from profiles pr where pr.is_active and pr.role in ('school_admin','reception') and (p_kind = 'certificate' or ct is null)) t where u is not null;
  exception when others then null; end;
  return rid;
end $$;

create or replace function review_parent_request(p_id uuid, p_status text, p_response text) returns void language plpgsql security definer set search_path = public as $$
declare r parent_requests;
begin
  select * into r from parent_requests where id = p_id for update; if not found then raise exception 'not found'; end if;
  if p_status not in ('approved','rejected') then raise exception 'invalid status'; end if;
  if r.status <> 'pending' then raise exception 'already decided'; end if;
  if not can_review_request(r.enrollment_id, r.kind) then raise exception 'not allowed'; end if;
  update parent_requests set status = p_status, response = nullif(left(trim(coalesce(p_response, '')), 500), ''), reviewed_by = auth.uid(), reviewed_at = now() where id = p_id;
  begin
    insert into notifications (user_id, title, message, type, related_module, related_record)
    select distinct g.user_id, 'Request ' || p_status || ': ' || r.subject,
      'Your request "' || r.subject || '" was ' || p_status || '.' || coalesce(' Note: ' || nullif(left(trim(coalesce(p_response, '')), 200), ''), '') || ' / तुमच्या अर्जावर निर्णय झाला आहे.', 'notice', 'requests', r.id::text
    from student_enrollments e join student_guardians g on g.student_id = e.student_id join profiles p on p.id = g.user_id and p.is_active where e.id = r.enrollment_id and g.user_id is not null;
  exception when others then null; end;
end $$;

create or replace function cancel_parent_request(p_id uuid) returns void language plpgsql security definer set search_path = public as $$
declare r parent_requests;
begin
  select * into r from parent_requests where id = p_id for update; if not found then raise exception 'not found'; end if;
  if not is_guardian_of_enrollment(r.enrollment_id) then raise exception 'not allowed'; end if;
  if r.status <> 'pending' then raise exception 'only pending requests can be cancelled'; end if;
  update parent_requests set status = 'cancelled' where id = p_id;
end $$;

-- ===== C) Library: overdue list, reminders to parents, fine paid =====
alter table book_transactions add column if not exists fine_paid boolean not null default false;
alter table book_transactions add column if not exists fine_paid_on date;
create or replace function mark_fine_paid(p_tx uuid) returns void language plpgsql security definer set search_path = public as $$
declare t book_transactions;
begin
  if not can_manage_library() then raise exception 'not allowed'; end if;
  select * into t from book_transactions where id = p_tx for update; if not found then raise exception 'not found'; end if;
  if t.status <> 'returned' or t.fine <= 0 then raise exception 'no fine to collect'; end if;
  if t.fine_paid then raise exception 'already marked paid'; end if;
  update book_transactions set fine_paid = true, fine_paid_on = current_date where id = p_tx;
end $$;

create or replace function overdue_books() returns table (tx_id uuid, book_title text, borrower text, class_name text, due_date date, days_late int, est_fine numeric)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare rate numeric := coalesce((select nullif(value, '')::numeric from school_settings where key = 'library_fine_per_day'), 0);
begin
  if not (can_manage_library() or current_role_name() = 'principal') then raise exception 'not allowed'; end if;
  return query
  select t.id, b.title,
    case when t.borrower_type = 'student' then trim(concat_ws(' ', s.first_name, s.last_name)) else coalesce((select full_name from profiles where id = t.teacher_id), 'Teacher') end,
    case when t.borrower_type = 'student' then c.name || ' - ' || d.name else 'Teacher' end,
    t.due_date, (current_date - t.due_date)::int, ((current_date - t.due_date) * rate)::numeric
  from book_transactions t join books b on b.id = t.book_id
  left join student_enrollments e on e.id = t.enrollment_id left join students s on s.id = e.student_id
  left join divisions d on d.id = e.division_id left join classes c on c.id = d.class_id
  where t.status = 'issued' and t.due_date < current_date order by t.due_date, 2;
end $$;

create or replace function send_overdue_reminders() returns int language plpgsql security definer set search_path = public as $$
declare n int;
begin
  if not can_manage_library() then raise exception 'not allowed'; end if;
  with ins as (
    insert into notifications (user_id, title, message, type, related_module, related_record)
    select distinct g.user_id, 'Library book overdue: ' || b.title,
      trim(concat_ws(' ', s.first_name, s.last_name)) || ' has not returned "' || b.title || '" (due ' || to_char(t.due_date, 'DD-MM-YYYY') || '). Please return it to the library. / ' ||
      trim(concat_ws(' ', s.first_name, s.last_name)) || ' यांनी "' || b.title || '" हे पुस्तक अजून परत केलेले नाही. कृपया ते ग्रंथालयात जमा करा.', 'notice', 'library', t.id::text
    from book_transactions t join books b on b.id = t.book_id join student_enrollments e on e.id = t.enrollment_id join students s on s.id = e.student_id
    join student_guardians g on g.student_id = s.id join profiles p on p.id = g.user_id and p.is_active
    where t.status = 'issued' and t.borrower_type = 'student' and t.due_date < current_date and g.user_id is not null
      and not exists (select 1 from notifications x where x.user_id = g.user_id and x.related_module = 'library' and x.related_record = t.id::text and x.created_at > now() - interval '7 days')
    returning 1)
  select count(*) into n from ins;
  return n;
end $$;

revoke all on function create_ptm(text,uuid,date,time,time,int,text), book_ptm_slot(uuid,uuid), cancel_ptm_slot(uuid), save_ptm_note(uuid,text), close_ptm(uuid),
  submit_parent_request(uuid,text,text,text,date,date), review_parent_request(uuid,text,text), cancel_parent_request(uuid),
  mark_fine_paid(uuid), overdue_books(), send_overdue_reminders() from public, anon;
grant execute on function create_ptm(text,uuid,date,time,time,int,text), book_ptm_slot(uuid,uuid), cancel_ptm_slot(uuid), save_ptm_note(uuid,text), close_ptm(uuid),
  submit_parent_request(uuid,text,text,text,date,date), review_parent_request(uuid,text,text), cancel_parent_request(uuid),
  mark_fine_paid(uuid), overdue_books(), send_overdue_reminders() to authenticated;
select 'phase19 finished' as result;

-- Phase 20 (round 6): AI assistant. Safe to run more than once. Nothing is deleted.
-- The AI runs in a Supabase Edge Function (ai-assistant). The API key lives only there as a secret, never in the website.
-- Students (minors) never get AI. No names or phone numbers are sent. Nothing the user types is stored, only a count per feature.

create table if not exists ai_config (
  id boolean primary key default true check (id),
  enabled boolean not null default false,
  limit_parent int not null default 10 check (limit_parent between 0 and 200),
  limit_staff int not null default 40 check (limit_staff between 0 and 500),
  limit_admin int not null default 100 check (limit_admin between 0 and 1000)
);
insert into ai_config (id) values (true) on conflict do nothing;
alter table ai_config enable row level security;
drop policy if exists aic_read on ai_config;
create policy aic_read on ai_config for select to authenticated using (is_admin());

create table if not exists ai_knowledge (
  id uuid primary key default gen_random_uuid(), title text not null check (length(title) between 2 and 120),
  body text not null check (length(body) between 2 and 2000), is_active boolean not null default true,
  updated_by uuid default auth.uid() references profiles(id), updated_at timestamptz not null default now()
);
alter table ai_knowledge enable row level security;
drop policy if exists aik_all on ai_knowledge;
create policy aik_all on ai_knowledge for all to authenticated using (is_admin()) with check (is_admin());
create or replace function ai_knowledge_touch() returns trigger language plpgsql as $$ begin new.updated_by := auth.uid(); new.updated_at := now(); return new; end $$;
drop trigger if exists aik_touch on ai_knowledge;
create trigger aik_touch before insert or update on ai_knowledge for each row execute function ai_knowledge_touch();

create table if not exists ai_usage (
  id bigint generated always as identity primary key, user_id uuid not null references profiles(id) on delete cascade,
  feature text not null check (feature in ('notice','translate','remark','questions','ask')), day date not null default current_date, created_at timestamptz not null default now()
);
create index if not exists ai_usage_user_day on ai_usage (user_id, day);
alter table ai_usage enable row level security;   -- no policies: only the functions below can touch it

create or replace function ai_group(r text) returns text language sql immutable as $$
  select case when r in ('super_admin','school_admin','principal') then 'admin' when r in ('teacher','class_teacher','reception') then 'staff' when r = 'parent' then 'parent' else null end $$;

create or replace function ai_allowed(r text, f text) returns boolean language sql immutable as $$
  select case f when 'ask' then ai_group(r) is not null
    when 'notice' then r in ('super_admin','school_admin','principal','reception','teacher','class_teacher')
    when 'translate' then r in ('super_admin','school_admin','principal','reception','teacher','class_teacher')
    when 'remark' then r in ('super_admin','school_admin','principal','teacher','class_teacher')
    when 'questions' then r in ('super_admin','school_admin','principal','teacher','class_teacher') else false end $$;

-- Called by the Edge Function with the user's own login. Checks everything and counts one use.
create or replace function ai_prepare(p_feature text) returns jsonb language plpgsql security definer set search_path = public as $$
declare r text := current_role_name()::text; g text; cfg ai_config%rowtype; lim int; used int; ctx jsonb; kn jsonb;
begin
  if auth.uid() is null or r is null then return jsonb_build_object('ok', false, 'error', 'auth'); end if;
  g := ai_group(r);
  if g is null or not ai_allowed(r, p_feature) then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
  select * into cfg from ai_config where id; if not found or not cfg.enabled then return jsonb_build_object('ok', false, 'error', 'ai_off'); end if;
  lim := case g when 'admin' then cfg.limit_admin when 'staff' then cfg.limit_staff else cfg.limit_parent end;
  select count(*) into used from ai_usage where user_id = auth.uid() and day = current_date;
  if used >= lim then return jsonb_build_object('ok', false, 'error', 'quota', 'limit', lim); end if;
  insert into ai_usage (user_id, feature) values (auth.uid(), p_feature);
  select coalesce(jsonb_object_agg(key, value), '{}'::jsonb) into ctx from school_settings where is_public and key in ('school_name','address','phone','email','website','principal','school_start_time','school_end_time');
  if p_feature = 'ask' then
    select coalesce(jsonb_agg(jsonb_build_object('title', title, 'body', body) order by updated_at desc), '[]'::jsonb) into kn from (select title, body, updated_at from ai_knowledge where is_active order by updated_at desc limit 40) k;
  else kn := '[]'::jsonb; end if;
  return jsonb_build_object('ok', true, 'role', r, 'remaining', lim - used - 1, 'school', ctx, 'knowledge', kn);
end $$;

create or replace function ai_status() returns jsonb language plpgsql security definer set search_path = public as $$
declare r text := current_role_name()::text; g text; cfg ai_config%rowtype; lim int; used int; feats text[];
begin
  if auth.uid() is null or r is null then return jsonb_build_object('enabled', false); end if;
  g := ai_group(r); select * into cfg from ai_config where id;
  select array_agg(f) into feats from unnest(array['notice','translate','remark','questions','ask']) f where ai_allowed(r, f);
  if g is null then return jsonb_build_object('enabled', false, 'features', '[]'::jsonb); end if;
  lim := case g when 'admin' then cfg.limit_admin when 'staff' then cfg.limit_staff else cfg.limit_parent end;
  select count(*) into used from ai_usage where user_id = auth.uid() and day = current_date;
  return jsonb_build_object('enabled', cfg.enabled, 'features', to_jsonb(feats), 'remaining', greatest(lim - used, 0), 'limit', lim);
end $$;

create or replace function ai_set_config(p_enabled boolean, p_parent int, p_staff int, p_admin int) returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_admin() then raise exception 'not allowed'; end if;
  update ai_config set enabled = coalesce(p_enabled, enabled), limit_parent = coalesce(p_parent, limit_parent), limit_staff = coalesce(p_staff, limit_staff), limit_admin = coalesce(p_admin, limit_admin) where id;
end $$;

create or replace function ai_usage_summary() returns table (day date, feature text, uses bigint, users bigint) language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not is_admin() then raise exception 'not allowed'; end if;
  return query select u.day, u.feature, count(*), count(distinct u.user_id) from ai_usage u where u.day >= current_date - 6 group by u.day, u.feature order by u.day desc, u.feature;
end $$;

revoke all on function ai_prepare(text), ai_status(), ai_set_config(boolean,int,int,int), ai_usage_summary() from public, anon;
grant execute on function ai_prepare(text), ai_status(), ai_set_config(boolean,int,int,int), ai_usage_summary() to authenticated;
select 'phase20 finished' as result;
-- Phase 21: dashboard + fee overview (read-only aggregates, role-gated)
create or replace function dashboard_overview() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare r text := current_role_name()::text; yr uuid; res jsonb := '{}'::jsonb; fin boolean := fees_staff();
  adm boolean := is_admin(); school boolean := r in ('super_admin','school_admin','principal','reception','accountant');
begin
  if r is null or r not in ('super_admin','school_admin','principal','accountant','reception','librarian') then raise exception 'not allowed'; end if;
  select id into yr from academic_years where is_active limit 1;
  res := jsonb_build_object('role', r, 'year', (select name from academic_years where id = yr));
  if r <> 'librarian' then
    res := res || jsonb_build_object(
      'students', (select count(*) from student_enrollments where academic_year_id = yr and status = 'active'),
      'teachers', (select count(*) from teachers where status = 'active'),
      'classes', (select count(*) from classes),
      'divisions', (select count(*) from divisions where academic_year_id = yr));
  end if;
  if r in ('super_admin','school_admin','principal','reception') then
    res := res || jsonb_build_object(
      'att_today', (select coalesce(jsonb_object_agg(status, n), '{}'::jsonb) from (select a.status, count(*) n from attendance a join student_enrollments e on e.id = a.enrollment_id where a.att_date = current_date and e.academic_year_id = yr group by a.status) t),
      'att_days', (select coalesce(jsonb_agg(jsonb_build_object('d', d, 'p', p, 'n', n) order by d), '[]'::jsonb) from (
          select a.att_date d, count(*) filter (where a.status in ('present','late','half_day')) p, count(*) n
          from attendance a join student_enrollments e on e.id = a.enrollment_id
          where a.att_date >= current_date - 13 and e.academic_year_id = yr group by a.att_date) t),
      'att_classes', (select coalesce(jsonb_agg(jsonb_build_object('c', c, 'p', p, 'n', n) order by so), '[]'::jsonb) from (
          select c.name c, c.sort_order so, count(*) filter (where a.status in ('present','late','half_day')) p, count(*) n
          from attendance a join student_enrollments e on e.id = a.enrollment_id join divisions d on d.id = e.division_id join classes c on c.id = d.class_id
          where a.att_date = current_date and e.academic_year_id = yr group by c.name, c.sort_order) t),
      'att_unmarked', (select count(*) from divisions d where d.academic_year_id = yr and exists (select 1 from student_enrollments e where e.division_id = d.id and e.status = 'active')
          and not exists (select 1 from attendance a join student_enrollments e on e.id = a.enrollment_id where e.division_id = d.id and a.att_date = current_date)),
      'gender', (select coalesce(jsonb_object_agg(g, n), '{}'::jsonb) from (select s.gender g, count(*) n from students s join student_enrollments e on e.student_id = s.id where e.academic_year_id = yr and e.status = 'active' group by s.gender) t),
      'strength', (select coalesce(jsonb_agg(jsonb_build_object('c', c, 'n', n) order by so), '[]'::jsonb) from (
          select c.name c, c.sort_order so, count(*) n from student_enrollments e join divisions d on d.id = e.division_id join classes c on c.id = d.class_id
          where e.academic_year_id = yr and e.status = 'active' group by c.name, c.sort_order) t),
      'pending_requests', (select count(*) from parent_requests where status = 'pending'),
      'pending_leave', (select count(*) from leave_requests where status = 'pending'),
      'events', (select coalesce(jsonb_agg(jsonb_build_object('t', title, 'd', event_date) order by event_date), '[]'::jsonb) from (select title, event_date from events where event_date >= current_date order by event_date limit 5) t),
      'notices', (select count(*) from notices where notice_date >= current_date - 7));
  end if;
  if fin then
    res := res || jsonb_build_object(
      'fees', (select jsonb_build_object('billed', coalesce(sum(assigned_amount - concession_amount), 0), 'paid', coalesce(sum(paid_amount), 0),
          'balance', coalesce(sum(balance), 0), 'overdue', coalesce(sum(balance) filter (where due_date < current_date), 0),
          'overdue_n', count(distinct enrollment_id) filter (where balance > 0 and due_date < current_date))
          from student_fees f join student_enrollments e on e.id = f.enrollment_id where e.academic_year_id = yr),
      'fee_months', (select coalesce(jsonb_agg(jsonb_build_object('m', m, 'a', a) order by m), '[]'::jsonb) from (
          select to_char(date_trunc('month', payment_date), 'YYYY-MM') m, sum(amount) a from fee_payments
          where payment_date >= date_trunc('month', current_date) - interval '5 months' group by 1) t),
      'fee_today', (select coalesce(sum(amount), 0) from fee_payments where payment_date = current_date),
      'pending_claims', (select count(*) from payment_claims where status = 'pending'));
  end if;
  return res;
end $$;
revoke all on function dashboard_overview() from public, anon; grant execute on function dashboard_overview() to authenticated;

create or replace function fee_overview(p_year uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare yr uuid := p_year;
begin
  if not fees_staff() then raise exception 'not allowed'; end if;
  if yr is null then select id into yr from academic_years where is_active limit 1; end if;
  return jsonb_build_object(
    'totals', (select jsonb_build_object('billed', coalesce(sum(assigned_amount),0), 'concession', coalesce(sum(concession_amount),0), 'paid', coalesce(sum(paid_amount),0), 'balance', coalesce(sum(balance),0))
        from student_fees f join student_enrollments e on e.id = f.enrollment_id where e.academic_year_id = yr),
    'by_class', (select coalesce(jsonb_agg(jsonb_build_object('c', c, 'net', net, 'paid', paid, 'bal', bal) order by so), '[]'::jsonb) from (
        select c.name c, c.sort_order so, sum(f.assigned_amount - f.concession_amount) net, sum(f.paid_amount) paid, sum(f.balance) bal
        from student_fees f join student_enrollments e on e.id = f.enrollment_id join divisions d on d.id = e.division_id join classes c on c.id = d.class_id
        where e.academic_year_id = yr group by c.name, c.sort_order) t),
    'months', (select coalesce(jsonb_agg(jsonb_build_object('m', m, 'a', a) order by m), '[]'::jsonb) from (
        select to_char(p.payment_date, 'YYYY-MM') m, sum(p.amount) a from fee_payments p join student_fees f on f.id = p.student_fee_id join student_enrollments e on e.id = f.enrollment_id
        where e.academic_year_id = yr group by 1) t),
    'modes', (select coalesce(jsonb_agg(jsonb_build_object('k', k, 'a', a) order by a desc), '[]'::jsonb) from (
        select p.mode k, sum(p.amount) a from fee_payments p join student_fees f on f.id = p.student_fee_id join student_enrollments e on e.id = f.enrollment_id
        where e.academic_year_id = yr group by p.mode) t),
    'aging', (select jsonb_build_object('current', coalesce(sum(balance) filter (where due_date >= current_date), 0),
        'd1_30', coalesce(sum(balance) filter (where due_date < current_date and due_date >= current_date - 30), 0),
        'd31_60', coalesce(sum(balance) filter (where due_date < current_date - 30 and due_date >= current_date - 60), 0),
        'd60p', coalesce(sum(balance) filter (where due_date < current_date - 60), 0))
        from student_fees f join student_enrollments e on e.id = f.enrollment_id where e.academic_year_id = yr and f.balance > 0),
    'top_due', (select coalesce(jsonb_agg(jsonb_build_object('n', n, 'adm', adm, 'cls', cls, 'bal', bal) order by bal desc), '[]'::jsonb) from (
        select s.first_name || ' ' || s.last_name n, s.admission_no adm, c.name || ' - ' || d.name cls, sum(f.balance) bal
        from student_fees f join student_enrollments e on e.id = f.enrollment_id join students s on s.id = e.student_id join divisions d on d.id = e.division_id join classes c on c.id = d.class_id
        where e.academic_year_id = yr and f.balance > 0 and f.due_date < current_date group by s.id, s.first_name, s.last_name, s.admission_no, c.name, d.name order by 4 desc limit 10) t));
end $$;
revoke all on function fee_overview(uuid) from public, anon; grant execute on function fee_overview(uuid) to authenticated;
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
