-- Phase 27 (round 13b): undo a wrong boarding tick on the running trip. Safe to run more than once.
create or replace function driver_unboard(p_token text, p_admission text) returns jsonb language plpgsql security definer set search_path = public as $$
declare rid uuid; rn text; b bus_live%rowtype; eid uuid; sid uuid; fn text; del int;
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
  delete from bus_boarding where route_id = rid and enrollment_id = eid and event_date = current_date and trip = b.trip;
  get diagnostics del = row_count;
  if del > 0 then
    begin
      insert into notifications (user_id, title, message, type, related_module, related_record)
      select distinct g.user_id, 'Correction: ' || fn || ' bus note',
        'The earlier bus note for ' || fn || ' was a mistake and has been removed. / ' || fn || ' ची आधीची बसमधील नोंद चुकून झाली होती, ती काढली आहे.',
        'notice', 'transport', rid::text
      from student_guardians g join profiles p on p.id = g.user_id and p.is_active where g.student_id = sid and g.user_id is not null;
    exception when others then null; end;
  end if;
  return jsonb_build_object('ok', true, 'name', fn, 'removed', del > 0);
end $$;
revoke all on function driver_unboard(text, text) from public;
grant execute on function driver_unboard(text, text) to anon, authenticated;
select 'phase27 finished' as result;
