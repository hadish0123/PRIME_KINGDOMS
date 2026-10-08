/* Royal Dawn native-layer importer. Run in the authorized Figma file context
 * after its MCP quota is available. This source has NOT been executed in Figma.
 * Inputs: tokens.json, exported layout JSON array and {res://path: SVG string}.
 * Optional worldImageHash must refer only to the HUD-free village-world.png.
 * Save the returned ledger in a local JSON file and pass it on the next call.
 * Existing screens are reused without deletion; visual reconciliation is a
 * separate, inspected update after the initial import succeeds.
 */
async function importRoyalDawn(tokens, layouts, svgSources, worldImageHash = null, ledger = {}) {
  // Keep the returned ledger outside Figma. The MCP API does not implement
  // loadAllPagesAsync or setPluginData; switch the single target page once.
  const createdNodeIds = new Set(), mutatedNodeIds = new Set();
  const createdVariableIds = [], mutatedVariableIds = [], reusedScreens = [];
  function track(node) {
    createdNodeIds.add(node.id);
    if ('children' in node) for (const child of node.children) track(child);
    return node;
  }
  const roles = new Set(['group','panel','button','art','text','field','progress','slider','clan_region']);
  for(const path of ['forward','knob','buildings'].map(name=>'res://assets/ui/dawn/'+name+'.svg')){
    if(!svgSources[path])throw new Error('Missing library SVG: '+path);
  }
  const screenNames = new Set();
  for (const data of layouts) {
    if (screenNames.has(data.name)) throw new Error('Duplicate screen: '+data.name);
    screenNames.add(data.name);
    if (data.viewport.width !== 1280 || data.viewport.height !== 720) throw new Error('Unsupported viewport: '+data.name);
    for (const record of data.nodes) {
      if (!roles.has(record.role)) throw new Error('Unsupported layer role: '+record.role);
      if (![...record.bounds,...record.clip].every(Number.isFinite)) throw new Error('Invalid native bounds: '+record.name);
      for (const path of [record.source,record.icon].filter(Boolean)) {
        if (!svgSources[path]) throw new Error('Missing editable SVG: '+path);
      }
    }
  }
  const fonts = await figma.listAvailableFontsAsync();
  function face(family) {
    return fonts.find(f => f.fontName.family === family && f.fontName.style === 'Regular')?.fontName;
  }
  const bodyFace = face('Noto Sans'), titleFace = face('Cinzel');
  if (!bodyFace || !titleFace) throw new Error('Cinzel Regular and Noto Sans Regular must be available; do not silently substitute the product fonts');
  await Promise.all([figma.loadFontAsync(bodyFace), figma.loadFontAsync(titleFace)]);
  const pageName = 'Royal Dawn · 0.9.5';
  let page = ledger.pageId ? await figma.getNodeByIdAsync(ledger.pageId) : figma.root.children.find(p => p.name === pageName);
  if (page && (page.type !== 'PAGE' || page.name !== pageName)) throw new Error('Unexpected page ledger identity');
  if (!page) { page = track(figma.createPage()); page.name = pageName; }
  await figma.setCurrentPageAsync(page);
  // Existing text must be loaded before reparenting or modifying a subtree.
  const currentFonts = page.findAllWithCriteria({types:['TEXT']}).flatMap(n => n.getStyledTextSegments(['fontName']).map(s => s.fontName));
  await Promise.all([...new Map(currentFonts.map(f => [JSON.stringify(f),f])).values()].map(f => figma.loadFontAsync(f)));
  mutatedNodeIds.add(page.id);
  const color = hex => ({r:parseInt(hex.slice(1,3),16)/255,g:parseInt(hex.slice(3,5),16)/255,b:parseInt(hex.slice(5,7),16)/255});
  const collections = await figma.variables.getLocalVariableCollectionsAsync();
  let collection = collections.find(c => c.name === 'Royal Dawn / Colors');
  if (!collection) collection = figma.variables.createVariableCollection('Royal Dawn / Colors');
  const mode = collection.defaultModeId;
  collection.renameMode(mode,'Light');
  const variables = await figma.variables.getLocalVariablesAsync('COLOR');
  const vars = {};
  for (const [name, hex] of Object.entries(tokens.palette)) {
    const existing = variables.find(v => v.variableCollectionId === collection.id && v.name === name);
    const variable = existing ?? figma.variables.createVariable(name, collection, 'COLOR');
    (existing ? mutatedVariableIds : createdVariableIds).push(variable.id);
    variable.scopes = name === 'border' ? ['STROKE_COLOR'] :
      ['text','muted','disabled','ink'].includes(name) ? ['TEXT_FILL'] :
      ['FRAME_FILL','SHAPE_FILL','TEXT_FILL','STROKE_COLOR'];
    const nativeName = {gold:'GOLD_TEXT',goldLight:'LIGHT_GOLD'}[name] ?? name.toUpperCase();
    variable.setVariableCodeSyntax('ANDROID','RoyalUI.'+nativeName);
    variable.setValueForMode(mode,color(hex)); vars[name] = variable;
  }
  function paint(hex) {
    let fill = {type:'SOLID',color:color(hex)};
    const name = Object.keys(tokens.palette).find(k => tokens.palette[k].toLowerCase() === hex.toLowerCase());
    if (name) fill = figma.variables.setBoundVariableForPaint(fill,'color',vars[name]);
    return [fill];
  }
  function label(text, size, hex, display = false) {
    const node = track(figma.createText()); node.fontName = display ? titleFace : bodyFace;
    node.fontSize = size; node.characters = text; node.fills = paint(hex);
    return node;
  }
  let library = page.children.find(n => n.type === 'FRAME' && n.name === 'Royal Dawn / Components');
  if (!library) {
    const right = Math.max(0,...page.children.map(n => n.x+n.width));
    library = track(figma.createFrame()); page.appendChild(library); library.name = 'Royal Dawn / Components';
    library.x = right+80; library.y = 4500;
    library.resize(1600,1500); library.fills = paint(tokens.palette.surface);
  }
  mutatedNodeIds.add(library.id);
  const icons = {};
  let at = 0;
  for (const [path, source] of Object.entries(svgSources)) {
    const name = 'Artwork / '+path;
    let component = library.children.find(n => n.type === 'COMPONENT' && n.name === name);
    if (!component) {
      component = track(figma.createComponent()); library.appendChild(component);
      component.name = name; component.description = 'Editable original SVG artwork from '+path;
      component.resize(64,64); component.fills = [];
      const art = track(figma.createNodeFromSvg(source)); component.appendChild(art); art.resize(64,64);art.x=0;art.y=0;
    }
    mutatedNodeIds.add(component.id);
    component.x = (at%18)*82+30; component.y = Math.floor(at/18)*90+300;
    icons[path] = component; at++;
  }
  let family = library.children.find(n => n.type === 'COMPONENT_SET' && n.name === 'Royal Action');
  if (!family) {
    const variants = [];
    for (const [i,state] of ['Default','Hover','Pressed','Disabled','Focus','Primary'].entries()) {
      const row = track(figma.createAutoLayout('HORIZONTAL')); library.appendChild(row);
      const c = track(figma.createComponentFromNode(row)); c.name = 'State='+state;
      c.x=30+i*250;c.y=60;c.resize(224,46);c.cornerRadius=10;c.strokes=paint(tokens.palette.border);c.strokeWeight=1;
      c.fills=paint(state==='Primary'?tokens.palette.champagne:['Hover','Pressed'].includes(state)?tokens.palette.raised:tokens.palette.surface);
      c.primaryAxisSizingMode='FIXED';c.counterAxisSizingMode='FIXED';
      c.primaryAxisAlignItems='CENTER';c.counterAxisAlignItems='CENTER';
      c.paddingLeft=12;c.paddingRight=12;c.paddingTop=8;c.paddingBottom=8;c.itemSpacing=9;
      const ico=track(icons['res://assets/ui/dawn/forward.svg'].createInstance());c.appendChild(ico);ico.name='Action icon';ico.resize(22,22);
      if(state==='Disabled')ico.opacity=0.5;
      const copy=label('Royal action',16,state==='Disabled'?tokens.palette.disabled:tokens.palette.text,true);c.appendChild(copy);copy.name='Label';
      if(state==='Focus'){c.strokeWeight=2;c.strokes=paint(tokens.palette.text);}
      variants.push(c);
    }
    family=track(figma.combineAsVariants(variants,library));family.name='Royal Action';
    family.description='Royal Dawn native action states; editable icon and Cinzel label.';
    family.x=30;family.y=30;
    for(const [i,c] of variants.entries()){c.x=i*250;c.y=0;}
    family.resizeWithoutConstraints(6*250,46);
  }
  const made = [];
  for (const data of layouts) {
    const name='PRIME KINGDOMS / '+data.name;
    const existing=page.children.find(n => n.type==='FRAME' && n.name===name);
    if(existing){made.push({name:data.name,id:existing.id});reusedScreens.push(data.name);continue;}
    const screen=track(figma.createFrame());page.appendChild(screen);
    screen.name = name;screen.resize(1280,720);
    const at=page.children.filter(n => n.type==='FRAME' && n.name.startsWith('PRIME KINGDOMS / ')).length-1;
    const origin=ledger.screenOrigin ?? {x:library.x,y:0};
    screen.x=origin.x+(at%4)*1360;screen.y=origin.y+Math.floor(at/4)*800;screen.fills=paint(tokens.palette.background);
    if(worldImageHash && data.name!=='login'){
      const world=track(figma.createRectangle());screen.appendChild(world);world.name='3D world artwork · no interface';
      world.resize(1280,720);world.fills=[{type:'IMAGE',imageHash:worldImageHash,scaleMode:'FILL'}];
    }
    for(const record of data.nodes){
      if(record.role==='group')continue;
      const [x,y,w,h]=record.bounds;
      if(w<=0 || h<=0)continue;
      let node;
      if(record.role==='button' && record.text){
        const state=record.disabled?'Disabled':record.skin?.endsWith('/gold.svg')?'Primary':'Default';
        node=track(family.children.find(c=>c.name==='State='+state).createInstance());node.resize(w,h);
        const copy=node.findOne(c=>c.type==='TEXT');copy.characters=record.text;copy.fontSize=record.fontSize;
        copy.fills=paint(record.colorText);
        const ico=node.findOne(c=>c.type==='INSTANCE');if(icons[record.icon]){ico.swapComponent(icons[record.icon]);track(ico);}else ico.visible=false;
      }else if(record.role==='art'){
        if(record.source.includes('/heraldry/') && svgSources[record.source]){
          const art=svgSources[record.source].replace(/#ffffff\b|#fff\b|\bwhite\b/gi,record.tint);
          node=track(figma.createNodeFromSvg(art));node.resize(w,h);
        }else{
          node=track(icons[record.source].createInstance());node.resize(w,h);
        }
      }else if(record.role==='text'){
        node=label(record.text,record.fontSize,record.color,record.font?.includes('Cinzel'));
        node.textAutoResize='HEIGHT';node.resize(w,Math.max(h,1));
        if(record.align===1)node.textAlignHorizontal='CENTER';
      }else{
        node=track(record.role==='field'?figma.createAutoLayout('HORIZONTAL'):figma.createFrame());node.resize(w,h);node.cornerRadius=record.role==='clan_region'?0:10;
        node.fills=paint(record.color ?? (record.skin?.endsWith('/gold.svg')?tokens.palette.champagne:tokens.palette.surface));
        node.strokes=paint(record.border ?? tokens.palette.border);node.strokeWeight=1;
        if(record.role==='field'){
          node.paddingLeft=10;node.paddingRight=10;node.paddingTop=8;node.paddingBottom=8;
          node.primaryAxisSizingMode='FIXED';node.counterAxisSizingMode='FIXED';node.counterAxisAlignItems='CENTER';
          const copy=label(record.text,record.fontSize,tokens.palette.text);node.appendChild(copy);copy.textAutoResize='HEIGHT';copy.resize(Math.max(1,w-20),Math.max(1,h-16));
        }else if(record.role==='progress' || record.role==='slider'){
          node.fills=paint(tokens.palette.raised);
          const bar=track(figma.createRectangle());node.appendChild(bar);bar.resize(Math.max(1,w*record.progress),record.role==='slider'?6:h);bar.fills=paint(tokens.palette.sage);
          if(record.role==='slider'){
            node.fills=[];node.strokes=[];bar.y=h/2-3;
            const rail=track(figma.createRectangle());node.insertChild(0,rail);rail.resize(w,6);rail.y=h/2-3;rail.fills=paint(tokens.palette.raised);
            const knob=track(icons['res://assets/ui/dawn/knob.svg'].createInstance());node.appendChild(knob);knob.resize(18,18);knob.x=Math.max(0,Math.min(w-18,w*record.progress-9));knob.y=h/2-9;
          }
        }else if(record.role==='clan_region'){
          const edge=Math.min(w-32,h-32),cell=edge/8,ox=(w-edge)/2,oy=(h-edge)/2;
          for(let plot=0;plot<64;plot++){
            const tile=track(figma.createRectangle());node.appendChild(tile);tile.x=ox+(plot%8)*cell;tile.y=oy+Math.floor(plot/8)*cell;
            tile.resize(cell,cell);tile.fills=paint('#dce3c7');tile.strokes=paint('#b4bf9f');tile.strokeWeight=1;
          }
          for(const member of record.group.members){
            const icon=track(icons['res://assets/ui/dawn/buildings.svg'].createInstance());node.appendChild(icon);
            icon.x=ox+(member.plot%8)*cell+4;icon.y=oy+Math.floor(member.plot/8)*cell+3;icon.resize(cell-8,cell-6);icon.name=member.displayName;
          }
          const border=track(figma.createRectangle());node.appendChild(border);border.x=ox-3;border.y=oy-3;
          border.resize(edge+6,edge+6);border.fills=[];border.strokes=paint(record.group.secondaryColor);border.strokeWeight=4;
        }
      }
      const [cx,cy,cw,ch]=record.clip;
      const crop=track(figma.createFrame());screen.appendChild(crop);crop.name=record.name+' · '+record.role;crop.resize(cw,ch);
      crop.x=cx;crop.y=cy;crop.fills=[];crop.clipsContent=true;crop.appendChild(node);node.x=x-cx;node.y=y-cy;
      track(node);
    }
    made.push({name:data.name,id:screen.id});
  }
  return {pageId:page.id,libraryId:library.id,screenOrigin:ledger.screenOrigin ?? {x:library.x,y:0},
    screens:made,reusedScreens,artworkIds:Object.fromEntries(Object.entries(icons).map(([path,c])=>[path,c.id])),
    buttonSetId:family.id,collectionId:collection.id,variableIds:Object.fromEntries(Object.entries(vars).map(([name,v])=>[name,v.id])),
    createdNodeIds:[...createdNodeIds],mutatedNodeIds:[...mutatedNodeIds].filter(id=>!createdNodeIds.has(id)),
    createdVariableIds,mutatedVariableIds,fonts:{body:bodyFace,title:titleFace},
    pendingValidations:['editable-layer inspection','Figma screenshots','native design-to-code comparison']};
}
