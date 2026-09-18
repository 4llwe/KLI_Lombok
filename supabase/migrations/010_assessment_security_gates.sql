-- Prevent client-side bypass of academic approval and validation gates.
alter table public.assessment_tests add column if not exists max_attempts int not null default 5 check(max_attempts between 1 and 20);
alter table public.assessment_tests add column if not exists cooldown_hours int not null default 24 check(cooldown_hours between 0 and 720);
drop policy if exists tests_staff_manage on public.assessment_tests;
create policy tests_staff_insert on public.assessment_tests for insert with check(public.current_role() in ('academic','admin','superadmin'));
create policy tests_staff_update on public.assessment_tests for update using(public.current_role() in ('academic','admin','superadmin')) with check(public.current_role() in ('academic','admin','superadmin'));
create policy tests_superadmin_delete on public.assessment_tests for delete using(public.current_role()='superadmin');
create or replace function public.guard_assessment_state() returns trigger language plpgsql security definer set search_path=public as $$ begin if auth.role()<>'service_role' and (new.review_status is distinct from old.review_status or new.validation_status is distinct from old.validation_status or new.reliability is distinct from old.reliability or new.pilot_sample_size is distinct from old.pilot_sample_size) then raise exception 'Assessment state must change through the controlled quality workflow'; end if; return new; end $$;
drop trigger if exists guard_assessment_state_trigger on public.assessment_tests;
create trigger guard_assessment_state_trigger before update on public.assessment_tests for each row execute function public.guard_assessment_state();
drop policy if exists reviews_staff on public.assessment_reviews;
create policy reviews_staff_read on public.assessment_reviews for select using(public.current_role() in ('academic','admin','superadmin'));
create policy reviews_staff_insert on public.assessment_reviews for insert with check(reviewer_id=auth.uid() and public.current_role() in ('academic','admin','superadmin'));
comment on function public.guard_assessment_state is 'Blocks browser clients from bypassing controlled review, statistics, and validation functions.';
