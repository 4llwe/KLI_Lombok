-- Initial access hardening. Apply to staging first; run the cross-role tests
-- in SECURITY_OPERATIONS.md before considering a production deployment.

-- A user's own profile update must never grant a privileged role or reactivate
-- an account. Administrative changes to other profiles remain subject to RLS.
create or replace function public.guard_profile_privileges()
returns trigger language plpgsql set search_path = public as $$
begin
  if (new.role is distinct from old.role or new.active is distinct from old.active)
     and auth.uid() is not null and coalesce(auth.role(), '') <> 'service_role'
     and (auth.uid() = old.id or coalesce(public.current_role()::text, '') not in ('admin', 'superadmin')) then
    raise exception 'Profile privileges may only be changed by an administrator for another user';
  end if;
  return new;
end;
$$;

drop trigger if exists guard_profile_privileges_trigger on public.profiles;
create trigger guard_profile_privileges_trigger before update on public.profiles
for each row execute function public.guard_profile_privileges();

-- Qualify the outer table to avoid binding an unqualified name to the inner
-- enrollments table rather than to the row whose access is being checked.
drop policy if exists cohorts_enrolled_read on public.cohorts;
create policy cohorts_enrolled_read on public.cohorts for select using (
  public.is_staff() or exists (
    select 1 from public.enrollments e
    where e.cohort_id = cohorts.id and e.student_id = auth.uid()
  )
);
drop policy if exists sessions_read on public.class_sessions;
create policy sessions_read on public.class_sessions for select using (
  public.is_staff() or exists (
    select 1 from public.enrollments e
    where e.cohort_id = class_sessions.cohort_id and e.student_id = auth.uid()
  )
);
drop policy if exists assignments_read on public.assignments;
create policy assignments_read on public.assignments for select using (
  public.is_staff() or exists (
    select 1 from public.enrollments e
    where e.cohort_id = assignments.cohort_id and e.student_id = auth.uid()
  )
);
drop policy if exists announcements_read on public.announcements;
create policy announcements_read on public.announcements for select using (
  public.is_staff() or announcements.cohort_id is null or exists (
    select 1 from public.enrollments e
    where e.cohort_id = announcements.cohort_id and e.student_id = auth.uid()
  )
);
drop policy if exists learning_read_modules on public.modules;
create policy learning_read_modules on public.modules for select using (
  public.is_staff() or exists (
    select 1 from public.cohorts c join public.enrollments e on e.cohort_id = c.id
    where c.program_id = modules.program_id and e.student_id = auth.uid()
  )
);
