-- Phase 24: bank transfer details for fee payment (not public; shown to parents after login via payment_info)
create or replace function settings_guard() returns trigger language plpgsql as $$
begin
  new.value := coalesce(trim(new.value), '');
  if length(new.value) > 4000 then raise exception 'invalid setting: too long'; end if;
  if new.key = 'working_days' and new.value !~ '^[1-7](,[1-7])*$' then raise exception 'invalid setting: working days'; end if;
  if new.key = 'receipt_prefix' and new.value !~ '^[A-Za-z0-9-]{1,6}$' then raise exception 'invalid setting: receipt prefix'; end if;
  if new.key = 'attendance_alert_percent' and (new.value !~ '^[0-9]{1,3}$' or new.value::int > 100) then raise exception 'invalid setting: attendance percent'; end if;
  if new.key = 'library_fine_per_day' and new.value !~ '^[0-9]{1,5}(\.[0-9]{1,2})?$' then raise exception 'invalid setting: fine'; end if;
  if new.key in ('school_start_time','school_end_time') and new.value <> '' and new.value !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then raise exception 'invalid setting: time'; end if;
  if new.key = 'upi_id' and new.value <> '' and new.value !~ '^[A-Za-z0-9._-]{2,64}@[A-Za-z0-9]{2,32}$' then raise exception 'invalid setting: UPI id'; end if;
  if new.key = 'bank_account_no' and new.value <> '' and new.value !~ '^[0-9]{6,20}$' then raise exception 'invalid setting: account number (digits only)'; end if;
  if new.key = 'bank_ifsc' and new.value <> '' and upper(new.value) !~ '^[A-Z]{4}0[A-Z0-9]{6}$' then raise exception 'invalid setting: IFSC'; end if;
  if new.key in ('bank_name','bank_account_name','bank_branch') and length(new.value) > 100 then raise exception 'invalid setting: too long'; end if;
  if new.key = 'bank_ifsc' then new.value := upper(new.value); end if;
  if new.key = 'upi_payee' and length(new.value) > 80 then raise exception 'invalid setting: payee name'; end if;
  if new.key in ('website','facebook','telegram') and new.value <> '' and new.value !~ '^https://[A-Za-z0-9._~:/?#@!$&''()*+,;=%-]{4,250}$' then raise exception 'invalid setting: link must start with https://'; end if;
  new.is_public := new.key in ('school_name','address','phone','email','website','principal','logo_path','school_start_time','school_end_time',
                               'home_tagline','about_text','vision','mission','principal_message',
                               'principal_title','registration','facebook','telegram');
  return new;
end $$;

create or replace function payment_info() returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not (fees_staff() or exists (select 1 from student_guardians g where g.user_id = auth.uid())) then raise exception 'not allowed'; end if;
  return jsonb_build_object('upi_id', coalesce(setting_text('upi_id'), ''), 'payee', coalesce(nullif(setting_text('upi_payee'), ''), setting_text('school_name'), ''),
    'bank_name', coalesce(setting_text('bank_name'), ''), 'bank_account_name', coalesce(setting_text('bank_account_name'), ''),
    'bank_account_no', coalesce(setting_text('bank_account_no'), ''), 'bank_ifsc', coalesce(setting_text('bank_ifsc'), ''), 'bank_branch', coalesce(setting_text('bank_branch'), ''));
end $$;
revoke all on function payment_info() from public, anon; grant execute on function payment_info() to authenticated;
insert into school_settings (key, value, is_public) values ('bank_name','',false),('bank_account_name','',false),('bank_account_no','',false),('bank_ifsc','',false),('bank_branch','',false) on conflict (key) do nothing;
