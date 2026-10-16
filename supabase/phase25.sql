-- Phase 25: approved claims keep the real mode (UPI or bank transfer) on the receipt
create or replace function review_payment_claim(p_id uuid, p_approve boolean, p_note text default null)
returns payment_claims language plpgsql security definer set search_path = public as $$
declare c payment_claims; rc text;
begin
  if not can_manage_fees() then raise exception 'not allowed'; end if;
  select * into c from payment_claims where id = p_id for update;
  if not found then raise exception 'claim not found'; end if;
  if c.status <> 'pending' then raise exception 'already decided'; end if;
  if p_approve then
    rc := record_fee_payments(c.enrollment_id, c.amount, c.paid_on, case when c.note like '[Bank transfer]%' then 'bank_transfer' else 'upi' end, c.upi_ref, 'Approved from parent online payment claim');
  end if;
  update payment_claims set status = case when p_approve then 'approved' else 'rejected' end, reviewed_by = auth.uid(), reviewed_at = now(),
    review_note = nullif(trim(coalesce(p_note, '')), ''), receipt_no = rc where id = p_id returning * into c;
  if c.submitted_by is not null then
    insert into notifications (user_id, title, message, type, related_module, related_record)
    values (c.submitted_by, case when p_approve then 'Your online payment is confirmed' else 'Your online payment could not be confirmed' end,
      case when p_approve then 'Receipt number ' || rc || ' for Rs. ' || c.amount || '.' else coalesce('Reason: ' || c.review_note, 'Please contact the school office.') end, 'fee', 'fees', c.id::text);
  end if;
  insert into audit_logs (user_id, action, module, record_id) values (auth.uid(), 'Payment claim ' || c.status, 'fees', c.id::text);
  return c;
end $$;
revoke all on function review_payment_claim(uuid, boolean, text) from public, anon;
grant execute on function review_payment_claim(uuid, boolean, text) to authenticated;
