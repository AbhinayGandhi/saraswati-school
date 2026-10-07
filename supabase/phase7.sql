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
