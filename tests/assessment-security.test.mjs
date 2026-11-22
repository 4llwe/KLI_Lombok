import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { handler as start } from '../netlify/functions/start-test.mjs';
import { handler as submit } from '../netlify/functions/submit-test.mjs';

process.env.SUPABASE_URL = 'https://example.invalid';
process.env.SUPABASE_ANON_KEY = 'example-anon';
process.env.SUPABASE_SERVICE_ROLE_KEY = 'example-service';
const realFetch = globalThis.fetch;
after(() => { globalThis.fetch = realFetch; });
const event = { httpMethod: 'POST', headers: { authorization: 'Bearer example' }, body: JSON.stringify({ attemptId: 'attempt', testId: 'test', answers: {q:'yes'}, completedSeconds: 1 }) };
const response = (data) => new Response(data === null ? '' : JSON.stringify(data), { status: 200 });
function installFetch({ active = true, startedAt = new Date(Date.now()-30_000).toISOString(), duration = 1, tasks = [], questions = [{id:'q',correct_option:'yes',points:1}] } = {}) {
  const writes = [];
  globalThis.fetch = async (url, opts = {}) => {
    const u = String(url), method = opts.method || 'GET';
    if (u.includes('/auth/v1/user')) return response({id:'student'});
    if (u.includes('/rest/v1/profiles?')) return response([{active}]);
    if (u.includes('/rest/v1/assessment_attempts?') && method === 'GET') return response([{id:'attempt', test_id:'test', started_at:startedAt, assessment_tests:{duration_minutes:duration,pass_score:70,review_status:'academic_review',validation_status:'content_ready'}}]);
    if (u.includes('/rest/v1/assessment_questions?')) return response(questions);
    if (u.includes('/rest/v1/assessment_tasks?')) return response(tasks);
    if (method === 'POST' || method === 'PATCH') { writes.push({url:u,method,body:JSON.parse(opts.body)}); return response(null); }
    throw new Error(`Unexpected request: ${method} ${u}`);
  };
  return writes;
}
test('inactive user cannot start an assessment', async () => {
  const writes=installFetch({active:false}); const result=await start(event);
  assert.equal(result.statusCode,403); assert.equal(writes.length,0);
});
test('inactive user cannot submit an assessment', async () => {
  const writes=installFetch({active:false}); const result=await submit(event);
  assert.equal(result.statusCode,403); assert.equal(writes.length,0);
});
test('late submission fails before writing answers', async () => {
  const writes=installFetch({startedAt:new Date(Date.now()-181_000).toISOString()});
  const result=await submit(event); assert.equal(result.statusCode,409); assert.equal(writes.length,0);
});
test('invalid server timestamp fails closed before writing answers', async () => {
  const writes=installFetch({startedAt:'invalid'}); const result=await submit(event);
  assert.equal(result.statusCode,409); assert.equal(writes.length,0);
});
test('valid submission records server time, not client-supplied duration', async () => {
  const writes=installFetch(); const result=await submit(event); assert.equal(result.statusCode,200);
  const attempt=writes.find(x=>x.method==='PATCH'); assert.ok(attempt); assert.ok(attempt.body.completed_seconds >= 29); assert.notEqual(attempt.body.completed_seconds,1);
  assert.equal(JSON.parse(result.body).practiceOnly,true);
});

test('rejects another user\'s audio path before writing answers', async () => {
  const writes=installFetch({tasks:[{id:'task1',skill:'speaking'}]});
  const input={...event,body:JSON.stringify({attemptId:'attempt',taskResponses:{task1:{filePath:'other/attempt/task1-file.webm'}}})};
  const result=await submit(input); assert.equal(result.statusCode,400); assert.equal(writes.length,0);
});
test('accepts a properly scoped audio path', async () => {
  const writes=installFetch({tasks:[{id:'task1',skill:'speaking'}]});
  const input={...event,body:JSON.stringify({attemptId:'attempt',taskResponses:{task1:{filePath:'student/attempt/task1-file.webm'}}})};
  const result=await submit(input); assert.equal(result.statusCode,200);
  assert.ok(writes.some(x=>x.url.includes('assessment_task_responses')));
});

test('unanswered productive tasks are recorded for human review', async () => {
  const writes=installFetch({tasks:[{id:'task1',skill:'speaking'},{id:'task2',skill:'writing'}]});
  const result=await submit(event); assert.equal(result.statusCode,200);
  const responses=writes.find(x=>x.url.includes('assessment_task_responses'));
  assert.equal(responses.body.length,2);
  assert.ok(responses.body.every(x=>x.response_text===null && x.file_path===null && x.status==='pending_review'));
  assert.equal(JSON.parse(result.body).pendingHumanReview,true);
});

test('an empty answer cannot earn points for an empty answer key', async () => {
  const writes=installFetch({questions:[{id:'q',correct_option:'',points:1}]});
  const input={...event,body:JSON.stringify({attemptId:'attempt',answers:{}})};
  const result=await submit(input); assert.equal(result.statusCode,200);
  const answers=writes.find(x=>x.url.includes('assessment_answers'));
  assert.equal(answers.body[0].correct,false); assert.equal(JSON.parse(result.body).objectiveScore,0);
});
test('start returns server and database timestamps for the timer', async () => {
  const startedAt=new Date().toISOString();
  globalThis.fetch=async (url,opts={})=>{
    const u=String(url);
    if(u.includes('/auth/v1/user')) return response({id:'student'});
    if(u.includes('/rest/v1/profiles?')) return response([{active:true}]);
    if(u.includes('/rest/v1/assessment_tests?')) return response([{id:'test',duration_minutes:15,review_status:'academic_review',validation_status:'content_ready'}]);
    if(u.includes('/rest/v1/assessment_questions?')) return response([{id:'q',prompt:'Q',options:['A','B']}]);
    if(u.includes('/rest/v1/assessment_tasks?') || u.includes('/rest/v1/assessment_blueprints?')) return response([]);
    if(u.endsWith('/rest/v1/assessment_attempts') && opts.method==='POST') return response([{id:'attempt',started_at:startedAt}]);
    throw new Error(`Unexpected request: ${u}`);
  };
  const result=await start(event); const body=JSON.parse(result.body);
  assert.equal(result.statusCode,201); assert.equal(body.startedAt,startedAt); assert.ok(Number.isFinite(Date.parse(body.serverNow)));
});
