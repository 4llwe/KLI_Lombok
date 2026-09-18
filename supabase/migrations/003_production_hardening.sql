-- KLI production hardening: timestamps, private payment proofs, idempotency, assessment governance
create or replace function public.set_updated_at() returns trigger language plpgsql as $$ begin new.updated_at=now(); return new; end $$;
drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at before update on public.profiles for each row execute function public.set_updated_at();
drop trigger if exists applications_set_updated_at on public.applications;
create trigger applications_set_updated_at before update on public.applications for each row execute function public.set_updated_at();

alter table public.payment_confirmations add constraint payment_status_valid check(status in ('submitted','verified','rejected'));
create unique index if not exists one_open_confirmation_per_invoice on public.payment_confirmations(invoice_id) where status='submitted';
create index if not exists payment_confirmations_status_idx on public.payment_confirmations(status,created_at desc);
create index if not exists applications_status_idx on public.applications(status,created_at desc);
create index if not exists invoices_student_status_idx on public.invoices(student_id,status);

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('payment-proofs','payment-proofs',false,5242880,array['image/jpeg','image/png','application/pdf'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

create policy payment_proof_owner_insert on storage.objects for insert to authenticated
with check(bucket_id='payment-proofs' and (storage.foldername(name))[1]=auth.uid()::text);
create policy payment_proof_owner_read on storage.objects for select to authenticated
using(bucket_id='payment-proofs' and ((storage.foldername(name))[1]=auth.uid()::text or public.current_role() in ('finance','admin','superadmin')));
create policy payment_proof_finance_update on storage.objects for update to authenticated
using(bucket_id='payment-proofs' and public.current_role() in ('finance','admin','superadmin'));

create table public.notification_events(
 id uuid primary key default gen_random_uuid(),event_key text not null unique,event_type text not null,recipient text not null,channel text not null check(channel in ('email','whatsapp')),status text not null check(status in ('pending','sent','failed')),provider_id text,error_message text,created_at timestamptz not null default now(),sent_at timestamptz
);
alter table public.notification_events enable row level security;
create policy notification_events_admin_read on public.notification_events for select using(public.current_role() in ('admin','superadmin'));

alter table public.assessment_tests add column if not exists version text not null default '1.0';
alter table public.assessment_tests add column if not exists review_status text not null default 'draft' check(review_status in ('draft','academic_review','approved','retired'));
alter table public.assessment_tests add column if not exists reviewed_by uuid references public.profiles(id);
alter table public.assessment_tests add column if not exists reviewed_at timestamptz;
alter table public.assessment_tests add column if not exists validity_months int not null default 12 check(validity_months between 1 and 60);
alter table public.assessment_questions add column if not exists competency text not null default 'language_use';
alter table public.assessment_questions add column if not exists difficulty numeric(3,2) check(difficulty is null or difficulty between 0 and 1);
alter table public.assessment_attempts add column if not exists completed_seconds int check(completed_seconds is null or completed_seconds>=0);
update public.assessment_tests set review_status='academic_review' where review_status='draft';

create or replace view public.assessment_quality_summary with (security_invoker=true) as
select t.id,t.code,t.language,t.level,t.test_type,t.version,t.review_status,count(q.id)::int question_count,sum(q.points) max_points
from public.assessment_tests t left join public.assessment_questions q on q.test_id=t.id
group by t.id;

comment on table public.notification_events is 'Idempotency and delivery audit for transactional messages.';
comment on column public.assessment_tests.review_status is 'Only approved tests should be used for high-stakes commercial decisions.';
