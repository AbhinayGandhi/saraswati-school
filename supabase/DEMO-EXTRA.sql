-- ============================================================================
-- DEMO-EXTRA.sql : extra demo content for the PRESENTATION (run AFTER DEMO-DATA.sql and ALL-IN-ONE.sql)
-- Adds: sample UPI + bank details (FAKE, so no real money can be sent), map positions for bus stops,
--       2 pending fee-payment claims for parent1@demo.example.com (one UPI, one bank transfer) so the
--       accountant can verify them live on stage.
-- Remove later with DEMO-EXTRA-UNDO.sql. Safe to run again.
-- ============================================================================
insert into school_settings (key, value, is_public) values
  ('upi_id','demoschool@demo',false), ('upi_payee','DEMO SCHOOL (sample, do not pay)',false),
  ('bank_name','Demo Bank (sample)',false), ('bank_account_name','Demo School Sample',false),
  ('bank_account_no','123456789012',false), ('bank_ifsc','DEMO0000001',false), ('bank_branch','Sample Branch',false)
on conflict (key) do update set value = excluded.value;

-- Approximate map positions (Pune) so "bus is near" alerts can be shown.
update transport_stops set lat = v.lat, lng = v.lng from (values
  ('Karve Road',18.5074,73.8077),('Paud Road',18.5090,73.8000),('Mayur Colony',18.5030,73.8130),
  ('Baner Gaon',18.5590,73.7868),('Balewadi',18.5770,73.7790),('Pashan',18.5373,73.7900)) v(name, lat, lng)
where transport_stops.name = v.name and transport_stops.lat is null;

-- Two pending payment claims for the demo parent (only if a fee balance exists and none were added before).
do $x$ declare p uuid; eid uuid; bal numeric;
begin
  select id into p from auth.users where email = 'parent1@demo.example.com';
  if p is null or exists (select 1 from payment_claims where upi_ref in ('DEMOUPI000001','DEMOBANK00002')) then return; end if;
  select e.id, sum(f.balance) into eid, bal from student_enrollments e
    join student_guardians g on g.student_id = e.student_id and g.user_id = p
    join student_fees f on f.enrollment_id = e.id and f.balance > 0
    group by e.id order by sum(f.balance) desc limit 1;
  if eid is null or bal < 2000 then return; end if;
  insert into payment_claims (enrollment_id, amount, paid_on, upi_ref, note, submitted_by) values
    (eid, 1000, current_date - 1, 'DEMOUPI000001', 'Demo UPI payment', p),
    (eid, 1000, current_date, 'DEMOBANK00002', '[Bank transfer] Demo bank transfer', p);
end $x$;
select 'demo extra ready' as result;
