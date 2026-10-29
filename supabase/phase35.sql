-- phase35: background GPS tracker support (Traccar Client / OwnTracks / any phone or device that can send HTTPS location).
-- The tracker keeps sending even when the phone screen is off. The server starts and ends the trip by itself.
-- Safe to re-run. Does not change the existing driver page.
alter table bus_live add column if not exists still_since timestamptz;
alter table bus_live add column if not exists auto_trip boolean not null default false;

create table if not exists bus_trail_buf (
  id bigserial primary key, route_id uuid not null references transport_routes(id) on delete cascade,
  lat double precision not null, lng double precision not null, at timestamptz not null default now()
);
create index if not exists bus_trail_buf_route on bus_trail_buf (route_id, id);
alter table bus_trail_buf enable row level security;   -- no policy: only the function below can use it

create or replace function gps_ingest(p_token text, p_lat double precision, p_lng double precision, p_speed_kmh real default null,
  p_heading real default null, p_acc real default null) returns jsonb language plpgsql security definer set search_path = public as $$
declare rid uuid; r record; b bus_live%rowtype; hr numeric; trip text; ist timestamp; pt text; dt text; lo numeric; hi numeric; moved boolean; lastp record;
  pts jsonb; sp real := coalesce(p_speed_kmh, 0);
begin
  if p_token is null or length(p_token) < 32 then return jsonb_build_object('ok', false, 'error', 'bad_key'); end if;
  select k.route_id, tr.pickup_time, tr.drop_time into r from transport_driver_keys k join transport_routes tr on tr.id = k.route_id where k.token = p_token and tr.status = 'active';
  rid := r.route_id;
  if rid is null then return jsonb_build_object('ok', false, 'error', 'bad_key'); end if;
  if p_lat is null or p_lng is null or p_lat not between -90 and 90 or p_lng not between -180 and 180 then return jsonb_build_object('ok', false, 'error', 'bad_position'); end if;
  if p_acc is not null and p_acc > 150 then return jsonb_build_object('ok', true, 'skipped', 'low_accuracy'); end if;
  if sp < 0 or sp > 200 then sp := 0; end if;
  select * into b from bus_live where route_id = rid;
  if b.route_id is not null and b.updated_at > now() - interval '3 seconds' then return jsonb_build_object('ok', true, 'skipped', 'too_soon'); end if;

  -- remember the driven path (only when the bus really moved) for learning the route
  select lat, lng into lastp from bus_trail_buf where route_id = rid order by id desc limit 1;
  moved := lastp.lat is null or geo_m(lastp.lat, lastp.lng, p_lat, p_lng) >= 25;
  if moved then insert into bus_trail_buf (route_id, lat, lng) values (rid, p_lat, p_lng); end if;
  delete from bus_trail_buf where route_id = rid and at < now() - interval '8 hours';

  if b.route_id is not null and b.trip_active and b.updated_at > now() - interval '20 minutes' then
    -- trip is running: normal ping (also sends the "bus is near" alerts)
    perform driver_ping(p_token, 'ping', null, p_lat, p_lng, sp, p_heading, p_acc);
    if sp < 3 then
      if b.still_since is null then update bus_live set still_since = now() where route_id = rid; end if;
      if b.still_since is not null and b.still_since < now() - interval '10 minutes' then
        select coalesce(jsonb_agg(jsonb_build_array(t.lat, t.lng) order by t.id), '[]'::jsonb) into pts from (select lat, lng, id from bus_trail_buf where route_id = rid and at >= coalesce(b.started_at, now() - interval '3 hours') order by id limit 400) t;
        begin if jsonb_array_length(pts) >= 8 then perform driver_save_path(p_token, pts); end if; exception when others then null; end;
        perform driver_ping(p_token, 'end', null, null, null, null, null, null);
        update bus_live set still_since = null where route_id = rid;
        delete from bus_trail_buf where route_id = rid;
        return jsonb_build_object('ok', true, 'state', 'trip_ended');
      end if;
    elsif b.still_since is not null then update bus_live set still_since = null where route_id = rid;
    end if;
    return jsonb_build_object('ok', true, 'state', 'running');
  end if;

  -- no trip running: start one by itself when the vehicle is really moving at a school-bus time
  ist := now() at time zone 'Asia/Kolkata'; hr := extract(hour from ist) + extract(minute from ist) / 60;
  if sp >= 8 then
    if r.pickup_time is not null and abs(hr - (extract(hour from r.pickup_time) + extract(minute from r.pickup_time) / 60)) <= 2 then trip := 'pickup';
    elsif r.drop_time is not null and abs(hr - (extract(hour from r.drop_time) + extract(minute from r.drop_time) / 60)) <= 2 then trip := 'drop';
    elsif r.pickup_time is null and r.drop_time is null then trip := case when hr >= 4 and hr < 12 then 'pickup' when hr >= 12 and hr < 20 then 'drop' else null end;
    end if;
    if trip is not null and not (b.route_id is not null and b.trip = trip and b.updated_at > now() - interval '90 minutes') then
      perform driver_ping(p_token, 'start', trip, p_lat, p_lng, sp, p_heading, p_acc);
      update bus_live set still_since = null, auto_trip = true where route_id = rid;
      delete from bus_trail_buf where route_id = rid and id < (select coalesce(max(id), 0) - 1 from bus_trail_buf where route_id = rid);
      return jsonb_build_object('ok', true, 'state', 'trip_started', 'trip', trip);
    end if;
  end if;
  return jsonb_build_object('ok', true, 'state', 'idle');
end $$;
revoke all on function gps_ingest(text, double precision, double precision, real, real, real) from public;
grant execute on function gps_ingest(text, double precision, double precision, real, real, real) to anon, authenticated;

select 'phase35 finished' as result;
