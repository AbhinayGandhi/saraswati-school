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
