-- Supabase TEST PROJECT ONLY. Everything below runs inside one transaction
-- and is rolled back. No actual user data is returned. Run the full script.
BEGIN;

-- Use a database-admin context before impersonating test users.
SELECT set_config('request.jwt.claim.sub', '', true);
SELECT set_config('request.jwt.claim.role', '', true);
SELECT set_config('request.jwt.claims', '{}', true);

CREATE TEMP TABLE kli_rls_test (name text PRIMARY KEY, id uuid NOT NULL) ON COMMIT DROP;
GRANT SELECT ON kli_rls_test TO authenticated;

INSERT INTO kli_rls_test
SELECT 'user_' || row_number() OVER (ORDER BY id), id
FROM (SELECT id FROM public.profiles ORDER BY id LIMIT 2) p;
INSERT INTO kli_rls_test
SELECT 'program_' || row_number() OVER (ORDER BY id), id
FROM (SELECT id FROM public.programs ORDER BY id LIMIT 2) p;
INSERT INTO kli_rls_test (name,id)
SELECT prefix || '_' || n, gen_random_uuid()
FROM unnest(ARRAY['cohort','assignment','module','material','session','announcement']) prefix
CROSS JOIN generate_series(1,2) n;

DO $$ BEGIN
  IF (SELECT count(*) FROM kli_rls_test WHERE name LIKE 'user_%') <> 2
     OR (SELECT count(*) FROM kli_rls_test WHERE name LIKE 'program_%') <> 2 THEN
    RAISE EXCEPTION 'Diperlukan sedikitnya dua profil dan dua program untuk uji';
  END IF;
END $$;

-- Temporarily model both existing accounts as active students. These updates
-- and every fixture below are rolled back, including profile timestamps.
UPDATE public.profiles SET role='student', active=true
WHERE id IN (SELECT id FROM kli_rls_test WHERE name LIKE 'user_%');

INSERT INTO public.cohorts(id,program_id,code,name,starts_on,ends_on,capacity,delivery_mode)
SELECT f.id, p.id, 'UAT-' || f.id::text, 'KLI temporary RLS test',
       '2026-01-01', '2026-12-31', 3, 'online'
FROM kli_rls_test f JOIN kli_rls_test p ON p.name='program_' || right(f.name,1)
WHERE f.name LIKE 'cohort_%';
INSERT INTO public.enrollments(student_id,cohort_id,status)
SELECT u.id,c.id,'active' FROM kli_rls_test u
JOIN kli_rls_test c ON c.name='cohort_' || right(u.name,1)
WHERE u.name LIKE 'user_%';
INSERT INTO public.assignments(id,cohort_id,title,instructions)
SELECT a.id,c.id,'Temporary assignment','Test only'
FROM kli_rls_test a JOIN kli_rls_test c ON c.name='cohort_' || right(a.name,1)
WHERE a.name LIKE 'assignment_%';
INSERT INTO public.modules(id,program_id,title,sort_order)
SELECT m.id,p.id,'Temporary module',1 FROM kli_rls_test m
JOIN kli_rls_test p ON p.name='program_' || right(m.name,1)
WHERE m.name LIKE 'module_%';
INSERT INTO public.materials(id,module_id,title,kind,published)
SELECT m.id,mo.id,'Temporary material','text',true FROM kli_rls_test m
JOIN kli_rls_test mo ON mo.name='module_' || right(m.name,1)
WHERE m.name LIKE 'material_%';
INSERT INTO public.class_sessions(id,cohort_id,title,starts_at,ends_at)
SELECT s.id,c.id,'Temporary session','2026-01-02 08:00+00','2026-01-02 09:00+00'
FROM kli_rls_test s JOIN kli_rls_test c ON c.name='cohort_' || right(s.name,1)
WHERE s.name LIKE 'session_%';
INSERT INTO public.announcements(id,cohort_id,title,body)
SELECT a.id,c.id,'Temporary announcement','Test only' FROM kli_rls_test a
JOIN kli_rls_test c ON c.name='cohort_' || right(a.name,1)
WHERE a.name LIKE 'announcement_%';

DO $$ DECLARE u uuid; BEGIN
  SELECT id INTO u FROM kli_rls_test WHERE name='user_1';
  PERFORM set_config('request.jwt.claim.sub',u::text,true);
  PERFORM set_config('request.jwt.claim.role','authenticated',true);
  PERFORM set_config('request.jwt.claims',json_build_object('sub',u,'role','authenticated')::text,true);
END $$;
SET LOCAL ROLE authenticated;

DO $$
DECLARE
  own_user uuid := (SELECT id FROM kli_rls_test WHERE name='user_1');
  own_cohort uuid := (SELECT id FROM kli_rls_test WHERE name='cohort_1');
  other_cohort uuid := (SELECT id FROM kli_rls_test WHERE name='cohort_2');
  own_assignment uuid := (SELECT id FROM kli_rls_test WHERE name='assignment_1');
  other_assignment uuid := (SELECT id FROM kli_rls_test WHERE name='assignment_2');
  own_material uuid := (SELECT id FROM kli_rls_test WHERE name='material_1');
  other_material uuid := (SELECT id FROM kli_rls_test WHERE name='material_2');
  blocked boolean;
BEGIN
  IF auth.uid() IS DISTINCT FROM own_user THEN RAISE EXCEPTION 'Simulasi identitas gagal'; END IF;
  IF (SELECT count(*) FROM public.cohorts WHERE id=own_cohort)<>1 OR
     (SELECT count(*) FROM public.cohorts WHERE id=other_cohort)<>0 THEN
    RAISE EXCEPTION 'Uji isolasi kelas gagal'; END IF;
  IF (SELECT count(*) FROM public.assignments WHERE id=own_assignment)<>1 OR
     (SELECT count(*) FROM public.assignments WHERE id=other_assignment)<>0 THEN
    RAISE EXCEPTION 'Uji isolasi tugas gagal'; END IF;
  IF (SELECT count(*) FROM public.modules WHERE id=(SELECT id FROM kli_rls_test WHERE name='module_1'))<>1 OR
     (SELECT count(*) FROM public.modules WHERE id=(SELECT id FROM kli_rls_test WHERE name='module_2'))<>0 THEN
    RAISE EXCEPTION 'Uji isolasi modul gagal'; END IF;
  IF (SELECT count(*) FROM public.class_sessions WHERE id=(SELECT id FROM kli_rls_test WHERE name='session_1'))<>1 OR
     (SELECT count(*) FROM public.class_sessions WHERE id=(SELECT id FROM kli_rls_test WHERE name='session_2'))<>0 THEN
    RAISE EXCEPTION 'Uji isolasi jadwal gagal'; END IF;
  IF (SELECT count(*) FROM public.announcements WHERE id=(SELECT id FROM kli_rls_test WHERE name='announcement_1'))<>1 OR
     (SELECT count(*) FROM public.announcements WHERE id=(SELECT id FROM kli_rls_test WHERE name='announcement_2'))<>0 THEN
    RAISE EXCEPTION 'Uji isolasi pengumuman gagal'; END IF;

  INSERT INTO public.submissions(assignment_id,student_id) VALUES (own_assignment,own_user);
  blocked:=false;
  BEGIN
    INSERT INTO public.submissions(assignment_id,student_id) VALUES (other_assignment,own_user);
  EXCEPTION WHEN insufficient_privilege THEN blocked:=true; END;
  IF NOT blocked THEN RAISE EXCEPTION 'Uji penolakan tugas kelas lain gagal'; END IF;

  INSERT INTO public.material_progress(material_id,student_id) VALUES (own_material,own_user);
  blocked:=false;
  BEGIN
    INSERT INTO public.material_progress(material_id,student_id) VALUES (other_material,own_user);
  EXCEPTION WHEN insufficient_privilege THEN blocked:=true; END;
  IF NOT blocked THEN RAISE EXCEPTION 'Uji penolakan materi program lain gagal'; END IF;
END $$;

-- Check the same isolation from the second participant's perspective.
DO $$ DECLARE u uuid; BEGIN
  SELECT id INTO u FROM kli_rls_test WHERE name='user_2';
  PERFORM set_config('request.jwt.claim.sub',u::text,true);
  PERFORM set_config('request.jwt.claim.role','authenticated',true);
  PERFORM set_config('request.jwt.claims',json_build_object('sub',u,'role','authenticated')::text,true);
END $$;
DO $$ BEGIN
  IF (SELECT count(*) FROM public.cohorts WHERE id=(SELECT id FROM kli_rls_test WHERE name='cohort_2'))<>1 OR
     (SELECT count(*) FROM public.cohorts WHERE id=(SELECT id FROM kli_rls_test WHERE name='cohort_1'))<>0 THEN
    RAISE EXCEPTION 'Uji isolasi kelas peserta kedua gagal'; END IF;
  IF (SELECT count(*) FROM public.assignments WHERE id=(SELECT id FROM kli_rls_test WHERE name='assignment_2'))<>1 OR
     (SELECT count(*) FROM public.assignments WHERE id=(SELECT id FROM kli_rls_test WHERE name='assignment_1'))<>0 THEN
    RAISE EXCEPTION 'Uji isolasi tugas peserta kedua gagal'; END IF;
END $$;

ROLLBACK;
