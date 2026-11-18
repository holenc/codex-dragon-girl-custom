import fs from 'node:fs';
import path from 'node:path';
import net from 'node:net';
import {randomUUID,randomBytes,createHash} from 'node:crypto';
import {atomicJson} from './usage.mjs';

const hash=x=>createHash('sha256').update(JSON.stringify(x)).digest('hex');
const read=f=>{try{return JSON.parse(fs.readFileSync(f,'utf8'))}catch{return null}};
export const NATIVE_PIPE='\\\\.\\pipe\\codex-ipc';
const MAX_FRAME=32*1024*1024;
export function nativeDecision(request,decision){
  if(request?.method!=='mcpServer/elicitation/request'||request.params?.mode!=='form')return null;
  const schema=request.params.requestedSchema;
  // Never synthesize form values, login responses or device-verification proofs.
  if(schema?.type!=='object'||!schema.properties||typeof schema.properties!=='object'||Array.isArray(schema.properties)||Object.keys(schema.properties).length||schema.required?.length)return null;
  if(decision==='allow')return {action:'accept',content:{}};
  if(decision==='deny')return {action:'decline'};
  return null;
}
export function patchRequests(requests,patches){
  let next=structuredClone(requests);
  for(const patch of patches||[]){
    const p=Array.isArray(patch.path)?patch.path:typeof patch.path==='string'?patch.path.split('/').slice(1).map(s=>s.replace(/~1/g,'/').replace(/~0/g,'~')):null;
    if(!p)throw new Error('Unknown native patch path');
    if(!p.length)throw new Error('Native state needs a fresh snapshot');
    if(p[0]!=='requests')continue;
    if(p.length===1){if(patch.op==='remove')next=[];else if(['add','replace'].includes(patch.op)&&Array.isArray(patch.value))next=structuredClone(patch.value);else throw new Error('Invalid request patch');continue;}
    let target=next;
    for(const key of p.slice(1,-1)){
      if(['__proto__','constructor','prototype'].includes(String(key))||target==null||!Object.hasOwn(target,key))throw new Error('Invalid request patch');
      target=target[key];
    }
    const key=p.at(-1);if(['__proto__','constructor','prototype'].includes(String(key)))throw new Error('Unsafe patch');
    if(Array.isArray(target)){
      const i=key==='-'?target.length:Number(key);
      if(!Number.isInteger(i)||i<0||i>target.length||patch.op!=='add'&&i===target.length)throw new Error('Invalid array patch');
      if(patch.op==='remove')target.splice(i,1);else if(patch.op==='add')target.splice(i,0,structuredClone(patch.value));else if(patch.op==='replace')target[i]=structuredClone(patch.value);else throw new Error('Unknown patch operation');
    }else if(patch.op==='remove')delete target[key];else if(['add','replace'].includes(patch.op))target[key]=structuredClone(patch.value);else throw new Error('Unknown patch operation');
  }
  return next;
}

// This uses the client's existing local window-coordination protocol. It does
// not start turns, change app files or settings, or grant persistent permission.
export class NativeApprovalBridge {
  constructor({dataDir,pipe=NATIVE_PIPE,connect=p=>net.connect(p),now=Date.now}={}){
    this.dataDir=dataDir;this.dir=path.join(dataDir,'interactions');this.pipe=pipe;this.connectSocket=connect;this.now=now;
    this.clientId=null;this.socket=null;this.pending=new Map();this.threads=new Map();this.entries=new Map();this.retryAfter=new Map();this.generation=randomUUID();this.nextConnect=0;this.stopped=false;
  }
  start(){fs.mkdirSync(this.dir,{recursive:true});this.tick();this.timer=setInterval(()=>this.tick(),250);return this;}
  send(message){if(!this.socket?.writable)throw new Error('Native approval connection is unavailable');const b=Buffer.from(JSON.stringify(message)),h=Buffer.alloc(4);if(b.length>MAX_FRAME)throw new Error('Oversized native message');h.writeUInt32LE(b.length);this.socket.write(Buffer.concat([h,b]));}
  request(method,params,{targetClientId,version=1}={}){
    const requestId=randomUUID();return new Promise((resolve,reject)=>{
      const timer=setTimeout(()=>{this.pending.delete(requestId);reject(new Error('Native approval request timed out'))},5000);
      this.pending.set(requestId,{resolve,reject,timer});
      try{this.send({type:'request',requestId,sourceClientId:this.clientId||'initializing-client',method,params,version,targetClientId,timeoutMs:4000})}catch(e){clearTimeout(timer);this.pending.delete(requestId);reject(e)}
    });
  }
  broadcast(method,params,targetClientIds){this.send({type:'broadcast',sourceClientId:this.clientId,method,params,targetClientIds,version:1});}
  follow(thread,following){this.broadcast('thread-stream-following-changed',{hostId:'local',conversationId:thread.id,following},[thread.owner]);}
  open(){
    this.nextConnect=this.now()+3000;const socket=this.connectSocket(this.pipe);this.socket=socket;this.buffer=Buffer.alloc(0);
    socket.on('connect',()=>{this.request('initialize',{clientType:'gpt-niang'},{version:0}).then(r=>{if(r.resultType!=='success'||!r.result?.clientId)throw new Error('Native initialization rejected');this.clientId=r.result.clientId;this.error=null}).catch(e=>this.fail(e));});
    socket.on('data',chunk=>{if(this.socket!==socket)return;try{
      this.buffer=Buffer.concat([this.buffer,chunk]);while(this.buffer.length>=4){const n=this.buffer.readUInt32LE();if(n>MAX_FRAME)throw new Error('Oversized native frame');if(this.buffer.length<n+4)break;const b=this.buffer.subarray(4,n+4);this.buffer=this.buffer.subarray(n+4);this.onMessage(JSON.parse(b.toString('utf8')));}
    }catch(e){this.fail(e)}});
    socket.on('error',e=>{this.error=e.code||e.message});socket.on('close',()=>{if(this.socket!==socket)return;this.socket=null;this.clientId=null;this.reset();});
  }
  fail(error){this.error=String(error.message||error).slice(0,160);this.reset();this.socket?.destroy();}
  reset(){
    for(const p of this.pending.values()){clearTimeout(p.timer);p.reject(new Error('Native approval connection closed'))}this.pending.clear();
    for(const t of this.threads.values())for(const waiter of t.waiters||[]){clearTimeout(waiter.timer);waiter.reject(new Error('Native snapshot unavailable'))}
    this.threads.clear();for(const e of this.entries.values())this.remove(e);this.entries.clear();this.writeState();
  }
  onMessage(m){
    if(m.type==='response'){const p=this.pending.get(m.requestId);if(p){clearTimeout(p.timer);this.pending.delete(m.requestId);p.resolve(m)}return;}
    if(m.type==='client-discovery-request'){this.send({type:'client-discovery-response',requestId:m.requestId,response:{canHandle:false}});return;}
    if(m.type!=='broadcast')return;
    if(m.method==='client-status-changed'&&m.params?.status==='disconnected'){
      for(const [id,t] of this.threads)if(t.owner===m.params.clientId){this.clearThread(id);this.threads.delete(id)}return;
    }
    if(m.method!=='thread-stream-state-changed')return;
    const t=this.threads.get(m.params?.conversationId);if(!t||m.sourceClientId!==t.owner||m.params.hostId!=='local')return;
    const change=m.params.change;
    try{
      if(m.version!==13)throw new Error('Unsupported native stream protocol');
      if(change?.type==='snapshot'){
        const state=change.conversationState;if(state?.id!==t.id||!Array.isArray(state.requests))throw new Error('Invalid native snapshot');
        t.requests=state.requests;t.title=typeof state.title==='string'?state.title.slice(0,100):'Codex';t.revision=change.revision;t.freshAt=this.now();t.ready=true;
        this.reconcile(t);
        for(const waiter of t.waiters.splice(0)){clearTimeout(waiter.timer);waiter.resolve()}
      }else if(change?.type==='patches'){
        if(!t.ready||change.baseRevision!==t.revision)throw new Error('Native stream revision changed');
        t.requests=patchRequests(t.requests,change.patches);t.revision=change.revision;t.freshAt=this.now();this.reconcile(t);
      }
    }catch(e){this.error=e.message;t.ready=false;t.nextSnapshotAt=this.now()+2000;this.clearThread(t.id);}
  }
  clearThread(id){for(const [key,e]of this.entries)if(e.request.threadId===id){this.remove(e);this.entries.delete(key)}}
  remove(entry){for(const suffix of ['request','mirror','response']){try{fs.unlinkSync(path.join(this.dir,entry.request.id+'.'+suffix+'.json'))}catch{}}}
  reconcile(t){
    const keys=new Set();
    for(const raw of t.requests.slice(0,64)){
      if(raw.method!=='mcpServer/elicitation/request'||!['string','number'].includes(typeof raw.id))continue;
      const p=raw.params;if(!p||p.threadId!==t.id||typeof p.turnId!=='string'||typeof p.message!=='string')continue;
      const key=JSON.stringify([t.owner,t.id,raw.method,raw.id]),signature=hash(raw);keys.add(key);
      let entry=this.entries.get(key);if(entry?.signature===signature)continue;if(entry)this.remove(entry);
      const createdAt=this.now(),id=randomUUID(),summary=p.message.slice(0,500),fullDetail=JSON.stringify({method:raw.method,params:p},null,2),detail=fullDetail.slice(0,64000);
      const request={version:1,id,token:randomBytes(32).toString('hex'),fingerprint:hash({owner:t.owner,raw}),kind:'permission',transport:'desktop-ipc',bridgeSession:this.generation,threadId:t.id,turnId:p.turnId,title:t.title||'Codex',summary,detail,tool:'Codex 浏览器/插件确认',createdAt,expiresAt:253402300799000,hookPid:process.pid};
      entry={key,signature,raw,request,clickable:fullDetail.length<=64000&&!!nativeDecision(raw,'allow'),busy:false,fallback:false};this.entries.set(key,entry);
      atomicJson(path.join(this.dir,id+'.mirror.json'),{...request,token:undefined,fingerprint:undefined});
      if(entry.clickable)atomicJson(path.join(this.dir,id+'.request.json'),request);
    }
    for(const [key,e]of this.entries)if(e.request.threadId===t.id&&!keys.has(key)){this.remove(e);this.entries.delete(key)}
    this.writeState();
  }
  writeState(){try{atomicJson(path.join(this.dataDir,'native-approval-state.json'),{version:1,at:this.now(),connected:!!this.clientId,session:this.generation,pendingIds:[...this.entries.values()].map(e=>e.request.id),error:this.error||null})}catch{}}
  freshSnapshot(t){return new Promise((resolve,reject)=>{
    const waiter={resolve,reject,timer:setTimeout(()=>{t.waiters=t.waiters.filter(w=>w!==waiter);reject(new Error('Approval recheck timed out'))},4000)};t.waiters.push(waiter);
    try{this.follow(t,false);this.follow(t,true)}catch(e){clearTimeout(waiter.timer);t.waiters=t.waiters.filter(w=>w!==waiter);reject(e)}
  });}
  async respond(entry,response){
    entry.busy=true;
    try{
      const r=entry.request;
      if(response?.id!==r.id||response.token!==r.token||response.fingerprint!==r.fingerprint||this.now()>=r.expiresAt||!['allow','deny','fallback'].includes(response.decision))throw new Error('Invalid native approval response');
      if(response.decision==='fallback'){entry.fallback=true;try{fs.unlinkSync(path.join(this.dir,r.id+'.request.json'))}catch{}return;}
      const t=this.threads.get(r.threadId);if(!t?.ready)throw new Error('Native approval disconnected');
      await this.freshSnapshot(t);
      if(this.entries.get(entry.key)!==entry||t.owner!==JSON.parse(entry.key)[0])return;
      const current=t.requests.find(x=>x.id===entry.raw.id&&x.method===entry.raw.method);
      if(!current||hash(current)!==entry.signature)return;
      const decision=nativeDecision(current,response.decision);if(!decision)throw new Error('This approval requires Codex');
      const result=await this.request('thread-follower-submit-mcp-server-elicitation-response',{conversationId:r.threadId,requestId:current.id,response:decision},{targetClientId:t.owner});
      if(result.resultType!=='success')throw new Error(result.error||'Native approval rejected');
      // Confirmation comes from the owner's refreshed request list, not from
      // locally deleting a button or assuming an RPC means it was accepted.
      await this.freshSnapshot(t);
      if(this.entries.get(entry.key)===entry)throw new Error('Codex still has this approval pending');
    }catch(e){this.error=e.message;
      // Keep a read-only notice after a failed submission, rather than a dead
      // or repeatedly submitting button. The user can finish in Codex.
      entry.fallback=true;try{fs.unlinkSync(path.join(this.dir,entry.request.id+'.request.json'))}catch{}
    }finally{try{fs.unlinkSync(path.join(this.dir,entry.request.id+'.response.json'))}catch{}entry.busy=false;this.writeState();}
  }
  tick(){
    if(this.stopped)return;
    try{
      if(!this.socket){if(this.now()>=this.nextConnect)this.open();return;}
      if(!this.clientId)return;
      const activity=read(path.join(this.dataDir,'activity.json'));
      const active=new Set((activity?.ok&&this.now()-activity.at<10000?activity.threads||[]:[]).filter(t=>t.status==='inProgress').map(t=>t.threadId));
      for(const e of this.entries.values())active.add(e.request.threadId);
      for(const id of active){
        if(this.threads.has(id)||this.now()<(this.retryAfter.get(id)||0))continue;
        const t={id,owner:null,requests:[],ready:false,waiters:[]};this.threads.set(id,t);
        this.request('thread-owner-discovery',{hostId:'local',conversationId:id}).then(r=>{if(this.threads.get(id)!==t)return;if(r.resultType!=='success'){this.retryAfter.set(id,this.now()+3000);this.threads.delete(id);return}t.owner=r.handledByClientId;this.follow(t,true)}).catch(()=>{this.retryAfter.set(id,this.now()+3000);this.threads.delete(id)});
      }
      for(const t of this.threads.values())if(t.owner&&!t.ready&&this.now()>=(t.nextSnapshotAt||0)){t.nextSnapshotAt=this.now()+5000;this.follow(t,false);this.follow(t,true);}
      for(const [id,t]of this.threads)if(!active.has(id)&&!t.waiters.length){if(t.owner)this.follow(t,false);this.clearThread(id);this.threads.delete(id)}
      for(const entry of this.entries.values()){
        if(entry.busy||!entry.clickable||entry.fallback)continue;
        const response=read(path.join(this.dir,entry.request.id+'.response.json'));if(response)this.respond(entry,response);
      }
      this.writeState();
    }catch(e){this.fail(e)}
  }
  stop(){this.stopped=true;clearInterval(this.timer);for(const t of this.threads.values())try{if(t.owner)this.follow(t,false)}catch{};this.socket?.destroy();this.clientId=null;this.reset();}
}
