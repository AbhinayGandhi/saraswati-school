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
