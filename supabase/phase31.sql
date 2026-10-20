-- phase31: school map location (public) for the Contact page map. Idempotent.
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
  if new.key = 'attendance_edit_days' and new.value <> '' and new.value !~ '^[0-9]{1,3}$' then raise exception 'invalid setting: attendance edit days'; end if;
  if new.key = 'portal_hidden' and new.value !~ '^([a-z]+(,[a-z]+)*)?$' then raise exception 'invalid setting: portal switches'; end if;
  if new.key in ('rc_title','rc_sign1','rc_sign2','rc_sign3') and length(new.value) > 60 then raise exception 'invalid setting: too long'; end if;
  if new.key = 'rc_note' and length(new.value) > 300 then raise exception 'invalid setting: too long'; end if;
  if new.key = 'map_lat' and new.value <> '' and (new.value !~ '^-?[0-9]{1,2}(\.[0-9]{1,8})?$' or abs(new.value::numeric) > 90) then raise exception 'invalid setting: latitude (example 17.701212)'; end if;
  if new.key = 'map_lng' and new.value <> '' and (new.value !~ '^-?[0-9]{1,3}(\.[0-9]{1,8})?$' or abs(new.value::numeric) > 180) then raise exception 'invalid setting: longitude (example 74.174362)'; end if;
  new.is_public := new.key in ('rc_title','rc_sign1','rc_sign2','rc_sign3','rc_note','school_name','address','phone','email','website','principal','logo_path','school_start_time','school_end_time',
                               'home_tagline','about_text','vision','mission','principal_message',
                               'principal_title','registration','facebook','telegram','map_lat','map_lng');
  return new;
end $$;

insert into school_settings (key, value, is_public) values ('map_lat','',true),('map_lng','',true) on conflict (key) do nothing;
