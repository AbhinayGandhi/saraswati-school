-- Removes what DEMO-EXTRA.sql added (demo UPI/bank values and the two demo claims that are still pending).
update school_settings set value = '' where key in ('upi_id','upi_payee','bank_name','bank_account_name','bank_account_no','bank_ifsc','bank_branch')
  and value in ('demoschool@demo','DEMO SCHOOL (sample, do not pay)','Demo Bank (sample)','Demo School Sample','123456789012','DEMO0000001','Sample Branch');
delete from payment_claims where upi_ref in ('DEMOUPI000001','DEMOBANK00002') and status = 'pending';
select 'demo extra removed' as result;
