-- Phase 2: run this once if you already ran the Phase 1 schema.sql.
create or replace function set_active_year(p_id uuid) returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_admin() then raise exception 'not allowed'; end if;
  update academic_years set is_active = false, status = 'closed' where is_active and id <> p_id;
  update academic_years set is_active = true, status = 'active' where id = p_id;
end $$;
revoke all on function set_active_year(uuid) from public, anon;
grant execute on function set_active_year(uuid) to authenticated;
