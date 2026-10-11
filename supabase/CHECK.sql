-- Read-only health check. Safe to run any time; it changes nothing.
select 'subjects (active)' as what, count(*) as how_many from subjects where is_active
union all select 'teacher logins (active, role teacher/class_teacher)', count(*) from profiles where role in ('teacher','class_teacher') and is_active
union all select 'inactive users waiting for approval', count(*) from profiles where not is_active
union all select 'tables without security (must be 0)', count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r' and not c.relrowsecurity
union all select 'tables in database (should be 43)', count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r';
-- Who are my users and what role do they have?
select p.full_name, u.email, p.role, p.is_active from profiles p join auth.users u on u.id = p.id order by p.role, p.full_name;
