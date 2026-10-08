extends RefCounted
## Royal Dawn: shared native skins, original vector glyphs and semantic colors.

const PORTRAIT = preload("res://assets/ui/dawn/brand-crest.svg")
const FRAME = preload("res://assets/ui/dawn/frame.svg")
const FINE = preload("res://assets/ui/dawn/fine.svg")
const GOLD = preload("res://assets/ui/dawn/gold.svg")
const BACKGROUND = Color("#f3eddf")
const SURFACE = Color("#fffaf0")
const RAISED = Color("#eee6d3")
const BORDER = Color("#bba675")
const GOLD_TEXT = Color("#876027")
const LIGHT_GOLD = Color("#6e542d")
const TEXT = Color("#243f35")
const MUTED = Color("#606957")
const SUCCESS = Color("#376b47")
const INK = Color("#343c2e")
const DISABLED = Color("#737766")
const DANGER = Color("#9f4a38")
const SAGE = Color("#9cb8a2")
const CHAMPAGNE = Color("#efd292")
const GLYPHS = {
 "food":preload("res://assets/ui/dawn/food.svg"),
 "wood":preload("res://assets/ui/dawn/wood.svg"),
 "stone":preload("res://assets/ui/dawn/stone.svg"),
 "iron":preload("res://assets/ui/dawn/iron.svg"),
 "gold":preload("res://assets/ui/dawn/gold-coin.svg"),
 "buildings":preload("res://assets/ui/dawn/buildings.svg"),
 "army":preload("res://assets/ui/dawn/army.svg"),
 "research":preload("res://assets/ui/dawn/research.svg"),
 "world":preload("res://assets/ui/dawn/world.svg"),
 "clan":preload("res://assets/ui/dawn/clan.svg"),
 "goals":preload("res://assets/ui/dawn/goals.svg"),
 "inbox":preload("res://assets/ui/dawn/inbox.svg"),
 "settings":preload("res://assets/ui/dawn/settings.svg"),
 "crown":preload("res://assets/ui/dawn/crown.svg"),
 "clock":preload("res://assets/ui/dawn/clock.svg"),
 "refresh":preload("res://assets/ui/dawn/refresh.svg"),
 "back":preload("res://assets/ui/dawn/back.svg"),
 "construct":preload("res://assets/ui/dawn/construct.svg"),
 "close":preload("res://assets/ui/dawn/close.svg"),
 "forward":preload("res://assets/ui/dawn/forward.svg"),
 "save":preload("res://assets/ui/dawn/save.svg"),
 "check":preload("res://assets/ui/dawn/check.svg"),
 "unchecked":preload("res://assets/ui/dawn/unchecked.svg"),
 "chevron":preload("res://assets/ui/dawn/chevron.svg"),
 "knob":preload("res://assets/ui/dawn/knob.svg"),
 "chat":preload("res://assets/ui/dawn/chat.svg"),
 "trade":preload("res://assets/ui/dawn/trade.svg"),
}
const ICON_NAMES = ["food","wood","stone","iron","gold","buildings","army","research","world","clan","goals","inbox","settings","crown","clock","refresh","back","crown","construct","close"]
static var building_plates: Dictionary = {}

static func frame(gold: bool = false,padding: float = 10.0,tint: Color = Color.WHITE,ornate: bool = false) -> StyleBoxTexture:
	var style = StyleBoxTexture.new()
	style.texture = GOLD if gold else (FRAME if ornate or padding>=13 else FINE)
	style.modulate_color = tint
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		style.set_texture_margin(side,16)
		style.set_content_margin(side,padding)
	return style

static func icon(index: int) -> Texture2D:
	return GLYPHS[ICON_NAMES[clampi(index,0,ICON_NAMES.size()-1)]]

static func action_icon(caption: String) -> Texture2D:
	var title = caption.to_lower()
	var sections = {"overview":"crown","queues":"clock","buildings":"buildings","army":"army","research":"research","empire":"crown","clan":"clan","map":"world","world":"world","reports":"research","commanders":"army","goals":"goals","inbox":"inbox","rankings":"goals","wars":"army","chat":"chat","settings":"settings"}
	if sections.has(title): return GLYPHS[sections[title]]
	for entry in [["return","back"],["sign out","back"],["refresh","refresh"],["reconnect","refresh"],["retry","refresh"],["save","save"],["research","research"],["train","army"],["march","army"],["attack","army"],["reinforce","army"],["army","army"],["battle","army"],["heal","check"],["claim","goals"],["goal","goals"],["clan","clan"],["join","clan"],["alliance","clan"],["donate","trade"],["send","inbox"],["message","inbox"],["mail","inbox"],["chat","chat"],["buy","trade"],["trade","trade"],["upgrade","construct"],["construct","construct"],["building","buildings"],["capital","buildings"],["survey","world"],["region","world"],["realm","crown"],["close","close"]]:
		if title.contains(entry[0]): return GLYPHS[entry[1]]
	return GLYPHS.forward

static func building(key: String) -> Texture2D:
	if not building_plates.has(key):
		var path = "res://assets/ui/dawn/building-%s.svg" % key
		building_plates[key] = load(path) if ResourceLoader.exists(path) else load("res://assets/ui/dawn/building-academy.svg")
	return building_plates[key]

static func flat(color: Color = RAISED,padding: float = 10.0,border: Color = BORDER) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: style.set_content_margin(side,padding)
	return style

static func focus_style() -> StyleBoxFlat:
	var style = flat(Color.TRANSPARENT,10,TEXT)
	style.draw_center = false
	style.set_border_width_all(2)
	return style

static func theme() -> Theme:
	var result = Theme.new()
	result.default_font_size = 16
	result.default_font = ThemeDB.fallback_font
	for type_name in ["Button","OptionButton","CheckButton","CheckBox","LineEdit","TextEdit","SpinBox","ColorPickerButton"]:
		for entry in [["normal",Color.WHITE],["hover",Color(0.96,1.0,0.96)],["pressed",Color(0.90,0.95,0.88)],["disabled",Color(0.94,0.94,0.91)],["read_only",Color(0.96,0.96,0.93)]]:
			result.set_stylebox(entry[0],type_name,frame(false,10,entry[1]))
		result.set_stylebox("focus",type_name,focus_style())
		for state in ["font_color","font_hover_color","font_focus_color","font_pressed_color"]: result.set_color(state,type_name,TEXT)
		result.set_color("font_disabled_color",type_name,DISABLED)
		result.set_color("font_uneditable_color",type_name,MUTED)
		result.set_color("font_readonly_color",type_name,MUTED)
		result.set_color("font_placeholder_color",type_name,MUTED)
		result.set_color("caret_color",type_name,TEXT)
		result.set_color("selection_color",type_name,Color(SAGE,0.5))
		result.set_constant("icon_max_width",type_name,24)
		result.set_constant("h_separation",type_name,8)
	result.set_color("font_color","Label",TEXT)
	result.set_color("font_color","RichTextLabel",TEXT)
	result.set_stylebox("panel","PopupMenu",frame(false,10))
	result.set_stylebox("hover","PopupMenu",flat(RAISED,8))
	for state in ["font_color","font_hover_color","font_accelerator_color"]: result.set_color(state,"PopupMenu",TEXT)
	result.set_color("font_disabled_color","PopupMenu",DISABLED)
	result.set_constant("v_separation","PopupMenu",12)
	result.set_icon("arrow","OptionButton",GLYPHS.chevron)
	for type_name in ["CheckButton","CheckBox"]:
		for state in ["checked","checked_disabled"]: result.set_icon(state,type_name,GLYPHS.check)
		for state in ["unchecked","unchecked_disabled"]: result.set_icon(state,type_name,GLYPHS.unchecked)
	result.set_stylebox("panel","PopupPanel",frame(false,16))
	for type_name in ["HSlider","VSlider"]:
		result.set_stylebox("slider",type_name,flat(RAISED,2))
		result.set_stylebox("grabber_area",type_name,flat(SAGE,2))
		result.set_stylebox("grabber_area_highlight",type_name,flat(SUCCESS,2))
		for state in ["grabber","grabber_highlight","grabber_disabled"]: result.set_icon(state,type_name,GLYPHS.knob)
	for type_name in ["VScrollBar","HScrollBar"]:
		result.set_stylebox("scroll",type_name,flat(RAISED,2))
		for state in ["grabber","grabber_highlight","grabber_pressed"]: result.set_stylebox(state,type_name,flat(BORDER,2))
	result.set_stylebox("background","ProgressBar",flat(RAISED,0))
	result.set_stylebox("fill","ProgressBar",flat(SAGE,0,SUCCESS))
	result.set_color("font_color","ProgressBar",TEXT)
	result.set_stylebox("normal","TooltipPanel",frame(false,10))
	result.set_color("font_color","TooltipLabel",TEXT)
	return result
