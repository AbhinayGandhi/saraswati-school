-- DEMO-ATTENDANCE-FIX.sql : the first version of DEMO-DATA.sql made every demo attendance "present" (100%).
-- Run this ONCE if you already loaded that demo data. It gives the demo students and teachers a realistic mix
-- (about 90% present, some absent, late, leave, half day). It changes only rows of demo students/teachers
-- (admission numbers starting SES26- and demo teachers). Safe to run again (it just reshuffles).
update attendance a set status = case when x < 0.90 then 'present' when x < 0.95 then 'absent' when x < 0.97 then 'late' when x < 0.985 then 'leave' else 'half_day' end
from (select id, random() as x from attendance) r
where a.id = r.id and a.enrollment_id in (select e.id from student_enrollments e join students s on s.id = e.student_id where s.admission_no like 'SES26-%');
update teacher_attendance a set status = case when x < 0.93 then 'present' when x < 0.97 then 'leave' else 'late' end
from (select id, random() as x from teacher_attendance) r
where a.id = r.id and a.teacher_id in (select id from teachers where email like '%@demo.example.com');
select status, count(*) from attendance group by 1 order by 2 desc;
