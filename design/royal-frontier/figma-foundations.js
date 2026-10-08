// Run through Figma use_figma with __ASSET_BYTES__ replaced by encoded,
// preview-sized copies of the checksum-verified project artwork.
const ASSET_BYTES = __ASSET_BYTES__;
const page = await figma.getNodeByIdAsync('0:1');
await figma.setCurrentPageAsync(page);
const createdNodeIds = [];
if (page.children.length) throw new Error('Foundations already exist: inspect the saved ledger before resuming.');
page.name = 'Royal Frontier';
await Promise.all([
  figma.loadFontAsync({ family:'Cinzel',style:'Regular' }),
  figma.loadFontAsync({ family:'Noto Sans',style:'Regular' }),
  figma.loadFontAsync({ family:'Noto Sans',style:'Bold' }),
]);
function rgb(hex) { return {r:parseInt(hex.slice(1,3),16)/255,g:parseInt(hex.slice(3,5),16)/255,b:parseInt(hex.slice(5,7),16)/255}; }
function record(node) { createdNodeIds.push(node.id); return node; }
// Adapted from figma-generate-library/scripts/createVariableCollection.js.
function collection(name) { const c=figma.variables.createVariableCollection(name);c.renameMode(c.modes[0].modeId,'Royal');return c; }
const primitives=collection('Royal / Primitives');
const semantic=collection('Royal / Interface');
const values={background:'#071711',surface:'#101f1d',raised:'#182b26',border:'#8a6a31',gold:'#dfb961',goldLight:'#ffe1a0',text:'#f1ead6',muted:'#b8baa0',success:'#8fbd86',ink:'#302518',disabled:'#636458'};
const vars={};
for (const [key,hex] of Object.entries(values)) {
  const p=figma.variables.createVariable('palette/'+key,primitives,'COLOR');
  p.scopes=[];p.setValueForMode(primitives.modes[0].modeId,rgb(hex));
  p.setVariableCodeSyntax('WEB','var(--royal-'+key+')');
  const v=figma.variables.createVariable('color/'+key,semantic,'COLOR');
  v.scopes=['FRAME_FILL','SHAPE_FILL','TEXT_FILL','STROKE_COLOR'];
  v.setValueForMode(semantic.modes[0].modeId,{type:'VARIABLE_ALIAS',id:p.id});
  v.setVariableCodeSyntax('WEB','var(--royal-'+key+')');vars[key]=v;
}
for (const [key,value] of Object.entries({xs:4,sm:8,md:12,lg:16,xl:24})) {
  const v=figma.variables.createVariable('spacing/'+key,semantic,'FLOAT');v.scopes=['GAP'];
  v.setValueForMode(semantic.modes[0].modeId,value);v.setVariableCodeSyntax('WEB','var(--royal-space-'+key+')');vars[key]=v;
}
const radius=figma.variables.createVariable('radius/card',semantic,'FLOAT');
radius.scopes=['CORNER_RADIUS'];radius.setValueForMode(semantic.modes[0].modeId,8);radius.setVariableCodeSyntax('WEB','var(--royal-radius-card)');vars.radius=radius;
const styles={};
for (const [key,family,style,size] of [['display','Cinzel','Regular',27],['title','Cinzel','Regular',20],['navigation','Cinzel','Regular',14],['body','Noto Sans','Regular',16],['value','Noto Sans','Bold',20],['caption','Noto Sans','Regular',12]]) {
  const s=figma.createTextStyle();s.name='Royal / '+key;s.fontName={family,style};s.fontSize=size;s.lineHeight={unit:'PERCENT',value:130};styles[key]=s;
}
const shadow=figma.createEffectStyle();shadow.name='Royal / Elevation';
shadow.effects=[{type:'DROP_SHADOW',color:{r:0,g:0,b:0,a:0.35},offset:{x:0,y:4},radius:12,spread:0,visible:true,blendMode:'NORMAL'}];
function paint(key) { return figma.variables.setBoundVariableForPaint({type:'SOLID',color:rgb(values[key])},'color',vars[key]); }
function base64(value) {
  const abc='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';const out=[];let bits=0,buffer=0;
  for (const char of value) {const n=abc.indexOf(char);if(n<0)continue;buffer=(buffer<<6)|n;bits+=6;if(bits>=8){bits-=8;out.push((buffer>>bits)&255);}}
  return new Uint8Array(out);
}
const icons={};const hashes={};let ix=0;
for (const [key,bytes] of Object.entries(ASSET_BYTES)) {
  const img=figma.createImage(base64(bytes));hashes[key]=img.hash;
  const c=record(figma.createComponent());c.name='Artwork / '+key.replace('.png','');c.resize(52,52);
  c.fills=[{type:'IMAGE',imageHash:img.hash,scaleMode:'FIT'}];c.description='Preview of pinned project artwork. Source: client/assets/ui; no complete-interface screenshot.';
  c.x=100+(ix%10)*72;c.y=2100+Math.floor(ix/10)*72;icons[key]=c;ix++;
}
function label(parent,chars,style='body',color='text') {
  const t=record(figma.createText());t.fontName=styles[style].fontName;t.textStyleId=styles[style].id;t.characters=chars;t.fills=[paint(color)];parent.appendChild(t);return t;
}
function frame(c,fill='surface') {
  c.fills=[paint(fill)];c.strokes=[paint('border')];c.strokeWeight=1;
  c.setBoundVariable('topLeftRadius',radius);c.setBoundVariable('topRightRadius',radius);c.setBoundVariable('bottomLeftRadius',radius);c.setBoundVariable('bottomRightRadius',radius);
}
const components={};
// Variant construction follows createComponentWithVariants.js, with one page
// switch for the entire operation and all new nodes tracked in this ledger.
function variants(name,states,width,height,builder,y) {
  const list=[];
  for (const state of states) {const c=record(figma.createComponent());c.name='State='+state;c.resize(width,height);c.layoutMode='HORIZONTAL';c.primaryAxisSizingMode='FIXED';c.counterAxisSizingMode='FIXED';c.primaryAxisAlignItems='CENTER';c.counterAxisAlignItems='CENTER';c.setBoundVariable('itemSpacing',vars.sm);builder(c,state);list.push(c);}
  const set=record(figma.combineAsVariants(list,page));set.name=name;set.description='Native Godot counterpart in royal_ui.gd/main.gd. Token-bound, editable states.';
  list.forEach((c,i)=>{c.x=i*(width+16);c.y=0;});set.resize(states.length*(width+16)-16,height);set.x=100;set.y=y;components[name]={setId:set.id,variantIds:list.map(c=>c.id)};return set;
}
const nav=variants('RealmNavigation',['Idle','Active','Disabled'],116,74,(c,state)=>{
  frame(c,state==='Active'?'gold':'surface');c.layoutMode='VERTICAL';c.itemSpacing=4;
  const icon=record(icons['icons-5.png'].createInstance());c.appendChild(icon);icon.resize(40,40);icon.name='Icon';
  label(c,'Buildings','navigation',state==='Active'?'ink':(state==='Disabled'?'disabled':'goldLight'));
},2280);
const navLabel=nav.addComponentProperty('Label','TEXT','Buildings');const navIcon=nav.addComponentProperty('Icon','INSTANCE_SWAP',icons['icons-5.png'].id);
for (const c of nav.children) {c.findAllWithCriteria({types:['TEXT']})[0].componentPropertyReferences={characters:navLabel};c.findAllWithCriteria({types:['INSTANCE']})[0].componentPropertyReferences={mainComponent:navIcon};}
components.RealmNavigation.properties={label:navLabel,icon:navIcon};
const resource=record(figma.createComponent());resource.name='ResourceCounter';resource.resize(106,78);resource.layoutMode='HORIZONTAL';resource.primaryAxisSizingMode='FIXED';resource.counterAxisSizingMode='FIXED';resource.counterAxisAlignItems='CENTER';resource.itemSpacing=4;frame(resource);
resource.paddingLeft=8;resource.paddingRight=8;
const ri=record(icons['icons-0.png'].createInstance());ri.name='Icon';resource.appendChild(ri);ri.resize(38,42);
const rv=record(figma.createAutoLayout('VERTICAL'));rv.name='Values';rv.fills=[];rv.itemSpacing=2;resource.appendChild(rv);
const rl=label(rv,'Food','caption','muted');const ra=label(rv,'500','value');
const rp={label:resource.addComponentProperty('Label','TEXT','Food'),amount:resource.addComponentProperty('Amount','TEXT','500'),icon:resource.addComponentProperty('Icon','INSTANCE_SWAP',icons['icons-0.png'].id)};
rl.componentPropertyReferences={characters:rp.label};ra.componentPropertyReferences={characters:rp.amount};ri.componentPropertyReferences={mainComponent:rp.icon};resource.x=540;resource.y=2280;components.ResourceCounter={id:resource.id,properties:rp};
const action=variants('RoyalAction',['Primary','Secondary','Disabled'],218,48,(c,state)=>{frame(c,state==='Primary'?'gold':'raised');label(c,'Construct','navigation',state==='Primary'?'ink':(state==='Disabled'?'disabled':'goldLight'));},2410);
const ap=action.addComponentProperty('Label','TEXT','Construct');for(const c of action.children)c.findAllWithCriteria({types:['TEXT']})[0].componentPropertyReferences={characters:ap};components.RoyalAction.properties={label:ap};
const badge=record(figma.createComponent());badge.name='RealmBadge';badge.resize(94,28);badge.layoutMode='HORIZONTAL';badge.primaryAxisAlignItems='CENTER';badge.counterAxisAlignItems='CENTER';badge.primaryAxisSizingMode='FIXED';badge.counterAxisSizingMode='FIXED';frame(badge,'raised');const bt=label(badge,'VILLAGE','caption','goldLight');const bp=badge.addComponentProperty('Label','TEXT','VILLAGE');bt.componentPropertyReferences={characters:bp};badge.x=800;badge.y=2280;components.RealmBadge={id:badge.id,properties:{label:bp}};
return {createdNodeIds,mutatedNodeIds:[page.id],pageId:page.id,collections:[primitives.id,semantic.id],variables:Object.fromEntries(Object.entries(vars).map(([k,v])=>[k,{id:v.id,name:v.name,scopes:v.scopes}])),styles:Object.fromEntries(Object.entries(styles).map(([k,v])=>[k,v.id])),shadowStyleId:shadow.id,icons:Object.fromEntries(Object.entries(icons).map(([k,v])=>[k,v.id])),hashes,components,validation:{nodeCount:createdNodeIds.length,colors:Object.keys(values).length,spacing:5,navStates:3,actionStates:3,fontFamilies:['Cinzel','Noto Sans']}};
