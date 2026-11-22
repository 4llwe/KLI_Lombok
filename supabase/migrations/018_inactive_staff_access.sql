-- Apply and test on a non-production Supabase project before rollout.
-- Keep the signature and SECURITY DEFINER semantics used by existing policies.
-- An inactive profile does not confer a staff role through current_role().
-- This does NOT revoke the user's session or remove access granted by
-- owner/public policies; account suspension requires a separate full audit.
create or replace function public.current_role()
returns public.app_role
language sql stable security definer set search_path = public
as $$
  select role from public.profiles
  where id = auth.uid() and active = true
$$;