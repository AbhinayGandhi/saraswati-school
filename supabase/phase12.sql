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
