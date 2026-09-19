-- Empirical validation controls for defensible commercial assessment use.
alter table public.assessment_tests add column if not exists usage_scope text not null default 'diagnostic' check(usage_scope in ('practice','diagnostic','placement','progress','final','readiness'));
alter table public.assessment_tests add column if not exists validation_status text not null default 'content_ready' check(validation_status in ('content_ready','pilot','validated','suspended'));
alter table public.assessment_tests add column if not exists pilot_sample_size int not null default 0;
alter table public.assessment_tests add column if not exists reliability numeric;
alter table public.assessment_tests add column if not exists last_statistics_at timestamptz;
update public.assessment_tests set usage_scope=case when test_type='placement' then 'placement' when test_type='progress' then 'progress' when test_type='final' then 'final' when test_type='certification_readiness' then 'readiness' else 'diagnostic' end;
create table public.assessment_validation_events(id uuid primary key default gen_random_uuid(),test_id uuid not null references public.assessment_tests(id),actor_id uuid not null references public.profiles(id),from_status text,to_status text not null,reason text not null,metrics jsonb not null default '{}',created_at timestamptz not null default now());
alter table public.assessment_validation_events enable row level security;
create policy validation_events_staff_read on public.assessment_validation_events for select using(public.is_staff());
drop view if exists public.assessment_quality_summary;
create or replace view public.assessment_quality_summary with (security_invoker=true) as select t.id,t.code,t.language,t.level,t.test_type,t.version,t.review_status,t.validation_status,t.pilot_sample_size,t.reliability,count(distinct q.id)::int question_count,count(distinct k.id)::int task_count,coalesce(b.min_objective_items,20) min_objective_items,coalesce(b.min_tasks,4) min_tasks,(count(distinct q.id)>=coalesce(b.min_objective_items,20) and count(distinct k.id)>=coalesce(b.min_tasks,4)) content_complete from public.assessment_tests t left join public.assessment_questions q on q.test_id=t.id left join public.assessment_tasks k on k.test_id=t.id left join public.assessment_blueprints b on b.test_id=t.id group by t.id,b.min_objective_items,b.min_tasks;
comment on column public.assessment_tests.validation_status is 'Only validated assessments may support final high-stakes decisions. Content-ready and pilot forms are practice/diagnostic only.';
