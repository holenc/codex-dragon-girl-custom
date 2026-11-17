import fs from 'node:fs';
import path from 'node:path';
import {randomBytes,randomUUID,createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {readThreadTitle,defaultCodexHome} from './completion-monitor.mjs';

export const fingerprint=value=>createHash('sha256').update(JSON.stringify(value)).digest('hex');
export function validResponse(request,response,now=Date.now()){
  return now<request.expiresAt && response?.id===request.id && response.token===request.token &&
    response.fingerprint===request.fingerprint && ['allow','deny','fallback'].includes(response.decision);
}
export function requestPending(request,snapshot,now=Date.now()){
  if(!snapshot?.ok||now-snapshot.at>10000||snapshot.at<request.createdAt)return true;
  if(snapshot.resolvedPermissionIds?.includes(request.id))return false;
  const t=snapshot.threads?.find(t=>t.threadId===request.threadId);
  if(t)return t.turnId===request.turnId&&t.status==='inProgress';
  return now-request.createdAt<10000;
}
export async function permissionHook(input,{dataDir,codexHome=defaultCodexHome(),timeoutMs=86400000,pollMs=200}={}){
  if(input?.hook_event_name!=='PermissionRequest'||!input.session_id||!input.turn_id||!input.tool_name||!dataDir)return null;
  // If the pet is unavailable, leave the original approval flow untouched.
  try{const p=JSON.parse(fs.readFileSync(path.join(dataDir,'presence.json'),'utf8'));if(Date.now()-p.at>5000||!p.visible)return null;}catch{return null;}
  const detail=JSON.stringify(input.tool_input??{},null,2);
  if(detail.length>64000)return null; // Never approve an incompletely displayed request.
  const dir=path.join(dataDir,'interactions');fs.mkdirSync(dir,{recursive:true});
  const id=randomUUID(),token=randomBytes(32).toString('hex'),createdAt=Date.now();
  const request={version:1,id,token,kind:'permission',threadId:input.session_id,turnId:input.turn_id,
    toolUseId:input.tool_use_id||input.tool_call_id||input.call_id||null,
    title:readThreadTitle(codexHome,input.session_id)||'Codex',tool:input.tool_name,
    summary:typeof input.tool_input?.description==='string'?input.tool_input.description:'请核对以下操作，再决定是否允许本次执行。',
    detail,createdAt,expiresAt:createdAt+timeoutMs,hookPid:process.pid,
    fingerprint:fingerprint({threadId:input.session_id,turnId:input.turn_id,tool:input.tool_name,input:input.tool_input})};
  const file=path.join(dir,id+'.request.json'),responseFile=path.join(dir,id+'.response.json');
  const mirrorFile=path.join(dir,id+'.mirror.json');
  const mirror=fs.existsSync(path.join(dataDir,'activity.json'));
  let preserveMirror=true;
  let interrupted=false;const stop=()=>{interrupted=true;};process.once('SIGTERM',stop);process.once('SIGINT',stop);
  const serializedRequest=JSON.stringify(request);
  fs.writeFileSync(file,serializedRequest,{flag:'wx'});
  if(mirror)fs.writeFileSync(mirrorFile,JSON.stringify({...request,token:undefined,fingerprint:undefined}),{flag:'wx'});
  try{
    while(!interrupted&&Date.now()<request.expiresAt){
      try{if(fs.readFileSync(file,'utf8')!==serializedRequest)return null;}catch{return null;}
      let snapshot;try{snapshot=JSON.parse(fs.readFileSync(path.join(dataDir,'activity.json'),'utf8'))}catch{}
      if(!requestPending(request,snapshot)){preserveMirror=false;return null;}
      let response;try{response=JSON.parse(fs.readFileSync(responseFile,'utf8'));}catch{}
      if(validResponse(request,response)){
        if(response.decision==='fallback')return null;
        preserveMirror=false;
        return {hookSpecificOutput:{hookEventName:'PermissionRequest',decision:{behavior:response.decision,...(response.decision==='deny'?{message:'用户在龙娘中拒绝了本次操作。'}:{})}}};
      }
      if(response)return null; // Bad/stale response never authorizes anything.
      try{const p=JSON.parse(fs.readFileSync(path.join(dataDir,'presence.json'),'utf8'));if(Date.now()-p.at>5000)return null;}catch{return null;}
      await new Promise(resolve=>setTimeout(resolve,pollMs));
    }
    return null;
  }finally{
    process.removeListener('SIGTERM',stop);process.removeListener('SIGINT',stop);
    for(const f of [file,responseFile])try{fs.unlinkSync(f);}catch{}
    if(mirror&&!preserveMirror)try{fs.unlinkSync(mirrorFile)}catch{}
  }
}
async function main(){
  let text='';for await(const chunk of process.stdin){text+=chunk;if(text.length>1024*1024)return;}
  let input;try{input=JSON.parse(text);}catch{return;}
  let config;try{config=JSON.parse(fs.readFileSync(path.join(path.dirname(fileURLToPath(import.meta.url)),'..','installation.json'),'utf8').replace(/^\uFEFF/,''));}catch{return;}
  const result=await permissionHook(input,{dataDir:config.dataDir});if(result)process.stdout.write(JSON.stringify(result));
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url))main().catch(()=>{});
