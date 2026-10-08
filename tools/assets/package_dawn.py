"""Package reviewed native evidence plus editable Royal Dawn design sources."""
from pathlib import Path
from html import escape
import json
import re
import textwrap
import zipfile

ROOT = Path(__file__).resolve().parents[2]
BUILD = ROOT / 'client/builds'
TOKENS = json.loads((ROOT/'design/royal-dawn/tokens.json').read_text())
P = TOKENS['palette']


def rect(box, fill, edge=P['border'], radius=8):
    x, y, w, h = box
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{radius}" fill="{fill}" stroke="{edge}" stroke-width="1"/>'


def artwork(source, box, identifier):
    path = ROOT/'client'/source.removeprefix('res://')
    if not path.is_file() or path.suffix != '.svg':
        return ''
    art = path.read_text()
    for name in re.findall(r'\bid="([^"]+)"', art):
        art = art.replace(f'id="{name}"',f'id="{identifier}-{name}"').replace(f'url(#{name})',f'url(#{identifier}-{name})')
    x,y,w,h=box
    # Nested SVG keeps paths editable and aspect ratios intact.
    art = re.sub(r'<svg\b[^>]*>',f'<svg x="{x}" y="{y}" width="{w}" height="{h}" viewBox="{re.search(r"viewBox=\"([^\"]+)\"",art).group(1)}">',art,count=1)
    return art


def text(value, box, size=16, color=P['text'], font='Noto Sans', centered=False):
    x,y,w,h=box
    if w<=0 or not value: return ''
    lines=[]
    for row in value.splitlines():
        lines.extend(textwrap.wrap(row,max(1,int(w/(size*0.57))),break_long_words=False) or [''])
    lines=lines[:max(1,int(h/(size*1.22)))]
    anchor='middle' if centered else 'start'
    at=x+w/2 if centered else x
    result=f'<text x="{at}" y="{y+size}" font-family="{escape(font)}" font-size="{size}" fill="{color}" text-anchor="{anchor}">'
    result+=''.join(f'<tspan x="{at}" dy="{0 if i==0 else size*1.22}">{escape(row)}</tspan>' for i,row in enumerate(lines))
    return result+'</text>'


def screen_svg(data):
    defs='<linearGradient id="paper" x2="0" y2="1"><stop stop-color="#fffdf7"/><stop offset="1" stop-color="#f2eadb"/></linearGradient><linearGradient id="gold" x2="0" y2="1"><stop stop-color="#fff1c0"/><stop offset="1" stop-color="#e9c77b"/></linearGradient>'
    parts=[]
    for i,n in enumerate(data['nodes']):
        clip=n['clip'];x,y,w,h=n['bounds'];role=n['role']
        defs+=f'<clipPath id="clip{i}"><rect x="{clip[0]}" y="{clip[1]}" width="{clip[2]}" height="{clip[3]}"/></clipPath>'
        body=''
        if role in ['panel','button','field']:
            fill=n.get('color','url(#gold)' if n.get('skin','').endswith('/gold.svg') else 'url(#paper)')
            body+=rect(n['bounds'],fill,n.get('border',P['border']))
        if role=='button' and n.get('text'):
            body+=text(n['text'],[x+36,y+(h-n['fontSize'])/2-3,w-48,n['fontSize']*1.3],n['fontSize'],n['colorText'],'Cinzel',True)
            if n.get('icon'):body+=artwork(n['icon'],[x+10,y+(h-22)/2,22,22],f'b{i}')
        elif role=='text':body+=text(n['text'],n['bounds'],n['fontSize'],n['color'],n.get('font','Noto Sans'),n.get('align')==1)
        elif role=='art':body+=artwork(n['source'],n['bounds'],f'a{i}')
        elif role=='field':body+=text(n['text'],[x+10,y+8,w-20,h-16],n['fontSize'])
        elif role in ['progress','slider']:
            body+=rect([x,y+h/2-3,w,6],P['raised'],P['border'],3)
            body+=rect([x,y+h/2-3,w*n['progress'],6],P['sage'],P['sage'],3)
            if role=='slider':body+=f'<circle cx="{x+w*n["progress"]}" cy="{y+h/2}" r="9" fill="#f5dda0" stroke="{P["gold"]}"/>'
        elif role=='clan_region' and n['group']:
            group=n['group'];edge=min(w-32,h-32);gx=x+(w-edge)/2;gy=y+(h-edge)/2;cell=edge/8
            body+=rect(n['bounds'],P['surface'])
            for plot in range(64):body+=rect([gx+(plot%8)*cell,gy+(plot//8)*cell,cell,cell],'#dce3c7','#b4bf9f',0)
            for member in group['members']:
                plot=int(member['plot']);mx=gx+(plot%8)*cell;my=gy+(plot//8)*cell
                body+=artwork('res://assets/ui/dawn/buildings.svg',[mx+4,my+3,cell-8,cell-6],f'c{i}-{plot}')
            body+=f'<rect x="{gx-3}" y="{gy-3}" width="{edge+6}" height="{edge+6}" fill="none" stroke="{group["secondaryColor"]}" stroke-width="4"/>'
        parts.append(f'<g id="layer-{i}" data-role="{role}" clip-path="url(#clip{i})">{body}</g>')
    return '<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="720" viewBox="0 0 1280 720"><title>'+escape(data['name'])+' · PRIME KINGDOMS</title><defs>'+defs+'</defs>'+''.join(parts)+'</svg>\n'


def main():
    layouts=sorted(BUILD.glob('design-*.json'))
    if len(layouts)!=17:raise SystemExit(f'Expected all 15 council screens, login and settings; received {len(layouts)}')
    destination=BUILD/'PRIME-KINGDOMS-Royal-Dawn-Design-0.9.5.zip'
    with zipfile.ZipFile(destination,'w',zipfile.ZIP_DEFLATED) as bundle:
        for source in sorted((ROOT/'design/royal-dawn').glob('*')):
            if source.is_file():bundle.write(source,'royal-dawn/'+source.name)
        for source in sorted((ROOT/'client/assets/ui/dawn').glob('*.svg')):
            bundle.write(source,'royal-dawn/assets/'+source.name)
        for source in (ROOT/'client/assets/fonts').glob('*.ttf'):
            bundle.write(source,'royal-dawn/fonts/'+source.name)
        for source in (ROOT/'client/assets/fonts').glob('*.txt'):
            bundle.write(source,'royal-dawn/fonts/'+source.name)
        bundle.write(ROOT/'client/assets/ATTRIBUTION.md','royal-dawn/ATTRIBUTION.md')
        for layout in layouts:
            data=json.loads(layout.read_text())
            bundle.write(layout,'royal-dawn/layouts/'+layout.name)
            bundle.writestr('royal-dawn/screens/'+data['name']+'.svg',screen_svg(data))
        for image in sorted(BUILD.glob('royal-*.png')) + [BUILD/(name+'.png') for name in ['starter-village','kingdom','clan-region','village-world','login','settings','district-village','district-empire','architecture-close']]:
            if not image.is_file():raise SystemExit('Missing native visual evidence: '+image.name)
            bundle.write(image,'royal-dawn/native-previews/'+image.name)
    print('ROYAL_DAWN_PACKAGE',destination.name,destination.stat().st_size,'bytes',len(layouts),'editable layouts')


if __name__=='__main__':main()
