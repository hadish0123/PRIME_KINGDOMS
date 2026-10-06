// These functions are mirrored in the Godot terrain generator. All coordinates
// use metres, with Y vertical. Keep terrain version 1 stable for existing worlds.
function hash(x, z, seed) {
  let n = Math.imul(x | 0, 374761393) ^ Math.imul(z | 0, 668265263) ^ (seed | 0);
  n = Math.imul(n ^ (n >>> 13), 1274126177);
  return ((n ^ (n >>> 16)) >>> 0) / 4294967295;
}
function noise(x, z, seed) {
  const ix = Math.floor(x), iz = Math.floor(z);
  const fx = x - ix, fz = z - iz;
  const sx = fx * fx * (3 - 2 * fx), sz = fz * fz * (3 - 2 * fz);
  const a = hash(ix, iz, seed), b = hash(ix + 1, iz, seed);
  const c = hash(ix, iz + 1, seed), d = hash(ix + 1, iz + 1, seed);
  return (a + (b - a) * sx) + ((c + (d - c) * sx) - (a + (b - a) * sx)) * sz;
}
export function terrainHeight(x, z, seed) {
  return 12 + noise(x / 1400, z / 1400, seed) * 44
    + noise(x / 360, z / 360, seed + 71) * 13
    + noise(x / 110, z / 110, seed + 137) * 3;
}

// Square spiral: centre first, then adjacent locations, with 512 m between
// centres. A database sequence plus a uniqueness constraint prevents overlap.
export function villageLocation(slot, seed) {
  if (!Number.isSafeInteger(slot) || slot < 0 || slot >= 16000) throw new RangeError('World village capacity exceeded');
  if (slot === 0) return { x: 0, y: terrainHeight(0, 0, seed), z: 0 };
  const ring = Math.ceil((Math.sqrt(slot + 1) - 1) / 2);
  const side = ring * 2, max = (2 * ring + 1) ** 2 - 1;
  const offset = max - slot;
  let gx, gz;
  if (offset < side) { gx = ring - offset; gz = -ring; }
  else if (offset < side * 2) { gx = -ring; gz = -ring + offset - side; }
  else if (offset < side * 3) { gx = -ring + offset - side * 2; gz = ring; }
  else { gx = ring; gz = ring - offset + side * 3; }
  const x = gx * 512, z = gz * 512;
  return { x, y: terrainHeight(x, z, seed), z };
}
