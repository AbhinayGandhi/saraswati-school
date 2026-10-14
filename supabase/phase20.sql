-- Phase 20 (round 6): AI assistant. Safe to run more than once. Nothing is deleted.
-- The AI runs in a Supabase Edge Function (ai-assistant). The API key lives only there as a secret, never in the website.
-- Students (minors) never get AI. No names or phone numbers are sent. Nothing the user types is stored, only a count per feature.

create table if not exists ai_config (
  id boolean primary key default true check (id),
  enabled boolean not null default false,
  limit_parent int not null default 10 check (limit_parent between 0 and 200),
  limit_staff int not null default 40 check (limit_staff between 0 and 500),
  limit_admin int not null default 100 check (limit_admin between 0 and 1000)
);
insert into ai_config (id) values (true) on conflict do nothing;
alter table ai_config enable row level security;
drop policy if exists aic_read on ai_config;
create policy aic_read on ai_config for select to authenticated using (is_admin());

create table if not exists ai_knowledge (
  id uuid primary key default gen_random_uuid(), title text not null check (length(title) between 2 and 120),
  body text not null check (length(body) between 2 and 2000), is_active boolean not null default true,
  updated_by uuid default auth.uid() references profiles(id), updated_at timestamptz not null default now()
);
alter table ai_knowledge enable row level security;
drop policy if exists aik_all on ai_knowledge;
create policy aik_all on ai_knowledge for all to authenticated using (is_admin()) with check (is_admin());
create or replace function ai_knowledge_touch() returns trigger language plpgsql as $$ begin new.updated_by := auth.uid(); new.updated_at := now(); return new; end $$;
drop trigger if exists aik_touch on ai_knowledge;
create trigger aik_touch before insert or update on ai_knowledge for each row execute function ai_knowledge_touch();

create table if not exists ai_usage (
  id bigint generated always as identity primary key, user_id uuid not null references profiles(id) on delete cascade,
  feature text not null check (feature in ('notice','translate','remark','questions','ask')), day date not null default current_date, created_at timestamptz not null default now()
);
create index if not exists ai_usage_user_day on ai_usage (user_id, day);
alter table ai_usage enable row level security;   -- no policies: only the functions below can touch it

create or replace function ai_group(r text) returns text language sql immutable as $$
  select case when r in ('super_admin','school_admin','principal') then 'admin' when r in ('teacher','class_teacher','reception') then 'staff' when r = 'parent' then 'parent' else null end $$;

create or replace function ai_allowed(r text, f text) returns boolean language sql immutable as $$
  select case f when 'ask' then ai_group(r) is not null
    when 'notice' then r in ('super_admin','school_admin','principal','reception','teacher','class_teacher')
    when 'translate' then r in ('super_admin','school_admin','principal','reception','teacher','class_teacher')
    when 'remark' then r in ('super_admin','school_admin','principal','teacher','class_teacher')
    when 'questions' then r in ('super_admin','school_admin','principal','teacher','class_teacher') else false end $$;

-- Called by the Edge Function with the user's own login. Checks everything and counts one use.
create or replace function ai_prepare(p_feature text) returns jsonb language plpgsql security definer set search_path = public as $$
declare r text := current_role_name()::text; g text; cfg ai_config%rowtype; lim int; used int; ctx jsonb; kn jsonb;
begin
  if auth.uid() is null or r is null then return jsonb_build_object('ok', false, 'error', 'auth'); end if;
  g := ai_group(r);
  if g is null or not ai_allowed(r, p_feature) then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
  select * into cfg from ai_config where id; if not found or not cfg.enabled then return jsonb_build_object('ok', false, 'error', 'ai_off'); end if;
  lim := case g when 'admin' then cfg.limit_admin when 'staff' then cfg.limit_staff else cfg.limit_parent end;
  select count(*) into used from ai_usage where user_id = auth.uid() and day = current_date;
  if used >= lim then return jsonb_build_object('ok', false, 'error', 'quota', 'limit', lim); end if;
  insert into ai_usage (user_id, feature) values (auth.uid(), p_feature);
  select coalesce(jsonb_object_agg(key, value), '{}'::jsonb) into ctx from school_settings where is_public and key in ('school_name','address','phone','email','website','principal','school_start_time','school_end_time');
  if p_feature = 'ask' then
    select coalesce(jsonb_agg(jsonb_build_object('title', title, 'body', body) order by updated_at desc), '[]'::jsonb) into kn from (select title, body, updated_at from ai_knowledge where is_active order by updated_at desc limit 40) k;
  else kn := '[]'::jsonb; end if;
  return jsonb_build_object('ok', true, 'role', r, 'remaining', lim - used - 1, 'school', ctx, 'knowledge', kn);
end $$;

create or replace function ai_status() returns jsonb language plpgsql security definer set search_path = public as $$
declare r text := current_role_name()::text; g text; cfg ai_config%rowtype; lim int; used int; feats text[];
begin
  if auth.uid() is null or r is null then return jsonb_build_object('enabled', false); end if;
  g := ai_group(r); select * into cfg from ai_config where id;
  select array_agg(f) into feats from unnest(array['notice','translate','remark','questions','ask']) f where ai_allowed(r, f);
  if g is null then return jsonb_build_object('enabled', false, 'features', '[]'::jsonb); end if;
  lim := case g when 'admin' then cfg.limit_admin when 'staff' then cfg.limit_staff else cfg.limit_parent end;
  select count(*) into used from ai_usage where user_id = auth.uid() and day = current_date;
  return jsonb_build_object('enabled', cfg.enabled, 'features', to_jsonb(feats), 'remaining', greatest(lim - used, 0), 'limit', lim);
end $$;

create or replace function ai_set_config(p_enabled boolean, p_parent int, p_staff int, p_admin int) returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_admin() then raise exception 'not allowed'; end if;
  update ai_config set enabled = coalesce(p_enabled, enabled), limit_parent = coalesce(p_parent, limit_parent), limit_staff = coalesce(p_staff, limit_staff), limit_admin = coalesce(p_admin, limit_admin) where id;
end $$;

create or replace function ai_usage_summary() returns table (day date, feature text, uses bigint, users bigint) language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not is_admin() then raise exception 'not allowed'; end if;
  return query select u.day, u.feature, count(*), count(distinct u.user_id) from ai_usage u where u.day >= current_date - 6 group by u.day, u.feature order by u.day desc, u.feature;
end $$;

revoke all on function ai_prepare(text), ai_status(), ai_set_config(boolean,int,int,int), ai_usage_summary() from public, anon;
grant execute on function ai_prepare(text), ai_status(), ai_set_config(boolean,int,int,int), ai_usage_summary() to authenticated;
select 'phase20 finished' as result;
