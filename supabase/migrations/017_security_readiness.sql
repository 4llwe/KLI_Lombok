-- Security hardening for staging. Apply after 001-016; test with real roles before release.
begin;

-- An inactive profile must not retain staff privileges via RLS.
create or replace function public.current_role() returns public.app_role
language sql stable security definer set search_path = public
as $$ select role from public.profiles where id = auth.uid() and active = true $$;

-- Row policies do not restrict individual columns. Guard sensitive fields explicitly.
create or replace function public.guard_profile_privileges() returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if new.role is distinct from old.role
     and coalesce(auth.role(), '') <> 'service_role'
     and coalesce(public.current_role()::text, '') <> 'superadmin' then
    raise exception 'Only a superadmin or service role may change a profile role';
  end if;
  if new.active is distinct from old.active
     and coalesce(auth.role(), '') <> 'service_role'
     and coalesce(public.current_role()::text, '') not in ('admin', 'superadmin') then
    raise exception 'Only an administrator or service role may change account status';
  end if;
  return new;
end $$;
drop trigger if exists guard_profile_privileges on public.profiles;
create trigger guard_profile_privileges before update on public.profiles
for each row execute function public.guard_profile_privileges();

-- Explicitly correlate outer rows; inactive/cancelled enrollments cannot unlock content.
drop policy if exists cohorts_enrolled_read on public.cohorts;
create policy cohorts_enrolled_read on public.cohorts for select using (
  public.is_staff() or exists (select 1 from public.enrollments e
    where e.cohort_id = cohorts.id and e.student_id = auth.uid()
      and e.status in ('active', 'completed'))
);
drop policy if exists sessions_read on public.class_sessions;
create policy sessions_read on public.class_sessions for select using (
  public.is_staff() or exists (select 1 from public.enrollments e
    where e.cohort_id = class_sessions.cohort_id and e.student_id = auth.uid()
      and e.status in ('active', 'completed'))
);
drop policy if exists assignments_read on public.assignments;
create policy assignments_read on public.assignments for select using (
  public.is_staff() or exists (select 1 from public.enrollments e
    where e.cohort_id = assignments.cohort_id and e.student_id = auth.uid()
      and e.status in ('active', 'completed'))
);
drop policy if exists announcements_read on public.announcements;
create policy announcements_read on public.announcements for select using (
  public.is_staff() or cohort_id is null or exists (select 1 from public.enrollments e
    where e.cohort_id = announcements.cohort_id and e.student_id = auth.uid()
      and e.status in ('active', 'completed'))
);
drop policy if exists learning_read_modules on public.modules;
create policy learning_read_modules on public.modules for select using (
  public.is_staff() or exists (select 1 from public.cohorts c
    join public.enrollments e on e.cohort_id = c.id
    where c.program_id = modules.program_id and e.student_id = auth.uid()
      and e.status in ('active', 'completed'))
);
drop policy if exists learning_read_materials on public.materials;
create policy learning_read_materials on public.materials for select using (
  public.is_staff() or (published and exists (select 1 from public.modules m
    join public.cohorts c on c.program_id = m.program_id
    join public.enrollments e on e.cohort_id = c.id
    where m.id = materials.module_id and e.student_id = auth.uid()
      and e.status in ('active', 'completed')))
);
-- A student may submit only to an assignment in their own active cohort.
drop policy if exists submissions_self on public.submissions;
create policy submissions_self on public.submissions for all using (
  public.is_staff() or student_id = auth.uid()
) with check (
  public.is_staff() or (student_id = auth.uid() and exists (
    select 1 from public.assignments a join public.enrollments e on e.cohort_id = a.cohort_id
    where a.id = submissions.assignment_id and e.student_id = auth.uid() and e.status = 'active'))
);

-- Public clients see only explicitly publishable fields, never personal contact details.
drop policy if exists testimonials_public_read on public.testimonials;
create policy testimonials_staff_read on public.testimonials for select to authenticated
using (public.is_staff());
revoke select on public.testimonials from public, anon;
create or replace view public.public_testimonials with (security_barrier = true) as
  select display_name, program, study_period, quote, published_at
  from public.testimonials where status = 'published' and consent = true;
revoke all on public.public_testimonials from public;
grant select on public.public_testimonials to anon, authenticated;

-- Ratings are inserted by the checked server function only. Direct reads expose only
-- one's own rating; the service role computes the final result after blind ratings.
drop policy if exists ratings_staff_read on public.assessment_ratings;
drop policy if exists ratings_rater_insert on public.assessment_ratings;
create policy ratings_own_read on public.assessment_ratings for select to authenticated
using (rater_id = auth.uid() and public.current_role() in ('instructor','academic','admin','superadmin'));
commit;
