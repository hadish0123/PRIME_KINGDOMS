import { randomBytes, scrypt, timingSafeEqual, createHash } from 'node:crypto';
import { promisify } from 'node:util';
import { ApiError } from './errors.js';

const derive = promisify(scrypt);
const options = { N: 131072, r: 8, p: 1, maxmem: 192 * 1024 * 1024 };
const dummySalt = Buffer.alloc(16, 3);
let activeHashes = 0;

export function normalizeEmail(value) {
  if (typeof value !== 'string') throw new ApiError(400, 'invalid_email');
  const email = value.trim().toLowerCase();
  if (email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new ApiError(400, 'invalid_email');
  return email;
}
export function validatePassword(value) {
  if (typeof value !== 'string' || Array.from(value).length < 10 || Buffer.byteLength(value) > 256) {
    throw new ApiError(400, 'password_length');
  }
  return value;
}
export function validateDisplayName(value) {
  if (typeof value !== 'string') throw new ApiError(400, 'invalid_name');
  const name = value.trim().normalize('NFKC');
  if (Array.from(name).length < 2 || Array.from(name).length > 24 || /[\u0000-\u001f\u007f<>]/.test(name)) {
    throw new ApiError(400, 'invalid_name');
  }
  return name;
}
async function key(password, salt) {
  if (activeHashes >= 4) throw new ApiError(429, 'authentication_busy');
  activeHashes++;
  try { return await derive(password, salt, 32, options); }
  finally { activeHashes--; }
}
export async function hashPassword(password) {
  const salt = randomBytes(16);
  const derived = await key(password, salt);
  return `scrypt$131072$8$1$${salt.toString('hex')}$${derived.toString('hex')}`;
}
export async function verifyPassword(password, encoded) {
  if (!encoded) { await key(password, dummySalt); return false; }
  const parts = encoded.split('$');
  if (parts.length !== 6 || parts.slice(0, 4).join('$') !== 'scrypt$131072$8$1') return false;
  const actual = await key(password, Buffer.from(parts[4], 'hex'));
  const expected = Buffer.from(parts[5], 'hex');
  return expected.length === actual.length && timingSafeEqual(actual, expected);
}
export function tokenHash(token) { return createHash('sha256').update(token).digest('hex'); }
export async function createSession(db, accountId) {
  const token = randomBytes(32).toString('base64url');
  const { rows } = await db.query(`
    INSERT INTO sessions(token_hash, account_id, expires_at)
    VALUES ($1, $2, now() + interval '14 days') RETURNING expires_at
  `, [tokenHash(token), accountId]);
  return { token, expiresAt: rows[0].expires_at };
}
export async function authenticate(pool, authorization) {
  const token = typeof authorization === 'string' ? authorization.match(/^Bearer ([A-Za-z0-9_-]{43})$/)?.[1] : null;
  if (!token) throw new ApiError(401, 'unauthorized');
  const { rows } = await pool.query(`
    SELECT s.account_id, p.id AS player_id, p.world_id
    FROM sessions s JOIN players p ON p.account_id = s.account_id
    WHERE s.token_hash = $1 AND s.expires_at > now()
  `, [tokenHash(token)]);
  if (!rows[0]) throw new ApiError(401, 'unauthorized');
  return { ...rows[0], tokenHash: tokenHash(token) };
}
