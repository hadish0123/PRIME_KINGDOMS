"""Download only the pinned, CC0 model files in sources.json; verify Git blob IDs."""
import hashlib
import json
from pathlib import Path
import urllib.request
from concurrent.futures import ThreadPoolExecutor

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = json.loads(Path(__file__).with_name('sources.json').read_text())
SOURCE = ROOT / 'tools' / 'assets' / 'cache'


def download(item):
    target = SOURCE / item['destination']
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        existing = target.read_bytes()
        digest = hashlib.sha1(b'blob ' + str(len(existing)).encode() + b'\0' + existing).hexdigest()
        if digest == item['sha']:
            return
    url = f"https://raw.githubusercontent.com/{item['repository']}/{item['ref']}/{item['path']}"
    request = urllib.request.Request(url, headers={'User-Agent': 'PRIME-KINGDOMS-asset-build/0.2'})
    with urllib.request.urlopen(request, timeout=60) as response:
        data = response.read()
    digest = hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()
    if digest != item['sha']:
        raise ValueError(f"Model checksum mismatch: {item['destination']}")
    target.write_bytes(data)
    print(f"Verified {item['destination']}: {len(data)} bytes", flush=True)


if __name__ == '__main__':
    with ThreadPoolExecutor(max_workers=4) as executor:
        list(executor.map(download, MANIFEST))
