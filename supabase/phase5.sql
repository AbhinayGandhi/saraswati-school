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
