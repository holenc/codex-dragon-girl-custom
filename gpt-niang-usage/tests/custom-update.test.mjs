import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
import {RELEASE_API,allowedUrl,selectRelease} from '../runtime/update.mjs';
test('custom updater accepts only the custom repository, never upstream downloads',()=>{
 assert.equal(RELEASE_API,'https://api.github.com/repos/holenc/codex-dragon-girl-custom/releases/latest');
 assert.doesNotThrow(()=>allowedUrl(RELEASE_API,{api:true}));
 assert.throws(()=>allowedUrl('https://api.github.com/repos/T7moris/GPT-Niang/releases/latest',{api:true}));
 assert.throws(()=>allowedUrl('https://github.com/T7moris/GPT-Niang/releases/download/v2.0.1/package.zip'));
 assert.doesNotThrow(()=>allowedUrl('https://github.com/holenc/codex-dragon-girl-custom/releases/download/v2.0.1/package.zip'));
 assert.equal(selectRelease({tag_name:'v2.0.0',draft:false,prerelease:false},'2.0.0'),null);
});
test('GUI checks once on launch, not on a daily or half-hour polling loop',()=>{
 const ui=fs.readFileSync(new URL('../runtime/update-ui.ps1',import.meta.url),'utf8');
 assert.ok(ui.includes('!$script:updateStartupChecked'));assert.ok(ui.includes("Start-WidgetUpdate 'automatic-enabled'"));
 assert.ok(!ui.includes('$Now-ge [long]$state.nextCheckAt'));
 const policy=JSON.parse(fs.readFileSync(new URL('../custom-build.json',import.meta.url),'utf8'));
 assert.equal(policy.updates.checkOnStartup,true);assert.equal(policy.updates.backgroundPolling,false);
});
