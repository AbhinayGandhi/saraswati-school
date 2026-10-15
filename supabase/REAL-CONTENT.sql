-- TEMPLATE: fill in the real details of the English Medium School (verified by the school), then run in Supabase SQL Editor.
-- Replace every text between the quotes. Leave a field as '' to keep it hidden/placeholder. You can also edit these later in School settings.
-- (phase23.sql must have been run once; it is included in ALL-IN-ONE.sql.)
insert into school_settings (key, value, is_public) values
 ('address', '', true),            -- full postal address
 ('phone', '', true),              -- office phone
 ('email', '', true),
 ('website', '', true),            -- must start with https://
 ('facebook', '', true),           -- must start with https://
 ('telegram', '', true),
 ('home_tagline', '', true),       -- motto
 ('principal', '', true),          -- name of principal / headmistress
 ('principal_title', 'Principal', true),
 ('about_text', '', true),         -- history / introduction (blank lines make paragraphs)
 ('registration', '', true)        -- recognition / affiliation / UDISE / society registration, one per line
on conflict (key) do update set value = excluded.value where excluded.value <> '';
