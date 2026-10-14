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
