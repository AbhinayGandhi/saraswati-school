-- Phase 16 (round 3): absence alerts to parents. Safe to run more than once. Nothing is deleted.
-- When a student is marked absent for today (or the last 2 days), every linked parent login gets a notification.
create or replace function notify_absence() returns trigger language plpgsql security definer set search_path = public as $$
declare nm text; cls text; dt text;
begin
  if new.status <> 'absent' or new.att_date < current_date - 2 then return new; end if;
  if tg_op = 'UPDATE' and old.status = 'absent' then return new; end if;
  select trim(concat_ws(' ', s.first_name, s.last_name)), c.name || ' - ' || d.name into nm, cls
    from student_enrollments e join students s on s.id = e.student_id join divisions d on d.id = e.division_id join classes c on c.id = d.class_id
    where e.id = new.enrollment_id;
  if nm is null then return new; end if;
  dt := to_char(new.att_date, 'DD-MM-YYYY');
  insert into notifications (user_id, title, message, type, related_module, related_record)
  select distinct g.user_id, 'Absent: ' || nm, nm || ' (' || cls || ') was marked absent on ' || dt || '. If this is not expected, please contact the school. / '
         || nm || ' (' || cls || ') हे ' || dt || ' रोजी गैरहजर होते. हे अपेक्षित नसल्यास कृपया शाळेशी संपर्क साधा.', 'notice', 'attendance', new.id::text
  from student_guardians g join profiles p on p.id = g.user_id and p.is_active
  where g.student_id = (select student_id from student_enrollments where id = new.enrollment_id) and g.user_id is not null
    and not exists (select 1 from notifications n where n.user_id = g.user_id and n.related_module = 'attendance' and n.related_record = new.id::text);
  return new;
end $$;
revoke all on function notify_absence() from public, anon, authenticated;
drop trigger if exists attendance_absence_notify on attendance;
create trigger attendance_absence_notify after insert or update of status on attendance for each row execute function notify_absence();
select 'phase16 finished' as result;
