// __ASSET_BYTES__ is replaced with a small batch of sprite previews.
const ASSET_BYTES = __ASSET_BYTES__;
const page = await figma.getNodeByIdAsync('0:1');
await figma.setCurrentPageAsync(page);
const createdNodeIds=[];const icons={};const hashes={};
function base64(value) {const abc='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';const out=[];let bits=0,buffer=0;for(const char of value){const n=abc.indexOf(char);if(n<0)continue;buffer=(buffer<<6)|n;bits+=6;if(bits>=8){bits-=8;out.push((buffer>>bits)&255);}}return new Uint8Array(out);}
let index=page.findAllWithCriteria({types:['COMPONENT']}).filter(n=>n.name.startsWith('Artwork / ')).length;
for(const [key,bytes] of Object.entries(ASSET_BYTES)) {
  const name='Artwork / '+key.replace('.png','');
  const existing=page.findAllWithCriteria({types:['COMPONENT']}).find(n=>n.name===name);
  if(existing){icons[key]=existing.id;hashes[key]=existing.fills.find(f=>f.type==='IMAGE').imageHash;continue;}
  const img=figma.createImage(base64(bytes));const c=figma.createComponent();
  c.name=name;c.resize(52,52);c.fills=[{type:'IMAGE',imageHash:img.hash,scaleMode:'FIT'}];
  c.description='Preview of the pinned original project artwork. Source: client/assets/ui.';
  c.x=100+(index%10)*72;c.y=2100+Math.floor(index/10)*72;index++;
  createdNodeIds.push(c.id);icons[key]=c.id;hashes[key]=img.hash;
}
return {createdNodeIds,icons,hashes};
