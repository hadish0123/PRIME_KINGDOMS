import { readdir } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
const source = new URL('./',import.meta.url);
for (const name of await readdir(source,{recursive:true})) {
  if (!name.endsWith('.js')) continue;
  const result = spawnSync(process.execPath,['--check',new URL(name,source).pathname],{stdio:'inherit'});
  if (result.status !== 0) process.exit(result.status ?? 1);
}
