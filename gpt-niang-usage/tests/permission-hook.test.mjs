import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {permissionHook,validResponse} from '../runtime/permission-hook.mjs';
import {parseAttentionRecord,CompletionMonitor} from '../runtime/completion-monitor.mjs';
const input={hook_event_name:'PermissionRequest',session_id:'test-thread',turn_id:'test-turn',tool_name:'Bash',tool_input:{command:'echo synthetic-test-only',description:'仅测试，不执行命令'}};
async function fixture(fn){const root=fs.mkdtempSync(path.join(os.tmpdir(),'niang-permission-'));try{fs.writeFileSync(path.join(root,'presence.json'),JSON.stringify({at:Date.now(),visible:true}));return await fn(root);}finally{const target=path.resolve(root);assert.ok(target.startsWith(path.resolve(os.tmpdir())+path.sep));fs.rmSync(target,{recursive:true,force:true});}}
async function requestIn(root){for(let i=0;i<50;i++){const dir=path.join(root,'interactions');let f;try{f=fs.readdirSync(dir).find(f=>f.endsWith('.request.json'));}catch{}if(f)return {file:path.join(dir,f),request:JSON.parse(fs.readFileSync(path.join(dir,f),'utf8'))};await new Promise(r=>setTimeout(r,10));}throw Error('request not created');}
test('no pet, timeout or malformed input never approves',async()=>{
 assert.equal(await permissionHook({},{}),null);
 await fixture(async root=>{assert.equal(await permissionHook(input,{dataDir:root,timeoutMs:20,pollMs:5}),null);fs.unlinkSync(path.join(root,'presence.json'));assert.equal(await permissionHook(input,{dataDir:root}),null);});
});
test('explicit one-request answers return only allow or deny; fallback preserves original prompt',async()=>{
 for(const decision of ['allow','deny','fallback'])await fixture(async root=>{
  const pending=permissionHook(input,{dataDir:root,timeoutMs:1000,pollMs:5});const {request}=await requestIn(root);
  fs.writeFileSync(path.join(root,'interactions',request.id+'.response.json'),JSON.stringify({id:request.id,token:request.token,fingerprint:request.fingerprint,decision}));
  const result=await pending;if(decision==='fallback')assert.equal(result,null);else assert.equal(result.hookSpecificOutput.decision.behavior,decision);
  assert.deepEqual(fs.readdirSync(path.join(root,'interactions')),[]);
 });
});
test('wrong request/token, altered displayed operation and expired answers cannot approve',async()=>{
 const r={id:'one',token:'secret',fingerprint:'hash',expiresAt:Date.now()+1000};
 assert.equal(validResponse(r,{...r,id:'two',decision:'allow'}),false);
 assert.equal(validResponse(r,{...r,token:'wrong',decision:'allow'}),false);
 assert.equal(validResponse(r,{...r,decision:'allow'},r.expiresAt),false);
 await fixture(async root=>{
  const pending=permissionHook(input,{dataDir:root,timeoutMs:1000,pollMs:5});const {request,file}=await requestIn(root);
  fs.writeFileSync(file,JSON.stringify({...request,detail:'different command'}));
  fs.writeFileSync(path.join(root,'interactions',request.id+'.response.json'),JSON.stringify({...request,decision:'allow'}));
  assert.equal(await pending,null);
 });
});
test('simultaneous requests cannot consume each other\'s reply',async()=>fixture(async root=>{
 const a=permissionHook(input,{dataDir:root,timeoutMs:200,pollMs:5}),b=permissionHook({...input,turn_id:'second'},{dataDir:root,timeoutMs:200,pollMs:5});
 const dir=path.join(root,'interactions'),requests=fs.readdirSync(dir).filter(x=>x.endsWith('.request.json')).map(x=>JSON.parse(fs.readFileSync(path.join(dir,x),'utf8')));
 assert.equal(requests.length,2);const first=requests.find(x=>x.turnId==='test-turn'),second=requests.find(x=>x.turnId==='second');
 fs.writeFileSync(path.join(dir,first.id+'.response.json'),JSON.stringify({id:first.id,token:second.token,fingerprint:first.fingerprint,decision:'allow'}));
 assert.equal(await a,null);assert.equal(await b,null);
}));
test('question notice parses choices without enabling an approval action',()=>{
 const record={type:'response_item',timestamp:Date.now(),payload:{type:'function_call',name:'request_user_input_async',call_id:'question-1',arguments:JSON.stringify({questions:[{title:'选择哪一个？',options:['甲','乙']}]})}};
 const event=parseAttentionRecord(record,{sessionId:'thread',turnId:'turn'});
 assert.equal(event.type,'attention');assert.equal(event.requestId,'question-1');assert.ok(event.detail.includes('乙'));assert.equal(event.token,undefined);
});
