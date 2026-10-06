"""Restore licensed source assets, rejecting any content that differs from its pin."""
import hashlib
import json
from pathlib import Path
import urllib.request
import time
import zlib
from concurrent.futures import ThreadPoolExecutor

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = json.loads(Path(__file__).with_name('sources.json').read_text())
SOURCE = ROOT / 'tools' / 'assets' / 'cache'


def digest(data, item):
    if 'sha256' in item:
        return hashlib.sha256(data).hexdigest() == item['sha256']
    return hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest() == item['sha']


def download(item):
    target = SOURCE / item['destination']
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        if digest(target.read_bytes(), item):
            return
    url = (f"https://raw.githubusercontent.com/{item['repository']}/{item['ref']}/{item['path']}"
           if 'repository' in item else item['url'])
    headers = {'User-Agent': 'PRIME-KINGDOMS-asset-build/0.4 (+https://github.com/hadish0123/PRIME_KINGDOMS)'}
    if 'range' in item:
        headers['Range'] = f"bytes={item['range'][0]}-{item['range'][1]}"
    for attempt in range(3):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=45) as response:
                if 'range' in item and response.status != 206:
                    raise ValueError('Asset archive server did not honor its pinned byte range')
                data = response.read()
            if item.get('deflate'): data = zlib.decompress(data, -15)
            if not digest(data, item):
                raise ValueError(f"Asset checksum mismatch: {item['destination']}")
            break
        except (OSError, TimeoutError):
            if attempt == 2: raise
            time.sleep(1 + attempt)
    target.write_bytes(data)
    print(f"Verified {item['destination']}: {len(data)} bytes", flush=True)


if __name__ == '__main__':
    with ThreadPoolExecutor(max_workers=4) as executor:
        list(executor.map(download, MANIFEST))
