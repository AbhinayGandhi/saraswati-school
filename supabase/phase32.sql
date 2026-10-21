-- phase32: learned bus paths (kept for good), parent pickup points, optional driver boarding switch. Safe to run more than once.

-- 1) Learned bus paths: the driver's phone sends the trip's path when the trip ends. Same path again = counted, a new path = saved (up to 5 per bus).
create table if not exists bus_paths (
  id uuid primary key default gen_random_uuid(), route_id uuid not null references transport_routes(id) on delete cascade,
  name text not null, points jsonb not null, trips int not null default 1, created_at timestamptz not null default now(), last_seen timestamptz not null default now()
);
create index if not exists bus_paths_route on bus_paths (route_id);
alter table bus_paths enable row level security;
drop policy if exists bp_read on bus_paths;
create policy bp_read on bus_paths for select to authenticated using (
  can_manage_transport() or exists (select 1 from transport_assignments a where a.route_id = bus_paths.route_id and a.status = 'active' and is_guardian_of_enrollment(a.enrollment_id)));
drop policy if exists bp_admin on bus_paths;
create policy bp_admin on bus_paths for all to authenticated using (can_manage_transport()) with check (can_manage_transport());

-- metres between two points (small distances)
create or replace function geo_m(a_lat double precision, a_lng double precision, b_lat double precision, b_lng double precision) returns double precision
language sql immutable as $$
  select sqrt(power((b_lat - a_lat) * 111320.0, 2) + power((b_lng - a_lng) * 111320.0 * cos(radians((a_lat + b_lat) / 2)), 2)) $$;

-- share of points of path A that lie within 80 m of some point of path B
create or replace function path_cover(a jsonb, b jsonb) returns double precision language sql immutable as $$
  select coalesce(avg(case when exists (
      select 1 from jsonb_array_elements(b) q
      where geo_m((p->>0)::double precision, (p->>1)::double precision, (q->>0)::double precision, (q->>1)::double precision) <= 80) then 1.0 else 0.0 end), 0)
  from jsonb_array_elements(a) p $$;

create or replace function driver_save_path(p_token text, p_points jsonb) returns jsonb language plpgsql security definer set search_path = public as $$
declare rid uuid; n int; pr record; cov_new double precision; cov_old double precision; cnt int; minlat double precision; maxlat double precision; minlng double precision; maxlng double precision; bad int;
begin
  if p_token is null or length(p_token) < 32 or p_points is null or jsonb_typeof(p_points) <> 'array' then return jsonb_build_object('ok', false, 'error', 'bad_request'); end if;
  select k.route_id into rid from transport_driver_keys k join transport_routes tr on tr.id = k.route_id where k.token = p_token and tr.status = 'active';
  if rid is null then return jsonb_build_object('ok', false, 'error', 'bad_key'); end if;
  n := jsonb_array_length(p_points);
  if n < 8 or n > 400 then return jsonb_build_object('ok', false, 'error', 'bad_size'); end if;
  select count(*) into bad from jsonb_array_elements(p_points) e
    where jsonb_typeof(e) <> 'array' or jsonb_array_length(e) <> 2 or jsonb_typeof(e->0) <> 'number' or jsonb_typeof(e->1) <> 'number'
       or (e->>0)::double precision not between -90 and 90 or (e->>1)::double precision not between -180 and 180;
  if bad > 0 then return jsonb_build_object('ok', false, 'error', 'bad_points'); end if;
  select min((e->>0)::double precision), max((e->>0)::double precision), min((e->>1)::double precision), max((e->>1)::double precision) into minlat, maxlat, minlng, maxlng from jsonb_array_elements(p_points) e;
  if geo_m(minlat, minlng, maxlat, maxlng) < 300 then return jsonb_build_object('ok', true, 'saved', false, 'reason', 'too_short'); end if;
  for pr in select id, points from bus_paths where route_id = rid order by last_seen desc loop
    cov_new := path_cover(p_points, pr.points); cov_old := path_cover(pr.points, p_points);
    if cov_new >= 0.9 and cov_old >= 0.9 then update bus_paths set trips = trips + 1, last_seen = now() where id = pr.id; return jsonb_build_object('ok', true, 'saved', false, 'reason', 'same_path'); end if;
    if cov_new >= 0.9 then update bus_paths set trips = trips + 1, last_seen = now() where id = pr.id; return jsonb_build_object('ok', true, 'saved', false, 'reason', 'part_of_path'); end if;
    if cov_old >= 0.9 then update bus_paths set points = p_points, trips = trips + 1, last_seen = now() where id = pr.id; return jsonb_build_object('ok', true, 'saved', true, 'reason', 'longer_path'); end if;
  end loop;
  select count(*) into cnt from bus_paths where route_id = rid;
  if cnt >= 5 then return jsonb_build_object('ok', true, 'saved', false, 'reason', 'limit'); end if;
  insert into bus_paths (route_id, name, points) values (rid, 'Path ' || (cnt + 1), p_points);
  return jsonb_build_object('ok', true, 'saved', true, 'reason', 'new_path');
end $$;
revoke all on function driver_save_path(text, jsonb) from public; grant execute on function driver_save_path(text, jsonb) to anon, authenticated;

-- 2) Parent pickup point: the parent sets it from the phone, no school action needed.
create table if not exists student_pickup (
  student_id uuid primary key references students(id) on delete cascade,
  lat double precision not null check (lat between -90 and 90), lng double precision not null check (lng between -180 and 180),
  accuracy_m real, set_by uuid, updated_at timestamptz not null default now()
);
alter table student_pickup enable row level security;
drop policy if exists sp_read on student_pickup;
create policy sp_read on student_pickup for select to authenticated using (can_manage_transport() or exists (select 1 from student_guardians g where g.student_id = student_pickup.student_id and g.user_id = auth.uid()));

create or replace function my_pickups() returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('student_id', s.id, 'name', s.first_name, 'lat', p.lat, 'lng', p.lng, 'acc', p.accuracy_m) order by s.first_name), '[]'::jsonb)
  from students s join student_guardians g on g.student_id = s.id and g.user_id = auth.uid()
  left join student_pickup p on p.student_id = s.id $$;
revoke all on function my_pickups() from public, anon; grant execute on function my_pickups() to authenticated;

create or replace function set_pickup(p_student uuid, p_lat double precision, p_lng double precision, p_acc real default null) returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return jsonb_build_object('ok', false, 'error', 'login'); end if;
  if p_lat is null or p_lng is null or p_lat not between -90 and 90 or p_lng not between -180 and 180 then return jsonb_build_object('ok', false, 'error', 'bad_point'); end if;
  if not (exists (select 1 from student_guardians g where g.student_id = p_student and g.user_id = auth.uid()) or can_manage_transport()) then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
  insert into student_pickup (student_id, lat, lng, accuracy_m, set_by) values (p_student, p_lat, p_lng, p_acc, auth.uid())
    on conflict (student_id) do update set lat = excluded.lat, lng = excluded.lng, accuracy_m = excluded.accuracy_m, set_by = excluded.set_by, updated_at = now();
  return jsonb_build_object('ok', true);
end $$;
revoke all on function set_pickup(uuid, double precision, double precision, real) from public, anon; grant execute on function set_pickup(uuid, double precision, double precision, real) to authenticated;

create or replace function clear_pickup(p_student uuid) returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return jsonb_build_object('ok', false, 'error', 'login'); end if;
  if not (exists (select 1 from student_guardians g where g.student_id = p_student and g.user_id = auth.uid()) or can_manage_transport()) then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
  delete from student_pickup where student_id = p_student; return jsonb_build_object('ok', true);
end $$;
revoke all on function clear_pickup(uuid) from public, anon; grant execute on function clear_pickup(uuid) to authenticated;

-- 3) Switch: driver page shows the QR scan + children list only when this is 'on' (public so the driver page can read it)
create or replace function settings_guard() returns trigger language plpgsql as $$
begin
  new.value := coalesce(trim(new.value), '');
  if length(new.value) > 4000 then raise exception 'invalid setting: too long'; end if;
  if new.key = 'working_days' and new.value !~ '^[1-7](,[1-7])*$' then raise exception 'invalid setting: working days'; end if;
  if new.key = 'receipt_prefix' and new.value !~ '^[A-Za-z0-9-]{1,6}$' then raise exception 'invalid setting: receipt prefix'; end if;
  if new.key = 'attendance_alert_percent' and (new.value !~ '^[0-9]{1,3}$' or new.value::int > 100) then raise exception 'invalid setting: attendance percent'; end if;
  if new.key = 'library_fine_per_day' and new.value !~ '^[0-9]{1,5}(\.[0-9]{1,2})?$' then raise exception 'invalid setting: fine'; end if;
  if new.key in ('school_start_time','school_end_time') and new.value <> '' and new.value !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then raise exception 'invalid setting: time'; end if;
  if new.key = 'upi_id' and new.value <> '' and new.value !~ '^[A-Za-z0-9._-]{2,64}@[A-Za-z0-9]{2,32}$' then raise exception 'invalid setting: UPI id'; end if;
  if new.key = 'bank_account_no' and new.value <> '' and new.value !~ '^[0-9]{6,20}$' then raise exception 'invalid setting: account number (digits only)'; end if;
  if new.key = 'bank_ifsc' and new.value <> '' and upper(new.value) !~ '^[A-Z]{4}0[A-Z0-9]{6}$' then raise exception 'invalid setting: IFSC'; end if;
  if new.key in ('bank_name','bank_account_name','bank_branch') and length(new.value) > 100 then raise exception 'invalid setting: too long'; end if;
  if new.key = 'bank_ifsc' then new.value := upper(new.value); end if;
  if new.key = 'upi_payee' and length(new.value) > 80 then raise exception 'invalid setting: payee name'; end if;
  if new.key in ('website','facebook','telegram') and new.value <> '' and new.value !~ '^https://[A-Za-z0-9._~:/?#@!$&''()*+,;=%-]{4,250}$' then raise exception 'invalid setting: link must start with https://'; end if;
  if new.key = 'attendance_edit_days' and new.value <> '' and new.value !~ '^[0-9]{1,3}$' then raise exception 'invalid setting: attendance edit days'; end if;
  if new.key = 'portal_hidden' and new.value !~ '^([a-z]+(,[a-z]+)*)?$' then raise exception 'invalid setting: portal switches'; end if;
  if new.key in ('rc_title','rc_sign1','rc_sign2','rc_sign3') and length(new.value) > 60 then raise exception 'invalid setting: too long'; end if;
  if new.key = 'rc_note' and length(new.value) > 300 then raise exception 'invalid setting: too long'; end if;
  if new.key = 'map_lat' and new.value <> '' and (new.value !~ '^-?[0-9]{1,2}(\.[0-9]{1,8})?$' or abs(new.value::numeric) > 90) then raise exception 'invalid setting: latitude (example 17.701212)'; end if;
  if new.key = 'map_lng' and new.value <> '' and (new.value !~ '^-?[0-9]{1,3}(\.[0-9]{1,8})?$' or abs(new.value::numeric) > 180) then raise exception 'invalid setting: longitude (example 74.174362)'; end if;
  if new.key = 'bus_boarding' and new.value not in ('', 'on') then raise exception 'invalid setting: bus boarding switch'; end if;
  new.is_public := new.key in ('rc_title','rc_sign1','rc_sign2','rc_sign3','rc_note','school_name','address','phone','email','website','principal','logo_path','school_start_time','school_end_time',
                               'home_tagline','about_text','vision','mission','principal_message',
                               'principal_title','registration','facebook','telegram','map_lat','map_lng','bus_boarding');
  return new;
end $$;

insert into school_settings (key, value, is_public) values ('bus_boarding','',true) on conflict (key) do nothing;
select 'phase32 finished' as result;
