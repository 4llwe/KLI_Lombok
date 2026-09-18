-- Conceptual PostgreSQL schema; review before migration.
create type user_role as enum ('student','guardian','instructor','academic','admin','finance','executive','superadmin');
create type enrollment_status as enum ('application','placement','offered','awaiting_payment','active','completed','cancelled');
create type invoice_status as enum ('draft','issued','partially_paid','paid','void','refunded');

create table organizations (id uuid primary key, name text not null, legal_name text, timezone text not null default 'Asia/Makassar', created_at timestamptz not null default now());
create table users (id uuid primary key, organization_id uuid not null references organizations(id), email text, phone text, full_name text not null, password_hash text, is_active boolean not null default true, created_at timestamptz not null default now());
create table user_roles (user_id uuid references users(id), role user_role not null, primary key(user_id,role));
create table programs (id uuid primary key, organization_id uuid not null references organizations(id), code text not null, name text not null, framework text, level text, description text, is_published boolean not null default false, unique(organization_id,code));
create table cohorts (id uuid primary key, program_id uuid not null references programs(id), name text not null, starts_on date, ends_on date, capacity int check(capacity>0), delivery_mode text, status text not null default 'draft');
create table enrollments (id uuid primary key, cohort_id uuid not null references cohorts(id), student_id uuid not null references users(id), status enrollment_status not null default 'application', enrolled_at timestamptz, unique(cohort_id,student_id));
create table sessions (id uuid primary key, cohort_id uuid not null references cohorts(id), title text not null, starts_at timestamptz not null, ends_at timestamptz not null, location text, meeting_url text, check(ends_at>starts_at));
create table attendance (session_id uuid references sessions(id), student_id uuid references users(id), status text not null, recorded_by uuid references users(id), recorded_at timestamptz not null default now(), primary key(session_id,student_id));
create table assessments (id uuid primary key, cohort_id uuid not null references cohorts(id), title text not null, kind text not null, max_score numeric not null, due_at timestamptz);
create table grades (assessment_id uuid references assessments(id), student_id uuid references users(id), score numeric, feedback text, graded_by uuid references users(id), graded_at timestamptz, primary key(assessment_id,student_id));
create table invoices (id uuid primary key, organization_id uuid not null references organizations(id), enrollment_id uuid references enrollments(id), invoice_number text not null unique, amount numeric(14,2) not null check(amount>=0), currency char(3) not null default 'IDR', status invoice_status not null default 'draft', due_at timestamptz, created_at timestamptz not null default now());
create table payments (id uuid primary key, invoice_id uuid not null references invoices(id), provider text not null, provider_reference text not null unique, amount numeric(14,2) not null, status text not null, paid_at timestamptz, raw_event_id text unique);
create table certificates (id uuid primary key, enrollment_id uuid not null unique references enrollments(id), certificate_number text not null unique, issued_at timestamptz not null, verification_token text not null unique, revoked_at timestamptz);
create table audit_logs (id bigint generated always as identity primary key, organization_id uuid not null references organizations(id), actor_id uuid references users(id), action text not null, entity_type text not null, entity_id text, metadata jsonb not null default '{}', created_at timestamptz not null default now());
create index idx_sessions_cohort_start on sessions(cohort_id,starts_at);
create index idx_enrollments_student on enrollments(student_id,status);
create index idx_invoices_status_due on invoices(status,due_at);
create index idx_audit_entity on audit_logs(entity_type,entity_id,created_at);
