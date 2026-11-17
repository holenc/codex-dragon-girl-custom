// Interactive demonstration only. A returned decision is recorded, never executed.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {permissionHook} from './permission-hook.mjs';
const appDir=path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const config=JSON.parse(fs.readFileSync(path.join(appDir,'installation.json'),'utf8').replace(/^\uFEFF/,''));
const result=await permissionHook({hook_event_name:'PermissionRequest',session_id:'widget-permission-test',turn_id:'preview-'+Date.now(),tool_name:'授权按钮测试',tool_input:{description:'测试：请选择同意或拒绝。不会执行命令，也不会修改文件。',operation:'演示请求，仅记录按钮选择，不执行任何操作。'}},{dataDir:config.dataDir,timeoutMs:180000});
fs.writeFileSync(path.join(config.dataDir,'permission-preview-result.json'),JSON.stringify({previewOnly:true,decision:result?.hookSpecificOutput?.decision?.behavior||'fallback-or-timeout',at:Date.now()}));
