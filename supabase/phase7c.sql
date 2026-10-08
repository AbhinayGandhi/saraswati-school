-- Update 7c: simpler fee model. A student has ONE total fee per fee type per year; parents may pay any amount at any time.
-- Run ONCE on your existing project. Safe: it checks that totals match before and after, and stops (rolls back) if anything differs.
alter table fee_payments drop constraint if exists fee_payments_receipt_fee_uq;
create index if not exists fee_payments_receipt_idx on fee_payments (receipt_no);

create temp table _fee_before as
  select enrollment_id, fee_structure_id, sum(assigned_amount) a, sum(paid_amount) p, sum(concession_amount) c
  from student_fees where fee_structure_id is not null group by 1, 2;

do $$
declare g record; keep uuid; tot numeric; last_due date;
begin
  for g in select enrollment_id, fee_structure_id from student_fees where fee_structure_id is not null group by 1, 2 having count(*) > 1 loop
    select id into keep from student_fees where enrollment_id = g.enrollment_id and fee_structure_id = g.fee_structure_id order by installment_no, id limit 1;
    select sum(assigned_amount), max(due_date) into tot, last_due from student_fees where enrollment_id = g.enrollment_id and fee_structure_id = g.fee_structure_id;
    update fee_payments set student_fee_id = keep where student_fee_id in
      (select id from student_fees where enrollment_id = g.enrollment_id and fee_structure_id = g.fee_structure_id and id <> keep);
    update fee_concessions set student_fee_id = keep where student_fee_id in
      (select id from student_fees where enrollment_id = g.enrollment_id and fee_structure_id = g.fee_structure_id and id <> keep);
    delete from student_fees where enrollment_id = g.enrollment_id and fee_structure_id = g.fee_structure_id and id <> keep;
    update student_fees set assigned_amount = tot, due_date = last_due, installment_no = 1 where id = keep;
    perform recalc_student_fee(keep);
  end loop;
end $$;

do $$
begin
  if exists (select 1 from _fee_before b join (select enrollment_id, fee_structure_id, sum(assigned_amount) a, sum(paid_amount) p, sum(concession_amount) c
        from student_fees where fee_structure_id is not null group by 1, 2) n using (enrollment_id, fee_structure_id)
      where b.a <> n.a or b.p <> n.p or b.c <> n.c) then
    raise exception 'Totals changed during the merge. Nothing was saved.'; end if;
end $$;

update fee_structures set
  amount = amount * case frequency when 'monthly' then 12 when 'quarterly' then 4 when 'half_yearly' then 2 else 1 end,
  due_date = (due_date + (case frequency when 'monthly' then 11 when 'quarterly' then 9 when 'half_yearly' then 6 else 0 end) * interval '1 month')::date,
  frequency = 'annual';
alter table fee_structures alter column frequency set default 'annual';

create or replace function fee_structure_guard() returns trigger language plpgsql as $$
begin
  if exists (select 1 from fee_structures x where x.academic_year_id = new.academic_year_id and x.class_id = new.class_id
      and x.fee_type_id = new.fee_type_id and x.id <> new.id) then
    raise exception 'duplicate fee structure'; end if;
  return new;
end $$;
drop trigger if exists fs_guard on fee_structures;
create trigger fs_guard before insert or update on fee_structures for each row execute function fee_structure_guard();

create or replace function student_fee_dup_guard() returns trigger language plpgsql as $$
begin
  if exists (select 1 from student_fees f where f.enrollment_id = new.enrollment_id and f.fee_type_id = new.fee_type_id) then
    raise exception 'duplicate fee for student'; end if;
  return new;
end $$;
drop trigger if exists sf_dup_guard on student_fees;
create trigger sf_dup_guard before insert on student_fees for each row execute function student_fee_dup_guard();

create or replace function assign_fee_structure(p_id uuid) returns text language plpgsql security definer set search_path = public as $$
declare s fee_structures; ins_n bigint; tot_n bigint;
begin
  if not can_manage_fees() then raise exception 'not allowed'; end if;
  select * into s from fee_structures where id = p_id;
  if not found then raise exception 'not found'; end if;
  select count(*) into tot_n from student_enrollments e join divisions d on d.id = e.division_id
    where e.academic_year_id = s.academic_year_id and e.status = 'active' and d.class_id = s.class_id and (s.division_id is null or d.id = s.division_id);
  with ins as (
    insert into student_fees (enrollment_id, fee_structure_id, fee_type_id, installment_no, assigned_amount, due_date)
    select e.id, s.id, s.fee_type_id, 1, s.amount, s.due_date from student_enrollments e join divisions d on d.id = e.division_id
    where e.academic_year_id = s.academic_year_id and e.status = 'active' and d.class_id = s.class_id and (s.division_id is null or d.id = s.division_id)
      and not exists (select 1 from student_fees f where f.enrollment_id = e.id and f.fee_type_id = s.fee_type_id)
    returning 1)
  select count(*) into ins_n from ins;
  return ins_n || ',' || tot_n;
end $$;
revoke all on function assign_fee_structure(uuid) from public, anon;
grant execute on function assign_fee_structure(uuid) to authenticated;

-- Built-in checker for the Fee check page.
create or replace function fee_integrity_check(p_year uuid) returns table (section text, detail text, n bigint) language plpgsql stable security definer set search_path = public as $$
begin
  if not fees_staff() then raise exception 'not allowed'; end if;
  return query
  select 'Fee structure'::text, (c.name || coalesce(' - ' || dv.name, ' (all divisions)') || ' | ' || ft.name || ' | ' || s.amount::text)::text,
    (select count(*) from student_fees f where f.fee_structure_id = s.id)
  from fee_structures s join classes c on c.id = s.class_id join fee_types ft on ft.id = s.fee_type_id left join divisions dv on dv.id = s.division_id
  where s.academic_year_id = p_year
  union all
  select 'Student has the same fee more than once'::text, (st.first_name || ' ' || st.last_name || ' (' || st.admission_no || ') | ' || ft.name)::text, count(*)
  from student_fees f join student_enrollments e on e.id = f.enrollment_id join students st on st.id = e.student_id join fee_types ft on ft.id = f.fee_type_id
  where e.academic_year_id = p_year group by st.id, st.first_name, st.last_name, st.admission_no, ft.id, ft.name having count(*) > 1
  union all
  select 'Fee belongs to a different class than the student'::text, (st.first_name || ' ' || st.last_name || ' (' || st.admission_no || ') is in ' || c1.name || ' but has ' || ft.name || ' of ' || c2.name)::text, 1::bigint
  from student_fees f join student_enrollments e on e.id = f.enrollment_id join divisions d on d.id = e.division_id join classes c1 on c1.id = d.class_id
    join students st on st.id = e.student_id join fee_structures s on s.id = f.fee_structure_id join classes c2 on c2.id = s.class_id join fee_types ft on ft.id = f.fee_type_id
  where e.academic_year_id = p_year and s.class_id <> d.class_id
  union all
  select 'Old installment rows still present'::text, 'rows with installment number above 1'::text, count(*)
  from student_fees f join student_enrollments e on e.id = f.enrollment_id where e.academic_year_id = p_year and f.installment_no > 1 having count(*) > 0;
end $$;
revoke all on function fee_integrity_check(uuid) from public, anon;
grant execute on function fee_integrity_check(uuid) to authenticated;
