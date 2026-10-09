extends RefCounted

const ICONS = preload("res://assets/ui/royal-icons.png")
const BUILDINGS = preload("res://assets/ui/royal-buildings.png")
const PORTRAIT = preload("res://assets/ui/royal-ruler.png")
const FRAME = preload("res://assets/ui/royal-frame.svg")
const FINE = preload("res://assets/ui/royal-fine.svg")
const GOLD = preload("res://assets/ui/royal-gold.svg")
const TOOLS = preload("res://assets/ui/royal-tools.svg")
const BUILDING_CELLS = {
 "academy":0,"keep":1,"farm":2,"lumber_mill":3,"quarry":4,"iron_mine":5,
 "market":6,"trading_post":6,"warehouse":7,"granary":7,"barracks":8,
 "training_grounds":8,"archery_range":9,"stable":10,"siege_workshop":11,
 "hospital":12,"blacksmith":13,"workshop":13,"embassy":14,"clan_hall":14,
 "commander_hall":15,"walls":1,"watch_towers":1,"gatehouse":1,
}

static func frame(gold: bool = false,padding: float = 10.0,tint: Color = Color.WHITE,ornate: bool = false) -> StyleBoxTexture:
	var style = StyleBoxTexture.new()
	style.texture = GOLD if gold else (FRAME if ornate or padding>=13 else FINE)
	style.modulate_color = tint
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		style.set_texture_margin(side,12 if gold else (18 if ornate or padding>=13 else 10))
		style.set_content_margin(side,padding)
	return style

static func cell(atlas: Texture2D,index: int) -> AtlasTexture:
	var texture = AtlasTexture.new()
	texture.atlas = atlas
	var extent = Vector2(atlas.get_size())/4.0
	texture.region = Rect2(Vector2(index%4,index/4)*extent+Vector2(2,2),extent-Vector2(4,4))
	texture.filter_clip = true
	return texture

static func icon(index: int) -> Texture2D:
	if index in [16,18,19]:
		var texture = AtlasTexture.new()
		texture.atlas = TOOLS
		texture.region = Rect2((1 if index==16 else (0 if index==18 else 2))*64,0,64,64)
		return texture
	# Preserve clock, refresh, back and crown semantics from the previous atlas.
	var mapped = 15 if index==14 else (14 if index==15 else (13 if index==17 else index))
	return cell(ICONS,clampi(mapped,0,15))

static func building(key: String) -> Texture2D:
	return cell(BUILDINGS,int(BUILDING_CELLS.get(key,0)))
