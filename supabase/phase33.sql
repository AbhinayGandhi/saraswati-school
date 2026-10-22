-- phase33: Send a message to parents (app notification + WhatsApp list). Safe to re-run.
create table if not exists broadcasts (
  id uuid primary key default gen_random_uuid(),
  sent_by uuid references profiles(id),
  class_id uuid references classes(id) on delete set null,
  division_id uuid references divisions(id) on delete set null,
  audience text not null,
  title text not null,
  message text not null,
  app_recipients int not null default 0,
  created_at timestamptz not null default now()
);
alter table broadcasts enable row level security;

create or replace function broadcast_staff() returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(current_role_name() in ('super_admin','school_admin','principal','reception'), false) $$;

drop policy if exists bc_read on broadcasts;
create policy bc_read on broadcasts for select to authenticated using (broadcast_staff());

-- Who will get the message: one row per active student of this year, with the main guardian.
create or replace function message_recipients(p_class uuid default null, p_division uuid default null)
returns table (enrollment_id uuid, student_name text, class_name text, division_name text,
               guardian_name text, guardian_mobile text, has_login boolean)
language plpgsql stable security definer set search_path = public as $$
begin
  if not broadcast_staff() then raise exception 'not allowed'; end if;
  return query
  select e.id, trim(concat_ws(' ', s.first_name, s.middle_name, s.last_name)), c.name, d.name,
         g.name, g.mobile,
         exists (select 1 from student_guardians sg where sg.student_id = s.id and sg.user_id is not null)
  from student_enrollments e
  join academic_years y on y.id = e.academic_year_id and y.is_active
  join students s on s.id = e.student_id
  join divisions d on d.id = e.division_id
  join classes c on c.id = d.class_id
  left join lateral (select sg.name, sg.mobile from student_guardians sg where sg.student_id = s.id
                     order by (sg.relation = 'father') desc, (sg.relation = 'mother') desc limit 1) g on true
  where e.status = 'active'
    and (p_class is null or c.id = p_class)
    and (p_division is null or d.id = p_division)
  order by c.sort_order, d.name, s.first_name;
end $$;
revoke all on function message_recipients(uuid, uuid) from public, anon;
grant execute on function message_recipients(uuid, uuid) to authenticated;

-- Send an app notification to every parent who has a login. Returns how many parents got it.
create or replace function send_broadcast(p_class uuid, p_division uuid, p_title text, p_message text)
returns int language plpgsql security definer set search_path = public as $$
declare n int; t text := trim(coalesce(p_title, '')); m text := trim(coalesce(p_message, '')); aud text; bid uuid;
begin
  if not broadcast_staff() then raise exception 'not allowed'; end if;
  if length(t) < 2 or length(t) > 120 then raise exception 'title must be 2 to 120 characters'; end if;
  if length(m) < 2 or length(m) > 1000 then raise exception 'message must be 2 to 1000 characters'; end if;
  aud := case when p_division is not null then 'division' when p_class is not null then 'class' else 'all' end;
  insert into broadcasts (sent_by, class_id, division_id, audience, title, message) values (auth.uid(), p_class, p_division, aud, t, m) returning id into bid;
  insert into notifications (user_id, title, message, type, related_module, related_record)
  select distinct sg.user_id, t, m, 'announcement', 'messages', bid::text
  from student_enrollments e
  join academic_years y on y.id = e.academic_year_id and y.is_active
  join divisions d on d.id = e.division_id
  join student_guardians sg on sg.student_id = e.student_id and sg.user_id is not null
  where e.status = 'active' and (p_class is null or d.class_id = p_class) and (p_division is null or d.id = p_division);
  get diagnostics n = row_count;
  update broadcasts set app_recipients = n where id = bid;
  insert into audit_logs (user_id, action, module, record_id) values (auth.uid(), 'Message sent to parents', 'messages', bid::text);
  return n;
end $$;
revoke all on function send_broadcast(uuid, uuid, text, text) from public, anon;
grant execute on function send_broadcast(uuid, uuid, text, text) to authenticated;

select 'phase33 finished' as result;
