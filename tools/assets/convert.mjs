import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import { dequantize, prune } from '@gltf-transform/functions';
import { MeshoptDecoder } from 'meshoptimizer';
import { readFile, writeFile, mkdir, copyFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';

const base = dirname(fileURLToPath(import.meta.url));
const root = resolve(base, '../..');
const manifest = JSON.parse(await readFile(resolve(base, 'sources.json'), 'utf8'));
const meadow=await readFile(resolve(root,'client/assets/textures/meadow_alpha.png'));
if(createHash('sha256').update(meadow).digest('hex')!=='91934ee9fd80b4d1b8595d019e656bd712e79d1403d82eb7f49b749050fd2659') throw new Error('Original meadow atlas checksum mismatch');
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
for (const item of manifest.filter(item => item.destination.startsWith('textures/') || item.destination.startsWith('fonts/'))) {
  const destination = resolve(root, 'client/assets', item.destination);
  await mkdir(dirname(destination), { recursive: true });
  await copyFile(resolve(root, 'tools/assets/cache', item.destination), destination);
}
// Split the CC0 photogrammetry set into individual reusable rocks, centered at ground.
const rockSource = resolve(base, 'cache/nature/rock_moss_set_02/rock_moss_set_02.gltf');
const rockSet = await io.read(rockSource);
const rockNames = rockSet.getRoot().listNodes().filter(n => n.getMesh()).map(n => n.getName());
for (let i = 0; i < rockNames.length; i++) {
  const document = await io.read(rockSource);
  for (const node of document.getRoot().listNodes()) {
    if (node.getMesh() && node.getName() !== rockNames[i]) node.dispose();
  }
  const node = document.getRoot().listNodes().find(n => n.getMesh());
  node.setTranslation([0, 0, 0]);
  // All seven instances share one photographic texture set at runtime.
  for (const material of document.getRoot().listMaterials()) {
    material.setBaseColorTexture(null).setNormalTexture(null).setMetallicRoughnessTexture(null).setOcclusionTexture(null);
  }
  await document.transform(prune());
  const destination = resolve(root, 'client/assets/nature', `rock-${i}.glb`);
  await mkdir(dirname(destination), { recursive: true });
  await writeFile(destination, await io.writeBinary(document));
  console.log(`Photogrammetry rock ${i}: ${rockNames[i]}`);
}
for (const [source, suffix] of [['diff','diff'],['nor_gl','normal'],['rough','rough']]) {
  await copyFile(resolve(base, 'cache/nature/rock_moss_set_02/textures', `rock_moss_set_02_${source}_1k.jpg`),
                 resolve(root, 'client/assets/textures', `rock_moss_${suffix}.jpg`));
}
