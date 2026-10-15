-- REAL SCHOOL CONTENT (facts taken from the school's public website https://saraswativk.edu.in).
-- Run in Supabase SQL Editor. Safe to run again. Edit the text first if anything is wrong, or change it later in School settings.
-- NOT included (not published by the school, so not invented): email, vision, mission, principal's message, timings, facilities.
-- (needs phase23 below; included here so this file works alone)
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
  if new.key = 'upi_payee' and length(new.value) > 80 then raise exception 'invalid setting: payee name'; end if;
  if new.key in ('website','facebook','telegram') and new.value <> '' and new.value !~ '^https://[A-Za-z0-9._~:/?#@!$&''()*+,;=%-]{4,250}$' then raise exception 'invalid setting: link must start with https://'; end if;
  new.is_public := new.key in ('school_name','address','phone','email','website','principal','logo_path','school_start_time','school_end_time',
                               'home_tagline','about_text','vision','mission','principal_message',
                               'principal_title','registration','facebook','telegram');
  return new;
end $$;

insert into school_settings (key, value, is_public) values
 ('address', 'Saraswati Vidyalaya, Koregaon - 415501, Tal. Koregaon, Dist. Satara, Maharashtra', true),
 ('phone', '02163-220218', true),
 ('website', 'https://saraswativk.edu.in', true),
 ('facebook', 'https://www.facebook.com/saraswatividyalaykoregoan/', true),
 ('telegram', 'https://t.me/svk1941', true),
 ('home_tagline', 'अनंत अमुची ध्येयासक्ती अनंत अन् आशा', true),
 ('principal', 'Shri Rajkumar Balaso Barge', true),
 ('principal_title', 'Headmaster', true),
 ('about_text', E'Saraswati Vidyalaya, Koregaon, is run by The Modern Education Society, Koregaon, in Satara district.\n\nEnglish teaching was not available in Koregaon before 1935. In 1936 Shri Gopal Keshav Bokil started "Saraswati English School". On 2 June 1941 it became "New Saraswati English School", and about three months later twelve citizens founded The Modern Education Society, Koregaon, with Advocate G. R. (Appasaheb) Kulkarni as its first president. The school began with 48 students. Its first SSC batch (1952-53) had 22 students. A permanent building was built from 1950-51 on land donated by Shri Bhikoba Sakharam Barge.\n\nSince 1978 the Society has also started Sharada Vidyalaya (Ekambe), R. D. Oswal Vidyalaya (Jamb-Tripudi) and an unaided primary school in Koregaon.', true),
 ('registration', E'Society: The Modern Education Society, Koregaon (Reg. No. 1129/4)\nS.S.C. School Code: 21-05-004\nRecognition: EDN / Sec / Kat / VI85-86 / Satara, dated 28-5-1986\nBoard: Maharashtra State Board of Secondary and Higher Secondary Education', true)
on conflict (key) do update set value = excluded.value, is_public = true;
