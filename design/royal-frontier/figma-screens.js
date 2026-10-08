// Replace the three marked constants from figma-state.json, village-world.png,
// and the existing lion.svg. The only large image is the separate 3D viewport;
// all interface labels, hierarchy, buttons and clan plots remain editable.
const STATE = __STATE__;
const WORLD_BYTES = __WORLD_BYTES__;
const LION_SVG = __LION_SVG__;
const page=await figma.getNodeByIdAsync(STATE.pageId);
await figma.setCurrentPageAsync(page);
await Promise.all([figma.loadFontAsync({family:'Cinzel',style:'Regular'}),figma.loadFontAsync({family:'Noto Sans',style:'Regular'}),figma.loadFontAsync({family:'Noto Sans',style:'Bold'})]);
const createdNodeIds=[];const vars={};const styles={};const icons={};
const dependencies=[...Object.entries(STATE.variables).map(([k,v])=>['variable',k,v.id]),...Object.entries(STATE.styles).map(([k,v])=>['style',k,v]),...Object.entries(STATE.icons).map(([k,v])=>['icon',k,v])];
const resolved=await Promise.all(dependencies.map(([type,k,id])=>type==='variable'?figma.variables.getVariableByIdAsync(id):type==='style'?figma.getStyleByIdAsync(id):figma.getNodeByIdAsync(id)));
dependencies.forEach(([type,k],i)=>{(type==='variable'?vars:type==='style'?styles:icons)[k]=resolved[i];});
const [nav,resource,action,badge]=await Promise.all([figma.getNodeByIdAsync(STATE.components.RealmNavigation.setId),figma.getNodeByIdAsync(STATE.components.ResourceCounter.id),figma.getNodeByIdAsync(STATE.components.RoyalAction.setId),figma.getNodeByIdAsync(STATE.components.RealmBadge.id)]);
function record(n){createdNodeIds.push(n.id);return n;}
function paint(k){return figma.variables.setBoundVariableForPaint({type:'SOLID',color:{r:0,g:0,b:0}},'color',vars[k]);}
function surface(n,k='surface'){n.fills=[paint(k)];n.strokes=[paint('border')];n.strokeWeight=1;for(const c of ['topLeftRadius','topRightRadius','bottomLeftRadius','bottomRightRadius'])n.setBoundVariable(c,vars.radius);}
function column(name,w,h,bg='surface'){const n=record(figma.createAutoLayout('VERTICAL'));n.name=name;n.resize(w,h);n.primaryAxisSizingMode='FIXED';n.counterAxisSizingMode='FIXED';n.itemSpacing=8;if(bg)surface(n,bg);else n.fills=[];return n;}
function row(name,w,h,bg=null){const n=record(figma.createAutoLayout('HORIZONTAL'));n.name=name;n.resize(w,h);n.primaryAxisSizingMode='FIXED';n.counterAxisSizingMode='FIXED';n.counterAxisAlignItems='CENTER';n.itemSpacing=8;if(bg)surface(n,bg);else n.fills=[];return n;}
function text(parent,chars,style='body',color='text',size=null){const n=record(figma.createText());n.fontName=styles[style].fontName;n.textStyleId=styles[style].id;if(size)n.fontSize=size;n.characters=chars;n.fills=[paint(color)];parent.appendChild(n);return n;}
function image(parent,key,w=40,h=40){const n=record(icons[key].createInstance());parent.appendChild(n);n.resize(w,h);return n;}
function absolute(parent,n,x,y){parent.appendChild(n);n.layoutPositioning='ABSOLUTE';n.x=x;n.y=y;return n;}
function shape(parent,x,y,w,h,color){const n=record(figma.createRectangle());parent.appendChild(n);if(parent.layoutMode&&parent.layoutMode!=='NONE')n.layoutPositioning='ABSOLUTE';n.x=x;n.y=y;n.resize(w,h);n.fills=[paint(color)];return n;}
function base64(v){const abc='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';const out=[];let bits=0,b=0;for(const c of v){const n=abc.indexOf(c);if(n<0)continue;b=(b<<6)|n;bits+=6;if(bits>=8){bits-=8;out.push((b>>bits)&255);}}return new Uint8Array(out);}
const world=figma.createImage(base64(WORLD_BYTES));
const profile=record(figma.createComponent());profile.name='RulerProfile';profile.resize(250,78);profile.layoutMode='HORIZONTAL';profile.primaryAxisSizingMode='FIXED';profile.counterAxisSizingMode='FIXED';profile.counterAxisAlignItems='CENTER';profile.itemSpacing=8;profile.paddingLeft=7;profile.paddingRight=7;surface(profile);
image(profile,'ruler.png',70,70);
const info=column('Identity',151,68,null);profile.appendChild(info);info.itemSpacing=1;
const pname=text(info,'PRIME','title','goldLight',17);const plevel=text(info,'Lv. 1','body','text',14);
const xp=record(figma.createFrame());xp.name='Server-confirmed experience';xp.resize(145,7);info.appendChild(xp);xp.fills=[paint('background')];shape(xp,0,0,32,7,'gold');
const prestige=text(info,'Prestige 0','caption','muted');
const pp={name:profile.addComponentProperty('Name','TEXT','PRIME'),level:profile.addComponentProperty('Level','TEXT','Lv. 1'),prestige:profile.addComponentProperty('Prestige','TEXT','Prestige 0')};
pname.componentPropertyReferences={characters:pp.name};plevel.componentPropertyReferences={characters:pp.level};prestige.componentPropertyReferences={characters:pp.prestige};profile.description='Profile identity, level, experience and prestige are populated from server snapshots.';profile.x=910;profile.y=2410;
function header(root){
  const h=row('RealmHeader',1260,94,'surface');h.paddingLeft=7;h.paddingRight=7;h.itemSpacing=6;absolute(root,h,10,8);
  h.appendChild(record(profile.createInstance()));
  const crest=column('Heraldry',48,78,'surface');crest.paddingLeft=8;crest.paddingRight=8;crest.paddingTop=7;crest.paddingBottom=7;h.appendChild(crest);const lion=record(figma.createNodeFromSvg(LION_SVG));crest.appendChild(lion);lion.resize(30,60);
  const identity=column('Realm identity',260,78,'surface');identity.paddingLeft=10;identity.primaryAxisAlignItems='CENTER';identity.itemSpacing=4;h.appendChild(identity);text(identity,'PRIME · Village','title','goldLight',17);text(identity,"PRIME’s Village · Level 1 · 1 holding",'caption','muted');
  const wallets=row('Resources',518,78);wallets.itemSpacing=5;h.appendChild(wallets);
  ['Food','Wood','Stone','Iron','Gold'].forEach((name,i)=>{const n=record(resource.createInstance());wallets.appendChild(n);n.resize(99.6,78);n.setProperties({[STATE.components.ResourceCounter.properties.label]:name,[STATE.components.ResourceCounter.properties.amount]:'500',[STATE.components.ResourceCounter.properties.icon]:icons['icons-'+i+'.png'].id});});
  const status=column('Connection and focus',146,78,'surface');status.paddingLeft=7;status.paddingRight=7;status.primaryAxisAlignItems='CENTER';status.counterAxisAlignItems='CENTER';status.itemSpacing=4;h.appendChild(status);text(status,'● Connected','caption','success',11);const focus=record(action.children.find(c=>c.name==='State=Secondary').createInstance());status.appendChild(focus);focus.resize(130,38);focus.setProperties({[STATE.components.RoyalAction.properties.label]:'Focus Capital'});
}
const navLabels=['Buildings','Army','Research','World','Clan','Goals','Inbox','Settings'];
function navigation(root,active='Buildings'){
  const bar=row('RealmNavigation',1000,84,'surface');bar.itemSpacing=5;bar.paddingLeft=7;bar.paddingRight=7;absolute(root,bar,140,629);
  navLabels.forEach((name,i)=>{const c=nav.children.find(c=>c.name==='State='+(name===active?'Active':'Idle'));const n=record(c.createInstance());bar.appendChild(n);n.resize(118.75,74);n.setProperties({[STATE.components.RealmNavigation.properties.label]:name,[STATE.components.RealmNavigation.properties.icon]:icons['icons-'+(i+5)+'.png'].id});});
}
function minimap(root){
  const map=record(figma.createFrame());map.name='Editable settlement minimap';map.resize(182,182);map.fills=[];absolute(root,map,1080,108);
  const ring=record(figma.createEllipse());map.appendChild(ring);ring.resize(180,180);ring.x=1;ring.y=1;ring.fills=[{type:'SOLID',color:{r:0.13,g:0.27,b:0.17},opacity:0.43}];ring.strokes=[paint('gold')];ring.strokeWeight=2;
  const area=shape(map,38,38,106,106,'raised');area.fills=[{type:'SOLID',color:{r:0.27,g:0.35,b:0.23},opacity:0.50}];area.strokes=[paint('muted')];area.strokeWeight=1;
  shape(map,87,38,7,106,'muted');shape(map,38,90,106,5,'muted');
  for(const [x,y] of [[85,57],[61,67],[58,88],[78,106],[112,116],[114,84],[103,54]])shape(map,x,y,7,10,'surface');
  const target=record(figma.createEllipse());map.appendChild(target);target.resize(18,18);target.x=82;target.y=82;target.fills=[];target.strokes=[paint('goldLight')];target.strokeWeight=2;
  const north=text(map,'N','caption','goldLight');north.x=86;north.y=0;
}
function guide(root){const g=row('RealmGuide',340,78,'surface');g.paddingLeft=14;g.paddingRight=14;g.itemSpacing=10;absolute(root,g,18,539);image(g,'icons-5.png',42,42);const c=column('Earned progression',254,56,null);c.itemSpacing=3;g.appendChild(c);text(c,'Village','title','goldLight',16);text(c,'Rise to Town · 0 / 5 milestones','caption','muted');const p=record(figma.createFrame());c.appendChild(p);p.name='Progress from real milestone requirements';p.resize(254,5);p.fills=[paint('background')];shape(p,0,0,60,5,'gold');}
function screen(name,x,active){if(page.children.some(n=>n.name===name))throw new Error('Screen exists: inspect the saved ledger before retrying.');const root=column(name,1280,720,'background');root.x=x;root.y=100;root.clipsContent=true;const scene=record(figma.createFrame());scene.name='3D world viewport — no interface pixels';scene.resize(1280,720);scene.fills=[{type:'IMAGE',imageHash:world.hash,scaleMode:'FILL'}];absolute(root,scene,0,0);header(root);navigation(root,active);minimap(root);return root;}
const village=screen('01 · Village HUD',100,'Buildings');guide(village);
function panelHeader(panel,section){const title=row('Council heading',panel.width-30,44);panel.appendChild(title);image(title,'icons-5.png',36,36);const heading=text(title,'ROYAL COUNCIL','display','goldLight');heading.textAutoResize='HEIGHT';heading.resize(panel.width-106,38);heading.layoutSizingHorizontal='FILL';const close=text(title,'×','display','goldLight');close.textAlignHorizontal='RIGHT';const dropdown=row('Section selector',panel.width-30,42,'raised');dropdown.paddingLeft=12;panel.appendChild(dropdown);text(dropdown,section,'body','text');}
function actionInstance(parent,name,kind='Secondary',width=218){const n=record(action.children.find(c=>c.name==='State='+kind).createInstance());parent.appendChild(n);n.resize(width,48);n.setProperties({[STATE.components.RoyalAction.properties.label]:name});return n;}
const council=screen('02 · Royal Council',1480,'Buildings');
const p=column('RoyalCouncil',537,500,'surface');p.paddingLeft=15;p.paddingRight=15;p.paddingTop=15;p.paddingBottom=15;p.itemSpacing=8;absolute(council,p,19,115);panelHeader(p,'Buildings');text(p,'PRIME’s Village · Level 1 · Village','body','muted',17);
const strip=row('Council resources',507,37);strip.itemSpacing=5;p.appendChild(strip);
['500','500','500','500','500'].forEach((amount,i)=>{const chip=row('Resource chip',97,37,'raised');chip.paddingLeft=5;chip.itemSpacing=5;strip.appendChild(chip);image(chip,'icons-'+i+'.png',25,25);text(chip,amount,'body','text',13);});
const card=column('Academy upgrade',507,224,'raised');card.paddingLeft=11;card.paddingRight=11;card.paddingTop=11;card.paddingBottom=11;card.itemSpacing=7;p.appendChild(card);
const detail=row('Academy information',485,116);detail.itemSpacing=11;card.appendChild(detail);image(detail,'buildings-0.png',106,116);
const desc=column('Upgrade quote',368,116,null);desc.itemSpacing=6;detail.appendChild(desc);text(desc,'ACADEMY · LEVEL 0','title','goldLight',19);text(desc,'Unlocks research levels.','body','text',14);text(desc,'0 → 1 facility level','body','muted',14);text(desc,'Wood 150   Stone 100   Gold 80','caption','goldLight');text(desc,'Construction · 0m 30s','caption','muted');text(card,'Requires Keep · Level 1 (1 reached)','caption','success');actionInstance(card,'Construct','Primary',485);
const footer=row('Council actions',507,48);footer.itemSpacing=8;p.appendChild(footer);actionInstance(footer,'Refresh','Secondary',249);actionInstance(footer,'Return to Realm','Secondary',249);
const clan=screen('03 · Clan Region',2860,'Clan');
const cp=column('Clan workspace',1222,500,'surface');cp.paddingLeft=15;cp.paddingRight=15;cp.paddingTop=15;cp.paddingBottom=15;cp.itemSpacing=8;absolute(clan,cp,19,115);panelHeader(cp,'Clan');
const region=column('Clan region card',1192,306,'raised');region.paddingLeft=12;region.paddingRight=12;region.paddingTop=10;region.paddingBottom=10;region.itemSpacing=6;cp.appendChild(region);text(region,'[PRIME] Royal Frontier · Clan Region','title','goldLight');
const rr=row('Region and membership',1168,252);rr.itemSpacing=18;region.appendChild(rr);
const map=record(figma.createFrame());map.name='ClanRegion / 64 editable reserved plots';map.resize(252,252);map.fills=[paint('background')];rr.appendChild(map);
for(let plot=0;plot<64;plot++){const tile=shape(map,16+(plot%8)*27.5,16+Math.floor(plot/8)*27.5,27.5,27.5,plot<3?'raised':'background');tile.name=plot===0?'Capital':(plot<3?'Member holding '+plot:'Open reserved plot '+plot);tile.strokes=[{type:'SOLID',color:{r:0.24,g:0.33,b:0.24},opacity:0.70}];tile.strokeWeight=1;if(plot===0){const emblem=record(figma.createNodeFromSvg(LION_SVG));map.appendChild(emblem);emblem.resize(15,23);emblem.x=22;emblem.y=18;}if(plot===1||plot===2){const home=shape(map,23+plot*27.5,29,11,9,'muted');home.name='Member settlement';const roof=record(figma.createNodeFromSvg('<svg xmlns="http://www.w3.org/2000/svg" width="14" height="8" viewBox="0 0 14 8"><path d="M0 8 7 0 14 8Z" fill="#8a6a31"/></svg>'));map.appendChild(roof);roof.x=21.5+plot*27.5;roof.y=23;}if(plot===2){const own=shape(map,16+plot*27.5,16,27.5,27.5,'background');own.name='Your holding outline';own.fills=[];own.strokes=[paint('goldLight')];own.strokeWeight=2;}}
const border=shape(map,13,13,226,226,'background');border.name='Continuous clan perimeter';border.fills=[];border.strokes=[paint('gold')];border.strokeWeight=3;
const outer=shape(map,8,8,236,236,'background');outer.fills=[];outer.strokes=[paint('border')];outer.strokeWeight=1;
const summary=column('Clan details',898,208,null);summary.itemSpacing=14;summary.primaryAxisAlignItems='CENTER';rr.appendChild(summary);text(summary,'Capital · 2 member settlements · 61 open plots','body','text');const tip=text(summary,'The outer border marks your clan region. Select a settlement to identify its ruler.','body','muted',14);tip.textAutoResize='HEIGHT';tip.resize(790,44);actionInstance(summary,'Survey Clan Region','Secondary',870);
const cf=row('Clan actions',1192,48);cf.itemSpacing=12;cp.appendChild(cf);actionInstance(cf,'Refresh','Secondary',590);actionInstance(cf,'Return to Realm','Secondary',590);
const screens=[village,council,clan];
const evidence=screens.map(root=>{const nodes=root.findAll(()=>true);const counts={};for(const n of nodes)counts[n.type]=(counts[n.type]||0)+1;return {id:root.id,name:root.name,width:root.width,height:root.height,nodeTypes:counts,imageNodes:nodes.filter(n=>Array.isArray(n.fills)&&n.fills.some(f=>f.type==='IMAGE')).map(n=>({id:n.id,name:n.name,type:n.type,width:n.width,height:n.height})),fonts:[...new Set(nodes.filter(n=>n.type==='TEXT').map(n=>n.fontName.family))]};});
return {createdNodeIds,screenIds:Object.fromEntries(screens.map(n=>[n.name,n.id])),worldImageHash:world.hash,profile:{id:profile.id,properties:pp},evidence};
