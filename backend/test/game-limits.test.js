import test from 'node:test';
import assert from 'node:assert/strict';
import { createGameLimiter } from '../src/http.js';

test('authenticated limits separate movement from actions and recover after server time window', () => {
  let now = 1000;
  const limit = createGameLimiter({ clock: () => now, maxKeys: 5 });
  for (let n = 0; n < 120; n++) limit('first', 'POST', '/v2/units/train');
  assert.throws(() => limit('first', 'POST', '/v2/clans/donate'), { code: 'rate_limited' });
  for (let n = 0; n < 300; n++) limit('first', 'POST', '/v2/scene/move');
  assert.throws(() => limit('first', 'POST', '/v2/scene/move'), { code: 'rate_limited' });
  limit('first', 'GET', '/v2/kingdom'); limit('other', 'POST', '/v2/units/train');
  now += 60001;
  limit('first', 'POST', '/v2/units/train');
});
