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
