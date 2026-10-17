-- ============================================================================
-- DEMO-DATA.sql : a complete working demo school, for learning and for presentations
-- ============================================================================
-- Creates: academic years 2026-27 (active) and 2027-28 (for the promotion demo), 16 divisions,
-- 10 subjects, 20 teachers, 3 office staff, ~190 students with parents, subject-teacher
-- assignments, a holiday calendar, ~6 weeks of attendance, a published First Term exam with marks
-- and remarks, a draft Unit Test, fees with full / part / no payments and receipts, concessions,
-- notices, events, activities, achievements, library books and issues, admission enquiries,
-- transport routes, staff leave, a timetable, homework and notifications.
-- Also creates DEMO LOGINS (password for all: Demo@12345):
--   principal@demo.example.com   accountant@demo.example.com   reception@demo.example.com   librarian@demo.example.com
--   teacher01@demo.example.com ... teacher20@demo.example.com  (01-16 class teachers, 17-20 subject teachers)
--   parent1@demo.example.com, parent2@demo.example.com, student1@demo.example.com, student2@demo.example.com
-- All names are made up. School settings (name, address, phone) are NOT changed.
-- Run it ONLY on an empty database: first run RESET-DATA.sql. Remove everything later with RESET-DATA.sql.
-- ============================================================================

do $g$ begin
  if exists (select 1 from students) or exists (select 1 from academic_years) then
    raise exception 'The database already has data. Run RESET-DATA.sql first (read its warning), then run this file.';
  end if;
end $g$;

select setseed(0.42);

-- Helper: makes a demo login that can sign in. Only columns that exist in your Supabase version are filled.
create function pg_temp.mk_user(p_email text, p_name text, p_role text) returns uuid language plpgsql as $f$
declare uid uuid := gen_random_uuid(); c text[]; v text[]; i int; cols text := ''; vals text := '';
begin
  c := array['id','instance_id','aud','role','email','encrypted_password','email_confirmed_at','raw_app_meta_data','raw_user_meta_data',
    'confirmation_token','recovery_token','email_change_token_new','email_change','email_change_token_current','phone_change','phone_change_token','reauthentication_token','created_at','updated_at'];
  v := array[quote_literal(uid::text), '''00000000-0000-0000-0000-000000000000''', '''authenticated''', '''authenticated''', quote_literal(p_email),
    'crypt(''Demo@12345'', gen_salt(''bf''))', 'now()', '''{"provider":"email","providers":["email"]}''::jsonb',
    quote_literal(json_build_object('full_name', p_name)::text)||'::jsonb', '''''', '''''', '''''', '''''', '''''', '''''', '''''', '''''', 'now()', 'now()'];
  for i in 1 .. array_length(c, 1) loop
    if exists (select 1 from information_schema.columns where table_schema = 'auth' and table_name = 'users' and column_name = c[i]) then
      cols := cols || case when cols = '' then '' else ',' end || quote_ident(c[i]);
      vals := vals || case when vals = '' then '' else ',' end || v[i];
    end if;
  end loop;
  execute 'insert into auth.users (' || cols || ') values (' || vals || ')';
  -- identity row (newer Supabase versions use it for email sign-in)
  begin
    if exists (select 1 from information_schema.tables where table_schema = 'auth' and table_name = 'identities') then
      c := array['id','provider_id','user_id','identity_data','provider','last_sign_in_at','created_at','updated_at'];
      v := array['gen_random_uuid()', quote_literal(uid::text), quote_literal(uid::text), quote_literal(json_build_object('sub', uid::text, 'email', p_email, 'email_verified', true)::text)||'::jsonb',
        '''email''', 'now()', 'now()', 'now()'];
      cols := ''; vals := '';
      for i in 1 .. array_length(c, 1) loop
        if exists (select 1 from information_schema.columns where table_schema = 'auth' and table_name = 'identities' and column_name = c[i]) then
          cols := cols || case when cols = '' then '' else ',' end || quote_ident(c[i]);
          vals := vals || case when vals = '' then '' else ',' end || v[i];
        end if;
      end loop;
      execute 'insert into auth.identities (' || cols || ') values (' || vals || ')';
    end if;
  exception when others then null;
  end;
  update profiles set role = p_role::user_role, is_active = true, full_name = p_name where id = uid;
  return uid;
end $f$;

do $demo$
#variable_conflict use_column
declare
  y1 uuid; y2 uuid; ft_t uuid; ft_e uuid;
  boys text[] := array['Aarav','Arjun','Atharva','Ishaan','Om','Shreyas','Sahil','Yash','Rohan','Pranav','Omkar','Soham','Tanmay','Vedant','Harsh','Kartik'];
  girls text[] := array['Aanya','Anvi','Diya','Isha','Kavya','Mrunal','Nidhi','Pooja','Riya','Sakshi','Shravani','Tanvi','Vaishnavi','Ananya','Gauri','Prachi'];
  surn text[] := array['Patil','Deshmukh','Jadhav','Kulkarni','Shinde','Pawar','More','Gaikwad','Joshi','Sawant','Chavan','Kale','Bhosale','Naik','Mane','Shelke','Salunkhe','Thorat'];
  fath text[] := array['Ramesh','Suresh','Sanjay','Vijay','Anil','Prakash','Mahesh','Dinesh','Rajesh','Santosh'];
  moth text[] := array['Sunita','Anita','Priya','Madhuri','Kavita','Sarita','Rekha','Jyoti','Sheetal','Manisha'];
  tnames text[] := array['Meera Kulkarni','Rahul Deshmukh','Sneha Patil','Amit Jadhav','Pallavi Shinde','Nitin Pawar','Kavita More','Sachin Gaikwad','Rutuja Joshi','Vikas Sawant',
                         'Swati Chavan','Prasad Kale','Madhavi Bhosale','Ganesh Naik','Archana Mane','Dhananjay Shelke','Seema Salunkhe','Ajay Thorat','Lata Bhagat','Sunil Waghmare'];
  subj_names text[] := array['Marathi','English','Hindi','Mathematics','EVS','Science','Social Studies','Computer','Drawing','Physical Education'];
  subj_ids uuid[]; tuser uuid[] := '{}'; principal uuid; accountant uuid; reception uuid; librarian uuid; parent1 uuid; parent2 uuid; stud1 uuid; stud2 uuid;
  i int; n int := 0; k int; ct int := 0; cls record; dv record; r record; sid uuid; eid uuid; fn text; ln text; gen text; ex1 uuid; ex2 uuid;
  base numeric; mk numeric; d date; pid uuid; sf record; amt numeric; paid_target numeric; rc text; first_pay boolean;
  remarks text[] := array['Excellent work. Keep it up.','Good progress. Needs more practice in writing.','Very attentive and well behaved.','Can do better with regular revision.','Shows great interest in class activities.'];
  houses text[] := array['Red','Blue','Green','Yellow']; bloods text[] := array['A+','B+','O+','AB+','O-','B-'];
begin
  ---------------------------------------------------------------- years, subjects, fee types
  insert into academic_years (name, start_date, end_date, status, is_active) values ('2026-27','2026-06-01','2027-04-30','active', true) returning id into y1;
  insert into academic_years (name, start_date, end_date, status, is_active) values ('2027-28','2027-06-01','2028-04-30','upcoming', false) returning id into y2;
  for i in 1 .. 10 loop
    insert into subjects (name, sort_order) values (subj_names[i], i);
  end loop;
  select array_agg(id order by sort_order) into subj_ids from subjects;
  insert into fee_types (name) values ('Tuition Fee'), ('Examination Fee') on conflict (name) do nothing;
  select id into ft_t from fee_types where name = 'Tuition Fee'; select id into ft_e from fee_types where name = 'Examination Fee';

  ---------------------------------------------------------------- logins
  principal  := pg_temp.mk_user('principal@demo.example.com',  'Dr. Sunanda Kulkarni (Principal)', 'principal');
  accountant := pg_temp.mk_user('accountant@demo.example.com', 'Mahesh Joshi (Accountant)', 'accountant');
  reception  := pg_temp.mk_user('reception@demo.example.com',  'Pooja Shinde (Reception)', 'reception');
  librarian  := pg_temp.mk_user('librarian@demo.example.com',  'Anil More (Librarian)', 'librarian');
  for i in 1 .. 20 loop
    tuser := tuser || pg_temp.mk_user('teacher' || lpad(i::text, 2, '0') || '@demo.example.com', tnames[i], case when i <= 16 then 'class_teacher' else 'teacher' end);
  end loop;
  parent1 := pg_temp.mk_user('parent1@demo.example.com', 'Ramesh Patil (Parent)', 'parent');
  parent2 := pg_temp.mk_user('parent2@demo.example.com', 'Sanjay Pawar (Parent)', 'parent');
  stud1   := pg_temp.mk_user('student1@demo.example.com', 'Student Demo One', 'student');
  stud2   := pg_temp.mk_user('student2@demo.example.com', 'Student Demo Two', 'student');

  ---------------------------------------------------------------- teachers and staff records
  for i in 1 .. 20 loop
    insert into teachers (employee_id, profile_id, name, qualification, subject, mobile, email, joining_date, is_public)
    values ('T' || lpad(i::text, 3, '0'), tuser[i], tnames[i], case when i % 3 = 0 then 'M.A., B.Ed.' when i % 3 = 1 then 'B.Sc., B.Ed.' else 'D.Ed., B.A.' end,
      case when i = 17 then 'Hindi' when i = 18 then 'Computer' when i = 19 then 'Drawing' when i = 20 then 'Physical Education' else 'Class teacher' end,
      '98900' || lpad((10000 + i)::text, 5, '0'), 'teacher' || lpad(i::text, 2, '0') || '@demo.example.com', date '2015-06-15' + i * 90, i <= 8);
  end loop;
  insert into staff (employee_id, name, staff_type, mobile, joining_date) values
    ('S001','Mahesh Joshi','Administrative Staff','9890011111','2016-04-01'), ('S002','Pooja Shinde','Administrative Staff','9890022222','2019-06-10'),
    ('S003','Baban Gaikwad','Support Staff','9890033333','2014-06-01'), ('S004','Anil More','Non-Teaching Staff','9890044444','2018-07-01');

  ---------------------------------------------------------------- divisions: A for every class, B for Grade 1 to 4; next year A only
  for cls in select * from classes order by sort_order loop
    ct := ct + 1; insert into divisions (academic_year_id, class_id, name, class_teacher_id) values (y1, cls.id, 'A', tuser[ct]);
    if cls.sort_order between 3 and 6 then ct := ct + 1; insert into divisions (academic_year_id, class_id, name, class_teacher_id) values (y1, cls.id, 'B', tuser[ct]); end if;
    insert into divisions (academic_year_id, class_id, name) values (y2, cls.id, 'A');
  end loop;

  ---------------------------------------------------------------- subject teachers
  for dv in select d.id, d.class_teacher_id as ctid, c.sort_order as ord from divisions d join classes c on c.id = d.class_id where d.academic_year_id = y1 loop
    for i in 1 .. 10 loop
      if (dv.ord <= 2 and i in (1, 2, 4, 5, 9)) or (dv.ord between 3 and 7 and i in (1, 2, 3, 4, 5, 8, 9, 10)) or (dv.ord >= 8 and i in (1, 2, 3, 4, 6, 7, 8, 10)) then
        insert into class_subjects (academic_year_id, division_id, subject_id, teacher_id)
        values (y1, dv.id, subj_ids[i], case i when 3 then tuser[17] when 8 then tuser[18] when 9 then tuser[19] when 10 then tuser[20] else dv.ctid end);
      end if;
    end loop;
  end loop;

  ---------------------------------------------------------------- students, parents, enrollments
  create temp table _demo_enr (enr uuid, student uuid, division uuid, ord int, n int, y uuid) on commit drop;
  for dv in select d.id, c.sort_order as ord from divisions d join classes c on c.id = d.class_id where d.academic_year_id = y1 order by c.sort_order, d.name loop
    for k in 1 .. 12 loop
      n := n + 1; gen := case when k % 2 = 1 then 'Male' else 'Female' end;
      fn := case when gen = 'Male' then boys[(n * 7) % 16 + 1] else girls[(n * 5) % 16 + 1] end; ln := surn[(n * 3) % 18 + 1];
      insert into students (admission_no, gr_no, first_name, middle_name, last_name, gender, dob, blood_group, admission_date, admission_class, house, status)
      values ('SES26-' || lpad(n::text, 4, '0'), 'GR' || lpad(n::text, 4, '0'), fn, fath[(n * 3) % 10 + 1], ln, gen,
        make_date(2023 - dv.ord, 1 + n % 12, 1 + n % 27), bloods[n % 6 + 1], date '2026-06-10', case when dv.ord <= 2 then 'LKG' else 'Grade 1' end, houses[n % 4 + 1], 'active')
      returning id into sid;
      insert into student_enrollments (student_id, academic_year_id, division_id, status) values (sid, y1, dv.id, 'active') returning id into eid;
      insert into _demo_enr values (eid, sid, dv.id, dv.ord, n, y1);
      insert into student_guardians (student_id, relation, name, mobile, address) values
        (sid, 'father', fath[(n * 3) % 10 + 1] || ' ' || ln, '98' || lpad((50000000 + n * 137)::text, 8, '0'), 'Demo Nagar, Pune'),
        (sid, 'mother', moth[(n * 7) % 10 + 1] || ' ' || ln, '97' || lpad((60000000 + n * 211)::text, 8, '0'), 'Demo Nagar, Pune');
    end loop;
  end loop;
  with ranked as (select e.id, row_number() over (partition by e.division_id order by lower(s.last_name), lower(s.first_name), s.admission_no) rn
                  from student_enrollments e join students s on s.id = e.student_id)
  update student_enrollments e set roll_no = r.rn from ranked r where r.id = e.id;
  -- link demo parents and students to real records
  update student_guardians set user_id = parent1 where relation = 'father' and student_id in (select student from _demo_enr where n in (13, 14));   -- two children of one parent
  update student_guardians set user_id = parent2 where relation = 'father' and student_id in (select student from _demo_enr where n = 100);
  update students set user_id = stud1 where id = (select student from _demo_enr where n = 75);
  update students set user_id = stud2 where id = (select student from _demo_enr where n = 150);

  ---------------------------------------------------------------- calendar
  insert into school_calendar (day, kind, title) values
    ('2026-10-02','holiday','Gandhi Jayanti'), ('2026-10-20','holiday','Dussehra'), ('2026-11-09','vacation','Diwali break'), ('2026-11-10','vacation','Diwali break'),
    ('2026-11-11','vacation','Diwali break'), ('2026-11-12','vacation','Diwali break'), ('2026-12-25','holiday','Christmas'), ('2027-01-26','holiday','Republic Day'),
    ('2026-09-14','exam','First Term exam begins'), ('2026-10-24','parent_meeting','Parent-teacher meeting'), ('2026-12-14','event','Annual Day'),
    ('2026-10-17','special_day','Make-up working Sunday (demo)');

  ---------------------------------------------------------------- attendance (last 42 days, skipping holidays and weekly offs)
  insert into attendance (enrollment_id, att_date, status)
  with g as (select e.enr, d::date as dd, random() as x
             from _demo_enr e cross join generate_series(greatest(current_date - 42, date '2026-06-15'), least(current_date - 1, date '2027-04-30'), interval '1 day') d)
  select enr, dd, case when x < 0.90 then 'present' when x < 0.95 then 'absent' when x < 0.97 then 'late' when x < 0.985 then 'leave' else 'half_day' end
  from g where is_working_day(dd);
  insert into teacher_attendance (teacher_id, att_date, status)
  with g as (select t.id as tid, d::date as dd, random() as x
             from teachers t cross join generate_series(greatest(current_date - 20, date '2026-06-15'), least(current_date - 1, date '2027-04-30'), interval '1 day') d)
  select tid, dd, case when x < 0.93 then 'present' when x < 0.97 then 'leave' else 'late' end from g where is_working_day(dd);

  ---------------------------------------------------------------- First Term exam (published) with marks, and a draft Unit Test
  insert into exams (academic_year_id, name, exam_type, status) values (y1, 'First Term Examination 2026', 'First Term', 'draft') returning id into ex1;
  insert into exams (academic_year_id, name, exam_type, status) values (y1, 'Unit Test 2', 'Unit Test', 'draft') returning id into ex2;
  insert into exam_subjects (exam_id, division_id, subject_id, max_marks, passing_marks, exam_date, status)
  select ex1, cs.division_id, cs.subject_id, case when c.sort_order <= 2 then 50 else 100 end, case when c.sort_order <= 2 then 18 else 35 end,
         date '2026-09-14' + (row_number() over (partition by cs.division_id order by cs.subject_id))::int, 'open'
  from class_subjects cs join divisions d on d.id = cs.division_id join classes c on c.id = d.class_id where cs.academic_year_id = y1;
  insert into marks (exam_subject_id, enrollment_id, marks, absent)
  select x.id, e.enr, case when ab then null else least(x.max_marks, greatest(0, round(x.max_marks * (0.35 + 0.6 * ability + (random() - 0.5) * 0.18)))) end, ab
  from exam_subjects x join _demo_enr e on e.division = x.division_id
  cross join lateral (select ((e.n * 37) % 100) / 100.0 as ability, (random() < 0.01) as ab) q
  where x.exam_id = ex1;
  update exam_subjects set status = 'locked' where exam_id = ex1;
  update exams set status = 'published' where id = ex1;
  insert into report_remarks (exam_id, enrollment_id, teacher_remark, principal_remark)
  select ex1, enr, remarks[(n % 5) + 1], case when n % 7 = 0 then 'Well done.' else null end from _demo_enr;
  -- Unit Test 2: Grade 8 A subjects are open, ready for live marks entry in a presentation
  insert into exam_subjects (exam_id, division_id, subject_id, max_marks, passing_marks, exam_date, status)
  select ex2, cs.division_id, cs.subject_id, 25, 9, current_date + 3, 'open'
  from class_subjects cs join divisions d on d.id = cs.division_id join classes c on c.id = d.class_id where cs.academic_year_id = y1 and c.sort_order = 10 and d.name = 'A';

  ---------------------------------------------------------------- fees: tuition (grows with class) and exam fee, with a mix of payments
  insert into fee_structures (academic_year_id, class_id, fee_type_id, amount, frequency, due_date)
  select y1, id, ft_t, 8000 + sort_order * 1500, 'annual', date '2026-07-31' from classes;
  insert into fee_structures (academic_year_id, class_id, fee_type_id, amount, frequency, due_date)
  select y1, id, ft_e, 500, 'annual', date '2026-08-31' from classes;
  insert into student_fees (enrollment_id, fee_structure_id, fee_type_id, installment_no, assigned_amount, due_date)
  select e.enr, fs.id, fs.fee_type_id, 1, fs.amount, fs.due_date
  from _demo_enr e join divisions d on d.id = e.division join fee_structures fs on fs.class_id = d.class_id and fs.academic_year_id = y1;
  for sf in select f.id, f.assigned_amount as a, f.fee_type_id as t, e.n from student_fees f join _demo_enr e on e.enr = f.enrollment_id order by e.n loop
    if sf.t = ft_e then paid_target := case when sf.n % 3 = 0 then 0 else sf.a end;
    else paid_target := case sf.n % 5 when 0 then 0 when 1 then sf.a when 2 then sf.a when 3 then round(sf.a * 0.4) else round(sf.a * 0.7) end;
    end if;
    first_pay := true;
    while paid_target > 0 loop
      amt := case when sf.t = ft_t and sf.n % 5 = 2 and first_pay then round(paid_target * 0.6) else paid_target end;   -- some pay in two parts
      rc := coalesce(nullif(setting_text('receipt_prefix'), ''), 'R') || '26' || lpad(nextval('receipt_seq')::text, 6, '0');
      insert into fee_payments (student_fee_id, amount, payment_date, mode, reference_no, receipt_no, is_first)
      values (sf.id, amt, current_date - (sf.n % 50) - case when first_pay then 0 else 10 end, case when sf.n % 3 = 0 then 'upi' else 'cash' end,
              case when sf.n % 3 = 0 then 'UPI' || (700000 + sf.n * 13) else null end, rc, first_pay);
      paid_target := paid_target - amt; first_pay := false;
    end loop;
  end loop;
  -- three sibling concessions (10 percent) for students who have not paid tuition yet
  insert into fee_concessions (student_fee_id, concession_type, value, reason, approved_by, concession_date)
  select f.id, 'percent', 10, 'Sibling concession', principal, current_date - 5
  from student_fees f join _demo_enr e on e.enr = f.enrollment_id where f.fee_type_id = ft_t and f.paid_amount = 0 order by e.n limit 3;

  ---------------------------------------------------------------- notices, events, activities, achievements
  insert into notices (title, description, notice_date, priority, audience, is_public, status, created_by) values
    ('Welcome to the new academic year', 'School reopens with full attendance. Please check your child''s timetable and fee details in the portal.', current_date - 40, 'normal', 'everyone', true, 'published', principal),
    ('Parent-teacher meeting on 24 October', 'The meeting will be held from 10 am to 1 pm. Please bring the report card.', current_date - 3, 'important', 'parents', false, 'published', principal),
    ('Staff meeting', 'Staff meeting after school on Friday about the First Term results.', current_date - 1, 'normal', 'teachers', false, 'published', principal),
    ('Diwali holidays (draft)', 'The school will remain closed from 9 to 12 November.', current_date, 'normal', 'everyone', true, 'draft', principal);
  insert into events (title, event_type, description, event_date, start_time, end_time, venue, audience, is_public, status, created_by) values
    ('Teachers Day celebration', 'Teachers Day', 'Students present cultural programs for teachers.', '2026-09-05', '10:00', '12:00', 'School hall', 'everyone', true, 'published', principal),
    ('Annual Sports Day', 'Sports Day', 'Races, relay and march past.', current_date + 14, '08:00', '12:00', 'School ground', 'everyone', true, 'published', principal),
    ('Parent meeting', 'Parent Meeting', 'Discuss First Term progress with class teachers.', '2026-10-24', '10:00', '13:00', 'Classrooms', 'parents', false, 'published', principal),
    ('Annual Day', 'Annual Day', 'Cultural evening.', '2026-12-14', '17:00', '20:00', 'School hall', 'everyone', true, 'published', principal);
  insert into activities (academic_year_id, title, category, activity_date, teacher_id, result, notes)
  values (y1, 'Inter-school Quiz', 'Quiz', current_date - 20, tuser[5], 'Second place', 'Held at a nearby school'),
         (y1, 'Drawing Competition', 'Drawing', current_date - 30, tuser[19], 'Three prizes', 'House-wise competition'),
         (y1, 'Kabaddi Tournament', 'Sports', current_date - 10, tuser[20], 'Runners-up', 'Taluka level');
  insert into activity_participants (activity_id, enrollment_id, position)
  select a.id, e.enr, case when e.n % 9 = 0 then 'Winner' else 'Participant' end from activities a join _demo_enr e on e.n % 12 = 0 and e.ord >= 6 where a.title = 'Inter-school Quiz';
  insert into achievements (subject_type, enrollment_id, category, title, description, achievement_date, event_name, position, approval_status, is_public, created_by)
  select 'student', e.enr, 'Quiz', 'Second place in district quiz', 'Represented the school.', current_date - 20, 'Inter-school Quiz', '2nd', 'approved', true, principal from _demo_enr e where e.n = 130;
  insert into achievements (subject_type, enrollment_id, category, title, description, achievement_date, event_name, position, approval_status, is_public, created_by)
  select 'student', e.enr, 'Sports', 'Kabaddi runners-up', 'Taluka level.', current_date - 10, 'Kabaddi Tournament', 'Runner-up', 'approved', true, principal from _demo_enr e where e.n = 160;
  insert into achievements (subject_type, enrollment_id, category, title, description, achievement_date, event_name, position, approval_status, is_public, created_by)
  select 'student', e.enr, 'Drawing', 'Drawing competition prize', 'Waiting for approval.', current_date - 30, 'Drawing Competition', '3rd', 'pending', false, tuser[19] from _demo_enr e where e.n = 40;

  ---------------------------------------------------------------- library
  for i in 1 .. 20 loop
    insert into books (book_code, title, author, category, quantity, available_quantity, shelf, price, status)
    values ('B' || lpad(i::text, 4, '0'), (array['Shyamchi Aai','Gosht Ek Chimnichi','Panchatantra Stories','Wings of Fire','Malgudi Days','Science for Kids','Atlas of India','Marathi Vyakaran','Ramayana for Children','Maths Magic'])[(i - 1) % 10 + 1] || case when i > 10 then ' (Vol 2)' else '' end,
      (array['Sane Guruji','Various','Vishnu Sharma','A. P. J. Abdul Kalam','R. K. Narayan'])[(i - 1) % 5 + 1], (array['Story','Science','Reference','Language'])[(i - 1) % 4 + 1], 4, 4, 'Shelf ' || ((i - 1) % 5 + 1), 120 + i * 5, 'active');
  end loop;
  insert into book_transactions (book_id, borrower_type, enrollment_id, issue_date, due_date, status, issued_by)
  select b.id, 'student', e.enr, current_date - 20, current_date - 6, 'issued', librarian from (select id from books order by book_code limit 3) b join _demo_enr e on e.n = 60 + (select count(*) from books x where x.book_code < (select book_code from books where id = b.id)) * 7;
  insert into book_transactions (book_id, borrower_type, enrollment_id, issue_date, due_date, status, issued_by)
  select b.id, 'student', e.enr, current_date - 3, current_date + 11, 'issued', librarian from (select id from books order by book_code offset 3 limit 3) b join _demo_enr e on e.n = 90 + (select count(*) from books x where x.book_code < (select book_code from books where id = b.id)) * 5;
  insert into book_transactions (book_id, borrower_type, enrollment_id, issue_date, due_date, return_date, status, issued_by)
  select b.id, 'student', e.enr, current_date - 30, current_date - 16, current_date - 17, 'returned', librarian from (select id from books order by book_code offset 6 limit 3) b join _demo_enr e on e.n = 20 + (select count(*) from books x where x.book_code < (select book_code from books where id = b.id)) * 3;
  update books b set available_quantity = quantity - (select count(*) from book_transactions t where t.book_id = b.id and t.status = 'issued');

  ---------------------------------------------------------------- admission enquiries
  perform submit_enquiry('Aarohi Kulkarni', date '2022-05-14', 'Female', (select id from classes where name = 'LKG'), 'Vikram Kulkarni', '9822011111', 'vikram@example.com', 'Kothrud, Pune', null, null, 'Please share the fee details.');
  perform submit_enquiry('Neel Deshmukh', date '2020-02-02', 'Male', (select id from classes where name = 'Grade 1'), 'Anita Deshmukh', '9822022222', null, 'Baner, Pune', 'Little Stars School', 'UKG', 'Looking for admission in Grade 1.');
  perform submit_enquiry('Siddhi Jadhav', date '2016-09-09', 'Female', (select id from classes where name = 'Grade 5'), 'Prakash Jadhav', '9822033333', null, 'Wakad, Pune', 'City School', 'Grade 4', 'Transfer from another city.');
  perform submit_enquiry('Rudra Pawar', date '2021-01-21', 'Male', (select id from classes where name = 'UKG'), 'Sheetal Pawar', '9822044444', null, 'Aundh, Pune', null, null, null);
  update admission_enquiries set status = 'contacted' where student_name = 'Neel Deshmukh';
  update admission_enquiries set status = 'follow_up' where student_name = 'Siddhi Jadhav';

  ---------------------------------------------------------------- transport
  insert into transport_routes (name, vehicle_no, driver_name, driver_contact, pickup_time, drop_time, status) values
    ('Route 1: Kothrud - School', 'MH12 AB 1001', 'Ganpat Shinde', '9890055555', '07:10', '14:30', 'active'),
    ('Route 2: Baner - School', 'MH12 CD 2002', 'Sudhir Kale', '9890066666', '07:00', '14:40', 'active');
  insert into transport_stops (route_id, name, stop_order)
  select r.id, s.name, s.o from transport_routes r join (values (1,'Karve Road',1),(1,'Paud Road',2),(1,'Mayur Colony',3),(1,'Main Gate',4)) s(rn,name,o) on r.name like 'Route 1%'
  union all select r.id, s.name, s.o from transport_routes r join (values ('Baner Gaon',1),('Balewadi',2),('Pashan',3),('Main Gate',4)) s(name,o) on r.name like 'Route 2%';
  insert into transport_assignments (enrollment_id, route_id, stop_id, start_date, status)
  select e.enr, r.id, (select id from transport_stops s where s.route_id = r.id order by stop_order offset (e.n % 3) limit 1), date '2026-06-15', 'active'
  from _demo_enr e join transport_routes r on r.name like case when e.n % 2 = 0 then 'Route 1%' else 'Route 2%' end where e.n % 13 = 0;

  ---------------------------------------------------------------- staff leave
  insert into leave_requests (teacher_id, leave_type, start_date, end_date, reason, applied_date, status, approved_by)
  select t.id, 'sick', current_date - 12, current_date - 11, 'Fever', current_date - 13, 'approved', principal from teachers t where employee_id = 'T004';
  insert into leave_requests (teacher_id, leave_type, start_date, end_date, reason, applied_date, status)
  select t.id, 'casual', current_date + 5, current_date + 6, 'Family function', current_date - 1, 'pending' from teachers t where employee_id = 'T009';
  insert into leave_requests (staff_id, leave_type, start_date, end_date, reason, applied_date, status)
  select s.id, 'casual', current_date + 2, current_date + 2, 'Personal work', current_date, 'pending' from staff s where employee_id = 'S003';

  ---------------------------------------------------------------- timetable and homework (Grade 5 A and Grade 8 A)
  for dv in select d.id, d.class_teacher_id from divisions d join classes c on c.id = d.class_id where d.academic_year_id = y1 and d.name = 'A' and c.sort_order in (7) loop
    for k in 1 .. 6 loop
      for i in 1 .. 6 loop
        insert into timetable_slots (academic_year_id, division_id, day, period, subject_id, teacher_id, start_time, end_time, room)
        select y1, dv.id, k, i, cs.subject_id, cs.teacher_id, time '08:00' + (i - 1) * interval '45 minutes', time '08:00' + (i - 1) * interval '45 minutes' + interval '40 minutes', 'Room 5A'
        from (select subject_id, teacher_id, row_number() over (order by subject_id) rn, count(*) over () cnt from class_subjects where division_id = dv.id) cs
        where cs.rn = ((k + i) % cs.cnt) + 1;
      end loop;
    end loop;
  end loop;
  insert into homework (academic_year_id, division_id, subject_id, teacher_id, homework_date, due_date, title, description, status)
  select y1, cs.division_id, cs.subject_id, cs.teacher_id, current_date - 1, current_date + 3, h.t, h.d, 'active'
  from class_subjects cs join divisions d on d.id = cs.division_id join classes c on c.id = d.class_id
  join (values (4, 'Chapter 5 exercises', 'Solve exercise 5.1 and 5.2 in your notebook.'), (1, 'Essay: My School', 'Write ten lines about your school.'), (2, 'Poem recitation', 'Learn the first two stanzas.')) h(s, t, d) on cs.subject_id = subj_ids[h.s]
  where cs.academic_year_id = y1 and d.name = 'A' and c.sort_order in (7, 10);

  ---------------------------------------------------------------- notifications for the demo parent
  insert into notifications (user_id, title, message, type, related_module) values
    (parent1, 'Parent-teacher meeting on 24 October', 'Please bring the report card.', 'notice', 'notices'),
    (parent1, 'First Term results are published', 'You can see the marks in the portal.', 'exam', 'results'),
    (parent2, 'Fee reminder', 'Tuition fee balance is pending.', 'fee', 'fees');
  insert into audit_logs (user_id, action, module, record_id) values (null, 'Demo data loaded', 'maintenance', null);
end $demo$;

select 'DEMO DATA loaded' as result,
  (select count(*) from students) as students, (select count(*) from student_enrollments) as enrollments, (select count(*) from divisions where academic_year_id = (select id from academic_years where is_active)) as divisions,
  (select count(*) from teachers) as teachers, (select count(*) from attendance) as attendance_rows, (select count(*) from marks) as marks_rows,
  (select count(*) from fee_payments) as payments, (select round(sum(balance)) from student_fees) as total_fee_balance;
