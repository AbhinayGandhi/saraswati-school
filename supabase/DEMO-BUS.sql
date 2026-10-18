-- ============================================================================
-- DEMO-BUS.sql : puts parent1@demo.example.com's child(ren) on "Route 1" and shows a running demo bus on the map.
-- Run AFTER DEMO-DATA.sql + DEMO-EXTRA.sql. Safe to run again. Demo only (fake position near Karve Road, Pune).
-- Undo: at the bottom (commented). When a real driver page sends GPS, it replaces the fake position.
-- ============================================================================
do $x$ declare p uuid; r uuid; s uuid; e record;
begin
  select id into p from auth.users where email = 'parent1@demo.example.com';
  select id into r from transport_routes where name like 'Route 1%' limit 1;
  if p is null or r is null then raise notice 'demo parent or Route 1 not found'; return; end if;
  select id into s from transport_stops where route_id = r order by stop_order offset 1 limit 1;   -- 2nd stop
  for e in select en.id from student_enrollments en join student_guardians g on g.student_id = en.student_id and g.user_id = p loop
    update transport_assignments set route_id = r, stop_id = s where enrollment_id = e.id and status = 'active';
    if not found then
      insert into transport_assignments (enrollment_id, route_id, stop_id, start_date, status) values (e.id, r, s, date '2026-06-15', 'active');
    end if;
  end loop;
  insert into bus_live (route_id, lat, lng, speed_kmh, heading, accuracy_m, trip, trip_active, started_at, updated_at)
  values (r, 18.5050, 73.8040, 22, 90, 10, 'pickup', true, now(), now())
  on conflict (route_id) do update set lat = excluded.lat, lng = excluded.lng, speed_kmh = excluded.speed_kmh,
    trip = 'pickup', trip_active = true, started_at = now(), updated_at = now();
end $x$;
select 'demo bus ready' as result;
-- UNDO (run separately):  update bus_live set trip_active = false;
