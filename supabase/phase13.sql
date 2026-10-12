-- Phase 13: closes small gaps against the master prompt. Safe to run more than once. Nothing is deleted.
alter table notices add column if not exists notice_type text not null default 'General';
do $$ begin
  alter table notices add constraint notices_type_chk check (notice_type in ('General','Holiday','Exam','Fee','Parent','Student','Teacher','Emergency'));
exception when duplicate_object then null; end $$;
alter table teachers add column if not exists photo_path text;
select 'phase13 finished' as result;
