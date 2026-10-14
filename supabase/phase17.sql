-- Phase 17 (round 4): live bus tracking. Safe to run more than once. Nothing is deleted.
-- Driver phone sends GPS using a secret per-bus link (no login). Parents see only their own child's bus.
alter table transport_stops add column if not exists lat double precision;
alter table transport_stops add column if not exists lng double precision;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'transport_stops_latlng_chk') then
    alter table transport_stops add constraint transport_stops_latlng_chk check ((lat is null and lng is null) or (lat between -90 and 90 and lng between -180 and 180 and lat is not null and lng is not null));
  end if;
end $$;

create table if not exists transport_driver_keys (
  route_id uuid primary key references transport_routes(id) on delete cascade,
  token text not null unique default replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''),
  created_at timestamptz not null default now()
);
alter table transport_driver_keys enable row level security;
drop policy if exists tdk_all on transport_driver_keys;
create policy tdk_all on transport_driver_keys for all to authenticated using (can_front_office()) with check (can_front_office());
insert into transport_driver_keys (route_id) select id from transport_routes on conflict do nothing;
create or replace function make_driver_key() returns trigger language plpgsql security definer set search_path = public as $$
begin insert into transport_driver_keys (route_id) values (new.id) on conflict do nothing; return new; end $$;
drop trigger if exists route_driver_key on transport_routes;
create trigger route_driver_key after insert on transport_routes for each row execute function make_driver_key();

create table if not exists bus_live (
  route_id uuid primary key references transport_routes(id) on delete cascade,
  lat double precision, lng double precision, speed_kmh real, heading real, accuracy_m real,
  trip text check (trip in ('pickup','drop')), trip_active boolean not null default false,
  started_at timestamptz, updated_at timestamptz not null default now()
);
alter table bus_live enable row level security;
drop policy if exists bl_read on bus_live;
create policy bl_read on bus_live for select to authenticated using (
  can_manage_transport() or exists (select 1 from transport_assignments a where a.route_id = bus_live.route_id and a.status = 'active' and is_guardian_of_enrollment(a.enrollment_id)));

create table if not exists bus_alerts (
  assignment_id uuid not null references transport_assignments(id) on delete cascade, alert_date date not null default current_date,
  trip text not null, kind text not null check (kind in ('near','start')), primary key (assignment_id, alert_date, trip, kind)
);
alter table bus_alerts enable row level security;

create or replace function haversine_m(a_lat double precision, a_lng double precision, b_lat double precision, b_lng double precision) returns double precision language sql immutable as $$
  select 2 * 6371000 * asin(sqrt(power(sin(radians(b_lat - a_lat) / 2), 2) + cos(radians(a_lat)) * cos(radians(b_lat)) * power(sin(radians(b_lng - a_lng) / 2), 2))) $$;

-- Admin: make a new secret link for one bus (old link stops working at once).
create or replace function reset_driver_key(p_route uuid) returns text language plpgsql security definer set search_path = public as $$
declare t text := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
begin
  if not can_front_office() then raise exception 'not allowed'; end if;
  insert into transport_driver_keys (route_id, token) values (p_route, t) on conflict (route_id) do update set token = excluded.token, created_at = now();
  return t;
end $$;
revoke all on function reset_driver_key(uuid) from public, anon;
grant execute on function reset_driver_key(uuid) to authenticated;

-- Driver phone: p_action = info | start | ping | end. Works with the secret token only.
create or replace function driver_ping(p_token text, p_action text default 'ping', p_trip text default null, p_lat double precision default null,
  p_lng double precision default null, p_speed real default null, p_heading real default null, p_acc real default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare rid uuid; rn text; vn text; b bus_live%rowtype; st record; d double precision;
begin
  if p_token is null or length(p_token) < 32 then return jsonb_build_object('ok', false, 'error', 'bad_key'); end if;
  select k.route_id, r.name, r.vehicle_no into rid, rn, vn from transport_driver_keys k join transport_routes r on r.id = k.route_id where k.token = p_token and r.status = 'active';
  if rid is null then return jsonb_build_object('ok', false, 'error', 'bad_key'); end if;
  select * into b from bus_live where route_id = rid;
  if p_action = 'info' then
    return jsonb_build_object('ok', true, 'route', rn, 'vehicle', vn, 'active', coalesce(b.trip_active, false), 'trip', b.trip);
  end if;
  if p_action = 'end' then
    update bus_live set trip_active = false, updated_at = now() where route_id = rid;
    return jsonb_build_object('ok', true, 'route', rn, 'active', false);
  end if;
  if p_lat is null or p_lng is null or p_lat not between -90 and 90 or p_lng not between -180 and 180 then return jsonb_build_object('ok', false, 'error', 'bad_position'); end if;
  if p_action = 'start' then
    if p_trip not in ('pickup','drop') then return jsonb_build_object('ok', false, 'error', 'bad_trip'); end if;
    insert into bus_live (route_id, lat, lng, speed_kmh, heading, accuracy_m, trip, trip_active, started_at, updated_at)
      values (rid, p_lat, p_lng, p_speed, p_heading, p_acc, p_trip, true, now(), now())
      on conflict (route_id) do update set lat = excluded.lat, lng = excluded.lng, speed_kmh = excluded.speed_kmh, heading = excluded.heading,
        accuracy_m = excluded.accuracy_m, trip = excluded.trip, trip_active = true, started_at = now(), updated_at = now();
    begin
      insert into bus_alerts (assignment_id, trip, kind) select a.id, p_trip, 'start' from transport_assignments a where a.route_id = rid and a.status = 'active' on conflict do nothing;
      insert into notifications (user_id, title, message, type, related_module, related_record)
      select distinct g.user_id, 'Bus started: ' || rn,
        case p_trip when 'pickup' then 'The school bus (' || rn || ') has started the morning pickup. You can track it live. / स्कूल बस सकाळच्या फेरीसाठी निघाली आहे. आपण ती लाइव्ह पाहू शकता.'
                    else 'The school bus (' || rn || ') has started the drop trip. You can track it live. / स्कूल बस घरी सोडण्यासाठी निघाली आहे. आपण ती लाइव्ह पाहू शकता.' end,
        'notice', 'transport', rid::text
      from transport_assignments a join student_enrollments e on e.id = a.enrollment_id join student_guardians g on g.student_id = e.student_id
      join profiles p on p.id = g.user_id and p.is_active
      where a.route_id = rid and a.status = 'active' and g.user_id is not null
        and not exists (select 1 from notifications n where n.user_id = g.user_id and n.related_module = 'transport' and n.related_record = rid::text and n.title like 'Bus started:%' and n.created_at::date = current_date and n.message like case p_trip when 'pickup' then '%morning pickup%' else '%drop trip%' end);
    exception when others then null; end;
    return jsonb_build_object('ok', true, 'route', rn, 'active', true, 'trip', p_trip);
  end if;
  -- ping
  if b.route_id is null or not b.trip_active then return jsonb_build_object('ok', false, 'error', 'no_trip'); end if;
  if b.updated_at > now() - interval '4 seconds' then return jsonb_build_object('ok', true, 'skipped', true); end if;
  update bus_live set lat = p_lat, lng = p_lng, speed_kmh = p_speed, heading = p_heading, accuracy_m = p_acc, updated_at = now() where route_id = rid;
  begin
    for st in select a.id as aid, s.name as sname, s.lat as slat, s.lng as slng, e.student_id from transport_assignments a join transport_stops s on s.id = a.stop_id
             join student_enrollments e on e.id = a.enrollment_id where a.route_id = rid and a.status = 'active' and s.lat is not null loop
      d := haversine_m(p_lat, p_lng, st.slat, st.slng);
      if d <= 500 and not exists (select 1 from bus_alerts x where x.assignment_id = st.aid and x.alert_date = current_date and x.trip = b.trip and x.kind = 'near') then
        insert into bus_alerts (assignment_id, trip, kind) values (st.aid, b.trip, 'near') on conflict do nothing;
        insert into notifications (user_id, title, message, type, related_module, related_record)
        select distinct g.user_id, 'Bus is near: ' || st.sname,
          'The school bus is about ' || greatest(round(d / 50) * 50, 50)::int || ' m from the stop "' || st.sname || '". Please be ready. / स्कूल बस "' || st.sname || '" थांब्यापासून सुमारे ' || greatest(round(d / 50) * 50, 50)::int || ' मीटरवर आहे. कृपया तयार रहा.',
          'notice', 'transport', rid::text
        from student_guardians g join profiles p on p.id = g.user_id and p.is_active where g.student_id = st.student_id and g.user_id is not null;
      end if;
    end loop;
  exception when others then null; end;
  return jsonb_build_object('ok', true);
end $$;
revoke all on function driver_ping(text, text, text, double precision, double precision, real, real, real) from public;
grant execute on function driver_ping(text, text, text, double precision, double precision, real, real, real) to anon, authenticated;
select 'phase17 finished' as result;
