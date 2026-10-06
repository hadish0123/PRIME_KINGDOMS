import test from 'node:test';
import assert from 'node:assert/strict';
import { hashPassword, verifyPassword, normalizeEmail, validatePassword, validateDisplayName, tokenHash } from '../src/auth.js';
import { terrainHeight, villageLocation } from '../src/terrain.js';

test('credentials are normalized, validated and salted; hashes never contain the password', async () => {
  assert.equal(normalizeEmail(' PRIME@Example.COM '), 'prime@example.com');
  assert.equal(validateDisplayName('  PRIME  '), 'PRIME');
  for (const value of ['', null, 'a@b', 'a b@example.com']) assert.throws(() => normalizeEmail(value));
  for (const value of ['123', null, 'a'.repeat(257)]) assert.throws(() => validatePassword(value));
  for (const value of ['<prime>', 'x', 'PRI\nME']) assert.throws(() => validateDisplayName(value));
  const password = 'test-password-unique';
  const first = await hashPassword(password), second = await hashPassword(password);
  assert.notEqual(first, second);
  assert.equal(first.includes(password), false);
  assert.equal(await verifyPassword(password, first), true);
  assert.equal(await verifyPassword('different-password', first), false);
  assert.equal(await verifyPassword(password, undefined), false);
  assert.equal(tokenHash('opaque-session').length, 64);
});

test('village allocation stays unique and inside the world and terrain is deterministic', () => {
  const points = new Set();
  for (let slot = 0; slot < 16000; slot++) {
    const p = villageLocation(slot, 541652784);
    assert.ok(Math.abs(p.x) < 32748 && Math.abs(p.z) < 32748);
    assert.equal(points.has(`${p.x},${p.z}`), false);
    points.add(`${p.x},${p.z}`);
    assert.equal(p.y, terrainHeight(p.x, p.z, 541652784));
  }
  assert.throws(() => villageLocation(16000, 1));
  assert.throws(() => villageLocation(-1, 1));
});
