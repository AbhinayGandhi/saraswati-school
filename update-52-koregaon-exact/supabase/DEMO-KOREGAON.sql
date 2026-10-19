-- ============================================================================
-- DEMO-KOREGAON.sql : puts the DEMO "Route 1" on the real Koregaon map.
--   School (Main Gate)   : 17.701212, 74.174362  (copied from Google Maps)
--   New ST Stand pickup  : 17.704002, 74.160634                             (copied from Google Maps)
-- Safe to run again. DEMO data only; run it before the demo, never on real data.
-- What it does: Route 1 gets 2 stops (1. New ST Stand, 2. Main Gate = school). Children from the old
-- demo stops (Karve Road, Mayur Colony) are moved to the ST Stand stop, then those two stops are removed.
-- parent1's child (Soham) stays on the stop that was "Paud Road" (now "New ST Stand").
-- Route 2 (Baner, Pune) is not touched.
-- ============================================================================
do $x$ declare r uuid; st uuid; mg uuid; ka uuid; mc uuid;
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
  update transport_stops set name = 'New ST Stand', stop_order = 1, lat = 17.704002, lng = 74.160634 where id = st;
  update transport_stops set stop_order = 2, lat = 17.701212, lng = 74.174362 where id = mg;
  update transport_routes set name = 'Route 1: Koregaon ST Stand - School' where id = r and name like 'Route 1: Kothrud%';
  -- demo bus: a little before the ST Stand, so "near the stop" shows
  insert into bus_live (route_id, lat, lng, speed_kmh, heading, accuracy_m, trip, trip_active, started_at, updated_at)
  values (r, 17.7050, 74.1590, 0, 90, 10, 'pickup', false, now(), now())
  on conflict (route_id) do nothing;
end $x$;
select 'koregaon demo map ready' as result;
-- To show the bus running for a demo (run 1-2 minutes before): see DEMO-BUS-KOREGAON.sql
