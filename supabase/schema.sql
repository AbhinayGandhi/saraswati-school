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
