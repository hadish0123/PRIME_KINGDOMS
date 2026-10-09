import { loadConfig } from './config.js';
import { createDatabase, initializeDatabase } from './database.js';
import { createApplication } from './server.js';
import { startMarchWorker } from './kingdom/campaigns.js';

async function main() {
  const config = loadConfig();
  const pool = createDatabase(config);
  try {
    await initializeDatabase(pool, config);
  } catch (error) {
    await pool.end();
    throw error;
  }
  const { server, beginDrain } = createApplication({ pool, config });
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(config.port, config.host, resolve);
  });
  console.log(JSON.stringify({ event: 'server_started', port: config.port, version: config.version, commit: config.commit }));
  const campaigns = startMarchWorker(pool);

  let stopping = false;
  const shutdown = async () => {
    if (stopping) return;
    stopping = true;
    beginDrain();
    console.log(JSON.stringify({ event: 'server_stopping' }));
    const deadline = setTimeout(() => process.exit(1), 15000);
    deadline.unref();
    await campaigns.stop();
    await new Promise((resolve) => server.close(resolve));
    await pool.end();
    clearTimeout(deadline);
  };
  const stop = () => {
    shutdown().catch(() => {
      console.error(JSON.stringify({ event: 'shutdown_failed' }));
      process.exit(1);
    });
  };
  process.once('SIGTERM', stop);
  process.once('SIGINT', stop);
}

main().catch(() => {
  console.error(JSON.stringify({ event: 'startup_failed', hint: 'Check configuration and database availability.' }));
  process.exit(1);
});
