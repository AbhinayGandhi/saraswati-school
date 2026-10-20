-- DEMO-BUS-KOREGAON.sql : shows a running demo bus about 60 m before the demo Home stop, Koregaon (coming from the ST Stand) (fake position, demo only).
-- Run 1-2 minutes before the demo (position goes stale after 3 minutes). Run DEMO-KOREGAON.sql first. Safe to run again.
-- Undo: update bus_live set trip_active = false;
insert into bus_live (route_id, lat, lng, speed_kmh, heading, accuracy_m, trip, trip_active, started_at, updated_at)
select id, 17.705453, 74.160073, 20, 90, 10, 'pickup', true, now(), now() from transport_routes where name like 'Route 1%' limit 1
on conflict (route_id) do update set lat = excluded.lat, lng = excluded.lng, speed_kmh = excluded.speed_kmh,
  trip = 'pickup', trip_active = true, started_at = now(), updated_at = now();
select 'demo bus ready (Koregaon)' as result;
