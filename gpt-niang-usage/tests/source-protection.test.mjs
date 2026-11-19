import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';import os from 'node:os';import path from 'node:path';import {spawnSync} from 'node:child_process';import {fileURLToPath} from 'node:url';
import {sourceProtection} from '../runtime/update.mjs';
const git=(...args)=>{const i=args.indexOf('-C');if(i>=0)args=['-c','safe.directory='+args[i+1],...args];const r=spawnSync('git',args,{encoding:'utf8',windowsHide:true});assert.equal(r.status,0,r.stderr);};
function fixture(fn){const root=fs.mkdtempSync(path.join(os.tmpdir(),'gn-source-'));try{fn(root)}finally{assert.ok(path.resolve(root).startsWith(path.resolve(os.tmpdir())+path.sep));fs.rmSync(root,{recursive:true,force:true})}}
function check(app,expected){
 assert.deepEqual(sourceProtection(app),expected);
 if(process.platform==='win32'){
  const r=spawnSync(path.join(process.env.WINDIR,'System32/WindowsPowerShell/v1.0/powershell.exe'),['-NoProfile','-ExecutionPolicy','Bypass','-File',fileURLToPath(new URL('source-protection.probe.ps1',import.meta.url)),'-AppDir',app],{encoding:'utf8',windowsHide:true,timeout:10000});
  assert.equal(r.status,0,r.stderr);assert.deepEqual(JSON.parse(r.stdout),expected);
 }
}
test('standalone release and an untracked release under an ancestor Git workspace can update',()=>fixture(root=>{
 const workspace=path.join(root,'workspace with spaces'),program=path.join(workspace,'downloads','dragon'),app=path.join(program,'gpt-niang-usage');fs.mkdirSync(app,{recursive:true});
 check(app,{blocked:false,reason:'standalone'});git('init','-q',workspace);
 fs.writeFileSync(path.join(workspace,'work.txt'),'workspace file');git('-C',workspace,'add','work.txt');
 const index=fs.readFileSync(path.join(workspace,'.git','index')),config=fs.readFileSync(path.join(workspace,'.git','config'));
 check(app,{blocked:false,reason:'ancestor-untracked'});
 assert.deepEqual(fs.readFileSync(path.join(workspace,'.git','index')),index);assert.deepEqual(fs.readFileSync(path.join(workspace,'.git','config')),config);
}));
test('tracked program files and true repositories remain protected',()=>fixture(root=>{
 const workspace=path.join(root,'workspace'),program=path.join(workspace,'release'),app=path.join(program,'gpt-niang-usage');fs.mkdirSync(app,{recursive:true});git('init','-q',workspace);
 fs.writeFileSync(path.join(app,'widget.ps1'),'source');git('-C',workspace,'add','release');check(app,{blocked:true,reason:'ancestor-tracked'});
 fs.writeFileSync(path.join(program,'.git'),'gitdir: elsewhere');check(app,{blocked:true,reason:'program-repository'});
}));
test('explicit maintenance sources remain protected without requiring Git',()=>fixture(root=>{
 const app=path.join(root,'program','gpt-niang-usage');fs.mkdirSync(app,{recursive:true});fs.writeFileSync(path.join(path.dirname(app),'.gpt-niang-source'),'source');check(app,{blocked:true,reason:'explicit-source'});
}));
test('unable to inspect an ancestor repository fails closed',()=>fixture(root=>{
 const app=path.join(root,'release','gpt-niang-usage');fs.mkdirSync(app,{recursive:true});fs.mkdirSync(path.join(root,'.git'));
 check(app,{blocked:true,reason:'ancestor-unverified'});
 const result=sourceProtection(app,{runGit:()=>({error:new Error('missing git')})});assert.equal(result.blocked,true);assert.equal(result.reason,'ancestor-unverified');
}));
