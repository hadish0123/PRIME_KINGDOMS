"""Verify the exact reviewed royal interface sources before game import/export."""
from pathlib import Path
import hashlib,json,struct
root=Path(__file__).resolve().parents[2]
manifest=json.loads((root/'docs/ROYAL_ART_0_9_2.json').read_text())
for entry in manifest['assets']:
    source=(root/entry['path']).read_bytes()
    if len(source)!=entry['bytes'] or hashlib.sha256(source).hexdigest()!=entry['sha256']:
        raise ValueError('Reviewed UI source changed: '+entry['path'])
    if entry['path'].endswith('.png'):
        if source[:8]!=b'\x89PNG\r\n\x1a\n':raise ValueError('UI asset is not a PNG')
        width,height=struct.unpack('>II',source[16:24])
        if (width,height)!=(1254,1254):raise ValueError('UI atlas dimensions changed')
        if entry['path'].endswith('royal-icons.png') and source[25] not in (4,6):
            raise ValueError('UI icons require transparent backgrounds')
print('ROYAL_ART_VERIFIED',len(manifest['assets']),'original pinned sources')
