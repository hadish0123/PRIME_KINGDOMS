const PREFIX=['Ashen','Iron','Rowan','Grey','Crown','Hearth','Amber','Oak','Silver','Raven','Stone','Briar'];
const SUFFIX=['Ford','March','Meadow','Hollow','Watch','Crossing','Vale','Ridge','Heath','Reach','Brook','Pass'];
export function territoryName(x,z) {
 const n=Math.abs(Math.imul(x,73856093)^Math.imul(z,19349663));
 return PREFIX[n%PREFIX.length]+' '+SUFFIX[Math.floor(n/PREFIX.length)%SUFFIX.length];
}
