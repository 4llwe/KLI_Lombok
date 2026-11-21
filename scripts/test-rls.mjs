// Local PGlite emulation: this is not a substitute for testing actual Supabase.
// Only the core schema (001) and migration 017 are loaded; auth and roles are simulated.
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
await db.exec(`select set_config('request.jwt.claim.sub','${ADMIN}',false); update profiles set active=false where id='${B}'`);
await assert.rejects(db.exec(`update profiles set role='superadmin' where id='${ADMIN}'`),/Profile privileges/);
console.log('PASS: migration parsed; access/trigger scenarios passed with PGlite emulation.');
await db.close();
