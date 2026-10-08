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
