-- Undo: the text in the earlier REAL-CONTENT.sql came from the Marathi-medium school's site (Saraswati Vidyalaya, Koregaon),
-- not from the English Medium School. This clears ONLY values that still match what that file inserted. Safe to run more than once.
update school_settings set value = '' where
  (key = 'address' and value like 'Saraswati Vidyalaya, Koregaon%') or
  (key = 'phone' and value = '02163-220218') or
  (key = 'website' and value = 'https://saraswativk.edu.in') or
  (key = 'facebook' and value like 'https://www.facebook.com/saraswatividyalaykoregoan%') or
  (key = 'telegram' and value = 'https://t.me/svk1941') or
  (key = 'home_tagline' and value = 'अनंत अमुची ध्येयासक्ती अनंत अन् आशा') or
  (key = 'principal' and value = 'Shri Rajkumar Balaso Barge') or
  (key = 'principal_title' and value = 'Headmaster') or
  (key = 'about_text' and value like 'Saraswati Vidyalaya, Koregaon, is run by%') or
  (key = 'registration' and value like 'Society: The Modern Education Society, Koregaon%');
-- Public pages show "to be provided by the school" again for the cleared fields.
