"""Reproduce original, editable Royal Dawn vector artwork (no external assets)."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'client/assets/ui/dawn'
OUT.mkdir(parents=True, exist_ok=True)
INK = '#264b40'
GOLD = '#ac7c32'
PALE = '#f8f3e7'
SAGE = '#9cb8a2'


def svg(body, size=64, defs=''):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 {size} {size}"><defs>{defs}</defs>{body}</svg>\n'


def write(name, body, size=64, defs=''):
    (OUT / (name + '.svg')).write_text(svg(body, size, defs))


for name, top, bottom, edge in [('frame', '#fffdf6', '#f2ead8', '#b69b65'),
                               ('fine', '#fffefa', '#f1ecdf', '#c6b792'),
                               ('gold', '#fff1c0', '#e9c77b', '#a77930')]:
    defs = f'<linearGradient id="surface" x2="0" y2="1"><stop stop-color="{top}"/><stop offset="1" stop-color="{bottom}"/></linearGradient>'
    body = '<rect x="2" y="4" width="124" height="122" rx="13" fill="#5b4c2b" opacity=".14"/>'
    body += f'<rect x="2" y="2" width="124" height="122" rx="12" fill="url(#surface)" stroke="{edge}" stroke-width="1.5"/>'
    body += '<rect x="5" y="5" width="118" height="116" rx="9" fill="none" stroke="#ffffff" stroke-opacity=".8"/>'
    if name == 'frame':
        body += f'<path d="M20 9h30m28 0h30M20 117h30m28 0h30" stroke="{edge}" opacity=".7"/>'
        body += '<path d="m64 5 5 4-5 4-5-4Zm0 108 5 4-5 4-5-4Z" fill="#b28b45"/>'
    write(name, body, 128, defs)

# Pictograms share a two-weight ink outline, warm material colors and soft shadows.
icons = {
 'food': '<path d="M22 53 42 13M30 37l-13-7 4-8 13 10m-1 7 14-2 4-9-13 2M38 25l-8-11 7-5 5 12" fill="#dfb158"/><path d="m19 48 11 4m-14-6 10 5"/>',
 'wood': '<path d="m15 18 28-8 12 31-28 9Z" fill="#cba16d"/><ellipse cx="21" cy="43" rx="12" ry="11" fill="#e8c394"/><ellipse cx="21" cy="43" rx="6" ry="5" fill="none"/><path d="m24 23 23-7m-18 17 21-7m-4 8 7-2"/>',
 'stone': '<path d="m11 32 15-6 15 6v18l-15 6-15-6Z" fill="#d5d5c3"/><path d="m32 17 13-5 12 5v16l-12 5-13-5Z" fill="#eeeadf"/><path d="m11 32 15 6 15-6M26 38v18m6-39 13 5 12-5M45 22v16" fill="none"/>',
 'iron': '<path d="m10 37 13-19h27l7 19-12 13H20Z" fill="#9eaaa7"/><path d="M23 18 31 36h26M10 37l21-1 14 14M31 36l-8 14" fill="none"/><path d="m31 22 11 1" stroke="#f7f8ef" stroke-width="3"/>',
 'gold': '<ellipse cx="22" cy="42" rx="13" ry="8" fill="#deb45d"/><path d="M9 37v6c0 10 26 10 26 0v-6" fill="#c99a46"/><ellipse cx="22" cy="35" rx="13" ry="8" fill="#f4d992"/><ellipse cx="43" cy="29" rx="11" ry="17" fill="#e4bd66"/><ellipse cx="43" cy="29" rx="7" ry="12" fill="none"/><path d="M43 21v16m-3-4 6-8"/>',
 'buildings': '<path d="M10 51V22h13v29m18 0V22h13v29M23 31h18v20H23Z" fill="#e3d3af"/><path d="M8 22 17 10l8 12m14 0 9-12 8 12" fill="#a0baa9"/><path d="M29 51V40a3 3 0 0 1 6 0v11M15 29h4m26 0h4M7 53h50" fill="none"/>',
 'army': '<path d="m15 9 37 34-9 9L9 15Zm34 0L12 43l9 9 34-37Z" fill="#e3e7dc"/><path d="m12 43 10 9m20-10 11 11M9 56l9-9m38 9-9-9" stroke="#ac7c32" stroke-width="5"/>',
 'research': '<path d="M11 16q12-6 21 0 9-6 21 0v36q-12-6-21 0-9-6-21 0Z" fill="#f7e6ba"/><path d="M32 16v36M17 24h9m-9 7h9m-9 7h9m12-14h8m-8 7h8m-8 7h8" fill="none"/><path d="m40 8 4-4 4 4-4 4Z" fill="#c2994e" stroke="none"/>',
 'world': '<circle cx="32" cy="29" r="21" fill="#b3cbb4"/><ellipse cx="32" cy="29" rx="10" ry="21" fill="none"/><path d="M12 22h40M12 36h40M32 8v42m-7 6h14M32 50v6" fill="none"/>',
 'clan': '<path d="M32 11 53 19v16c0 12-14 21-21 25-7-4-21-13-21-25V19Z" fill="#adbfad"/><circle cx="32" cy="28" r="6" fill="#f9efda"/><path d="M21 45c0-14 22-14 22 0Z" fill="#f9efda"/><path d="m18 11 3-5m25 5-3-5" stroke="#ac7c32"/>',
 'goals': '<path d="M21 11h22v17c0 16-22 16-22 0Zm0 6H11v10c0 7 7 10 12 10m20-20h10v10c0 7-7 10-12 10" fill="#e8c77e"/><path d="M32 40v12m-9 3h18M26 22h12" fill="none"/>',
 'inbox': '<path d="M8 18h48v34H8Z" fill="#f2dfb7"/><path d="m8 18 24 19 24-19M8 52l17-19m31 19L39 33" fill="none"/><circle cx="32" cy="37" r="5" fill="#a66448" stroke="none"/>',
 'settings': '<path d="m28 8 8 0 2 7 6 3 7-2 4 7-5 5v8l5 5-4 7-7-2-6 3-2 7h-8l-2-7-6-3-7 2-4-7 5-5v-8l-5-5 4-7 7 2 6-3Z" fill="#ddcba5"/><circle cx="32" cy="32" r="10" fill="#f9f4e6"/>',
 'crown': '<path d="m10 21 10 7L32 13l12 15 10-7-6 24H16Z" fill="#eac675"/><path d="M17 51h30M20 37h24" fill="none"/><circle cx="32" cy="33" r="3" fill="#59816b" stroke="none"/>',
 'clock': '<circle cx="32" cy="34" r="22" fill="#f3e9d0"/><path d="M26 6h12M32 6v6m0 6v17l11 6" fill="none"/>',
 'refresh': '<path d="M52 26A21 21 0 0 0 14 18L8 26m0-13v13h13m-9 12a21 21 0 0 0 38 8l6-8m0 13V38H43" fill="none" stroke-width="4"/>',
 'back': '<path d="M53 32H12m16-17L11 32l17 17" fill="none" stroke-width="4"/>',
 'construct': '<path d="m20 48 25-31 7 6-26 31Z" fill="#d2af76"/><path d="m29 14 7-7 20 16-7 8Z" fill="#b1bbb2"/><path d="m13 16 6-5 33 36-6 6Z" fill="#d7dccf"/>',
 'close': '<path d="m18 18 28 28m0-28L18 46" fill="none" stroke-width="4"/>',
 'forward': '<path d="M11 32h41M36 15l17 17-17 17" fill="none" stroke-width="4"/>',
 'save': '<path d="M13 9h32l9 9v37H13Z" fill="#c2cebb"/><path d="M22 9v17h22V9M22 55V36h23v19" fill="#f8efd7"/><path d="M35 14v8"/>',
 'check': '<rect x="10" y="10" width="44" height="44" rx="9" fill="#cadbc7"/><path d="m20 33 8 8 17-20" fill="none" stroke-width="4"/>',
 'unchecked': '<rect x="10" y="10" width="44" height="44" rx="9" fill="#f8f3e7"/>',
 'chevron': '<path d="m18 25 14 14 14-14" fill="none" stroke-width="4"/>',
 'knob': '<circle cx="32" cy="32" r="21" fill="#f5dda0"/><circle cx="32" cy="32" r="14" fill="#fff8e9" stroke="#ba9855"/>',
 'chat': '<path d="M10 12h44v32H31L18 55V44h-8Z" fill="#d7e0cc"/><path d="M18 23h28m-28 10h19" fill="none"/>',
 'trade': '<path d="M10 21h39m-10-9 10 9-10 9M54 43H15m10-9-10 9 10 9" fill="none" stroke-width="4"/>',
}
for name, body in icons.items():
    write('gold-coin' if name == 'gold' else name, f'<g stroke="{INK}" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round">{body}</g>')
    if name in ['check','unchecked','chevron','knob']:
        path = OUT / (name+'.svg')
        extent = 16 if name == 'chevron' else 22
        path.write_text(path.read_text().replace('width="64" height="64"', f'width="{extent}" height="{extent}"'))

# Original PK crown-and-keep crest: separate from players' saved heraldry.
crest = '<circle cx="128" cy="128" r="116" fill="#fcf5e4" stroke="#bb9850" stroke-width="3"/><circle cx="128" cy="128" r="104" fill="none" stroke="#e1d2ae" stroke-width="2"/>'
crest += '<path d="M128 34 199 62v69c0 43-44 77-71 91-27-14-71-48-71-91V62Z" fill="#315b49" stroke="#b99245" stroke-width="4"/>'
crest += '<path d="m82 71 21 14 25-28 25 28 21-14-8 33H90Z" fill="#f2d58e"/><path d="M91 120h23v-9h28v9h23v53H91Z" fill="#f4e5bd"/>'
crest += '<path d="M91 131h74M106 142v14m44-14v14m-31 17v-22a9 9 0 0 1 18 0v22" fill="none" stroke="#315b49" stroke-width="5"/>'
crest += '<path d="m128 187 6 8-6 8-6-8Z" fill="#f2d58e"/>'
write('brand-crest', crest, 256)

# Editable building plates, in the same architectural palette as the 3D scene.
buildings = ['academy','keep','farm','lumber_mill','quarry','iron_mine','market','trading_post','warehouse','granary','barracks','training_grounds','archery_range','stable','siege_workshop','hospital','blacksmith','workshop','embassy','clan_hall','commander_hall','walls','watch_towers','gatehouse']
for index, name in enumerate(buildings):
    roof = '#bb7651' if index % 3 != 0 else '#60836f'
    body = '<rect x="2" y="2" width="252" height="252" rx="22" fill="url(#plate)"/><path d="M23 181 119 133l114 56-97 48Z" fill="#d3d9be"/><path d="m30 190 105 40 85-41" fill="none" stroke="#b3bf9f" stroke-width="2"/>'
    body += '<path d="M63 98 133 67l64 32v91l-66 30-68-33Z" fill="#e8d8b2"/><path d="m63 98 68 30v92l-68-33Z" fill="#fff2d6"/><path d="m131 128 66-29v91l-66 30Z" fill="#d9c69a"/>'
    body += f'<path d="m53 102 77-57 79 57-76 31Z" fill="{roof}" stroke="#59634d" stroke-width="2"/><path d="m130 45 3 88" fill="none" stroke="#edc38f" stroke-width="3"/>'
    body += '<g fill="none" stroke="#a2814e" stroke-width="3"><path d="M63 159 131 190l66-30M79 118v76m35-60v74m34-87v90m32-105v90"/></g>'
    body += '<g fill="#51796b" stroke="#e9ca81" stroke-width="3"><path d="m84 126 16 7v24l-16-7Zm59 17 16-7v24l-16 7Zm27-12 15-7v24l-15 7Z"/></g><path d="m111 175 16 7v36l-16-7Z" fill="#6b8b6f" stroke="#b99651" stroke-width="2"/>'
    if name in ['keep','embassy','clan_hall','commander_hall','watch_towers','gatehouse','walls']:
        body += '<path d="m42 89 22-10 22 10v91l-22 10-22-10Z" fill="#f4e6c4" stroke="#bca879" stroke-width="2"/><path d="m39 88 25-31 25 31-25 11Z" fill="#618373"/><path d="M58 106h12v17H58m0 17h12v17H58" fill="#527568"/>'
    if name in ['academy','hospital','embassy']:
        for x in range(76, 125, 16):
            body += f'<path d="M{x} 165v-21q6-12 12 5v21" fill="#748c73" stroke="#f5e6bf" stroke-width="3"/>'
    if name in ['farm','lumber_mill']:
        for i in range(4):
            body += f'<path d="m35 {197+i*5} 46-20" stroke="#718c59" stroke-width="4"/>'
        if name == 'lumber_mill':
            body += '<path d="M199 160v-41m-17 12 17-30 17 30Z" fill="#7c9b65" stroke="#4b7055" stroke-width="3"/>'
    if name in ['quarry','iron_mine']:
        body += '<path d="m38 172 17-22 21 7 9 21-25 13Z" fill="#b7bbae" stroke="#6f806e" stroke-width="2"/><path d="m52 177 27-5m-24-20 7 23" fill="none" stroke="#eae9de" stroke-width="3"/>'
    if name in ['market','trading_post','stable']:
        body += '<path d="m41 166 39-18 33 14-38 20Z" fill="#d7bd82"/><path d="M43 169v34m34-22v34m31-51v34" stroke="#765e3d" stroke-width="3"/><path d="m37 171 40-29 41 21-41 26Z" fill="#aec7a9" stroke="#5d8168" stroke-width="2"/>'
    if name in ['warehouse','granary','blacksmith','workshop','siege_workshop']:
        body += '<ellipse cx="65" cy="201" rx="12" ry="7" fill="#b59258"/><path d="M53 186v15c0 10 24 10 24 0v-15" fill="#c9a76c" stroke="#78633f" stroke-width="2"/><ellipse cx="65" cy="186" rx="12" ry="7" fill="#e4c48a" stroke="#78633f" stroke-width="2"/>'
    if name in ['barracks','training_grounds','archery_range','clan_hall','commander_hall']:
        body += '<path d="M180 72V25m0 0 35 9-35 15" fill="#315b49" stroke="#b48d40" stroke-width="3"/><path d="m193 33 5 6 5-6" fill="none" stroke="#edce86" stroke-width="2"/>'
    if name == 'hospital':
        body += '<path d="M156 81v24m-12-12h24" stroke="#fbf5e8" stroke-width="6"/>'
    body += '<circle cx="128" cy="240" r="2" fill="#ba9655"/>'
    write('building-'+name, body, 256, '<linearGradient id="plate" x2="0" y2="1"><stop stop-color="#fffcf3"/><stop offset="1" stop-color="#e9eedc"/></linearGradient>')

palette = dict(background='#f3eddf',surface='#fffaf0',raised='#eee6d3',border='#bba675',gold='#876027',goldLight='#6e542d',text='#243f35',muted='#606957',success='#376b47',ink='#343c2e',disabled='#737766',danger='#9f4a38',sage='#9cb8a2',champagne='#efd292')
design = ROOT / 'design/royal-dawn'
design.mkdir(parents=True, exist_ok=True)
(design/'tokens.json').write_text(json.dumps(dict(name='PRIME KINGDOMS / Royal Dawn',version='0.9.5',palette=palette,spacing=dict(xs=4,sm=8,md=12,lg=16,xl=24),radius=dict(card=12,chip=6),typography=dict(display=['Cinzel',27],title=['Cinzel',20],navigation=['Cinzel',14],body=['Noto Sans',16],value=['Noto Sans',20],caption=['Noto Sans',12]),viewport=dict(width=1280,height=720),figma=dict(file='https://www.figma.com/design/ENUteLxvRgApkWKUmrYQ5w',status='Existing Royal Frontier file unchanged. MCP Starter call limit blocks Royal Dawn writes. SVG sources are editable/importable.')), indent=2)+'\n')

# The launcher preserves the editable crest rather than baking a wordmark into art.
(ROOT/'client/icon.svg').write_text(svg('<rect width="256" height="256" rx="52" fill="#f4ecd8"/>'+crest,256))

assets = []
for path in sorted(OUT.glob('*.svg')) + [ROOT/'client/icon.svg']:
    data = path.read_bytes()
    assets.append(dict(path=str(path.relative_to(ROOT)),bytes=len(data),sha256=hashlib.sha256(data).hexdigest(),source='Original PRIME KINGDOMS Royal Dawn vector artwork',license='Original project artwork; no external source'))
(design/'assets.json').write_text(json.dumps(dict(version='0.9.5',direction='Ivory surfaces, champagne gold, sage glass and the original crown-and-keep crest.',assets=assets),indent=2)+'\n')
print('ROYAL_DAWN_CREATED',len(assets),'editable vector assets')
