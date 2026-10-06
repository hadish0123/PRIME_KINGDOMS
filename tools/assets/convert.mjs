import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import { dequantize } from '@gltf-transform/functions';
import { MeshoptDecoder } from 'meshoptimizer';
import { readFile, writeFile, mkdir, copyFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const base = dirname(fileURLToPath(import.meta.url));
const root = resolve(base, '../..');
const manifest = JSON.parse(await readFile(resolve(base, 'sources.json'), 'utf8'));
await MeshoptDecoder.ready;
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS).registerDependencies({ 'meshopt.decoder': MeshoptDecoder });
for (const item of manifest) {
  if (!item.destination.startsWith('characters/') && !item.destination.startsWith('village/')) continue;
  const source = resolve(base, 'cache', item.destination);
  const destination = resolve(root, 'client/assets', item.destination.replace(/\.gltf$/, '.glb'));
  await mkdir(dirname(destination), { recursive: true });
  const document = await io.read(source);
  for (const extension of document.getRoot().listExtensionsUsed()) {
    if (extension.extensionName === 'EXT_meshopt_compression') extension.dispose();
  }
  await document.transform(dequantize());
  await writeFile(destination, await io.writeBinary(document));
  console.log(`Native Godot model: ${item.destination}`);
}
for (const item of manifest.filter(item => item.destination.startsWith('textures/'))) {
  const destination = resolve(root, 'client/assets', item.destination);
  await mkdir(dirname(destination), { recursive: true });
  await copyFile(resolve(root, 'tools/assets/cache', item.destination), destination);
}
