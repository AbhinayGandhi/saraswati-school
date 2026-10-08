-- Update 7b: safely remove a wrongly created fee structure. Run ONCE on your existing project.
-- Removes only installments with no payment and no concession. Installments that already have payments are kept.
create or replace function remove_fee_structure(p_id uuid) returns text language plpgsql security definer set search_path = public as $$
declare removed int; kept int;
begin
  if not can_manage_fees() then raise exception 'not allowed'; end if;
  delete from student_fees sf where sf.fee_structure_id = p_id and sf.paid_amount = 0 and sf.concession_amount = 0
    and not exists (select 1 from fee_payments fp where fp.student_fee_id = sf.id)
    and not exists (select 1 from fee_concessions fc where fc.student_fee_id = sf.id);
  get diagnostics removed = row_count;
  select count(*) into kept from student_fees where fee_structure_id = p_id;
  if kept = 0 then delete from fee_structures where id = p_id; end if;
  return removed || ',' || kept;
end $$;
revoke all on function remove_fee_structure(uuid) from public, anon;
grant execute on function remove_fee_structure(uuid) to authenticated;
