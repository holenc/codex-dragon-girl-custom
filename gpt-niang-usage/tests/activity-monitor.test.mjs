import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';import os from 'node:os';import path from 'node:path';import {DatabaseSync} from 'node:sqlite';
import {ActivityLog,ActivityMonitor,buildActivity} from '../runtime/activity-monitor.mjs';
import {requestPending,permissionHook} from '../runtime/permission-hook.mjs';
const event=(payload,type='event_msg',timestamp=10000)=>({timestamp,type,payload});
const ask=(id,async=true)=>event({type:'function_call',name:async?'request_user_input_async':'request_user_input',call_id:id,arguments:JSON.stringify({questions:[{title:'Question',options:['A','B']}]})},'response_item');
test('question acceptance is not an answer; matching native replies and cancellation clear the right card',()=>{
 const log=new ActivityLog();log.accept(event({type:'task_started',turn_id:'one'}));log.accept(ask('a'));log.accept(ask('b'));
 log.accept(event({type:'function_call_output',call_id:'a',output:'{"accepted":true}'},'response_item'));assert.equal(log.questions.size,2);
 log.accept(event({role:'user',content:[{text:'<send_user_message_question_reply>'+JSON.stringify([{questionItemId:JSON.stringify(['request_user_input_async','a',0]),answer:'A'}])+'</send_user_message_question_reply>'}]},'response_item',11000));
 assert.deepEqual([...log.questions.keys()],['b']);log.accept(event({type:'turn_aborted',turn_id:'one'}));assert.equal(log.questions.size,0);
 log.accept(ask('native'));log.accept(event({type:'item_completed',item:{type:'UserMessage',content:[{type:'text',text:'<send_user_message_question_reply>'+JSON.stringify([{questionItemId:JSON.stringify(['request_user_input_async','native',0]),answer:'A'}])+'</send_user_message_question_reply>'}]}},'event_msg',12000));assert.equal(log.questions.size,0);
 log.accept(ask('c',false));log.accept(event({type:'function_call_output',call_id:'c',output:'{"answers":{}}'},'response_item'));assert.equal(log.questions.size,0);
});
test('authorization queue precedes questions; only blocking waits pause running count',()=>{
 const threads=[{threadId:'a',turnId:'1',status:'inProgress'},{threadId:'b',turnId:'2',status:'inProgress'},{threadId:'c',turnId:'3',status:'interrupted'}];
 const q=[{id:'q',threadId:'b',turnId:'2',kind:'notice',createdAt:1,blocking:false}];
 const p=[{id:'p2',threadId:'a',turnId:'1',kind:'permission',createdAt:3,blocking:true},{id:'p1',threadId:'a',turnId:'1',kind:'permission',createdAt:2,blocking:true}];
 const s=buildActivity(threads,q,p);assert.equal(s.running,1);assert.equal(s.waiting,3);assert.deepEqual(s.permissionIds,['p1','p2']);assert.equal(s.failures.length,0);
});
function fixture(fn){const root=fs.mkdtempSync(path.join(os.tmpdir(),'niang-activity-'));try{return fn(root)}finally{const target=path.resolve(root);assert.ok(target.startsWith(path.resolve(os.tmpdir())+path.sep));fs.rmSync(target,{recursive:true,force:true})}}

test('resumed chats missing from the history index count from lifecycle logs and clear on completion or cancellation',()=>fixture(root=>{
 const now=Date.now(),epoch=now-60000,s=new DatabaseSync(path.join(root,'state_5.sqlite')),h=new DatabaseSync(path.join(root,'thread_history_1.sqlite'));
 s.exec('create table threads(id text,rollout_path text,source text,name text,title text,archived int); create table thread_read_receipts(thread_id text,first_unread_turn text);');
 h.exec('create table thread_turns(thread_id text,turn_id text,rollout_ordinal int,status text,started_at int,error_json text);');
 fs.writeFileSync(path.join(root,'supervisor-status.json'),JSON.stringify({appServerStartedAt:new Date(epoch).toISOString()}));
 for(const id of ['indexed','resumed','unindexed']){
  fs.writeFileSync(path.join(root,id+'.jsonl'),JSON.stringify(event({type:'task_started',turn_id:id+'-new'},'event_msg',now-2000))+'\n');
  s.prepare('insert into threads values(?,?,?,?,?,0)').run(id,path.join(root,id+'.jsonl'),'vscode',id,id);
 }
 h.prepare('insert into thread_turns values(?,?,1,?,?,null)').run('indexed','indexed-new','inProgress',Math.floor((now-2000)/1000));
 h.prepare('insert into thread_turns values(?,?,9999,?,?,null)').run('resumed','ancient','interrupted',Math.floor((epoch-3600000)/1000));
 const opts={codexHome:root,dataDir:root};let monitor=new ActivityMonitor(opts);
 let snapshot=monitor.poll(now);assert.equal(snapshot.ok,true);assert.equal(snapshot.running,3);
 fs.appendFileSync(path.join(root,'resumed.jsonl'),JSON.stringify(event({type:'task_complete',turn_id:'resumed-new'},'event_msg',now))+'\n');
 fs.appendFileSync(path.join(root,'unindexed.jsonl'),JSON.stringify(event({type:'turn_aborted',turn_id:'unindexed-new'},'event_msg',now))+'\n');
 snapshot=monitor.poll(now+1);assert.equal(snapshot.running,1);assert.equal(snapshot.threads.find(t=>t.threadId==='resumed').status,'completed');
 // Late terminal records for the old turn must not end a newer turn.
 fs.appendFileSync(path.join(root,'resumed.jsonl'),JSON.stringify(event({type:'task_started',turn_id:'resumed-next'},'event_msg',now+2))+'\n'+JSON.stringify(event({type:'task_complete',turn_id:'resumed-new'},'event_msg',now+3))+'\n');
 snapshot=monitor.poll(now+4);assert.equal(snapshot.running,2);monitor.stop();
 monitor=new ActivityMonitor(opts);assert.equal(monitor.poll(now+5).running,2);monitor.stop();s.close();h.close();
}));
test('native pending requests pause running counts and clear when their owner resolves or disconnects',()=>fixture(root=>{
 const now=Date.now(),epoch=now-60000,s=new DatabaseSync(path.join(root,'state_5.sqlite')),h=new DatabaseSync(path.join(root,'thread_history_1.sqlite'));
 s.exec('create table threads(id text,rollout_path text,source text,name text,title text,archived int); create table thread_read_receipts(thread_id text,first_unread_turn text);');
 h.exec('create table thread_turns(thread_id text,turn_id text,rollout_ordinal int,status text,started_at int,error_json text);');
 const log=path.join(root,'chat.jsonl');fs.writeFileSync(log,JSON.stringify(event({type:'task_started',turn_id:'turn'},'event_msg',now-2000))+'\n');
 s.prepare('insert into threads values(?,?,?,?,?,0)').run('chat',log,'vscode','chat','chat');
 fs.writeFileSync(path.join(root,'supervisor-status.json'),JSON.stringify({appServerStartedAt:new Date(epoch).toISOString()}));
 const dir=path.join(root,'interactions');fs.mkdirSync(dir);
 const r={version:1,id:'native-test',transport:'desktop-ipc',bridgeSession:'session',threadId:'chat',turnId:'turn',hookPid:process.pid,createdAt:now,expiresAt:now+60000,title:'chat',summary:'Allow download?',detail:'test'};
 fs.writeFileSync(path.join(dir,r.id+'.mirror.json'),JSON.stringify(r));fs.writeFileSync(path.join(dir,r.id+'.request.json'),'{}');
 const state={version:1,session:'session',connected:true,at:now,pendingIds:[r.id]},file=path.join(root,'native-approval-state.json');
 fs.writeFileSync(file,JSON.stringify(state));const monitor=new ActivityMonitor({codexHome:root,dataDir:root});
 let a=monitor.poll(now);assert.equal(a.ok,true);assert.equal(a.running,0);assert.equal(a.waiting,1);assert.deepEqual(a.permissionIds,[r.id]);
 state.pendingIds=[];fs.writeFileSync(file,JSON.stringify(state));a=monitor.poll(now+1);assert.equal(a.running,1);assert.equal(a.waiting,0);assert.ok(a.resolvedPermissionIds.includes(r.id));
 state.pendingIds=[r.id];state.connected=false;fs.writeFileSync(file,JSON.stringify(state));a=monitor.poll(now+2);assert.equal(a.waiting,0);
 monitor.stop();s.close();h.close();
}));

test('SQLite reconciliation survives pet restart and removes historical in-progress turns, finished tasks and read failures',()=>fixture(root=>{
 const epoch=Date.now()-60000,now=Date.now(),s=new DatabaseSync(path.join(root,'state_5.sqlite')),h=new DatabaseSync(path.join(root,'thread_history_1.sqlite'));
 s.exec('create table threads(id text,rollout_path text,source text,name text,title text,archived int); create table thread_read_receipts(thread_id text,first_unread_turn text);');
 h.exec('create table thread_turns(thread_id text,turn_id text,rollout_ordinal int,status text,started_at int,error_json text);');
 fs.writeFileSync(path.join(root,'supervisor-status.json'),JSON.stringify({appServerStartedAt:new Date(epoch).toISOString()}));
 for(const [id,status,source] of [['a','inProgress','vscode'],['b','failed','vscode'],['sub','inProgress','{"subagent":{}}']]){
  const file=path.join(root,id+'.jsonl');fs.writeFileSync(file,JSON.stringify(event({type:'task_started',turn_id:id+'1'},'event_msg',now-2000))+'\n');
  s.prepare('insert into threads values(?,?,?,?,?,0)').run(id,file,source,id,id);s.prepare('insert into thread_read_receipts values(?,?)').run(id,id+'1');
  h.prepare('insert into thread_turns values(?,?,1,?,?,?)').run(id,id+'1',status,Math.floor((now-2000)/1000),status==='failed'?'system error':null);
 }
 // A leftover historical inProgress row does not add another running chat.
 h.prepare("insert into thread_turns values('a','old',0,'inProgress',?,null)").run(Math.floor(epoch/1000));
 const opts={codexHome:root,dataDir:root};let monitor=new ActivityMonitor(opts);let snapshot=monitor.poll(now);assert.equal(snapshot.ok,true);assert.equal(snapshot.running,1);assert.equal(snapshot.failures.length,1);monitor.stop();
 monitor=new ActivityMonitor(opts);snapshot=monitor.poll(now+10);assert.equal(snapshot.running,1);
 h.prepare("update thread_turns set status='completed' where turn_id='a1'").run();s.prepare("update thread_read_receipts set first_unread_turn=null where thread_id='b'").run();
 snapshot=monitor.poll(now+20);assert.equal(snapshot.running,0);assert.equal(snapshot.failures.length,0);monitor.stop();s.close();h.close();
}));
test('late hook replies cannot authorize requests already handled in the main app',async()=>{
 const now=Date.now(),r={id:'req',threadId:'a',turnId:'1',createdAt:now-100};
 assert.equal(requestPending(r,{ok:true,at:now,threads:[{threadId:'a',turnId:'1',status:'completed'}]},now),false);
 assert.equal(requestPending(r,{ok:true,at:now,resolvedPermissionIds:['req'],threads:[]},now),false);
 assert.equal(requestPending(r,{ok:false,at:now,threads:[]},now),true);
});
test('native resolution wins a race against an Allow reply; timed out hooks preserve only a non-actionable mirror',async()=>{
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'niang-hook-lifecycle-'));
 try{
  const now=Date.now(),snapshot={ok:true,at:now,threads:[{threadId:'a',turnId:'1',status:'inProgress'}]};
  const write=()=>fs.writeFileSync(path.join(root,'activity.json'),JSON.stringify(snapshot));write();
  fs.writeFileSync(path.join(root,'presence.json'),JSON.stringify({at:now,visible:true}));
  const input={hook_event_name:'PermissionRequest',session_id:'a',turn_id:'1',tool_name:'synthetic',tool_input:{description:'No commands execute'}};
  let pending=permissionHook(input,{dataDir:root,timeoutMs:1000,pollMs:10});
  const dir=path.join(root,'interactions');let file=fs.readdirSync(dir).find(x=>x.endsWith('.request.json'));let r=JSON.parse(fs.readFileSync(path.join(dir,file),'utf8'));
  snapshot.at=Date.now()+1;snapshot.threads[0].status='completed';write();
  fs.writeFileSync(path.join(dir,r.id+'.response.json'),JSON.stringify({id:r.id,token:r.token,fingerprint:r.fingerprint,decision:'allow'}));
  assert.equal(await pending,null);assert.equal(fs.existsSync(path.join(dir,r.id+'.mirror.json')),false);
  snapshot.at=Date.now();snapshot.threads[0].status='inProgress';write();
  pending=permissionHook(input,{dataDir:root,timeoutMs:30,pollMs:5});file=fs.readdirSync(dir).find(x=>x.endsWith('.request.json'));r=JSON.parse(fs.readFileSync(path.join(dir,file),'utf8'));
  assert.equal(await pending,null);assert.equal(fs.existsSync(path.join(dir,r.id+'.request.json')),false);
  const mirror=JSON.parse(fs.readFileSync(path.join(dir,r.id+'.mirror.json'),'utf8'));assert.equal(mirror.token,undefined);assert.equal(mirror.fingerprint,undefined);
 }finally{assert.ok(path.resolve(root).startsWith(path.resolve(os.tmpdir())+path.sep));fs.rmSync(root,{recursive:true,force:true})}
});
