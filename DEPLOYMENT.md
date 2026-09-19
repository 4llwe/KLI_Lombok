# Deployment KLI — Production Checklist

## 1. Supabase
Run migrations in filename order, including both `015_*.sql`, then `016_professional_readiness.sql`.
Confirm the following tables exist: `profiles`, `applications`, `cohorts`, `enrollments`, `site_menu_items`, `testimonials`, and `admission_student_links`.
Create and verify private Storage buckets `payment-proofs` and `assessment-responses` using the policies in the migrations.

## 2. Netlify environment
Copy every key in `.env.example` into Netlify Site configuration → Environment variables. Never commit the service-role key to Git.
Set `PUBLIC_SITE_URL` to the final HTTPS domain without a trailing slash. Configure the bank fields before accepting payments.

## 3. First production smoke test
1. Submit a public application.
2. Sign in as admin and confirm the account opens `/admin.html`.
3. Move the application to `accepted`; confirm the participant receives the Supabase invitation.
4. Open **Aktivasi Peserta**, assign a cohort, and confirm the participant sees the active program in `/portal.html`.
5. Publish one test and complete it as a participant.
6. Upload and verify one payment proof.
7. Submit, moderate, and publish one consented testimonial.
8. Test reset password and certificate verification.

## 4. Professional content gate
Do not publish invented testimonials, tutor identities, scores, accreditations, or partner claims. Publish tutor profiles only after credential and consent checks. Keep practice assessments clearly labelled until academic validation is complete.

## 5. Release
Run `npm run check`, review desktop/mobile captures, deploy to a preview URL, complete the smoke test, then promote the preview to production.
