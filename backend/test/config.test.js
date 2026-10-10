import test from 'node:test';
import assert from 'node:assert/strict';
import { loadConfig } from '../src/config.js';

const base = { DATABASE_URL: 'postgresql://test:test@localhost:5432/test' };

test('Railway port and pool limits are accepted', () => {
  const config = loadConfig({ ...base, PORT: '8080', DATABASE_POOL_MAX: '8' });
  assert.equal(config.port, 8080);
  assert.equal(config.host, '0.0.0.0');
  assert.equal(config.databasePoolMax, 8);
});

test('invalid ports and unsafe pool sizes fail before startup', () => {
  for (const value of ['0', '65536', '-1', '3000abc', '1.5', 'Infinity']) {
    assert.throws(() => loadConfig({ ...base, PORT: value }), /Invalid PORT/);
  }
  for (const value of ['0', '51', 'unlimited']) {
    assert.throws(() => loadConfig({ ...base, DATABASE_POOL_MAX: value }), /Invalid DATABASE_POOL_MAX/);
  }
});

test('missing or invalid database URL fails without exposing credentials', () => {
  assert.throws(() => loadConfig({}), /DATABASE_URL is required/);
  const secret = 'do-not-print-this-password';
  for (const value of [`https://user:${secret}@localhost/db`, secret, 'postgresql:///db']) {
    assert.throws(() => loadConfig({ DATABASE_URL: value }), (error) => {
      assert.equal(error.message, 'Invalid DATABASE_URL');
      assert.equal(error.message.includes(secret), false);
      return true;
    });
  }
});


test('owner account binding is optional and only accepts a UUID', () => {
  assert.equal(loadConfig(base).ownerAccountId, null);
  const owner = '11111111-2222-4333-8444-555555555555';
  assert.equal(loadConfig({ ...base, PRIME_OWNER_ACCOUNT_ID: owner }).ownerAccountId, owner);
  for (const value of ['owner@example.com','123','00000000-0000-0000-0000-00000000000z']) {
    assert.throws(() => loadConfig({ ...base, PRIME_OWNER_ACCOUNT_ID: value }), /Invalid PRIME_OWNER_ACCOUNT_ID/);
  }
});
