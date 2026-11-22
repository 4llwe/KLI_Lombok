// Local PGlite emulation: this is not a substitute for testing actual Supabase.
// Only the core schema (001) and migrations 017/018 are loaded; auth and roles are simulated.
import {PGlite} from '@electric-sql/pglite';
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const db=new PGlite();
const A='00000000-0000-4000-8000-000000000001', B='00000000-0000-4000-8000-000000000002', ADMIN='00000000-0000-4000-8000-000000000003';
const core=(await readFile(new URL('../supabase/migrations/001_core.sql', import.meta.url),'utf8')).replace('create extension if not exists pgcrypto;','-- gen_random_uuid is provided by this PostgreSQL test runtime');
const patch=await readFile(new URL('../supabase/migrations/017_lms_access_hardening.sql', import.meta.url),'utf8');
await db.exec(`create role authenticated nologin; create schema auth; create table auth.users(id uuid primary key, raw_user_meta_data jsonb default '{}'::jsonb, email text); create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$; create function auth.role() returns text language sql stable as $$select nullif(current_setting('request.jwt.claim.role',true),'')$$; grant usage on schema public,auth to authenticated; grant execute on function auth.uid(),auth.role() to authenticated;`);
await db.exec(core);
await db.exec(`grant select, insert, update, delete on all tables in schema public to authenticated; grant usage,select on all sequences in schema public to authenticated; insert into auth.users(id,email,raw_user_meta_data) values ('${A}','a@example.invalid','{"full_name":"A"}'),('${B}','b@example.invalid','{"full_name":"B"}'),('${ADMIN}','admin@example.invalid','{"full_name":"Admin"}'); update public.profiles set role='admin' where id='${ADMIN}'; insert into public.cohorts(id,program_id,code,name,starts_on,ends_on,capacity,delivery_mode) values ('10000000-0000-4000-8000-000000000001',(select id from programs where code='EN-A1'),'A','A','2026-01-01','2026-12-31',5,'online'),('10000000-0000-4000-8000-000000000002',(select id from programs where code='JP-N5'),'B','B','2026-01-01','2026-12-31',5,'online'); insert into public.enrollments(student_id,cohort_id,status) values ('${A}','10000000-0000-4000-8000-000000000001','active'),('${B}','10000000-0000-4000-8000-000000000002','active'); insert into public.assignments(id,cohort_id,title,instructions) values ('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','A','A'),('20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000002','B','B'); insert into public.modules(id,program_id,title,sort_order) values ('30000000-0000-4000-8000-000000000001',(select id from programs where code='EN-A1'),'A',1),('30000000-0000-4000-8000-000000000002',(select id from programs where code='JP-N5'),'B',1); insert into public.materials(id,module_id,title,kind,published) values ('40000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','A','text',true),('40000000-0000-4000-8000-000000000002','30000000-0000-4000-8000-000000000002','B','text',true);`);
await db.exec(patch);
await db.exec(patch); // Reapplication must be safe on a partially prepared test database.
const inactiveStaffPatch=await readFile(new URL('../supabase/migrations/018_inactive_staff_access.sql', import.meta.url),'utf8');
await db.exec(inactiveStaffPatch);
await db.exec(inactiveStaffPatch);
await db.exec(`set role authenticated; select set_config('request.jwt.claim.role','authenticated',false); select set_config('request.jwt.claim.sub','${A}',false);`);
async function count(sql){const x=await db.query(sql);return Number(x.rows[0].n)}
assert.equal(await count('select count(*)::int n from public.cohorts'),1,'cohort isolation');
assert.equal(await count('select count(*)::int n from public.assignments'),1,'assignment isolation');
assert.equal(await count('select count(*)::int n from public.modules'),1,'module isolation');
await assert.rejects(db.exec(`update profiles set role='superadmin' where id='${A}'`), /Profile privileges/);
await assert.rejects(db.exec(`update profiles set active=false where id='${A}'`), /Profile privileges/);
await db.exec(`update profiles set full_name='A revised' where id='${A}'`);
await db.exec(`insert into submissions(assignment_id,student_id) values('20000000-0000-4000-8000-000000000001','${A}')`);
await assert.rejects(db.exec(`insert into submissions(assignment_id,student_id) values('20000000-0000-4000-8000-000000000002','${A}')`),/row-level security/);
await db.exec(`insert into material_progress(material_id,student_id) values('40000000-0000-4000-8000-000000000001','${A}')`);
await assert.rejects(db.exec(`insert into material_progress(material_id,student_id) values('40000000-0000-4000-8000-000000000002','${A}')`),/row-level security/);

// The portal uses upsert for submissions and progress. Exercise both update
// paths, not just INSERT, with a real PostgreSQL ON CONFLICT statement.
await db.exec(`insert into submissions(assignment_id,student_id,submission_text) values('20000000-0000-4000-8000-000000000001','${A}','updated') on conflict(assignment_id,student_id) do update set submission_text=excluded.submission_text`);
await db.exec(`insert into material_progress(material_id,student_id) values('40000000-0000-4000-8000-000000000001','${A}') on conflict(material_id,student_id) do update set completed_at=now()`);
assert.equal(await count(`select count(*)::int n from submissions where student_id='${A}' and submission_text='updated'`),1,'active enrollment upsert');

// Existing records remain readable; new and upsert writes are denied for
// every non-active enrollment status, including completed and cancelled.
for (const status of ['pending_payment','completed','cancelled']) {
  await db.exec(`reset role; select set_config('request.jwt.claim.sub','',false); update enrollments set status='${status}' where student_id='${A}'; set role authenticated; select set_config('request.jwt.claim.sub','${A}',false);`);
  assert.equal(await count(`select count(*)::int n from submissions where student_id='${A}'`),1,`${status}: history read`);
  await assert.rejects(db.exec(`insert into submissions(assignment_id,student_id,submission_text) values('20000000-0000-4000-8000-000000000001','${A}','bad') on conflict(assignment_id,student_id) do update set submission_text=excluded.submission_text`),/row-level security/,`${status}: submission upsert`);
  await assert.rejects(db.exec(`insert into material_progress(material_id,student_id) values('40000000-0000-4000-8000-000000000001','${A}') on conflict(material_id,student_id) do update set completed_at=now()`),/row-level security/,`${status}: progress upsert`);
}
await db.exec(`reset role; select set_config('request.jwt.claim.sub','',false); update enrollments set status='active' where student_id='${A}'; update profiles set active=false where id='${A}'; set role authenticated; select set_config('request.jwt.claim.sub','${A}',false);`);
await assert.rejects(db.exec(`insert into submissions(assignment_id,student_id) values('20000000-0000-4000-8000-000000000001','${A}') on conflict(assignment_id,student_id) do update set submitted_at=now()`),/row-level security/,'inactive student write');
await assert.rejects(db.exec(`insert into material_progress(material_id,student_id) values('40000000-0000-4000-8000-000000000001','${A}') on conflict(material_id,student_id) do update set completed_at=now()`),/row-level security/,'inactive student progress');
await db.exec(`reset role; select set_config('request.jwt.claim.sub','',false); update profiles set active=true where id='${A}'; set role authenticated; select set_config('request.jwt.claim.sub','${ADMIN}',false);`);
assert.equal(await count(`select count(*)::int n from profiles`),3,'active admin can read all profiles');
await db.exec(`update profiles set active=false where id='${B}'`);
await assert.rejects(db.exec(`update profiles set role='superadmin' where id='${ADMIN}'`),/Profile privileges/);

// Inactive staff must not retain privileges granted via current_role/is_staff.
await db.exec(`reset role; select set_config('request.jwt.claim.sub','',false); update profiles set active=false where id='${ADMIN}'; set role authenticated; select set_config('request.jwt.claim.sub','${ADMIN}',false);`);
assert.equal(await count(`select count(*)::int n from profiles`),1,'inactive admin sees own profile only');
assert.equal(await count(`select count(*)::int n from cohorts`),0,'inactive admin has no staff cohort access');
assert.equal((await db.query('select public.is_staff() as staff, public.current_role() as role')).rows[0].staff,false,'inactive admin not staff');
const inactiveUpdate=await db.query(`update profiles set active=true where id='${B}' returning id`);
assert.equal(inactiveUpdate.rows.length,0,'inactive admin cannot change another profile');
await assert.rejects(db.exec(`update profiles set active=true where id='${ADMIN}'`),/Profile privileges/,'inactive admin cannot reactivate self');

// Authenticated instructors still receive the original broad staff access;
// this is a documented outstanding RBAC issue, not an approval of that scope.
await db.exec(`reset role; select set_config('request.jwt.claim.sub','',false); update profiles set role='instructor',active=true where id='${B}'; set role authenticated; select set_config('request.jwt.claim.sub','${B}',false);`);
assert.equal(await count('select count(*)::int n from public.cohorts'),2,'active instructor retains current staff access');
await db.exec(`reset role; select set_config('request.jwt.claim.sub','',false); update profiles set active=false where id='${B}'; set role authenticated; select set_config('request.jwt.claim.sub','${B}',false);`);
assert.equal(await count('select count(*)::int n from public.cohorts'),1,'inactive instructor retains only own enrolled cohort');
assert.equal((await db.query('select public.is_staff() as staff')).rows[0].staff,false,'inactive instructor not staff');
await db.exec('reset role');
// The first staging script was designed for the user's test project, which
// has no enrollments. Prevent this simulation's unrelated fixture enrollments
// from granting additional access to the same program during that script.
await db.exec('delete from public.enrollments');
const stagingTest = await readFile(new URL('./test-supabase-staging-rls.sql', import.meta.url), 'utf8');
const snapshotQuery = "select (select count(*) from cohorts)::int as cohorts, (select count(*) from enrollments)::int as enrollments, (select count(*) from profiles where role='admin')::int as admins";
const before = await db.query(snapshotQuery);
await db.exec(stagingTest);
const after = await db.query(snapshotQuery);
assert.deepEqual(after.rows, before.rows, 'staging test must roll back fixture and profile changes');
const staffStagingTest=await readFile(new URL('./test-supabase-inactive-staff.sql', import.meta.url),'utf8');
const preciseSnapshot=`
  select (select json_agg(row_to_json(p) order by p.id) from (select id,role,active from profiles) p) as profiles,
  (select count(*)::int from programs) as programs,
  (select count(*)::int from cohorts) as cohorts,
  (select count(*)::int from enrollments) as enrollments,
  (select count(*)::int from assignments) as assignments,
  (select count(*)::int from modules) as modules,
  (select count(*)::int from materials) as materials,
  (select count(*)::int from submissions) as submissions,
  (select count(*)::int from material_progress) as progress,
  pg_get_functiondef('public.current_role()'::regprocedure) as role_function`;
const roleBefore=await db.query(preciseSnapshot);
await db.exec(staffStagingTest);
const roleAfter=await db.query(preciseSnapshot);
assert.deepEqual(roleAfter.rows, roleBefore.rows, 'staff test must restore function, profiles and fixture data');
console.log('PASS: migrations, status/upsert and staff-access checks, and staging rollback passed in PGlite emulation.');
await db.close();
