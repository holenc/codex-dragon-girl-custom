import fs from 'node:fs';
import path from 'node:path';
import {DatabaseSync} from 'node:sqlite';
import {StringDecoder} from 'node:string_decoder';
import {createHash} from 'node:crypto';
import {atomicJson} from './usage.mjs';

const stamp=r=>typeof r.timestamp==='number'?r.timestamp:Date.parse(r.timestamp);
const canonical=x=>JSON.stringify(x&&typeof x==='object'?Array.isArray(x)?x.map(v=>JSON.parse(canonical(v))):Object.fromEntries(Object.keys(x).sort().map(k=>[k,JSON.parse(canonical(x[k]))])):x??null);
const inputHash=x=>createHash('sha256').update(canonical(x)).digest('hex');
export class ActivityLog {
  constructor(since=0){this.since=since;this.questions=new Map();this.calls=new Map();this.results=new Map();this.turnId=null;this.offset=0;this.pending='';this.decoder=new StringDecoder('utf8');}
  accept(r){
    const at=stamp(r),p=r.payload;if(!p||!Number.isFinite(at)||at<this.since)return;
    if(r.type==='event_msg'){
      if(p.type==='item_completed'&&p.item){
        const item=p.item;
        if(['UserMessage','userMessage'].includes(item.type))this.accept({timestamp:at,type:'response_item',payload:{role:'user',content:item.content||[]}});
        else if(item.id&&['completed','failed','declined'].includes(String(item.status||'').toLowerCase())){
          this.results.set(item.id,at);if(this.results.size>512)this.results.delete(this.results.keys().next().value);
        }
      }
      if(p.type==='task_started')this.turnId=p.turn_id;
      if(['turn_aborted','turn_cancelled'].includes(p.type))for(const [id,q] of this.questions)if(q.turnId===(p.turn_id||this.turnId))this.questions.delete(id);
      return;
    }
    if(r.type!=='response_item')return;
    if(p.type==='function_call'){
      let args;try{args=JSON.parse(p.arguments)}catch{}
      if(p.call_id){this.calls.set(p.call_id,{name:p.name,inputHash:inputHash(args),at,turnId:this.turnId});if(this.calls.size>512)this.calls.delete(this.calls.keys().next().value);}
      if(!['request_user_input','request_user_input_async'].includes(p.name)||!p.call_id||!Array.isArray(args?.questions))return;
      const summary=args.questions.map(q=>q.question||q.title||'').join('\n').slice(0,500);
      if(!summary)return;
      this.questions.set(p.call_id,{id:p.call_id,turnId:this.turnId,createdAt:at,summary,detail:args.questions.map(q=>(q.question||q.title||'')+'\n'+(q.options||[]).map(o=>typeof o==='string'?o:o.label||o.description||'').join('\n')).join('\n\n').slice(0,1000),blocking:p.name==='request_user_input'});
    }else if(p.type==='function_call_output'){
      this.results.set(p.call_id,at);if(this.results.size>512)this.results.delete(this.results.keys().next().value);
      const q=this.questions.get(p.call_id);
      if(q){let output;try{output=typeof p.output==='string'?JSON.parse(p.output):p.output}catch{}
        if(q.blocking||output?.accepted!==true)this.questions.delete(p.call_id);
      }
    }else if(p.role==='user'){
      for(const c of p.content||[]){const text=c.text||'';
        if(!text.includes('<send_user_message_question_reply>')){
          // A fresh ordinary user turn supersedes the previous unanswered card.
          // Scheduler envelopes are not a human answer.
          if(text.trim()&&!/^\s*<heartbeat>/.test(text))for(const [id,q] of this.questions)if(at>q.createdAt)this.questions.delete(id);
          continue;
        }
        const body=text.match(/<send_user_message_question_reply>\s*([\s\S]*?)\s*<\/send_user_message_question_reply>/)?.[1];
        try{for(const reply of JSON.parse(body||'[]')){
          let key=reply.questionItemId;try{key=JSON.parse(key)}catch{}
          if(Array.isArray(key)&&typeof key[1]==='string')this.questions.delete(key[1]);
        }}catch{}
      }
    }
  }
  update(file){
    const stat=fs.statSync(file),identity=String(stat.dev)+':'+String(stat.ino);if(stat.size<this.offset||this.file&&this.file!==file||this.identity&&this.identity!==identity){this.questions.clear();this.calls.clear();this.results.clear();this.offset=0;this.pending='';this.turnId=null;this.decoder=new StringDecoder('utf8');}this.file=file;this.identity=identity;
    const fd=fs.openSync(file,'r');try{
      // A large initial history is read in bounded chunks; only control metadata survives.
      let budget=32*1024*1024;
      while(this.offset<stat.size&&budget>0){const b=Buffer.alloc(Math.min(512*1024,stat.size-this.offset,budget));const n=fs.readSync(fd,b,0,b.length,this.offset);if(!n)break;this.offset+=n;budget-=n;
        this.pending+=this.decoder.write(b.subarray(0,n));const lines=this.pending.split('\n');this.pending=lines.pop();
        for(const line of lines){if(line.length>1024*1024||!/(?:"event_msg"|"response_item")/.test(line))continue;try{this.accept(JSON.parse(line))}catch{}}
        if(this.pending.length>1024*1024)this.pending='';
      }
    }finally{fs.closeSync(fd)}
    return this.offset>=stat.size;
  }
  resolved(request){
    const direct=request.toolUseId;if(direct&&this.results.get(direct)>=request.createdAt)return true;
    let input;try{input=JSON.parse(request.detail)}catch{return false}
    for(const [id,c] of this.calls)if(c.turnId===request.turnId&&c.name===request.tool&&c.inputHash===inputHash(input)&&this.results.get(id)>=request.createdAt)return true;
    return false;
  }
}

export function buildActivity(threads,questions,permissions,now=Date.now()){
  const live=new Map(threads.map(t=>[t.threadId,t]));
  const waiting=[...questions,...permissions].filter(q=>{
    const t=live.get(q.threadId);return t&&(!q.blocking||t.turnId===q.turnId&&t.status==='inProgress');
  }).sort((a,b)=>(a.kind==='permission'||a.nativePermissionId?0:1)-(b.kind==='permission'||b.nativePermissionId?0:1)||a.createdAt-b.createdAt||a.id.localeCompare(b.id));
  const paused=new Set(waiting.filter(q=>q.blocking).map(q=>q.threadId));
  return {version:1,ok:true,at:now,running:threads.filter(t=>t.status==='inProgress'&&!paused.has(t.threadId)).length,waiting:waiting.length,threads,questions:waiting.filter(q=>q.kind==='notice'),permissionIds:waiting.filter(q=>q.kind==='permission').map(q=>q.id),failures:threads.filter(t=>t.status==='failed'&&t.unread).map(t=>({threadId:t.threadId,turnId:t.turnId,quota:t.quota}))};
}

export class ActivityMonitor {
  constructor({codexHome,dataDir,intervalMs=2000}){this.home=codexHome;this.dataDir=dataDir;this.file=path.join(dataDir,'activity.json');this.intervalMs=intervalMs;this.logs=new Map();this.epoch=0;this.recovered=false;}
  open(){
    if(this.history)return;
    try{
      this.state=new DatabaseSync(path.join(this.home,'state_5.sqlite'),{readOnly:true});this.state.exec('PRAGMA query_only=ON; PRAGMA busy_timeout=500');
      this.history=new DatabaseSync(path.join(this.home,'thread_history_1.sqlite'),{readOnly:true});this.history.exec('PRAGMA query_only=ON; PRAGMA busy_timeout=500');
    }catch(e){this.state?.close();this.history?.close();this.state=null;this.history=null;throw e;}
  }
  poll(now=Date.now()){
    try{
      this.open();let epoch=this.epoch;
      try{const s=JSON.parse(fs.readFileSync(path.join(this.dataDir,'supervisor-status.json'),'utf8'));if(s.appServerStartedAt)epoch=Date.parse(s.appServerStartedAt)}catch{}
      if(!epoch)throw new Error('Waiting for the desktop app-server identity');
      if(epoch!==this.epoch){this.epoch=epoch;this.logs.clear();this.recovered=false;}
      const meta=new Map(this.state.prepare('select id,rollout_path,source,name,title from threads where archived=0').all().filter(r=>!/subagent/i.test(r.source)).map(r=>[r.id,r]));
      const unread=new Map(this.state.prepare('select thread_id,first_unread_turn from thread_read_receipts').all().map(r=>[r.thread_id,Boolean(r.first_unread_turn)]));
      const latest=this.history.prepare(`select t.thread_id,t.turn_id,t.status,t.started_at,t.error_json from thread_turns t join (select thread_id,max(rollout_ordinal) last from thread_turns group by thread_id) n on t.thread_id=n.thread_id and t.rollout_ordinal=n.last`).all();
      const threads=[],questions=[],permissions=[],resolvedPermissionIds=[];let recovering=false;
      for(const row of latest){const m=meta.get(row.thread_id);if(!m)continue;
        const startedAt=(row.started_at||0)*1000;if(startedAt<epoch-1000)continue;
        const t={threadId:row.thread_id,turnId:row.turn_id,status:row.status,startedAt,unread:unread.get(row.thread_id)??true,quota:/usage.?limit|rate.?limit|quota|credit.?balance/i.test(row.error_json||'')};threads.push(t);
        let log=this.logs.get(row.thread_id);if(!log){log=new ActivityLog(epoch);this.logs.set(row.thread_id,log)}
        if(!log.update(m.rollout_path)){recovering=true;continue;}
        // Cancelled turns have no active question cards. Async accepted questions
        // can outlive a completed turn until the explicit question reply arrives.
        for(const q of log.questions.values())if(q.turnId===t.turnId&&['interrupted','failed'].includes(t.status))log.questions.delete(q.id);
        for(const q of log.questions.values())questions.push({...q,threadId:t.threadId,kind:'notice',title:(m.name||m.title||'Codex').slice(0,100)});
      }
      const threadMap=new Map(threads.map(t=>[t.threadId,t]));
      const dir=path.join(this.dataDir,'interactions');
      for(const file of fs.existsSync(dir)?fs.readdirSync(dir).filter(n=>n.endsWith('.mirror.json')):[]){
        const target=path.join(dir,file);let r;try{r=JSON.parse(fs.readFileSync(target,'utf8'))}catch{continue}
        const t=threadMap.get(r.threadId),log=this.logs.get(r.threadId);
        if(r.version!==1||file!==r.id+'.mirror.json')continue;
        const done=t&&(t.turnId!==r.turnId||t.status!=='inProgress'||log?.resolved(r));
        if(done||r.createdAt<epoch){resolvedPermissionIds.push(r.id);try{fs.unlinkSync(target)}catch{};continue;}
        if(!t){if(now-r.createdAt>10000){resolvedPermissionIds.push(r.id);try{fs.unlinkSync(target)}catch{}}continue;}
        if(fs.existsSync(path.join(dir,r.id+'.response.json')))continue;
        permissions.push({...r,kind:'permission',blocking:true});
        // Once the hook hands back to Codex, mirror only the notice; never keep
        // an expired authorization button capable of submitting an old decision.
        let hookAlive=false;try{process.kill(r.hookPid,0);hookAlive=now<r.expiresAt&&fs.existsSync(path.join(dir,r.id+'.request.json'))}catch{}
        if(!hookAlive)questions.push({...r,id:'native-'+r.id,kind:'notice',blocking:true,title:r.title||'Codex',nativePermissionId:r.id,detail:r.detail,summary:r.summary});
      }
      const snapshot=buildActivity(threads,questions,permissions,now);
      // Native notices and their permission entry describe one pending request.
      snapshot.waiting-=snapshot.questions.filter(q=>q.nativePermissionId).length;
      snapshot.resolvedPermissionIds=resolvedPermissionIds;snapshot.recovering=recovering;
      if(recovering)snapshot.ok=false;
      atomicJson(this.file,snapshot);this.recovered=!recovering;return snapshot;
    }catch(e){const snapshot={version:1,ok:false,at:now,error:String(e.message).slice(0,160),running:0,waiting:0,threads:[],questions:[],failures:[]};try{atomicJson(this.file,snapshot)}catch{};return snapshot;}
  }
  start(){this.poll();this.timer=setInterval(()=>this.poll(),this.intervalMs);return this;}
  stop(){clearInterval(this.timer);this.history?.close();this.state?.close();this.history=null;this.state=null;}
}
