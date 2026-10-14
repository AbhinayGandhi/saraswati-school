-- Phase 18 (round 5A): bus boarding scan, photo uploads, student insights. Safe to run more than once. Nothing is deleted.

-- 1) Bus boarding: driver scans the student's ID card QR. Pickup trip = "boarded", drop trip = "got off". Parents get a notification.
create table if not exists bus_boarding (
  id uuid primary key default gen_random_uuid(), route_id uuid not null references transport_routes(id) on delete cascade,
  enrollment_id uuid not null references student_enrollments(id) on delete cascade,
  trip text not null check (trip in ('pickup','drop')), event text not null check (event in ('board','alight')),
  event_date date not null default current_date, at timestamptz not null default now(),
  unique (enrollment_id, event_date, trip, event)
);
create index if not exists bus_boarding_route_day on bus_boarding (route_id, event_date);
alter table bus_boarding enable row level security;
drop policy if exists bb_read on bus_boarding;
create policy bb_read on bus_boarding for select to authenticated using (can_manage_transport() or is_guardian_of_enrollment(enrollment_id));

create or replace function driver_board(p_token text, p_admission text) returns jsonb language plpgsql security definer set search_path = public as $$
declare rid uuid; rn text; b bus_live%rowtype; eid uuid; sid uuid; fn text; ev text; ins int; total int; done int; tm text;
begin
  if p_token is null or length(p_token) < 32 or p_admission is null or length(p_admission) > 40 then return jsonb_build_object('ok', false, 'error', 'bad_request'); end if;
  select k.route_id, r.name into rid, rn from transport_driver_keys k join transport_routes r on r.id = k.route_id where k.token = p_token and r.status = 'active';
  if rid is null then return jsonb_build_object('ok', false, 'error', 'bad_key'); end if;
  select * into b from bus_live where route_id = rid;
  if b.route_id is null or not b.trip_active then return jsonb_build_object('ok', false, 'error', 'no_trip'); end if;
  select e.id, s.id, s.first_name into eid, sid, fn
    from students s join student_enrollments e on e.student_id = s.id and e.status = 'active'
    join transport_assignments a on a.enrollment_id = e.id and a.route_id = rid and a.status = 'active'
    where s.admission_no = trim(p_admission) limit 1;
  if eid is null then return jsonb_build_object('ok', false, 'error', 'not_on_route'); end if;
  ev := case b.trip when 'pickup' then 'board' else 'alight' end;
  insert into bus_boarding (route_id, enrollment_id, trip, event) values (rid, eid, b.trip, ev) on conflict do nothing;
  get diagnostics ins = row_count;
  if ins = 1 then
    tm := to_char(now() at time zone 'Asia/Kolkata', 'HH12:MI AM');
    begin
      insert into notifications (user_id, title, message, type, related_module, related_record)
      select distinct g.user_id,
        case ev when 'board' then fn || ' boarded the bus' else fn || ' got off the bus' end,
        case ev when 'board' then fn || ' boarded the school bus (' || rn || ') at ' || tm || '. / ' || fn || ' स्कूल बसमध्ये ' || tm || ' वाजता चढले.'
                else fn || ' got off the school bus (' || rn || ') at ' || tm || '. / ' || fn || ' स्कूल बसमधून ' || tm || ' वाजता उतरले.' end,
        'notice', 'transport', rid::text
      from student_guardians g join profiles p on p.id = g.user_id and p.is_active where g.student_id = sid and g.user_id is not null;
    exception when others then null; end;
  end if;
  select count(*) into total from transport_assignments where route_id = rid and status = 'active';
  select count(*) into done from bus_boarding where route_id = rid and event_date = current_date and trip = b.trip;
  return jsonb_build_object('ok', true, 'name', fn, 'event', ev, 'repeat', ins = 0, 'done', done, 'total', total);
end $$;
revoke all on function driver_board(text, text) from public;
grant execute on function driver_board(text, text) to anon, authenticated;

-- 2) Photos: private bucket, small JPEG/PNG/WebP (max 1 MB). A photo can be opened only by people who may already see that student or teacher row.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('photos','photos',false,1048576,array['image/jpeg','image/png','image/webp']) on conflict (id) do nothing;
drop policy if exists ph_read on storage.objects;
drop policy if exists ph_write on storage.objects;
drop policy if exists ph_delete on storage.objects;
create policy ph_read on storage.objects for select to authenticated using (bucket_id = 'photos' and (
  exists (select 1 from students s where s.photo_path = name) or exists (select 1 from teachers t where t.photo_path = name)));
create policy ph_write on storage.objects for insert to authenticated with check (bucket_id = 'photos' and (is_admin() or can_front_office()));
create policy ph_delete on storage.objects for delete to authenticated using (bucket_id = 'photos' and (is_admin() or can_front_office()));

-- 3) Insights: simple, explainable risk flags from attendance (last 30 days), marks trend and overdue fees. No guessing, no outside service.
drop function if exists student_insights(uuid);
create function student_insights(p_division uuid default null)
returns table (enrollment_id uuid, student_id uuid, student_name text, admission_no text, class_name text, division_name text, att_pct numeric, absent_streak int,
               last_exam text, last_pct numeric, prev_pct numeric, overdue numeric, risk_score int, reasons text[])
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare staff boolean := is_admin(); show_fees boolean := fees_staff();
begin
  if not staff and current_role_name() not in ('teacher','class_teacher') then raise exception 'not allowed'; end if;
  return query
  with en as (
    select e.id eid, s.id sid, trim(concat_ws(' ', s.first_name, s.last_name)) nm, s.admission_no adm, c.name cn, d.name dn, c.sort_order so
    from student_enrollments e join academic_years y on y.id = e.academic_year_id and y.is_active
    join students s on s.id = e.student_id join divisions d on d.id = e.division_id join classes c on c.id = d.class_id
    where e.status = 'active' and (p_division is null or d.id = p_division) and (staff or d.class_teacher_id = auth.uid())),
  att as (
    select a.enrollment_id eid, count(*) n, count(*) filter (where a.status in ('present','late','half_day')) ok
    from attendance a join en on en.eid = a.enrollment_id where a.att_date >= current_date - 30 group by a.enrollment_id),
  streak as (
    select en.eid, coalesce(
      (select min(t.rn) - 1 from (select a.status, row_number() over (order by a.att_date desc) rn from attendance a
         where a.enrollment_id = en.eid and a.att_date >= current_date - 30) t where t.status <> 'absent'),
      (select count(*) from attendance a where a.enrollment_id = en.eid and a.att_date >= current_date - 30)) st from en),
  ex as (
    select m.enrollment_id eid, x.id xid, x.name xn, x.created_at xc,
           100.0 * sum(m.marks) / nullif(sum(es.max_marks), 0) pct
    from marks m join exam_subjects es on es.id = m.exam_subject_id join exams x on x.id = es.exam_id
    join en on en.eid = m.enrollment_id where m.marks is not null and not m.absent group by m.enrollment_id, x.id, x.name, x.created_at),
  rk as (select ex.*, row_number() over (partition by eid order by xc desc) r from ex),
  fee as (select f.enrollment_id eid, sum(f.balance) ov from student_fees f join en on en.eid = f.enrollment_id where f.balance > 0 and f.due_date < current_date group by f.enrollment_id),
  base as (
    select en.*, case when att.n >= 5 then round(100.0 * att.ok / att.n, 1) end ap, coalesce(streak.st, 0)::int stk,
           l.xn lxn, round(l.pct, 1) lp, round(p.pct, 1) pp, case when show_fees then coalesce(fee.ov, 0) end ovd
    from en left join att on att.eid = en.eid left join streak on streak.eid = en.eid
    left join rk l on l.eid = en.eid and l.r = 1 left join rk p on p.eid = en.eid and p.r = 2 left join fee on fee.eid = en.eid)
  select b.eid, b.sid, b.nm, b.adm, b.cn, b.dn, b.ap, b.stk, b.lxn, b.lp, b.pp, b.ovd,
    (case when b.ap < 75 then 2 when b.ap < 85 then 1 else 0 end + case when b.stk >= 3 then 2 else 0 end
     + case when b.lp is not null and b.lp < 35 then 2 when b.lp is not null and b.lp < 50 then 1 else 0 end
     + case when b.lp is not null and b.pp is not null and b.pp - b.lp >= 15 then 2 else 0 end + case when coalesce(b.ovd, 0) > 0 then 1 else 0 end)::int,
    array_remove(array[
      case when b.ap < 85 then 'Attendance ' || b.ap || '% in the last 30 days' end,
      case when b.stk >= 3 then 'Absent ' || b.stk || ' school days in a row' end,
      case when b.lp is not null and b.lp < 50 then 'Low marks in ' || b.lxn || ' (' || b.lp || '%)' end,
      case when b.lp is not null and b.pp is not null and b.pp - b.lp >= 15 then 'Marks fell from ' || b.pp || '% to ' || b.lp || '%' end,
      case when coalesce(b.ovd, 0) > 0 then 'Overdue fees Rs ' || b.ovd end], null)
  from base b order by 12 desc, b.so, b.dn, b.nm;
end $$;
revoke all on function student_insights(uuid) from public, anon;
grant execute on function student_insights(uuid) to authenticated;
select 'phase18 finished' as result;
