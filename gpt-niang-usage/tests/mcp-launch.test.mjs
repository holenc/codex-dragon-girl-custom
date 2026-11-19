import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';import os from 'node:os';import path from 'node:path';import {spawnSync} from 'node:child_process';import {fileURLToPath} from 'node:url';
test('stable Windows launcher preserves MCP initialize and tool-list JSON-RPC bytes',{skip:process.platform!=='win32'},()=>{
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'gn-mcp-launch-')),app=fileURLToPath(new URL('../',import.meta.url));
 try{
  fs.cpSync(path.join(app,'runtime'),path.join(root,'runtime'),{recursive:true});fs.cpSync(path.join(app,'.codex-plugin'),path.join(root,'.codex-plugin'),{recursive:true});fs.copyFileSync(path.join(app,'package.json'),path.join(root,'package.json'));
  fs.writeFileSync(path.join(root,'installation.json'),JSON.stringify({version:'fixture',appDir:root,dataDir:path.join(root,'state'),nodePath:process.execPath,codexPath:process.execPath}));
  const input=[{jsonrpc:'2.0',id:1,method:'initialize',params:{protocolVersion:'2024-11-05',capabilities:{}}},{jsonrpc:'2.0',id:2,method:'tools/list',params:{}}].map(x=>JSON.stringify(x)).join('\n')+'\n';
  const result=spawnSync(path.join(process.env.WINDIR,'System32/WindowsPowerShell/v1.0/powershell.exe'),['-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File',path.join(root,'runtime/mcp-launch.ps1')],{input,encoding:'utf8',windowsHide:true,timeout:20000});
  assert.equal(result.status,0,result.stderr);const rows=result.stdout.trim().split(/\r?\n/).map(x=>JSON.parse(x));
  assert.equal(rows.length,2);assert.equal(rows[0].result.serverInfo.name,'gpt-niang-usage');assert.equal(rows[1].result.tools[0].name,'get_codex_usage');
 }finally{assert.ok(path.resolve(root).startsWith(path.resolve(os.tmpdir())+path.sep));fs.rmSync(root,{recursive:true,force:true})}
});
