import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
const sql = await readFile(new URL('../supabase/migrations/017_security_readiness.sql', import.meta.url), 'utf8');
const client = await readFile(new URL('../public/testimonials.js', import.meta.url), 'utf8');
test('profile privilege changes have a server-side trigger', () => {
  assert.match(sql, /new\.role is distinct from old\.role/i);
  assert.match(sql, /new\.active is distinct from old\.active/i);
  assert.match(sql, /before update on public\.profiles/i);
});
test('policies explicitly correlate cohort-owned data', () => {
  for (const outer of ['cohorts.id', 'class_sessions.cohort_id', 'assignments.cohort_id', 'announcements.cohort_id', 'modules.program_id', 'materials.module_id']) assert.ok(sql.includes(outer), outer);
});
test('public testimonial view omits contact data and requires consent', () => {
  const view = sql.match(/create or replace view public\.public_testimonials[\s\S]*?;/i)?.[0];
  assert.ok(view); assert.doesNotMatch(view, /\b(email|phone|full_name)\b/i);
  assert.match(view, /status = 'published' and consent = true/i);
  assert.match(client, /rest\/v1\/public_testimonials\?/);
});
test('rating access is restricted and direct rating insert policy removed', () => {
  assert.match(sql, /drop policy if exists ratings_rater_insert/i);
  assert.match(sql, /rater_id = auth\.uid\(\)/i);
});
