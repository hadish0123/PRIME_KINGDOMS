"""Restore only the pinned dependencies needed by the production player review."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import shutil
import download
import humans

TEXTURES = {'textures/sky.hdr', 'textures/rough_linen_diff.jpg', 'textures/rough_linen_normal.jpg'}
items = [item for item in download.MANIFEST if item['destination'].startswith('human/') or item['destination'] in TEXTURES]
with ThreadPoolExecutor(max_workers=4) as pool:
    list(pool.map(download.download, items))
humans.build('hero')
for item in items:
    if item['destination'] not in TEXTURES: continue
    source = download.SOURCE / item['destination']
    destination = download.ROOT / 'client/assets' / item['destination']
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)
