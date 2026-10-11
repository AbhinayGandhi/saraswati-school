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
