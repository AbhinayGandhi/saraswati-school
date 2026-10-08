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
