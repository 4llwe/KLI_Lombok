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

-- Students can read their own history, but may write only for a currently
-- active enrollment. Preserve the existing staff access until role-specific
-- policies are designed and validated separately.
drop policy if exists submissions_self on public.submissions;
create policy submissions_owner_read on public.submissions for select to authenticated
using (student_id = auth.uid());
create policy submissions_staff_manage on public.submissions for all to authenticated
using (public.is_staff()) with check (public.is_staff());
create policy submissions_student_insert on public.submissions for insert to authenticated
with check (
  student_id = auth.uid()
  and exists (select 1 from public.profiles p where p.id = auth.uid() and p.active)
  and exists (
    select 1 from public.assignments a
    join public.enrollments e on e.cohort_id = a.cohort_id
    where a.id = submissions.assignment_id and e.student_id = auth.uid() and e.status = 'active'
  )
);
create policy submissions_student_update on public.submissions for update to authenticated
using (student_id = auth.uid())
with check (
  student_id = auth.uid()
  and exists (select 1 from public.profiles p where p.id = auth.uid() and p.active)
  and exists (
    select 1 from public.assignments a
    join public.enrollments e on e.cohort_id = a.cohort_id
    where a.id = submissions.assignment_id and e.student_id = auth.uid() and e.status = 'active'
  )
);

drop policy if exists material_progress_self on public.material_progress;
create policy material_progress_owner_read on public.material_progress for select to authenticated
using (student_id = auth.uid());
create policy material_progress_staff_manage on public.material_progress for all to authenticated
using (public.is_staff()) with check (public.is_staff());
create policy material_progress_student_insert on public.material_progress for insert to authenticated
with check (
  student_id = auth.uid()
  and exists (select 1 from public.profiles p where p.id = auth.uid() and p.active)
  and exists (
    select 1 from public.materials m
    join public.modules mo on mo.id = m.module_id
    join public.cohorts c on c.program_id = mo.program_id
    join public.enrollments e on e.cohort_id = c.id
    where m.id = material_progress.material_id and m.published
      and e.student_id = auth.uid() and e.status = 'active'
  )
);
create policy material_progress_student_update on public.material_progress for update to authenticated
using (student_id = auth.uid())
with check (
  student_id = auth.uid()
  and exists (select 1 from public.profiles p where p.id = auth.uid() and p.active)
  and exists (
    select 1 from public.materials m
    join public.modules mo on mo.id = m.module_id
    join public.cohorts c on c.program_id = mo.program_id
    join public.enrollments e on e.cohort_id = c.id
    where m.id = material_progress.material_id and m.published
      and e.student_id = auth.uid() and e.status = 'active'
  )
);
