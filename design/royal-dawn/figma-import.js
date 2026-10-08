/* Royal Dawn native-layer importer. Run in the authorized Figma file context
 * after its MCP quota is available. This source has NOT been executed in Figma.
 * Inputs: tokens.json, exported layout JSON array and {res://path: SVG string}.
 * Optional worldImageHash must refer only to the HUD-free village-world.png.
 */
async function importRoyalDawn(tokens, layouts, svgSources, worldImageHash = null) {
  await figma.loadAllPagesAsync();
  const key = 'prime-royal-dawn-095';
  let page = figma.root.children.find(p => p.getPluginData('milestone') === key);
  if (!page) {
    page = figma.createPage(); page.name = 'Royal Dawn · 0.9.5';
    page.setPluginData('milestone', key);
  }
  await figma.setCurrentPageAsync(page);
  const fonts = await figma.listAvailableFontsAsync();
  function face(family) {
    return fonts.find(f => f.fontName.family === family && f.fontName.style === 'Regular')?.fontName
      ?? fonts.find(f => f.fontName.family === 'Inter' && f.fontName.style === 'Regular')?.fontName;
  }
  const bodyFace = face('Noto Sans'), titleFace = face('Cinzel');
  if (!bodyFace || !titleFace) throw new Error('A regular text face is required');
  await Promise.all([figma.loadFontAsync(bodyFace), figma.loadFontAsync(titleFace)]);
  const color = hex => ({r:parseInt(hex.slice(1,3),16)/255,g:parseInt(hex.slice(3,5),16)/255,b:parseInt(hex.slice(5,7),16)/255});
  const collections = await figma.variables.getLocalVariableCollectionsAsync();
  let collection = collections.find(c => c.name === 'Royal Dawn / Colors');
  if (!collection) collection = figma.variables.createVariableCollection('Royal Dawn / Colors');
  const mode = collection.defaultModeId;
  const variables = await figma.variables.getLocalVariablesAsync('COLOR');
  const vars = {};
  for (const [name, hex] of Object.entries(tokens.palette)) {
    const variable = variables.find(v => v.variableCollectionId === collection.id && v.name === name)
      ?? figma.variables.createVariable(name, collection, 'COLOR');
    variable.setValueForMode(mode,color(hex)); vars[name] = variable;
  }
  function paint(hex) {
    let fill = {type:'SOLID',color:color(hex)};
    const name = Object.keys(tokens.palette).find(k => tokens.palette[k].toLowerCase() === hex.toLowerCase());
    if (name) fill = figma.variables.setBoundVariableForPaint(fill,'color',vars[name]);
    return [fill];
  }
  function label(text, size, hex, display = false) {
    const node = figma.createText(); node.fontName = display ? titleFace : bodyFace;
    node.fontSize = size; node.characters = text; node.fills = paint(hex);
    return node;
  }
  let library = page.findOne(n => n.getPluginData('dawnLibrary') === key);
  if (!library) {
    library = figma.createFrame(); page.appendChild(library); library.name = 'Royal Dawn / Components';
    library.setPluginData('dawnLibrary',key); library.y = 4500;
    library.resize(1600,1500); library.fills = paint(tokens.palette.surface);
  }
  const icons = {};
  let at = 0;
  for (const [path, source] of Object.entries(svgSources)) {
    let component = library.findOne(n => n.type === 'COMPONENT' && n.getPluginData('artSource') === path);
    if (!component) {
      component = figma.createComponent(); library.appendChild(component);
      component.name = path.split('/').pop().replace('.svg',''); component.setPluginData('artSource',path);
      component.resize(64,64); component.fills = [];
      const art = figma.createNodeFromSvg(source); component.appendChild(art); art.resize(64,64);
    }
    component.x = (at%18)*82+30; component.y = Math.floor(at/18)*90+300;
    icons[path] = component; at++;
  }
  let family = library.findOne(n => n.type === 'COMPONENT_SET' && n.getPluginData('dawnButton') === key);
  if (!family) {
    const variants = [];
    for (const [i,state] of ['Default','Hover','Pressed','Disabled','Focus','Primary'].entries()) {
      const c = figma.createComponent(); library.appendChild(c); c.name = 'State='+state;
      c.x=30+i*250;c.y=60;c.resize(224,46);c.cornerRadius=10;c.strokes=paint(tokens.palette.border);c.strokeWeight=1;
      c.fills=paint(state==='Primary'?tokens.palette.champagne:state==='Hover'?tokens.palette.raised:tokens.palette.surface);
      c.layoutMode='HORIZONTAL';c.primaryAxisSizingMode='FIXED';c.counterAxisSizingMode='FIXED';
      c.primaryAxisAlignItems='CENTER';c.counterAxisAlignItems='CENTER';
      c.paddingLeft=12;c.paddingRight=12;c.paddingTop=8;c.paddingBottom=8;c.itemSpacing=9;
      const ico=icons['res://assets/ui/dawn/forward.svg'].createInstance();c.appendChild(ico);ico.name='Action icon';ico.resize(22,22);
      const copy=label('Royal action',16,state==='Disabled'?tokens.palette.disabled:tokens.palette.text,true);c.appendChild(copy);copy.name='Label';
      if(state==='Focus'){c.strokeWeight=2;c.strokes=paint(tokens.palette.text);}
      variants.push(c);
    }
    family=figma.combineAsVariants(variants,library);family.name='Royal Action';family.setPluginData('dawnButton',key);
  }
  const made = [];
  for (const [screenIndex,data] of layouts.entries()) {
    let screen = page.findOne(n => n.type==='FRAME' && n.getPluginData('dawnScreen') === data.name);
    if (!screen) {screen=figma.createFrame();page.appendChild(screen);screen.setPluginData('dawnScreen',data.name);}
    // Retry modifies only this milestone's screen; unrelated Figma content survives.
    for(const child of [...screen.children])child.remove();
    screen.name = 'PRIME KINGDOMS / '+data.name;screen.resize(1280,720);
    screen.x=(screenIndex%4)*1360;screen.y=Math.floor(screenIndex/4)*800;screen.fills=paint(tokens.palette.background);
    if(worldImageHash && data.name!=='login'){
      const world=figma.createRectangle();screen.appendChild(world);world.name='3D world artwork · no interface';
      world.resize(1280,720);world.fills=[{type:'IMAGE',imageHash:worldImageHash,scaleMode:'FILL'}];
    }
    for(const record of data.nodes){
      if(record.role==='group')continue;
      const [x,y,w,h]=record.bounds;
      if(w<=0 || h<=0)continue;
      let node;
      if(record.role==='button' && record.text){
        const state=record.disabled?'Disabled':record.skin?.endsWith('/gold.svg')?'Primary':'Default';
        node=family.children.find(c=>c.name==='State='+state).createInstance();node.resize(w,h);
        const copy=node.findOne(c=>c.type==='TEXT');copy.characters=record.text;copy.fontSize=record.fontSize;
        const ico=node.findOne(c=>c.type==='INSTANCE');if(icons[record.icon])ico.swapComponent(icons[record.icon]);else ico.visible=false;
      }else if(record.role==='art'){
        if(record.source.includes('/heraldry/') && svgSources[record.source]){
          const art=svgSources[record.source].replaceAll('#ffffff',record.tint).replaceAll('white',record.tint);
          node=figma.createNodeFromSvg(art);node.resize(w,h);
        }else{
          if(!icons[record.source])continue;node=icons[record.source].createInstance();node.resize(w,h);
        }
      }else if(record.role==='text'){
        node=label(record.text,record.fontSize,record.color,record.font?.includes('Cinzel'));
        node.textAutoResize='HEIGHT';node.resize(w,Math.max(h,1));
        if(record.align===1)node.textAlignHorizontal='CENTER';
      }else{
        node=figma.createFrame();node.resize(w,h);node.cornerRadius=record.role==='clan_region'?0:10;
        node.fills=paint(record.color ?? (record.skin?.endsWith('/gold.svg')?tokens.palette.champagne:tokens.palette.surface));
        node.strokes=paint(record.border ?? tokens.palette.border);node.strokeWeight=1;
        if(record.role==='field'){
          const copy=label(record.text,record.fontSize,tokens.palette.text);node.appendChild(copy);copy.x=10;copy.y=8;
        }else if(record.role==='progress' || record.role==='slider'){
          node.fills=paint(tokens.palette.raised);
          const bar=figma.createRectangle();node.appendChild(bar);bar.resize(Math.max(1,w*record.progress),h);bar.fills=paint(tokens.palette.sage);
        }else if(record.role==='clan_region'){
          const edge=Math.min(w-32,h-32),cell=edge/8,ox=(w-edge)/2,oy=(h-edge)/2;
          for(let plot=0;plot<64;plot++){
            const tile=figma.createRectangle();node.appendChild(tile);tile.x=ox+(plot%8)*cell;tile.y=oy+Math.floor(plot/8)*cell;
            tile.resize(cell,cell);tile.fills=paint('#dce3c7');tile.strokes=paint('#b4bf9f');tile.strokeWeight=1;
          }
          for(const member of record.group.members){
            const icon=icons['res://assets/ui/dawn/buildings.svg'].createInstance();node.appendChild(icon);
            icon.x=ox+(member.plot%8)*cell+4;icon.y=oy+Math.floor(member.plot/8)*cell+3;icon.resize(cell-8,cell-6);icon.name=member.displayName;
          }
          const border=figma.createRectangle();node.appendChild(border);border.x=ox-3;border.y=oy-3;
          border.resize(edge+6,edge+6);border.fills=[];border.strokes=paint(record.group.secondaryColor);border.strokeWeight=4;
        }
      }
      const [cx,cy,cw,ch]=record.clip;
      const crop=figma.createFrame();screen.appendChild(crop);crop.name=record.name+' · '+record.role;crop.resize(cw,ch);
      crop.x=cx;crop.y=cy;crop.fills=[];crop.clipsContent=true;crop.appendChild(node);node.x=x-cx;node.y=y-cy;
    }
    made.push({name:data.name,id:screen.id});
  }
  return {pageId:page.id,libraryId:library.id,screens:made,fonts:{body:bodyFace,title:titleFace},editable:true};
}
