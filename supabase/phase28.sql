-- Phase 28 (round 14): the dashboard no longer says 'divisions not marked today' on holidays and weekly offs. Safe to run more than once.
create or replace function dashboard_overview() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare r text := current_role_name()::text; yr uuid; res jsonb := '{}'::jsonb; fin boolean := fees_staff();
  adm boolean := is_admin(); school boolean := r in ('super_admin','school_admin','principal','reception','accountant');
begin
  if r is null or r not in ('super_admin','school_admin','principal','accountant','reception','librarian') then raise exception 'not allowed'; end if;
  select id into yr from academic_years where is_active limit 1;
  res := jsonb_build_object('role', r, 'year', (select name from academic_years where id = yr));
  if r <> 'librarian' then
    res := res || jsonb_build_object(
      'students', (select count(*) from student_enrollments where academic_year_id = yr and status = 'active'),
      'teachers', (select count(*) from teachers where status = 'active'),
      'classes', (select count(*) from classes),
      'divisions', (select count(*) from divisions where academic_year_id = yr));
  end if;
  if r in ('super_admin','school_admin','principal','reception') then
    res := res || jsonb_build_object(
      'att_today', (select coalesce(jsonb_object_agg(status, n), '{}'::jsonb) from (select a.status, count(*) n from attendance a join student_enrollments e on e.id = a.enrollment_id where a.att_date = current_date and e.academic_year_id = yr group by a.status) t),
      'att_days', (select coalesce(jsonb_agg(jsonb_build_object('d', d, 'p', p, 'n', n) order by d), '[]'::jsonb) from (
          select a.att_date d, count(*) filter (where a.status in ('present','late','half_day')) p, count(*) n
          from attendance a join student_enrollments e on e.id = a.enrollment_id
          where a.att_date >= current_date - 13 and e.academic_year_id = yr group by a.att_date) t),
      'att_classes', (select coalesce(jsonb_agg(jsonb_build_object('c', c, 'p', p, 'n', n) order by so), '[]'::jsonb) from (
          select c.name c, c.sort_order so, count(*) filter (where a.status in ('present','late','half_day')) p, count(*) n
          from attendance a join student_enrollments e on e.id = a.enrollment_id join divisions d on d.id = e.division_id join classes c on c.id = d.class_id
          where a.att_date = current_date and e.academic_year_id = yr group by c.name, c.sort_order) t),
      'att_unmarked', (select count(*) from divisions d where is_working_day(current_date) and d.academic_year_id = yr and exists (select 1 from student_enrollments e where e.division_id = d.id and e.status = 'active')
          and not exists (select 1 from attendance a join student_enrollments e on e.id = a.enrollment_id where e.division_id = d.id and a.att_date = current_date)),
      'gender', (select coalesce(jsonb_object_agg(g, n), '{}'::jsonb) from (select s.gender g, count(*) n from students s join student_enrollments e on e.student_id = s.id where e.academic_year_id = yr and e.status = 'active' group by s.gender) t),
      'strength', (select coalesce(jsonb_agg(jsonb_build_object('c', c, 'n', n) order by so), '[]'::jsonb) from (
          select c.name c, c.sort_order so, count(*) n from student_enrollments e join divisions d on d.id = e.division_id join classes c on c.id = d.class_id
          where e.academic_year_id = yr and e.status = 'active' group by c.name, c.sort_order) t),
      'pending_requests', (select count(*) from parent_requests where status = 'pending'),
      'pending_leave', (select count(*) from leave_requests where status = 'pending'),
      'events', (select coalesce(jsonb_agg(jsonb_build_object('t', title, 'd', event_date) order by event_date), '[]'::jsonb) from (select title, event_date from events where event_date >= current_date order by event_date limit 5) t),
      'notices', (select count(*) from notices where notice_date >= current_date - 7));
  end if;
  if fin then
    res := res || jsonb_build_object(
      'fees', (select jsonb_build_object('billed', coalesce(sum(assigned_amount - concession_amount), 0), 'paid', coalesce(sum(paid_amount), 0),
          'balance', coalesce(sum(balance), 0), 'overdue', coalesce(sum(balance) filter (where due_date < current_date), 0),
          'overdue_n', count(distinct enrollment_id) filter (where balance > 0 and due_date < current_date))
          from student_fees f join student_enrollments e on e.id = f.enrollment_id where e.academic_year_id = yr),
      'fee_months', (select coalesce(jsonb_agg(jsonb_build_object('m', m, 'a', a) order by m), '[]'::jsonb) from (
          select to_char(date_trunc('month', payment_date), 'YYYY-MM') m, sum(amount) a from fee_payments
          where payment_date >= date_trunc('month', current_date) - interval '5 months' group by 1) t),
      'fee_today', (select coalesce(sum(amount), 0) from fee_payments where payment_date = current_date),
      'pending_claims', (select count(*) from payment_claims where status = 'pending'));
  end if;
  return res;
end $$;
revoke all on function dashboard_overview() from public, anon; grant execute on function dashboard_overview() to authenticated;
select 'phase28 finished' as result;
