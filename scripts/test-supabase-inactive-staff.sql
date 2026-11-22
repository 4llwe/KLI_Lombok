-- TEST PROJECT ONLY. Execute this entire single DO block, not a selection.
-- Applies migration 018 only inside an exception subtransaction, performs tests,
-- and deliberately rolls back *all* changes on success. Failures also roll back.
-- This is not an end-to-end test of Supabase Auth, API, Storage, or every policy.
DO $test$
DECLARE
  v_admin_id uuid; v_student_id uuid; v_program_id uuid := gen_random_uuid();
  v_cohort_id uuid := gen_random_uuid(); v_assignment_id uuid := gen_random_uuid();
  v_module_id uuid := gen_random_uuid(); v_material_id uuid := gen_random_uuid();
  blocked boolean; affected integer;
BEGIN
  BEGIN
    PERFORM set_config('request.jwt.claim.sub','',true);
    PERFORM set_config('request.jwt.claim.role','',true);
    PERFORM set_config('request.jwt.claims','{}',true);
    EXECUTE $fn$
      CREATE OR REPLACE FUNCTION public.current_role()
      RETURNS public.app_role LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public
      AS 'SELECT role FROM public.profiles WHERE id=auth.uid() AND active=true'
    $fn$;
    SELECT id INTO v_admin_id FROM public.profiles ORDER BY id LIMIT 1;
    SELECT id INTO v_student_id FROM public.profiles ORDER BY id OFFSET 1 LIMIT 1;
    IF v_admin_id IS NULL OR v_student_id IS NULL THEN
      RAISE EXCEPTION 'Diperlukan dua profil'; END IF;
    UPDATE public.profiles SET role='admin',active=true WHERE id=v_admin_id;
    UPDATE public.profiles SET role='student',active=true WHERE id=v_student_id;
    -- A distinct program prevents pre-existing active enrollments in another
    -- cohort of the same program from making progress writes legitimate.
    INSERT INTO public.programs(id,code,name,language,framework,level,description)
      VALUES(v_program_id,'UAT-'||v_program_id::text,'Temporary program','English','test','test','Test only');
    INSERT INTO public.cohorts(id,program_id,code,name,starts_on,ends_on,capacity,delivery_mode)
      VALUES(v_cohort_id,v_program_id,'UAT-'||v_cohort_id::text,'Temporary role test','2026-01-01','2026-12-31',3,'online');
    INSERT INTO public.enrollments(student_id,cohort_id,status) VALUES(v_student_id,v_cohort_id,'active');
    INSERT INTO public.assignments(id,cohort_id,title,instructions) VALUES(v_assignment_id,v_cohort_id,'Temporary task','Test only');
    INSERT INTO public.modules(id,program_id,title,sort_order) VALUES(v_module_id,v_program_id,'Temporary module',1);
    INSERT INTO public.materials(id,module_id,title,kind,published) VALUES(v_material_id,v_module_id,'Temporary material','text',true);

    PERFORM set_config('request.jwt.claim.sub',v_student_id::text,true);
    PERFORM set_config('request.jwt.claim.role','authenticated',true);
    PERFORM set_config('request.jwt.claims',json_build_object('sub',v_student_id,'role','authenticated')::text,true);
    PERFORM set_config('role','authenticated',true);
    IF auth.uid() IS DISTINCT FROM v_student_id THEN RAISE EXCEPTION 'Simulasi peserta gagal'; END IF;
    INSERT INTO public.submissions(assignment_id,student_id,submission_text) VALUES(v_assignment_id,v_student_id,'test')
      ON CONFLICT (assignment_id,student_id) DO UPDATE SET submission_text=excluded.submission_text;
    INSERT INTO public.material_progress(material_id,student_id) VALUES(v_material_id,v_student_id)
      ON CONFLICT (material_id,student_id) DO UPDATE SET completed_at=now();
    -- Repeat to exercise ON CONFLICT update with active enrollment.
    INSERT INTO public.submissions(assignment_id,student_id,submission_text) VALUES(v_assignment_id,v_student_id,'test update')
      ON CONFLICT (assignment_id,student_id) DO UPDATE SET submission_text=excluded.submission_text;
    INSERT INTO public.material_progress(material_id,student_id) VALUES(v_material_id,v_student_id)
      ON CONFLICT (material_id,student_id) DO UPDATE SET completed_at=now();

    PERFORM set_config('request.jwt.claim.sub',v_admin_id::text,true);
    PERFORM set_config('request.jwt.claims',json_build_object('sub',v_admin_id,'role','authenticated')::text,true);
    IF NOT public.is_staff() OR public.current_role() IS DISTINCT FROM 'admin'::public.app_role THEN
      RAISE EXCEPTION 'Admin aktif tidak dikenali'; END IF;
    IF (SELECT count(*) FROM public.profiles WHERE id=v_student_id)<>1 THEN
      RAISE EXCEPTION 'Admin aktif tidak dapat membaca profil peserta'; END IF;
    UPDATE public.enrollments e SET status='cancelled' WHERE e.student_id=v_student_id AND e.cohort_id=v_cohort_id;
    GET DIAGNOSTICS affected=ROW_COUNT;
    IF affected<>1 THEN RAISE EXCEPTION 'Admin aktif tidak dapat mengubah enrollment uji'; END IF;

    PERFORM set_config('request.jwt.claim.sub',v_student_id::text,true);
    PERFORM set_config('request.jwt.claims',json_build_object('sub',v_student_id,'role','authenticated')::text,true);
    IF (SELECT count(*) FROM public.submissions s WHERE s.assignment_id=v_assignment_id AND s.student_id=v_student_id)<>1 THEN
      RAISE EXCEPTION 'Riwayat pengumpulan peserta tidak terbaca'; END IF;
    blocked:=false;
    BEGIN
      INSERT INTO public.submissions(assignment_id,student_id,submission_text) VALUES(v_assignment_id,v_student_id,'should fail')
        ON CONFLICT (assignment_id,student_id) DO UPDATE SET submission_text=excluded.submission_text;
    EXCEPTION WHEN insufficient_privilege THEN blocked:=true; END;
    IF NOT blocked THEN RAISE EXCEPTION 'Upsert tugas untuk enrollment cancelled tidak ditolak'; END IF;
    blocked:=false;
    BEGIN
      INSERT INTO public.material_progress(material_id,student_id) VALUES(v_material_id,v_student_id)
        ON CONFLICT (material_id,student_id) DO UPDATE SET completed_at=now();
    EXCEPTION WHEN insufficient_privilege THEN blocked:=true; END;
    IF NOT blocked THEN RAISE EXCEPTION 'Upsert progres untuk enrollment cancelled tidak ditolak'; END IF;

    -- Restore the SQL editor role to deactivate the temporary admin; claims are
    -- cleared so the profile guard does not mistake this for self-escalation.
    PERFORM set_config('role','none',true);
    PERFORM set_config('request.jwt.claim.sub','',true);
    PERFORM set_config('request.jwt.claim.role','',true);
    PERFORM set_config('request.jwt.claims','{}',true);
    UPDATE public.profiles SET active=false WHERE id=v_admin_id;
    PERFORM set_config('request.jwt.claim.sub',v_admin_id::text,true);
    PERFORM set_config('request.jwt.claim.role','authenticated',true);
    PERFORM set_config('request.jwt.claims',json_build_object('sub',v_admin_id,'role','authenticated')::text,true);
    PERFORM set_config('role','authenticated',true);
    IF public.is_staff() OR public.current_role() IS NOT NULL THEN
      RAISE EXCEPTION 'Admin nonaktif masih memiliki peran staf'; END IF;
    IF (SELECT count(*) FROM public.profiles WHERE id=v_student_id)<>0 OR
       (SELECT count(*) FROM public.cohorts c WHERE c.id=v_cohort_id)<>0 THEN
      RAISE EXCEPTION 'Admin nonaktif masih dapat membaca data staf uji'; END IF;
    UPDATE public.profiles SET active=false WHERE id=v_student_id;
    GET DIAGNOSTICS affected=ROW_COUNT;
    IF affected<>0 THEN RAISE EXCEPTION 'Admin nonaktif masih dapat mengubah profil lain'; END IF;

    RAISE EXCEPTION USING ERRCODE='K1000', MESSAGE='KLI_ROLE_PASS_ROLLBACK';
  EXCEPTION WHEN SQLSTATE 'K1000' THEN
    IF SQLERRM <> 'KLI_ROLE_PASS_ROLLBACK' THEN RAISE; END IF;
  END;
  RAISE NOTICE 'KLI_ROLE_PASS: tests passed; all temporary changes rolled back.';
END
$test$;
