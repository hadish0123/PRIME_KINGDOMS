function integer(env, name, fallback, min, max) {
  const raw = env[name] ?? String(fallback);
  if (!/^\d+$/.test(raw)) throw new Error(`Invalid ${name}`);
  const value = Number(raw);
  if (!Number.isSafeInteger(value) || value < min || value > max) {
    throw new Error(`Invalid ${name}`);
  }
  return value;
}

export function loadConfig(env = process.env) {
  if (!env.DATABASE_URL) throw new Error('DATABASE_URL is required');
  let databaseUrl;
  try {
    databaseUrl = new URL(env.DATABASE_URL);
  } catch {
    throw new Error('Invalid DATABASE_URL');
  }
  if (!['postgres:', 'postgresql:'].includes(databaseUrl.protocol) || !databaseUrl.hostname) {
    throw new Error('Invalid DATABASE_URL');
  }
  return Object.freeze({
    port: integer(env, 'PORT', 3000, 1, 65535),
    host: '0.0.0.0',
    databaseUrl: env.DATABASE_URL,
    databasePoolMax: integer(env, 'DATABASE_POOL_MAX', 5, 1, 50),
    startupAttempts: integer(env, 'DATABASE_STARTUP_ATTEMPTS', 12, 1, 30),
    startupRetryMs: integer(env, 'DATABASE_RETRY_MS', 3000, 100, 10000),
    version: '0.6.4',
    commit: env.RAILWAY_GIT_COMMIT_SHA || 'local',
  });
}
