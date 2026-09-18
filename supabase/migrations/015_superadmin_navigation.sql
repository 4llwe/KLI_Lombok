-- Dynamic navigation managed by superadmin.
create table if not exists public.site_menu_items(
  id uuid primary key default gen_random_uuid(),
  label text not null check(char_length(label) between 1 and 60),
  url text not null check(char_length(url) between 1 and 500 and lower(url) not like 'javascript:%' and lower(url) not like 'data:%'),
  placement text not null check(placement in ('public_header','portal_sidebar','admin_sidebar')),
  roles text[] not null default array['student'],
  sort_order integer not null default 10 check(sort_order between 0 and 999),
  active boolean not null default true,
  open_new_tab boolean not null default false,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists site_menu_items_placement_order_idx on public.site_menu_items(placement,active,sort_order);
alter table public.site_menu_items enable row level security;

create policy site_menu_public_read on public.site_menu_items for select
using(active and placement='public_header');
create policy site_menu_authorized_read on public.site_menu_items for select to authenticated
using(public.current_role()='superadmin' or (active and public.current_role()::text=any(roles)));
create policy site_menu_superadmin_insert on public.site_menu_items for insert to authenticated
with check(public.current_role()='superadmin');
create policy site_menu_superadmin_update on public.site_menu_items for update to authenticated
using(public.current_role()='superadmin') with check(public.current_role()='superadmin');
create policy site_menu_superadmin_delete on public.site_menu_items for delete to authenticated
using(public.current_role()='superadmin');

grant select on public.site_menu_items to anon,authenticated;
grant insert,update,delete on public.site_menu_items to authenticated;
comment on table public.site_menu_items is 'Navigation links managed from the superadmin operations console.';
