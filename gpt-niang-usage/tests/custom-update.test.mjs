import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
import {RELEASE_API,CHECK_INTERVAL,DAY,allowedUrl,selectRelease} from '../runtime/update.mjs';
test('custom updater accepts only the custom repository, never upstream downloads',()=>{
 assert.equal(RELEASE_API,'https://api.github.com/repos/holenc/codex-dragon-girl-custom/releases/latest');
 assert.doesNotThrow(()=>allowedUrl(RELEASE_API,{api:true}));
 assert.throws(()=>allowedUrl('https://api.github.com/repos/T7moris/GPT-Niang/releases/latest',{api:true}));
 assert.throws(()=>allowedUrl('https://github.com/T7moris/GPT-Niang/releases/download/v2.0.1/package.zip'));
 assert.doesNotThrow(()=>allowedUrl('https://github.com/holenc/codex-dragon-girl-custom/releases/download/v2.0.1/package.zip'));
 assert.equal(selectRelease({tag_name:'v2.0.0',draft:false,prerelease:false},'2.0.0'),null);
});
test('update policy checks at startup and daily while running',()=>{
 assert.equal(CHECK_INTERVAL,DAY);assert.equal(CHECK_INTERVAL,86400000);
 const policy=JSON.parse(fs.readFileSync(new URL('../custom-build.json',import.meta.url),'utf8'));
 assert.equal(policy.updates.checkOnStartup,true);assert.equal(policy.updates.backgroundPolling,true);assert.equal(policy.updates.checkIntervalHours,24);
});
