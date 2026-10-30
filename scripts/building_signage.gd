extends RefCounted
## Recognisable painted shop emblems, reusing the game's filtered illustrations.
const Icons = preload("res://scripts/hud_icons.gd")
const Activity = preload("res://scripts/activity_indicator.gd")
const SYMBOLS = {"residence":"home","cafe":"coffee","garden":"vegetables","workshop":"tools","clinic":"medkit","bakery":"bread","waterworks":"water","tailor":"cloth"}
static var _textures: Dictionary = {}
static var _styles: Dictionary = {}

static func texture(kind: String) -> Texture2D:
	var key: String = str(SYMBOLS.get(kind,"home"))
	if _textures.has(key): return _textures[key]
	var source: Texture2D = Icons.texture(key) if key in ["home","coffee"] else load("res://assets/art/products/%s.png" % key)
	var pixels: Image = source.get_image()
	if pixels.is_compressed(): pixels.decompress()
	pixels = pixels.get_region(pixels.get_used_rect())
	# A small dedicated texture avoids downsampling a large product PNG every
	# frame, even on canvas renderers whose default filter does not use mipmaps.
	var longest: int = maxi(pixels.get_width(),pixels.get_height())
	if longest>128:
		var ratio: float = 128.0/longest
		pixels.resize(maxi(1,roundi(pixels.get_width()*ratio)),maxi(1,roundi(pixels.get_height()*ratio)),Image.INTERPOLATE_LANCZOS)
	pixels.generate_mipmaps()
	_textures[key] = ImageTexture.create_from_image(pixels)
	return _textures[key]

static func bounds(scene: Control, id: int) -> Rect2:
	var building: Rect2 = scene._building_rect(id)
	var diameter: float = clampf(64.0*scene._building_zoom(),44.0,96.0)
	var center: Vector2 = Vector2(building.get_center().x,building.position.y+5.0*scene._building_zoom()-8.0)
	var rect: Rect2 = Rect2(center-Vector2.ONE*diameter*0.5,Vector2.ONE*diameter)
	var header: float = DeviceLayout.PHONE_HEADER_HEIGHT if DeviceLayout.mobile else 116.0
	rect.position.y = maxf(rect.position.y,(DeviceLayout.safe_rect().position.y+header)*DeviceLayout.ui_scale()+8.0)
	if is_instance_valid(scene.ui):
		# Keep signs visible below contextual shortcuts and beside zoom buttons.
		# Use each button's real canvas bounds, including the phone UI scale.
		rect = _avoid_buttons(rect,building,scene.ui._town_context,false)
		rect = _avoid_buttons(rect,building,scene.ui._camera_controls,true)
		rect = _avoid_buttons(rect,building,scene.ui._pan_controls,true)
	return rect

static func _avoid_buttons(rect: Rect2, building: Rect2, group: Control, prefer_side: bool) -> Rect2:
	if not is_instance_valid(group) or not group.visible: return rect
	for child: Node in group.get_children():
		if not child is Button or not child.visible: continue
		var blocker: Rect2 = child.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,child.size)
		if not rect.grow(5.0).intersects(blocker): continue
		var beside: float = blocker.position.x-rect.size.x-8.0
		if prefer_side and beside>=building.position.x+4.0:
			rect.position.x = beside
		else:
			rect.position.y = blocker.end.y+8.0
	return rect

static func draw_sign(scene: Control, building: Dictionary) -> void:
	var rect: Rect2 = bounds(scene,int(building.id))
	var state: String = "hover" if scene.hover=="building:%d" % int(building.id) else "construction" if Game.is_under_construction(building) else "normal"
	if not _styles.has(state):
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color("fff1d4") if state=="hover" else Color("f2e7ce")
		style.border_color = Color("dba54c") if state!="normal" else Color("826741")
		style.set_border_width_all(3)
		style.set_corner_radius_all(48)
		style.shadow_color = Color(0.10,0.14,0.12,0.40)
		style.shadow_size = 3
		style.shadow_offset = Vector2(0,4)
		_styles[state] = style
	scene.draw_style_box(_styles[state],rect)
	var art: Texture2D = texture(str(building.type))
	var content: Rect2 = rect.grow(-rect.size.x*0.14)
	var factor: float = minf(content.size.x/art.get_width(),content.size.y/art.get_height())
	var dimensions: Vector2 = art.get_size()*factor
	scene.draw_texture_rect(art,Rect2(content.get_center()-dimensions*0.5,dimensions),false)
	var tasks: Array[Dictionary] = Activity.preparations(scene.get_node("/root/Game"),building)
	Activity.draw_ring(scene,rect,tasks)
	Activity.draw_preparation_badge(scene,rect,tasks)
