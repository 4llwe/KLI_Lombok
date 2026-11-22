// Local browser regression tests with mocked assessment APIs; never contacts Supabase.
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, resolve } from 'node:path';
import assert from 'node:assert/strict';
import { chromium } from 'playwright';
const root = resolve(new URL('../public', import.meta.url).pathname);
const server = createServer(async (req,res) => {
  const path=resolve(join(root,decodeURIComponent(new URL(req.url,'http://localhost').pathname)));
  if (!path.startsWith(root+'/')) { res.writeHead(403).end(); return; }
  try { const file=await readFile(path); const type={'.js':'text/javascript','.html':'text/html','.css':'text/css'}[extname(path)] || 'application/octet-stream';res.writeHead(200,{'content-type':type}).end(file); }
  catch { res.writeHead(404).end(); }
});
await new Promise(ok=>server.listen(0,'127.0.0.1',ok));
const origin=`http://127.0.0.1:${server.address().port}`;
const browser=await chromium.launch({headless:true,...(process.env.CHROMIUM_PATH?{executablePath:process.env.CHROMIUM_PATH}:{}),args:['--no-sandbox']});
async function scenario({duration,tasks,failFirst=false,action}){
 const context=await browser.newContext(); const calls=[];
 await context.addInitScript(()=>localStorage.setItem('kliSession',JSON.stringify({access_token:'test',user:{id:'student'}})));
 await context.route('**/.netlify/functions/start-test',route=>{const now=new Date().toISOString();return route.fulfill({status:201,contentType:'application/json',body:JSON.stringify({attemptId:'attempt',startedAt:now,serverNow:now,test:{duration_minutes:duration,language:'English',level:'A1',title:'Test',description:'Test'},questions:[{id:'q',prompt:'Choose',options:['yes','no']}],tasks,practiceOnly:true})});});
 await context.route('**/.netlify/functions/submit-test',async route=>{calls.push(route.request().postDataJSON());if(failFirst&&calls.length===1)return route.fulfill({status:500,contentType:'application/json',body:JSON.stringify({error:'Gangguan uji'})});return route.fulfill({status:200,contentType:'application/json',body:JSON.stringify({objectiveScore:100,message:'Tersimpan',sectionScores:[],practiceOnly:true})});});
 const page=await context.newPage(); await page.goto(`${origin}/take-test.html?testId=test`); await page.waitForSelector('input[name="q"]');
 await action({page,calls}); await context.close();
}
try {
 await scenario({duration:0.015,tasks:[{id:'w',skill:'writing',prompt:'write',min_words:3,max_words:20},{id:'s',skill:'speaking',prompt:'speak'}],action:async({page,calls})=>{
   await page.waitForSelector('#test-form[hidden]',{state:'attached',timeout:5000});
   assert.equal(calls.length,1); assert.equal(calls[0].answers.q,null); assert.equal(calls[0].taskResponses.w.text,''); assert.equal(calls[0].taskResponses.s,undefined);
   assert.match(await page.locator('#test-result').innerText(),/Rekaman speaking/);
 }});
 await scenario({duration:0.12,tasks:[{id:'w',skill:'writing',prompt:'write',min_words:2,max_words:20}],failFirst:true,action:async({page,calls})=>{
   await page.locator('input[name="q"]').first().check(); await page.locator('textarea[name="task-w"]').fill('short');
   await page.locator('#test-form button[type=submit]').click(); assert.match(await page.locator('#test-result').innerText(),/Jumlah kata/); assert.equal(calls.length,0);
   await page.locator('textarea[name="task-w"]').fill('two words'); await page.locator('#test-form button[type=submit]').click();
   await page.getByText(/Gangguan uji/).waitFor(); assert.equal(calls.length,1);
   await page.locator('#test-form button[type=submit]').click(); await page.waitForSelector('#test-form[hidden]',{state:'attached'}); assert.equal(calls.length,2);
 }});
 console.log('PASS: timeout partial submission, validation and retry in local Chromium with mocked APIs.');
} finally { await browser.close(); await new Promise(ok=>server.close(ok)); }
