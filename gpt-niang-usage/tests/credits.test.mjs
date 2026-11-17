import test from 'node:test';
import assert from 'node:assert/strict';
import {normalizeLimits} from '../runtime/usage.mjs';
const read=credits=>normalizeLimits({rateLimits:{primary:{windowDurationMins:300,usedPercent:100,resetsAt:null},credits}});
test('paid credits preserve decimal balances including zero without borrowing other buckets',()=>{
  assert.equal(read({balance:'493.58332'}).credits.balance,493.58332);
  assert.equal(read({balance:'0'}).credits.balance,0);
  for(const balance of [null,'',-1,'invalid',Infinity])assert.equal(read({balance}).credits.balance,null);
  assert.equal(read(undefined).credits,null);
  assert.equal(read({unlimited:true}).credits.unlimited,true);
  const value=normalizeLimits({rateLimits:{credits:{balance:'900'}},rateLimitsByLimitId:{codex:{primary:{windowDurationMins:300,usedPercent:0}}}});
  assert.equal(value.credits,null);
});
