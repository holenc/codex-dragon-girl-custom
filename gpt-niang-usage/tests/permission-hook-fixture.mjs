// Isolated UI test only: returns a decision, never executes a command.
import fs from 'node:fs';
import path from 'node:path';
import {permissionHook} from '../runtime/permission-hook.mjs';
const dataDir=process.argv[2];
const result=await permissionHook({hook_event_name:'PermissionRequest',session_id:'ui-test-only',turn_id:'ui-test-only',tool_name:'Bash',tool_input:{description:'界面测试，不会执行任何命令。',command:'TEST ONLY — no command is executed'}},{dataDir,timeoutMs:10000,pollMs:50});
fs.writeFileSync(path.join(dataDir,'result.json'),JSON.stringify(result));
