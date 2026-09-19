begin;

create table if not exists public.testimonials(
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  display_name text,
  email text not null,
  phone text not null,
  program text,
  study_period text,
  quote text not null check(char_length(quote) between 60 and 1200),
  consent boolean not null default false,
  status text not null default 'pending' check(status in ('pending','published','rejected')),
  reviewed_by uuid references public.profiles(id),
  published_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists testimonials_status_published_idx on public.testimonials(status,published_at desc);
alter table public.testimonials enable row level security;
drop policy if exists testimonials_public_read on public.testimonials;
create policy testimonials_public_read on public.testimonials for select to anon,authenticated using(status='published' or public.is_staff());
drop policy if exists testimonials_internal_update on public.testimonials;
create policy testimonials_internal_update on public.testimonials for update to authenticated using(public.is_staff()) with check(public.is_staff());
grant select on public.testimonials to anon,authenticated;
grant update on public.testimonials to authenticated;

create table if not exists public.admission_student_links(
  application_id uuid primary key references public.applications(id) on delete cascade,
  student_id uuid not null references public.profiles(id) on delete cascade,
  provisioned_at timestamptz not null default now(),
  provisioned_by uuid references public.profiles(id)
);
alter table public.admission_student_links enable row level security;
drop policy if exists admission_links_internal_read on public.admission_student_links;
create policy admission_links_internal_read on public.admission_student_links for select to authenticated using(public.is_staff());
grant select on public.admission_student_links to authenticated;

comment on table public.testimonials is 'Verified alumni stories. Public visibility requires staff approval and explicit consent.';
comment on table public.admission_student_links is 'Links accepted applications to provisioned student accounts.';
commit;
