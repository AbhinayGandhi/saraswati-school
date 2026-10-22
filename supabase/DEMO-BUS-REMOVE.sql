-- Removes ALL demo bus data (routes, stops, student assignments, live positions,
-- boarding records, learned paths, pickup points, bus notifications).
-- Run ONCE in the Supabase SQL Editor before real bus operation. Safe to re-run.
-- Does not touch students, fees, attendance or any other module.
begin;
delete from bus_alerts;
delete from bus_boarding;
delete from student_pickup;
delete from bus_paths;
delete from bus_live;
delete from transport_assignments;
delete from transport_stops;
delete from transport_driver_keys;
delete from transport_routes;
delete from notifications where related_module = 'transport' or title like 'Bus started:%' or title like 'Bus is near%' or title like 'Bus near%';
commit;
select (select count(*) from transport_routes) as routes_left,
       (select count(*) from transport_stops) as stops_left,
       (select count(*) from transport_assignments) as assignments_left,
       (select count(*) from notifications where related_module = 'transport') as bus_notifications_left;
