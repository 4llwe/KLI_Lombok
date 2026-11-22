-- RUN ONLY ON THE SUPABASE TEST PROJECT.
-- Run this entire DO block as one statement; do not select just part of it.
-- All test writes and temporary profile-role changes are reverted by the
-- deliberate exception in the inner subtransaction, even when the test passes.
DO $test$
DECLARE
  user_a uuid; user_b uuid; program_a uuid; program_b uuid;
  cohort_a uuid := gen_random_uuid(); cohort_b uuid := gen_random_uuid();
  assignment_a uuid := gen_random_uuid(); assignment_b uuid := gen_random_uuid();
  module_a uuid := gen_random_uuid(); module_b uuid := gen_random_uuid();
  material_a uuid := gen_random_uuid(); material_b uuid := gen_random_uuid();
  session_a uuid := gen_random_uuid(); session_b uuid := gen_random_uuid();
  announcement_a uuid := gen_random_uuid(); announcement_b uuid := gen_random_uuid();
  blocked boolean;
BEGIN
  BEGIN
    PERFORM set_config('request.jwt.claim.sub', '', true);
    PERFORM set_config('request.jwt.claim.role', '', true);
    PERFORM set_config('request.jwt.claims', '{}', true);

    SELECT id INTO user_a FROM public.profiles ORDER BY id LIMIT 1;
    SELECT id INTO user_b FROM public.profiles ORDER BY id OFFSET 1 LIMIT 1;
    SELECT id INTO program_a FROM public.programs ORDER BY id LIMIT 1;
    SELECT id INTO program_b FROM public.programs ORDER BY id OFFSET 1 LIMIT 1;
    IF user_a IS NULL OR user_b IS NULL OR program_a IS NULL OR program_b IS NULL THEN
      RAISE EXCEPTION 'Diperlukan dua profil dan dua program untuk uji';
    END IF;

    UPDATE public.profiles SET role='student', active=true WHERE id IN (user_a,user_b);
    INSERT INTO public.cohorts(id,program_id,code,name,starts_on,ends_on,capacity,delivery_mode)
    VALUES (cohort_a,program_a,'UAT-'||cohort_a::text,'Temporary RLS test','2026-01-01','2026-12-31',3,'online'),
           (cohort_b,program_b,'UAT-'||cohort_b::text,'Temporary RLS test','2026-01-01','2026-12-31',3,'online');
    INSERT INTO public.enrollments(student_id,cohort_id,status)
    VALUES (user_a,cohort_a,'active'),(user_b,cohort_b,'active');
    INSERT INTO public.assignments(id,cohort_id,title,instructions)
    VALUES (assignment_a,cohort_a,'Temporary assignment','Test only'),
           (assignment_b,cohort_b,'Temporary assignment','Test only');
    INSERT INTO public.modules(id,program_id,title,sort_order)
    VALUES (module_a,program_a,'Temporary module',1),(module_b,program_b,'Temporary module',1);
    INSERT INTO public.materials(id,module_id,title,kind,published)
    VALUES (material_a,module_a,'Temporary material','text',true),
           (material_b,module_b,'Temporary material','text',true);
    INSERT INTO public.class_sessions(id,cohort_id,title,starts_at,ends_at)
    VALUES (session_a,cohort_a,'Temporary session','2026-01-02 08:00+00','2026-01-02 09:00+00'),
           (session_b,cohort_b,'Temporary session','2026-01-02 08:00+00','2026-01-02 09:00+00');
    INSERT INTO public.announcements(id,cohort_id,title,body)
    VALUES (announcement_a,cohort_a,'Temporary announcement','Test only'),
           (announcement_b,cohort_b,'Temporary announcement','Test only');

    PERFORM set_config('request.jwt.claim.sub',user_a::text,true);
    PERFORM set_config('request.jwt.claim.role','authenticated',true);
    PERFORM set_config('request.jwt.claims',json_build_object('sub',user_a,'role','authenticated')::text,true);
    PERFORM set_config('role','authenticated',true);

    IF auth.uid() IS DISTINCT FROM user_a THEN RAISE EXCEPTION 'Simulasi identitas A gagal'; END IF;
    IF (SELECT count(*) FROM public.cohorts WHERE id=cohort_a)<>1 OR
       (SELECT count(*) FROM public.cohorts WHERE id=cohort_b)<>0 THEN
      RAISE EXCEPTION 'Uji isolasi kelas A gagal'; END IF;
    IF (SELECT count(*) FROM public.assignments WHERE id=assignment_a)<>1 OR
       (SELECT count(*) FROM public.assignments WHERE id=assignment_b)<>0 THEN
      RAISE EXCEPTION 'Uji isolasi tugas A gagal'; END IF;
    IF (SELECT count(*) FROM public.modules WHERE id=module_a)<>1 OR
       (SELECT count(*) FROM public.modules WHERE id=module_b)<>0 THEN
      RAISE EXCEPTION 'Uji isolasi modul A gagal'; END IF;
    IF (SELECT count(*) FROM public.class_sessions WHERE id=session_a)<>1 OR
       (SELECT count(*) FROM public.class_sessions WHERE id=session_b)<>0 THEN
      RAISE EXCEPTION 'Uji isolasi jadwal A gagal'; END IF;
    IF (SELECT count(*) FROM public.announcements WHERE id=announcement_a)<>1 OR
       (SELECT count(*) FROM public.announcements WHERE id=announcement_b)<>0 THEN
      RAISE EXCEPTION 'Uji isolasi pengumuman A gagal'; END IF;

    INSERT INTO public.submissions(assignment_id,student_id) VALUES (assignment_a,user_a);
    blocked:=false;
    BEGIN
      INSERT INTO public.submissions(assignment_id,student_id) VALUES (assignment_b,user_a);
    EXCEPTION WHEN insufficient_privilege THEN blocked:=true; END;
    IF NOT blocked THEN RAISE EXCEPTION 'Uji penolakan tugas kelas lain gagal'; END IF;

    INSERT INTO public.material_progress(material_id,student_id) VALUES (material_a,user_a);
    blocked:=false;
    BEGIN
      INSERT INTO public.material_progress(material_id,student_id) VALUES (material_b,user_a);
    EXCEPTION WHEN insufficient_privilege THEN blocked:=true; END;
    IF NOT blocked THEN RAISE EXCEPTION 'Uji penolakan materi program lain gagal'; END IF;

    PERFORM set_config('request.jwt.claim.sub',user_b::text,true);
    PERFORM set_config('request.jwt.claims',json_build_object('sub',user_b,'role','authenticated')::text,true);
    IF auth.uid() IS DISTINCT FROM user_b THEN RAISE EXCEPTION 'Simulasi identitas B gagal'; END IF;
    IF (SELECT count(*) FROM public.cohorts WHERE id=cohort_b)<>1 OR
       (SELECT count(*) FROM public.cohorts WHERE id=cohort_a)<>0 THEN
      RAISE EXCEPTION 'Uji isolasi kelas B gagal'; END IF;
    IF (SELECT count(*) FROM public.assignments WHERE id=assignment_b)<>1 OR
       (SELECT count(*) FROM public.assignments WHERE id=assignment_a)<>0 THEN
      RAISE EXCEPTION 'Uji isolasi tugas B gagal'; END IF;

    -- Intentional: PostgreSQL rolls back the entire inner block, including
    -- test records, claim/role settings, and the temporary profile changes.
    RAISE EXCEPTION USING ERRCODE='K1000', MESSAGE='KLI_RLS_PASS_ROLLBACK';
  EXCEPTION WHEN SQLSTATE 'K1000' THEN
    IF SQLERRM <> 'KLI_RLS_PASS_ROLLBACK' THEN RAISE; END IF;
  END;
  RAISE NOTICE 'KLI_RLS_PASS: isolation checks completed; all test changes rolled back.';
END
$test$;
