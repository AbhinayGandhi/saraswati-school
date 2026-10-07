-- Update 6b: run ONCE on your existing Supabase project (do not re-run schema.sql).
-- 1) Subject display order  2) One payment covering several installments, one receipt.
alter table subjects add column if not exists sort_order int not null default 0;
update subjects s set sort_order = r.n from (select id, row_number() over (order by name) as n from subjects) r where r.id = s.id and s.sort_order = 0;

alter table fee_payments drop constraint if exists fee_payments_receipt_no_key;
alter table fee_payments add constraint fee_payments_receipt_fee_uq unique (receipt_no, student_fee_id);
alter table fee_payments add column if not exists is_first boolean not null default true;
drop index if exists fee_payments_ref;
create unique index fee_payments_ref on fee_payments (mode, lower(reference_no)) where reference_no is not null and mode <> 'cash' and is_first;

create or replace function record_fee_payments(p_enrollment uuid, p_amount numeric, p_date date, p_mode text, p_ref text, p_notes text)
returns text language plpgsql security definer set search_path = public as $$
declare rcpt text; remaining numeric := p_amount; r record; pay numeric; first_row boolean := true; total numeric;
begin
  if not can_manage_fees() then raise exception 'not allowed'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'invalid amount'; end if;
  if p_mode not in ('cash','upi','bank_transfer','cheque','other') then raise exception 'invalid mode'; end if;
  if p_mode <> 'cash' and coalesce(trim(p_ref), '') = '' then raise exception 'reference required'; end if;
  select coalesce(sum(balance), 0) into total from student_fees where enrollment_id = p_enrollment and balance > 0;
  if p_amount > total then raise exception 'amount exceeds balance'; end if;
  rcpt := 'R' || to_char(now(),'YY') || lpad(nextval('receipt_seq')::text, 6, '0');
  for r in select id, balance from student_fees where enrollment_id = p_enrollment and balance > 0 order by due_date, installment_no, id for update loop
    exit when remaining <= 0;
    pay := least(r.balance, remaining);
    insert into fee_payments (student_fee_id, amount, payment_date, mode, reference_no, notes, receipt_no, is_first)
      values (r.id, pay, coalesce(p_date, current_date), p_mode, nullif(trim(p_ref), ''), p_notes, rcpt, first_row);
    first_row := false; remaining := remaining - pay;
  end loop;
  return rcpt;
end $$;
revoke all on function record_fee_payments(uuid, numeric, date, text, text, text) from public, anon;
grant execute on function record_fee_payments(uuid, numeric, date, text, text, text) to authenticated;
