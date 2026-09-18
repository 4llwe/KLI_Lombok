# Release V3 — Production Hardening

## Added
- Private Supabase Storage bucket and policies for payment proofs.
- Student payment confirmation page with file validation and server verification.
- Finance/Admin verification and rejection workflow with audit logs.
- Admissions status workflow with role authorization and audit logs.
- Assessment review dashboard, versioning, approval status, and approval action.
- Password recovery and password-update flow.
- Notification idempotency and delivery event records.
- Updated-at triggers, indexes, payment constraints, HSTS, and COOP headers.
- Commercial readiness, assessment, security, and operations standards.

## Required deployment order
1. `001_core.sql`
2. `002_assessment_engine.sql`
3. `003_production_hardening.sql`
4. Configure Netlify environment variables.
5. Configure Supabase Auth URLs and require MFA for internal accounts.
6. Run staging UAT and role-by-role RLS tests before production.

## Important
The 69 initial questions are an operational starter bank. They must complete documented academic review and pilot analysis before being used for placement, certification readiness, or other high-stakes decisions.
