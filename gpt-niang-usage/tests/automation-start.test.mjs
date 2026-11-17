import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {CompletionMonitor,parseAutomationStartRecord,readThreadTitle} from '../runtime/completion-monitor.mjs';

const thread='01a1bceb-5447-7e93-a221-6b37a2f78ec9';
const start=(turn,trigger='automation_heartbeat_scheduled',at=Date.now())=>({timestamp:at,type:'event_msg',payload:{type:'task_started',turn_id:turn,turn_attribution:{turn_trigger:trigger}}});
test('scheduled starts are recognized independently of task name and schedule kind',()=>{
  for(const trigger of ['automation_heartbeat_scheduled','automation_once_scheduled','automation_cron_scheduled']){
    assert.equal(parseAutomationStartRecord(start('turn',trigger),{sessionId:thread}).type,'automation-start');
  }
  for(const trigger of ['composer','guardian_review','remote_ios'])assert.equal(parseAutomationStartRecord(start('turn',trigger),{sessionId:thread}),null);
  assert.equal(parseAutomationStartRecord(start('old','automation_heartbeat_scheduled',1000),{since:2000}),null);
});
test('explicit heartbeat fallback recognizes legacy scheduling, not quoted prose',()=>{
  const record={timestamp:Date.now(),type:'response_item',payload:{role:'user',content:[{type:'input_text',text:'<heartbeat>\n<automation_id>once-123</automation_id>\n</heartbeat>'}]}};
  assert.equal(parseAutomationStartRecord(record,{sessionId:thread,turnId:'once'}).turnId,'once');
  record.payload.content[0].text='帮我写一个 <heartbeat>\n<automation_id>x</automation_id>';
  assert.equal(parseAutomationStartRecord(record,{sessionId:thread,turnId:'manual'}),null);
});
test('existing and newly created sessions notify, resolve renames live, dedupe, and preserve completions',()=>{
  const root=fs.mkdtempSync(path.join(os.tmpdir(),'gpt-niang-automation-'));
  try{
    fs.mkdirSync(path.join(root,'sessions'));
    const file=path.join(root,'sessions',`rollout-${thread}.jsonl`),index=path.join(root,'session_index.jsonl');
    const append=r=>fs.appendFileSync(file,JSON.stringify(r)+'\n');
    append({type:'session_meta',payload:{id:thread,source:'desktop'}});
    fs.writeFileSync(index,JSON.stringify({id:thread,thread_name:'英国课程'})+'\n');
    append(start('historical'));
    const found=[],monitor=new CompletionMonitor({codexHome:root,since:Date.now()-1000,onNotification:e=>found.push(e)});
    monitor.scan(true);assert.equal(found.length,0);
    append(start('daily'));append(start('daily'));monitor.scan();
    assert.deepEqual(found.map(e=>e.title),['英国课程']);
    fs.appendFileSync(index,JSON.stringify({id:thread,thread_name:'明天的课程安排'})+'\n');
    append(start('next'));monitor.scan();assert.equal(found.at(-1).title,'明天的课程安排');
    append({timestamp:Date.now(),type:'event_msg',payload:{type:'task_complete',turn_id:'next'}});
    monitor.scan();assert.equal(found.at(-1).type,'completion');
    const newThread='01a1bceb-5447-7e93-a221-6b37a2f78eca';
    fs.appendFileSync(index,JSON.stringify({id:newThread,thread_name:'倒计时一次'})+'\n');
    fs.writeFileSync(path.join(root,'sessions',`rollout-${newThread}.jsonl`),JSON.stringify({type:'session_meta',payload:{id:newThread,source:'desktop'}})+'\n'+JSON.stringify(start('new-once'))+'\n');
    monitor.scan();assert.equal(found.at(-1).title,'倒计时一次');
    assert.equal(readThreadTitle(root,thread),'明天的课程安排');monitor.stop();
  }finally{fs.rmSync(root,{recursive:true,force:true});}
});
