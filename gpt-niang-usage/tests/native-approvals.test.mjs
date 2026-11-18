import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';import path from 'node:path';import os from 'node:os';import net from 'node:net';import {randomUUID} from 'node:crypto';
import {NativeApprovalBridge,nativeDecision,patchRequests} from '../runtime/native-approvals.mjs';
const raw=(id=34)=>({id,method:'mcpServer/elicitation/request',params:{threadId:'chat',turnId:'turn',mode:'form',message:'Allow the test download?',requestedSchema:{type:'object',properties:{}}}});
const wait=async(fn)=>{const deadline=Date.now()+5000;while(Date.now()<deadline){if(fn())return;await new Promise(r=>setTimeout(r,15));}throw new Error('Timed out waiting for fixture state')};
const read=file=>JSON.parse(fs.readFileSync(file,'utf8'));
async function fixture(fn){
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'gn-native-')),pipe=process.platform==='win32'?'\\\\.\\pipe\\gn-native-test-'+randomUUID():path.join(root,'ipc.sock');
 const sockets=new Set();let revision=1,requests=[raw()],onRefresh=null;const actions=[];
 const send=(s,m)=>{const b=Buffer.from(JSON.stringify(m)),h=Buffer.alloc(4);h.writeUInt32LE(b.length);s.write(Buffer.concat([h,b]));};
 const snapshot=s=>send(s,{type:'broadcast',method:'thread-stream-state-changed',sourceClientId:'owner',version:13,params:{hostId:'local',conversationId:'chat',change:{type:'snapshot',revision:revision++,conversationState:{id:'chat',title:'Test chat',requests}}}});
 const server=net.createServer(s=>{sockets.add(s);let buffer=Buffer.alloc(0);s.on('close',()=>sockets.delete(s));s.on('data',b=>{
  buffer=Buffer.concat([buffer,b]);while(buffer.length>=4){const n=buffer.readUInt32LE();if(buffer.length<n+4)return;const m=JSON.parse(buffer.subarray(4,n+4));buffer=buffer.subarray(n+4);
   if(m.type==='request'){
    if(m.method==='initialize')send(s,{type:'response',requestId:m.requestId,resultType:'success',result:{clientId:'pet'}});
    else if(m.method==='thread-owner-discovery')send(s,{type:'response',requestId:m.requestId,resultType:'success',handledByClientId:'owner',result:{}});
    else if(m.method==='thread-follower-submit-mcp-server-elicitation-response'){
     actions.push(m.params);requests=requests.filter(r=>r.id!==m.params.requestId);
     send(s,{type:'response',requestId:m.requestId,resultType:'success',result:{ok:true}});snapshot(s);
    }else throw new Error('Unexpected mutating method: '+m.method);
   }else if(m.type==='broadcast'&&m.params.following){if(onRefresh){const cb=onRefresh;onRefresh=null;cb()}snapshot(s);}
  }
 });});
 await new Promise(r=>server.listen(pipe,r));fs.writeFileSync(path.join(root,'activity.json'),JSON.stringify({ok:true,at:Date.now(),threads:[{threadId:'chat',status:'inProgress'}]}));
 const bridge=new NativeApprovalBridge({dataDir:root,pipe}).start();
 const requestFile=()=>{const name=fs.readdirSync(path.join(root,'interactions')).find(n=>n.endsWith('.request.json'));return name&&path.join(root,'interactions',name)};
 const respond=(r,decision,extra={})=>fs.writeFileSync(path.join(root,'interactions',r.id+'.response.json'),JSON.stringify({id:r.id,token:r.token,fingerprint:r.fingerprint,decision,...extra}));
 try{await wait(()=>requestFile());await fn({bridge,root,actions,requestFile,respond,setRequests:r=>{requests=r;for(const s of sockets)snapshot(s)},onRefresh:fn=>{onRefresh=fn},clearOnRefresh:()=>{onRefresh=()=>{requests=[]}},disconnect:()=>{for(const s of sockets)s.destroy()}})}finally{
  bridge.stop();for(const s of sockets)s.destroy();await new Promise(r=>server.close(r));assert.ok(path.resolve(root).startsWith(path.resolve(os.tmpdir())+path.sep));fs.rmSync(root,{recursive:true,force:true});
 }
}
test('only empty confirmation forms support a manual allow/deny; login and filled forms stay native',()=>{
 assert.deepEqual(nativeDecision(raw(),'allow'),{action:'accept',content:{}});assert.deepEqual(nativeDecision(raw(),'deny'),{action:'decline'});
 for(const mode of ['url','openai/userVerification']){const r=raw();r.params.mode=mode;assert.equal(nativeDecision(r,'allow'),null)}
 const r=raw();r.params.requestedSchema.properties={password:{type:'string'}};assert.equal(nativeDecision(r,'allow'),null);assert.equal(nativeDecision(raw(),'fallback'),null);
});
test('request patches handle arrays without applying unrelated conversation data or prototype mutations',()=>{
 assert.equal(patchRequests([raw()],[{op:'remove',path:['requests',0]}]).length,0);
 assert.equal(patchRequests([],[{op:'add',path:'/requests/0',value:raw()}]).length,1);
 assert.equal(patchRequests([raw()],[{op:'replace',path:['title'],value:'Other'}]).length,1);
 assert.throws(()=>patchRequests([raw()],[{op:'add',path:['requests',0,'__proto__'],value:{polluted:true}}]));assert.equal({}.polluted,undefined);
});
test('live IPC mirror submits exactly one explicit allow and removes it after owner confirmation',()=>fixture(async f=>{
 const r=read(f.requestFile());assert.equal(r.transport,'desktop-ipc');assert.equal(f.actions.length,0);
 assert.equal(read(path.join(f.root,'interactions',r.id+'.mirror.json')).token,undefined);
 f.respond(r,'allow');await wait(()=>f.actions.length===1&&!f.requestFile());
 assert.equal(f.actions[0].requestId,34);assert.deepEqual(f.actions[0].response,{action:'accept',content:{}});
 await wait(()=>read(path.join(f.root,'native-approval-state.json')).pendingIds.length===0);
}));
test('explicit denial reaches only the matching native request',()=>fixture(async f=>{
 const r=read(f.requestFile());f.respond(r,'deny');await wait(()=>f.actions.length===1);assert.deepEqual(f.actions[0].response,{action:'decline'});
}));
test('handling in Codex clears the pet without sending any decision',()=>fixture(async f=>{
 f.setRequests([]);await wait(()=>!f.requestFile());assert.equal(f.actions.length,0);
}));
test('fresh native recheck defeats a resolution race and changed-request reuse',()=>fixture(async f=>{
 const r=read(f.requestFile());f.onRefresh(()=>{const changed=raw();changed.params.message='A different action';f.setRequests([changed])});f.respond(r,'allow');
 await wait(()=>f.requestFile()&&read(f.requestFile()).id!==r.id);assert.equal(f.actions.length,0);
}));
test('tampered responses never approve and become a read-only fallback',()=>fixture(async f=>{
 const r=read(f.requestFile());f.respond(r,'allow',{token:'wrong'});await wait(()=>!f.requestFile());assert.equal(f.actions.length,0);assert.ok(fs.existsSync(path.join(f.root,'interactions',r.id+'.mirror.json')));
}));
test('disconnect invalidates buttons and native pending state',()=>fixture(async f=>{
 f.disconnect();await wait(()=>!f.requestFile());assert.equal(read(path.join(f.root,'native-approval-state.json')).pendingIds.length,0);assert.equal(f.actions.length,0);
}));
