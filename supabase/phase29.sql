-- phase29: fix parent read access to transport routes/stops (unqualified column names resolved to the inner table).
drop policy if exists tr_read on transport_routes;
create policy tr_read on transport_routes for select to authenticated using (can_manage_transport() or exists (select 1 from transport_assignments a where a.route_id = transport_routes.id and a.status = 'active' and is_guardian_of_enrollment(a.enrollment_id)));
drop policy if exists ts_read on transport_stops;
create policy ts_read on transport_stops for select to authenticated using (can_manage_transport() or exists (select 1 from transport_assignments a where a.route_id = transport_stops.route_id and a.status = 'active' and is_guardian_of_enrollment(a.enrollment_id)));
