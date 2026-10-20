-- ============================================================================
-- DEMO-KOREGAON.sql : puts the DEMO "Route 1" on the real Koregaon map.
--   School (Main Gate)   : 17.701004, 74.174376  (copied from Google Maps)
--   New ST Stand pickup  : 17.703876, 74.160626                             (copied from Google Maps)
-- Safe to run again. DEMO data only; run it before the demo, never on real data.
-- What it does: Route 1 gets 2 stops (1. New ST Stand, 2. Main Gate = school). Children from the old
-- demo stops (Karve Road, Mayur Colony) are moved to the ST Stand stop, then those two stops are removed.
-- Then a 'Home stop (demo)' is added between them (lat 17.705964, lng 74.159893) and parent1's child is moved to it,
-- so the bus comes to the home stop and the distance shows. Move it later on the Transport page if needed.
-- Route 2 (Baner, Pune) is not touched.
-- ============================================================================
do $x$ declare r uuid; st uuid; mg uuid; ka uuid; mc uuid; hs uuid; p uuid;
begin
  select id into r from transport_routes where name like 'Route 1%' limit 1;
  if r is null then raise notice 'Route 1 not found'; return; end if;
  select id into st from transport_stops where route_id = r and name in ('Paud Road','New ST Stand') order by stop_order limit 1;
  select id into mg from transport_stops where route_id = r and name = 'Main Gate';
  select id into ka from transport_stops where route_id = r and name = 'Karve Road';
  select id into mc from transport_stops where route_id = r and name = 'Mayur Colony';
  if st is null or mg is null then raise notice 'expected stops not found'; return; end if;
  update transport_assignments set stop_id = st where stop_id in (coalesce(ka, st), coalesce(mc, st)) and stop_id <> st;
  delete from transport_stops where id in (ka, mc) and not exists (select 1 from transport_assignments a where a.stop_id = transport_stops.id);
  update transport_stops set name = 'New ST Stand', stop_order = 1, lat = 17.703876, lng = 74.160626 where id = st;
  update transport_stops set stop_order = 3, lat = 17.701004, lng = 74.174376 where id = mg;
  -- demo HOME stop (the presenter's home, 245 m from the ST Stand): parent1's child is picked up here
  insert into transport_stops (route_id, name, stop_order, lat, lng) values (r, 'Home stop (demo)', 2, 17.705964, 74.159893)
    on conflict (route_id, name) do update set stop_order = 2, lat = excluded.lat, lng = excluded.lng;
  select id into hs from transport_stops where route_id = r and name = 'Home stop (demo)';
  select id into p from auth.users where email = 'parent1@demo.example.com';
  if p is not null then
    update transport_assignments set stop_id = hs where status = 'active' and route_id = r
      and enrollment_id in (select en.id from student_enrollments en join student_guardians g on g.student_id = en.student_id and g.user_id = p);
  end if;
  update transport_routes set name = 'Route 1: Koregaon ST Stand - School' where id = r and name like 'Route 1: Kothrud%';
  -- demo bus: a little before the ST Stand, so "near the stop" shows
  insert into bus_live (route_id, lat, lng, speed_kmh, heading, accuracy_m, trip, trip_active, started_at, updated_at)
  values (r, 17.705453, 74.160073, 0, 90, 10, 'pickup', false, now(), now())
  on conflict (route_id) do nothing;
end $x$;
select 'koregaon demo map ready' as result;
-- To show the bus running for a demo (run 1-2 minutes before): see DEMO-BUS-KOREGAON.sql
