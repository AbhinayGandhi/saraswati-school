-- Phase 26 (round 13): bus helper checklist. The driver/attendant page can list the children on this bus and tick them. Safe to run more than once. Nothing is deleted.
-- Works with the bus secret token only. Shows first name, last initial, admission no, stop name and whether the child is already noted on the running trip.
create or replace function driver_roster(p_token text) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare rid uuid; b bus_live%rowtype; r jsonb;
begin
  if p_token is null or length(p_token) < 32 then return jsonb_build_object('ok', false, 'error', 'bad_key'); end if;
  select k.route_id into rid from transport_driver_keys k join transport_routes t on t.id = k.route_id where k.token = p_token and t.status = 'active';
  if rid is null then return jsonb_build_object('ok', false, 'error', 'bad_key'); end if;
  select * into b from bus_live where route_id = rid;
  if b.route_id is null or not b.trip_active then return jsonb_build_object('ok', false, 'error', 'no_trip'); end if;
  select coalesce(jsonb_agg(x order by x->>'stop', x->>'name'), '[]'::jsonb) into r from (
    select jsonb_build_object(
      'adm', s.admission_no,
      'name', trim(s.first_name || ' ' || coalesce(left(s.last_name, 1) || '.', '')),
      'stop', coalesce(st.name, ''),
      'done', exists (select 1 from bus_boarding bb where bb.enrollment_id = e.id and bb.route_id = rid and bb.event_date = current_date and bb.trip = b.trip)
    ) x
    from transport_assignments a join student_enrollments e on e.id = a.enrollment_id and e.status = 'active'
    join students s on s.id = e.student_id left join transport_stops st on st.id = a.stop_id
    where a.route_id = rid and a.status = 'active') q;
  return jsonb_build_object('ok', true, 'trip', b.trip, 'rows', r);
end $$;
revoke all on function driver_roster(text) from public;
grant execute on function driver_roster(text) to anon, authenticated;
select 'phase26 finished' as result;
