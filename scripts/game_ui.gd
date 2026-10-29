extends CanvasLayer

const CozyPanel = preload("res://scripts/cozy_panel.gd")
const CozyRules = preload("res://scripts/cozy_rules.gd")
const Chrome = preload("res://scripts/ui_chrome.gd")
const MobileHUD = preload("res://scripts/mobile_hud.gd")
const Typography = preload("res://scripts/typography.gd")
const ActorVisuals = preload("res://scripts/actor_visuals.gd")
const HUDIcons = preload("res://scripts/hud_icons.gd")
const ResourceUI = preload("res://scripts/resource_ui.gd")
const Workforce = preload("res://scripts/workforce_panel.gd")
const WeaponIcon = preload("res://scripts/weapon_icon.gd")
const ProductIcons = preload("res://scripts/product_icons.gd")
const ExpeditionPanel = preload("res://scripts/expedition_panel.gd")
const ArmoryPanel = preload("res://scripts/armory_panel.gd")
const PhonePages = preload("res://scripts/phone_pages.gd")
const BuildPanel = preload("res://scripts/build_panel.gd")
const ConstructionPanel = preload("res://scripts/construction_panel.gd")
const CitizenEquipmentPanel = preload("res://scripts/citizen_equipment_panel.gd")
const DemolitionPanel = preload("res://scripts/demolition_panel.gd")
const SurvivorCatalog = preload("res://scripts/survivor_catalog.gd")
const PURCHASE_PANELS = ["build","building","citizens","citizen_equipment","gate","armory","weapon_details","expeditions"]

signal focus_gate
signal focus_defense
signal focus_city
signal sound_toggled(enabled: bool)
signal panel_changed(opened: bool)
signal zoom_requested(direction: int)
signal camera_pan(direction: int)
signal game_started
signal main_menu_opened

const INK = Color("263f36")
const PANEL = Color("f8f4e9")
const CARD = Color("fffdf4")
const BORDER = Color("d9d8c6")
const TEXT = Color("30483c")
const MUTED = Color("72816e")
const GOLD = Color("a46d33")
const SAGE = Color("4b7c60")
const RED = Color("ad4f3d")
const CREAM = Color("fff6e2")
const CREAM_EDGE = Color("c8cfb7")
const HONEY = Color("ecc66e")
const WOOD = Color("294c40")
const WOOD_EDGE = Color("849d75")
const LIGHT = Color("fff6e5")
const MODAL_APPEAR_DURATION = 0.26
const WEAPON_COPY = {
	"pistol":["Pistola di servizio","Un colpo contro i classici. Affidabile, con munizioni infinite.","Gittata medio-corta"],
	"shotgun":["Fucile a pompa","Ferma più zombie classici con un colpo. Ideale quando si avvicinano in gruppo.","Gittata corta"],
	"sniper":["Fucile di precisione","Un colpo ferma un colosso. Grande portata, richiede una pausa tra i tiri.","Gittata molto lunga"],
	"smg":["Mitragliatore","Raffiche rapide: tieni premuto su uno zombie per continuare a sparare.","Gittata media"]
}

var root: Control
var hud: Control
var menu_layer: Control
var main_menu_active: bool = false
var _menu_had_save: bool = false
var _pause_before_modal: bool = false
var _pause_owner: bool = false
var modal: Control
var modal_content: VBoxContainer
var modal_scroll: ScrollContainer
var modal_actions: VBoxContainer
var modal_navigation: HBoxContainer
var _modal_box: Control
var _modal_shade: ColorRect
var _modal_motion_tween: Tween
var _modal_rest_top: float = -350.0
var _modal_rest_bottom: float = 350.0
var _modal_shade_start_alpha: float = 0.0
var _modal_motion_progress: float = 1.0:
	set(value):
		_modal_motion_progress = clampf(value,0.0,1.0)
		_apply_modal_motion()
var _scroll_positions: Dictionary = {}
var _restore_scroll_key: String = ""
var tutorial_panel: PanelContainer
var _tutorial_signature: String = ""
var _tutorial_minimized: bool = false
var panel_kind: String = ""
var panel_id: int = -1
var selected_tab: String = "rifugio"
var sound_enabled: bool = true
var heading: Font
var body: Font
var coin_label: Label
var supply_label: Label
var gem_label: Label
var day_label: Label
var population_label: Label
var objective_label: Label
var zombie_alert: Button
var visible_zombies: Callable
var _seen_zombies: Dictionary = {}
var gate_label: Label
var gate_button: Button
var sound_button: Button
var pause_button: Button
var gate_bar: ProgressBar
var nav_buttons: Dictionary = {}
var bindings: Array = []
var selected_members: Array = []
var selected_zone: int = 0
var building_tab: String = "production"
var journal_tab: String = "projects"
var expedition_step: int = 0
var _equipment_from_expedition: bool = false
var toast_stack: VBoxContainer
var damage_overlay: ColorRect
var _hud_clock: float = 0.0
var _alert_clock: float = 0.0
var _last_panel_signature: String = ""
var _header: PanelContainer
var _footer: PanelContainer
var _camera_controls: Control
var _pan_controls: Control
var _menu_margin: MarginContainer
var _menu_hero: Control
var _menu_cabinet: Control
var _settings_grid: GridContainer
var _phone_safe: MarginContainer
var _phone_page: VBoxContainer
var _phone_pause_return: bool = false
var _context_root: Control
var _defense_context: HBoxContainer
var _town_context: HBoxContainer
var _defense_weapon: Control
var _defense_ammo: Label
var _defense_status: Label
var _defense_ready: ProgressBar
var _ready_shop_button: Button
var _empty_shop_button: Button
var _expedition_status_button: Button
var _ready_shops: Array[int] = []
var _empty_shops: Array[int] = []
var _defense_view: bool = false
var _cherry_asset: Texture2D
var _header_row: HBoxContainer
var _header_optional: Array[Control] = []

class Glyph extends Control:
	var kind: String = "coin"
	var tint: Color = Color.WHITE
	const KEYS = HUDIcons.KEYS
	const REGIONS = HUDIcons.REGIONS
	func _init() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	func _draw() -> void:
		var texture: Texture2D = HUDIcons.texture(kind)
		var factor: float = minf(size.x/texture.get_width(),size.y/texture.get_height())
		var destination: Rect2 = Rect2((size-texture.get_size()*factor)/2.0,texture.get_size()*factor)
		draw_texture_rect(texture,destination,false)
		if kind == "mute":
			var c: Vector2 = size/2.0
			draw_line(c+Vector2(5,-7),c+Vector2(13,1),Color("e98e75"),3,true)
			draw_line(c+Vector2(13,-7),c+Vector2(5,1),Color("e98e75"),3,true)

class CabinetFrame extends PanelContainer:
	# Small hand-drawn details give the warm paper a physical wooden cabinet.
	func _draw() -> void:
		var wood: Color = Color("a17b4b")
		for corner: Vector2 in [Vector2(10,10),Vector2(size.x-10,10),Vector2(10,size.y-10),Vector2(size.x-10,size.y-10)]:
			draw_circle(corner,3.2,Color("d3aa63"),true,-1,true)
			draw_line(corner-Vector2(1.5,0),corner+Vector2(1.5,0),Color("674e37"),1,true)
		for i: int in range(5):
			var y: float = size.y*.18+float(i)*size.y*.15
			draw_line(Vector2(4,y),Vector2(7,y+13),wood,1,true)
			draw_line(Vector2(size.x-7,y+6),Vector2(size.x-4,y+23),wood,1,true)

func _ready() -> void:
	layer = 10
	heading = Typography.heading()
	body = Typography.body()
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	root.size = DeviceLayout.ui_size()
	scale = Vector2.ONE*DeviceLayout.ui_scale()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme: Theme = Theme.new()
	theme.default_font = body
	theme.default_font_size = 16
	theme.set_font("font","Button",heading)
	theme.set_font("font","OptionButton",body)
	theme.set_font("font","PopupMenu",body)
	theme.set_font_size("font_size","PopupMenu",16)
	root.theme = theme
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	_build_header()
	_build_footer()
	_open_hud_gaps(_header)
	_open_hud_gaps(_footer)
	_build_camera_controls()
	_build_notifications()
	_build_zombie_alert()
	_build_tutorial_panel()
	_build_context_hud()
	DeviceLayout.changed.connect(_layout_screen)
	_layout_screen()
	Game.changed.connect(_update_hud)
	Game.toast.connect(_show_toast)
	Game.wave_started.connect(_on_wave_started)
	sound_enabled = Preferences.sound_enabled
	Preferences.changed.connect(_sync_preferences)
	_sync_preferences()
	_update_hud()
	get_tree().create_timer(1.5).timeout.connect(func() -> void:
		var report: Dictionary = Game.offline_report
		if int(report.get("construction_ready",0))>0:
			_show_toast("Cantieri completati mentre eri via: %d. Gli edifici sono pronti!" % int(report.construction_ready))
		if float(report.get("seconds",0))>=60.0:
			_show_toast("Ben tornato! I negozi hanno guadagnato %d monete mentre eri via." % int(report.get("coins",0)))
			if report.get("expedition_ready",false):
				_show_toast("La squadra è tornata. Il bottino ti aspetta nelle Spedizioni.")
		else:
			_show_toast("Benvenuto al rifugio. Qui si ricomincia, insieme.")
	)

func _process(delta: float) -> void:
	_update_defense_status()
	_alert_clock += delta
	if is_instance_valid(zombie_alert) and zombie_alert.visible:
		var pulse: float = 0.5+0.5*sin(_alert_clock*3.2)
		zombie_alert.self_modulate = Color(1.0,lerpf(0.88,1.0,pulse),lerpf(0.78,1.0,pulse))
	_hud_clock += delta
	if _hud_clock >= .25:
		_hud_clock = 0
		_update_hud()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if is_instance_valid(modal):
			if DeviceLayout.android_phone(): _dismiss_phone_page()
			else: _close_modal()
		elif main_menu_active:
			get_viewport().set_input_as_handled()
			return
		else:
			_show_pause()
		get_viewport().set_input_as_handled()

func _style(bg: Color, border: Color = BORDER, radius: int = 14, padding: int = 16) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.content_margin_left = padding
	s.content_margin_right = padding
	s.content_margin_top = padding
	s.content_margin_bottom = padding
	return s

func _raised(bg: Color, border: Color, radius: int = 14, pressed: bool = false, padding: int = 14) -> StyleBoxFlat:
	var s: StyleBoxFlat = _style(bg,border,radius,padding)
	s.border_width_bottom = 3 if not pressed else 1
	s.border_width_top = 2
	s.shadow_color = Color(0.12,0.09,0.06,.16)
	s.shadow_size = 2
	s.shadow_offset = Vector2(0,1 if pressed else 3)
	return s

func _label(value: String, font_size: int = 16, color: Color = TEXT, title: bool = false) -> Label:
	var l: Label = Label.new()
	l.text = value
	l.add_theme_font_override("font", heading if title else body)
	l.add_theme_font_size_override("font_size", maxi(font_size,13))
	if DeviceLayout.mobile:
		l.add_theme_font_size_override("font_size",maxi(font_size,18))
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _copy(value: String, font_size: int = 16, color: Color = MUTED) -> Label:
	var l: Label = _label(value, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _icon(kind: String, pixels: int = 24, tint: Color = TEXT) -> Control:
	var g: Glyph = Glyph.new()
	g.kind = kind
	g.tint = tint
	g.custom_minimum_size = Vector2(pixels,pixels)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g

func _weapon_icon(kind: String, dimensions: Vector2 = Vector2(112,76)) -> Control:
	var visual: Control = WeaponIcon.new()
	visual.kind = kind
	visual.custom_minimum_size = dimensions
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.set_meta("weapon_icon",kind)
	return visual

func _painted_icon(texture: Texture2D, dimensions: Vector2, key: String = "") -> TextureRect:
	var visual: TextureRect = TextureRect.new()
	visual.texture = texture
	visual.custom_minimum_size = dimensions
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	visual.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	visual.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not key.is_empty(): visual.set_meta("painted_icon",key)
	return visual

func _product_icon(kind: String, tier: int, pixels: int = 68) -> TextureRect:
	return _painted_icon(ProductIcons.texture(kind,tier),Vector2(pixels,pixels),"%s_%d" % [kind,tier])

func _button(value: String, callback: Callable, primary: bool = false, small: bool = false) -> Button:
	var b: Button = Button.new()
	b.text = value
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var padding: int = 10 if DeviceLayout.android_phone() else 14
	b.custom_minimum_size.y = 52 if small else 58
	if DeviceLayout.mobile: b.custom_minimum_size.y = DeviceLayout.TOUCH_TARGET
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", heading)
	b.add_theme_font_size_override("font_size", 16 if small else 18)
	if DeviceLayout.mobile: b.add_theme_font_size_override("font_size",18)
	if DeviceLayout.android_phone(): b.add_theme_font_size_override("font_size",20)
	b.add_theme_color_override("font_color", CREAM if primary else INK)
	b.add_theme_color_override("font_hover_color", CREAM if primary else INK)
	b.add_theme_color_override("font_pressed_color", CREAM if primary else INK)
	b.add_theme_color_override("font_hover_pressed_color", CREAM if primary else INK)
	b.add_theme_color_override("font_focus_color", CREAM if primary else INK)
	b.add_theme_color_override("font_disabled_color", Color("9c927e"))
	b.add_theme_stylebox_override("normal", _raised(Chrome.FOREST if primary else Color("f4efdf"),Color("b6c2a4") if primary else Color("d2d3ba"),18,false,padding))
	b.add_theme_stylebox_override("hover", _raised(Color("4c7557") if primary else Color("fff9e8"),Color("a9bb99"),18,false,padding))
	b.add_theme_stylebox_override("pressed", _raised(Color("1e4438") if primary else Color("e9e3cc"),Color("879c74"),18,true,padding))
	b.add_theme_stylebox_override("disabled", _style(Color("ded6c1"),Color("c4b698"),14,padding))
	b.add_theme_stylebox_override("focus", _style(Color(0,0,0,0),GOLD,14,padding))
	b.ready.connect(func() -> void: Chrome.decorate_button(b))
	b.pressed.connect(func() -> void:
		Game.sfx.emit("ui")
		callback.call()
	)
	return b

func _amounts(entries: Array, tint: Color=SAGE) -> HFlowContainer:
	return ResourceUI.row(self,entries,tint)

func _cost_button(caption: String, entries: Array, callback: Callable, primary: bool=false, small: bool=false) -> Button:
	var button: Button = _button(caption,callback,primary,small)
	ResourceUI.set_button(self,button,caption,entries,primary)
	return button

func _update_cost_button(button: Button, caption: String, entries: Array, primary: bool=true) -> void:
	ResourceUI.set_button(self,button,caption,entries,primary)

func _button_stack(button: Button, gap: int = 4, padding: Vector2 = Vector2(8,8)) -> VBoxContainer:
	# Center the complete icon/text group within symmetric button margins.
	var stack: VBoxContainer = _vbox(gap)
	stack.name = "ButtonContent"
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.offset_left = padding.x
	stack.offset_right = -padding.x
	stack.offset_top = padding.y
	stack.offset_bottom = -padding.y
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(stack)
	return stack

func _icon_button(kind: String, callback: Callable, hint: String = "") -> Button:
	var b: Button = _button("",callback,false,true)
	b.custom_minimum_size = Vector2(54,54)
	if DeviceLayout.mobile: b.custom_minimum_size = Vector2.ONE*DeviceLayout.TOUCH_TARGET
	b.tooltip_text = hint
	var g: Control = _icon(kind,30,MUTED)
	b.add_child(g)
	g.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	g.position = Vector2(-15,-15)
	return b

func _hbox(gap: int = 12) -> HBoxContainer:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation",gap)
	return h

func _vbox(gap: int = 10) -> VBoxContainer:
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation",gap)
	return v

func _spacer() -> Control:
	var c: Control = Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _rule(parent: Node) -> void:
	var r: HSeparator = HSeparator.new()
	r.add_theme_stylebox_override("separator",_style(BORDER,BORDER,0,0))
	r.custom_minimum_size.y = 1
	parent.add_child(r)

func _cabinet_style(padding: int = 28) -> StyleBoxFlat:
	if DeviceLayout.mobile: padding = 14
	var s: StyleBoxFlat = _style(PANEL,WOOD,23,padding)
	s.set_border_width_all(4)
	s.border_width_bottom = 7
	s.shadow_color = Color(0.08,0.16,0.10,.25)
	s.shadow_size = 22
	s.shadow_offset = Vector2(0,9)
	if DeviceLayout.android_phone():
		# Phone pages own their insets and gutters independently of this background.
		s.set_corner_radius_all(0)
		s.set_border_width_all(0)
		s.set_content_margin_all(0)
	return s

func _floating_group(padding: int = 0) -> StyleBoxEmpty:
	var style: StyleBoxEmpty = StyleBoxEmpty.new()
	style.set_content_margin_all(padding)
	return style

func _open_hud_gaps(node: Node) -> void:
	# Empty layout containers must not turn the space between controls into a panel.
	if node is Container and not node.has_meta("hud_card"):
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		if not child is BaseButton: _open_hud_gaps(child)

func _floating_caption(label: Label) -> void:
	label.add_theme_color_override("font_color",CREAM)
	label.add_theme_color_override("font_outline_color",WOOD)
	label.add_theme_constant_override("outline_size",4)

func _layout_screen() -> void:
	if not is_instance_valid(root): return
	scale = Vector2.ONE*DeviceLayout.ui_scale()
	root.size = DeviceLayout.ui_size()
	var safe: Rect2 = DeviceLayout.safe_rect()
	hud.offset_left = safe.position.x
	hud.offset_top = safe.position.y
	hud.offset_right = safe.end.x-root.size.x
	hud.offset_bottom = safe.end.y-root.size.y
	if DeviceLayout.mobile:
		_header.offset_bottom = DeviceLayout.PHONE_HEADER_HEIGHT
		_footer.offset_top = -DeviceLayout.PHONE_FOOTER_HEIGHT
		_camera_controls.offset_top = 98
		_camera_controls.offset_bottom = 252
		_camera_controls.offset_left = -84
		_camera_controls.offset_right = -12
		_pan_controls.hide()
		zombie_alert.position = safe.position+Vector2(12,98)
		zombie_alert.custom_minimum_size = Vector2.ONE*DeviceLayout.TOUCH_TARGET
		zombie_alert.size = zombie_alert.custom_minimum_size
		toast_stack.offset_left = -minf(280,safe.size.x*0.35)
		toast_stack.offset_right = minf(280,safe.size.x*0.35)
		toast_stack.offset_top = -192-(root.size.y-safe.end.y)
		toast_stack.offset_bottom = -104-(root.size.y-safe.end.y)
		_layout_phone_tutorial()
		_apply_mobile_controls()
	_fit_modal_to_screen()
	PhonePages.layout(self)
	if is_instance_valid(_phone_page): _finish_phone_page.call_deferred(_modal_box.get_instance_id())
	_layout_settings_grid()
	_layout_menu()
	_fit_header_contents()
	_layout_context_hud()

func _fit_header_contents() -> void:
	if not is_instance_valid(_header_row): return
	var width: float = DeviceLayout.safe_rect().size.x
	var tight: bool = width<980
	var compact: bool = width<1250
	_header_row.add_theme_constant_override("separation",6 if compact else 12)
	for optional: Control in _header_optional: optional.visible = width>=1320
	for card: Node in _header_row.get_children():
		if not card.has_meta("hud_card"): continue
		card.custom_minimum_size.x = 0 if compact else 90 if DeviceLayout.mobile else 115
		var style: StyleBoxFlat = card.get_theme_stylebox("panel").duplicate()
		style.content_margin_left = 6 if compact else 9
		style.content_margin_right = 6 if compact else 9
		card.add_theme_stylebox_override("panel",style)
		var row: HBoxContainer = card.get_child(0)
		row.add_theme_constant_override("separation",4 if compact else 8)
		row.get_child(0).custom_minimum_size = Vector2.ONE*(24 if tight else 28 if compact else 34)
		var text: VBoxContainer = row.get_child(1)
		text.get_child(0).visible = not DeviceLayout.mobile and not compact
		text.get_child(1).add_theme_font_size_override("font_size",16 if tight else 18 if compact else 22)
	if DeviceLayout.android_phone(): MobileHUD.fit(self)
	else: _defense_context.custom_minimum_size.x = 0
	_defense_ammo.add_theme_font_size_override("font_size",14 if compact else 16)

func _fit_modal_to_screen() -> void:
	if not is_instance_valid(_modal_box) or not is_instance_valid(modal): return
	var safe: Rect2 = DeviceLayout.safe_rect()
	var preferred: Vector2 = _modal_box.get_meta("preferred_size",Vector2(940,700))
	var dimensions: Vector2 = preferred.min(safe.size-Vector2(24,24))
	if DeviceLayout.android_phone():
		safe = Rect2(Vector2.ZERO,DeviceLayout.ui_size())
		dimensions = safe.size
		_modal_box.add_theme_stylebox_override("panel",_cabinet_style())
	elif DeviceLayout.mobile:
		# Tablets and other mobile targets keep their previous windowed cabinet.
		dimensions = dimensions.min(Vector2(880,minf(536,safe.size.y*0.84)))
	var center: Vector2 = safe.get_center()-root.size*0.5
	_modal_box.offset_left = center.x-dimensions.x*0.5
	_modal_box.offset_right = center.x+dimensions.x*0.5
	_modal_rest_top = center.y-dimensions.y*0.5
	_modal_rest_bottom = center.y+dimensions.y*0.5
	_apply_modal_motion()

func _apply_mobile_controls() -> void:
	if not DeviceLayout.mobile or not is_instance_valid(root): return
	for node: Node in root.find_children("*","BaseButton",true,false):
		var button: BaseButton = node as BaseButton
		button.custom_minimum_size.y = maxf(button.custom_minimum_size.y,DeviceLayout.TOUCH_TARGET)
		button.custom_minimum_size.x = maxf(button.custom_minimum_size.x,DeviceLayout.TOUCH_TARGET)
	for node: Node in root.find_children("*","ScrollContainer",true,false):
		var scroll: ScrollContainer = node as ScrollContainer
		scroll.scroll_deadzone = 12
		scroll.mouse_filter = Control.MOUSE_FILTER_STOP
		for content: Node in scroll.get_children():
			_pass_scroll_gestures(content)

func _pass_scroll_gestures(node: Node) -> void:
	# Cards and buttons must bubble the touch-emulated mouse gesture to the
	# ScrollContainer. Its native deadzone cancels button presses on a swipe
	# and retains kinetic scrolling. Sliders keep their own drag interaction.
	if node is ScrollContainer or node is Slider or node is ScrollBar: return
	if node is Control and node.mouse_filter==Control.MOUSE_FILTER_STOP:
		node.mouse_filter = Control.MOUSE_FILTER_PASS
	for child: Node in node.get_children():
		_pass_scroll_gestures(child)

func _layout_phone_tutorial() -> void:
	if not DeviceLayout.mobile or not is_instance_valid(tutorial_panel): return
	var safe: Rect2 = DeviceLayout.safe_rect()
	tutorial_panel.offset_left = safe.end.x-root.size.x-368
	tutorial_panel.offset_right = safe.end.x-root.size.x-12
	tutorial_panel.offset_bottom = safe.end.y-root.size.y-104
	tutorial_panel.offset_top = tutorial_panel.offset_bottom-(108 if _tutorial_minimized else 276)

func _layout_menu() -> void:
	if not DeviceLayout.mobile or not is_instance_valid(_menu_margin): return
	var safe: Rect2 = DeviceLayout.safe_rect()
	_menu_margin.add_theme_constant_override("margin_left",int(safe.position.x)+14)
	_menu_margin.add_theme_constant_override("margin_top",int(safe.position.y)+10)
	_menu_margin.add_theme_constant_override("margin_right",int(root.size.x-safe.end.x)+14)
	_menu_margin.add_theme_constant_override("margin_bottom",int(root.size.y-safe.end.y)+10)
	_menu_hero.visible = safe.size.x>=740
	_menu_cabinet.custom_minimum_size.x = minf(360,safe.size.x-48)
	_menu_cabinet.custom_minimum_size.y = minf(432,safe.size.y-48)
	if DeviceLayout.android_phone():
		_menu_hero.visible = safe.size.x>=800
		_menu_hero.custom_minimum_size.x = 280 if _menu_hero.visible else 0
		_menu_cabinet.custom_minimum_size = Vector2(minf(440,safe.size.x-48),360)
		_menu_margin.add_theme_constant_override("margin_left",ceili(safe.position.x)+28)
		_menu_margin.add_theme_constant_override("margin_right",ceili(root.size.x-safe.end.x)+28)

func _build_phone_header() -> void:
	if DeviceLayout.android_phone():
		MobileHUD.header(self)
		return
	_header = PanelContainer.new()
	_header.name = "PhoneHeader"
	_header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	var spacing: StyleBoxEmpty = _floating_group()
	spacing.content_margin_left = 12
	spacing.content_margin_right = 12
	spacing.content_margin_top = 8
	spacing.content_margin_bottom = 4
	_header.add_theme_stylebox_override("panel",spacing)
	hud.add_child(_header)
	var row: HBoxContainer = _hbox(12)
	_header_row = row
	_header.add_child(row)
	coin_label = _resource_pill(row,"coin","MONETE",GOLD,70)
	supply_label = _resource_pill(row,"crate","PROVVISTE",SAGE,70)
	gem_label = _resource_pill(row,"bill","BANCONOTE",SAGE,70)
	day_label = _resource_pill(row,"sun","GIORNO",GOLD,66)
	population_label = _resource_pill(row,"population","ABITANTI",SAGE,88)
	row.add_child(_spacer())
	_build_weapon_header(row)
	row.add_child(_icon_button("journal",_show_quests,"Diario del rifugio"))
	pause_button = _icon_button("pause",_show_pause,"Pausa e impostazioni")
	row.add_child(pause_button)
	objective_label = _label("")
	objective_label.hide()
	_header.add_child(objective_label)

func _build_header() -> void:
	if DeviceLayout.mobile:
		_build_phone_header()
		return
	var p: PanelContainer = PanelContainer.new()
	_header = p
	p.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	p.offset_bottom = 116
	p.add_theme_stylebox_override("panel",_floating_group())
	hud.add_child(p)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left",20)
	margin.add_theme_constant_override("margin_right",20)
	margin.add_theme_constant_override("margin_top",11)
	margin.add_theme_constant_override("margin_bottom",10)
	p.add_child(margin)
	var stack: VBoxContainer = _vbox(10)
	margin.add_child(stack)
	var row: HBoxContainer = _hbox(12)
	_header_row = row
	stack.add_child(row)
	coin_label = _resource_pill(row,"coin","MONETE",Color("a57726"),122)
	supply_label = _resource_pill(row,"crate","PROVVISTE",Color("627b4f"),122)
	gem_label = _resource_pill(row,"bill","BANCONOTE",Color("547b6b"),122)
	day_label = _resource_pill(row,"sun","GIORNO",GOLD,122)
	population_label = _resource_pill(row,"population","ABITANTI",SAGE,142)
	row.add_child(_spacer())
	_build_weapon_header(row)
	row.add_child(_icon_button("journal",_show_quests,"Diario del rifugio · obiettivi e ricompense"))
	pause_button = _icon_button("pause",_show_pause,"Pausa · Esc")
	row.add_child(pause_button)
	sound_button = _icon_button("sound",_toggle_sound,"Attiva / disattiva audio")
	row.add_child(sound_button)
	_header_optional.append(sound_button)
	var help: Button = _icon_button("help",show_help,"Come si gioca")
	row.add_child(help)
	_header_optional.append(help)
	var subrow: HBoxContainer = _hbox(10)
	stack.add_child(subrow)
	objective_label = _label("Ogni piccolo rifugio può diventare una città.",12,MUTED)
	objective_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	objective_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_floating_caption(objective_label)
	subrow.add_child(objective_label)

func _resource_pill(parent: Node, kind: String, caption: String, tint: Color, width: int) -> Label:
	var p: PanelContainer = PanelContainer.new()
	p.custom_minimum_size = Vector2(width,52)
	p.set_meta("hud_card",kind)
	p.tooltip_text = "Persone accolte / posti disponibili nelle case" if kind=="population" else "Giorni trascorsi nel rifugio" if kind=="sun" else caption.capitalize()
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pill_style: StyleBoxFlat = _style(CREAM,CREAM_EDGE,18,9)
	pill_style.set_border_width_all(1)
	pill_style.border_width_bottom = 2
	pill_style.shadow_color = Color(0.08,0.18,0.12,0.12)
	pill_style.shadow_size = 1
	pill_style.shadow_offset = Vector2(0,3)
	p.add_theme_stylebox_override("panel",pill_style)
	var row: HBoxContainer = _hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(row)
	if kind=="population":
		row.add_child(_painted_icon(ProductIcons.population(),Vector2(36,36),"population"))
	else:
		row.add_child(_icon(kind,34,tint))
	var box: VBoxContainer = _vbox(-3)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var title_label: Label = _label(caption,11,Color("676e55"),true)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(title_label)
	if DeviceLayout.mobile: title_label.hide()
	var amount: Label = _label("0",22,INK,true)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(amount)
	row.add_child(box)
	parent.add_child(p)
	return amount

func _build_footer() -> void:
	if DeviceLayout.android_phone():
		MobileHUD.footer(self)
		return
	var p: PanelContainer = PanelContainer.new()
	_footer = p
	p.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	p.offset_top = -148
	p.add_theme_stylebox_override("panel",_floating_group())
	hud.add_child(p)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left",12 if DeviceLayout.mobile else 30)
	margin.add_theme_constant_override("margin_right",12 if DeviceLayout.mobile else 30)
	margin.add_theme_constant_override("margin_top",8 if DeviceLayout.mobile else 14)
	margin.add_theme_constant_override("margin_bottom",12 if DeviceLayout.mobile else 14)
	p.add_child(margin)
	var col: VBoxContainer = _vbox(9)
	margin.add_child(col)
	var hint: HBoxContainer = _hbox()
	col.add_child(hint)
	hint.add_child(_spacer())
	var hint_label: Label = _label("TRASCINA PER ESPLORARE  ·  + / – PER ZOOM  ·  TOCCA PER INTERAGIRE",11,CREAM)
	_floating_caption(hint_label)
	hint.add_child(hint_label)
	hint.visible = not DeviceLayout.mobile
	var row: HBoxContainer = _hbox(16 if DeviceLayout.mobile else 24)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if DeviceLayout.mobile: row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	var nav: HBoxContainer = _hbox(12 if DeviceLayout.mobile else 14)
	if not DeviceLayout.mobile: nav.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(nav)
	var entries: Array = [["rifugio","home","Rifugio"],["citizens","people","Cittadini"],["build","build","Costruisci"],["expeditions","compass","Spedizioni"],["armory","gun","Armeria"]]
	for entry in entries:
		var key: String = entry[0]
		var b: Button = _button("",_navigate.bind(key),false)
		b.custom_minimum_size = Vector2(110,DeviceLayout.TOUCH_TARGET) if DeviceLayout.mobile else Vector2(104,82)
		if not DeviceLayout.mobile: b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v: VBoxContainer = _button_stack(b,3,Vector2(8,5)) if DeviceLayout.mobile else _button_stack(b)
		var center: CenterContainer = CenterContainer.new()
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(_icon(entry[1],30 if DeviceLayout.mobile else 38,GOLD if key=="rifugio" else MUTED))
		v.add_child(center)
		var l: Label = _label(entry[2],15,TEXT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		v.add_child(l)
		nav.add_child(b)
		nav_buttons[key] = b
	gate_button = _button("",_gate_focus,false)
	gate_button.custom_minimum_size = Vector2(204,82)
	if DeviceLayout.mobile: gate_button.custom_minimum_size = Vector2(184,DeviceLayout.TOUCH_TARGET)
	var gate_box: VBoxContainer = _button_stack(gate_button,6,Vector2(14,10))
	var gate_title: HBoxContainer = _hbox(7)
	gate_title.alignment = BoxContainer.ALIGNMENT_CENTER
	gate_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gate_title.add_child(_icon("shield",28,SAGE))
	gate_label = _label("AL CANCELLO  100%",12,TEXT,true)
	gate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gate_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gate_title.add_child(gate_label)
	gate_box.add_child(gate_title)
	gate_bar = _progress(SAGE,6)
	gate_box.add_child(gate_bar)
	row.add_child(gate_button)
	if DeviceLayout.mobile:
		gate_title.get_child(0).hide()
		gate_label.add_theme_font_size_override("font_size",18)
	set_selected_tab("rifugio")

func _context_button(kind: String, caption: String, callback: Callable) -> Button:
	var button: Button = _button("",callback,false,true)
	button.custom_minimum_size = Vector2(170,72 if DeviceLayout.mobile else 60)
	var content: HBoxContainer = _hbox(7)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 10
	content.offset_right = -10
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon: Control = _icon(kind,28)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_child(icon)
	var text: Label = _label(caption,18,TEXT,true)
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(text)
	button.add_child(content)
	button.set_meta("caption",text)
	return button

func _build_weapon_header(parent: Node) -> void:
	_defense_context = _hbox(10)
	_defense_context.custom_minimum_size = Vector2(220 if DeviceLayout.mobile else 242,72 if DeviceLayout.mobile else 58)
	_defense_context.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(_defense_context)
	var choose: Button = _button("",_show_armory,false,true)
	choose.name = "ActiveWeapon"
	choose.custom_minimum_size = Vector2(72,72) if DeviceLayout.mobile else Vector2(64,58)
	choose.tooltip_text = "Arma attiva · Apri l'armeria"
	_defense_weapon = _weapon_icon("pistol",Vector2(52,40))
	choose.add_child(_defense_weapon)
	_defense_weapon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_defense_weapon.position = -Vector2(26,20)
	_defense_context.add_child(choose)
	var status: PanelContainer = PanelContainer.new()
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_theme_stylebox_override("panel",_raised(CREAM,CREAM_EDGE,14,false,8))
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_defense_context.add_child(status)
	var stack: VBoxContainer = _vbox(2)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	status.add_child(stack)
	var line: VBoxContainer = _vbox(0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(line)
	_defense_ammo = _label("Pistola · ∞",16,TEXT,true)
	line.add_child(_defense_ammo)
	_defense_status = _label("Pronto",14,SAGE,true)
	_defense_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_defense_status.custom_minimum_size.x = 64
	_defense_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	line.add_child(_defense_status)
	_defense_ready = _progress(SAGE,4)
	_defense_ready.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(_defense_ready)

func _build_context_hud() -> void:
	_context_root = Control.new()
	_context_root.name = "ContextHUD"
	_context_root.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_context_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_context_root)
	_town_context = _hbox(10)
	_town_context.alignment = BoxContainer.ALIGNMENT_CENTER
	_town_context.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_town_context.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_context_root.add_child(_town_context)
	_ready_shop_button = _context_button("crate","Pronti: 0",_open_shop_attention.bind(true))
	_ready_shop_button.name = "ReadyShops"
	_ready_shop_button.tooltip_text = "Prodotti pronti: apri il negozio per riempire gli scaffali"
	_town_context.add_child(_ready_shop_button)
	_empty_shop_button = _context_button("coffee","Rifornisci: 0",_open_shop_attention.bind(false))
	_empty_shop_button.name = "EmptyShops"
	_empty_shop_button.tooltip_text = "Prodotti esauriti: apri il negozio per avviare il rifornimento"
	_town_context.add_child(_empty_shop_button)
	_expedition_status_button = _context_button("compass","Spedizione",_show_expeditions)
	_expedition_status_button.name = "ExpeditionStatus"
	_expedition_status_button.custom_minimum_size.x = 240
	_town_context.add_child(_expedition_status_button)
	_open_hud_gaps(_context_root)
	_update_town_status()
	_update_context_visibility()

func _layout_context_hud() -> void:
	if not is_instance_valid(_context_root): return
	var safe: Rect2 = DeviceLayout.safe_rect()
	var width: float = minf(660,safe.size.x-204)
	# HUD children are relative to the safe-area-adjusted HUD, not the window.
	_context_root.position = Vector2((safe.size.x-width)*0.5,98 if DeviceLayout.mobile else 132)
	_context_root.size = Vector2(width,72 if DeviceLayout.mobile else 64)

func set_world_context(defense: bool) -> void:
	if _defense_view==defense: return
	_defense_view = defense
	_update_context_visibility()
	_update_defense_status()

func _update_context_visibility() -> void:
	if not is_instance_valid(_context_root): return
	if DeviceLayout.android_phone():
		_context_root.hide()
		return
	_context_root.visible = hud.visible and not main_menu_active and not is_instance_valid(modal) and not (Game.tutorial_active() and not _tutorial_minimized)
	_defense_context.visible = true
	_town_context.visible = not _defense_view

func _update_defense_status() -> void:
	if not is_instance_valid(_defense_weapon): return
	if _defense_weapon.kind!=Game.weapon:
		_defense_weapon.kind = Game.weapon
		_defense_weapon.queue_redraw()
	var definition: Dictionary = Game.WEAPONS.get(Game.weapon,Game.WEAPONS.pistol)
	_defense_ammo.text = str({"pistol":"Pistola","shotgun":"Pompa","sniper":"Precisione","smg":"Mitra"}.get(Game.weapon,"Pistola"))+(" · ∞" if Game.weapon=="pistol" else " · %s" % _number(Game.ammo))
	var cooling: bool = Game.shot_cooldown>0.01
	_defense_status.text = ("Ricarica %.1f s" % Game.shot_cooldown).replace(".",",") if cooling else "Pronto"
	if Game.weapon!="pistol" and Game.ammo<=0: _defense_status.text = "Senza colpi"
	var color: Color = HONEY if DeviceLayout.android_phone() else GOLD if cooling else RED if Game.weapon!="pistol" and Game.ammo<=0 else SAGE
	if _defense_status.get_theme_color("font_color")!=color:
		_defense_status.add_theme_color_override("font_color",color)
	_defense_ready.value = clampf((1.0-Game.shot_cooldown/maxf(float(definition.cooldown),0.01))*100.0,0,100)

func _update_town_status() -> void:
	if not is_instance_valid(_town_context): return
	_ready_shops.clear()
	_empty_shops.clear()
	var ready_count: int = 0
	var empty_count: int = 0
	var available: Dictionary = {}
	for citizen: Dictionary in Game.citizens:
		if not citizen.get("away",false): available[int(citizen.id)] = true
	for building: Dictionary in Game.buildings:
		var workers: int = 0
		for id: Variant in building.get("workers",[]):
			if available.has(int(id)): workers += 1
		for index: int in range(building.get("products",[]).size()):
			var product: Dictionary = building.products[index]
			if product.status=="ready":
				ready_count += 1
				if not _ready_shops.has(int(building.id)): _ready_shops.append(int(building.id))
			elif product.status=="empty" and workers>index:
				empty_count += 1
				if not _empty_shops.has(int(building.id)): _empty_shops.append(int(building.id))
	_ready_shop_button.visible = ready_count>0
	_empty_shop_button.visible = empty_count>0
	_ready_shop_button.get_meta("caption").text = "Pronti: %d" % ready_count
	_empty_shop_button.get_meta("caption").text = "Rifornisci: %d" % empty_count
	var exp_status: String = str(Game.expedition.get("status","idle"))
	_expedition_status_button.visible = exp_status!="idle"
	_expedition_status_button.get_meta("caption").text = "Squadra rientrata" if exp_status=="ready" else "Rientro "+_time(float(Game.expedition.get("remaining",0)))
	if DeviceLayout.android_phone(): MobileHUD.badges(self,ready_count,exp_status)

func _open_shop_attention(ready: bool) -> void:
	_update_town_status()
	var shops: Array[int] = _ready_shops if ready else _empty_shops
	if shops.is_empty(): return
	show_building(shops[0])
	_reveal_shop_action.call_deferred(modal_scroll.get_instance_id(),ready)

func _reveal_shop_action(scroll_id: int, ready: bool) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_id_valid(scroll_id) or modal_scroll!=instance_from_id(scroll_id): return
	var caption: String = "Riempi gli scaffali" if ready else "Avvia rifornimento"
	for control: Node in modal_content.find_children("*","Button",true,false):
		if control.text.begins_with(caption):
			modal_scroll.ensure_control_visible(control)
			return

func _build_camera_controls() -> void:
	# View-only signals keep input devices separate from camera implementation.
	var camera_controls: VBoxContainer = _vbox(9)
	_camera_controls = camera_controls
	camera_controls.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	camera_controls.offset_left = -86
	camera_controls.offset_right = -30
	camera_controls.offset_top = 145
	camera_controls.offset_bottom = 345
	camera_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(camera_controls)
	for direction in [1,-1]:
		var zoom_btn: Button = _button("+" if direction>0 else "–",func() -> void: zoom_requested.emit(direction),false,true)
		zoom_btn.custom_minimum_size = Vector2(56,56)
		zoom_btn.add_theme_font_override("font",heading)
		zoom_btn.add_theme_font_size_override("font_size",30)
		zoom_btn.add_theme_stylebox_override("normal",_raised(PANEL,WOOD_EDGE,14,false,7))
		zoom_btn.add_theme_stylebox_override("hover",_raised(CREAM,GOLD,14,false,7))
		zoom_btn.add_theme_stylebox_override("pressed",_raised(Color("d9c5a0"),WOOD_EDGE,14,true,7))
		zoom_btn.tooltip_text = "Avvicina la visuale" if direction>0 else "Allontana la visuale"
		camera_controls.add_child(zoom_btn)
	var pan: HBoxContainer = _hbox(9)
	_pan_controls = pan
	pan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pan.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pan.offset_left = -151
	pan.offset_right = -30
	pan.offset_top = 281
	pan.offset_bottom = 337
	hud.add_child(pan)
	for direction in [-1,1]:
		var pan_btn: Button = _button("‹" if direction<0 else "›",func() -> void: camera_pan.emit(direction),false,true)
		pan_btn.custom_minimum_size = Vector2(56,56)
		pan_btn.add_theme_font_size_override("font_size",30)
		pan_btn.add_theme_stylebox_override("normal",_raised(PANEL,WOOD_EDGE,14,false,7))
		pan_btn.add_theme_stylebox_override("hover",_raised(CREAM,GOLD,14,false,7))
		pan_btn.add_theme_stylebox_override("pressed",_raised(Color("d9c5a0"),WOOD_EDGE,14,true,7))
		pan_btn.tooltip_text = "Sposta la visuale a sinistra" if direction<0 else "Sposta la visuale a destra"
		pan.add_child(pan_btn)

func _progress(tint: Color = SAGE, height: int = 8) -> ProgressBar:
	var p: ProgressBar = ProgressBar.new()
	p.custom_minimum_size.y = height
	p.show_percentage = false
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("background",_style(Color("d1c09b"),Color("c2af88"),height/2,0))
	p.add_theme_stylebox_override("fill",_style(tint,tint,height/2,0))
	return p

func _build_notifications() -> void:
	toast_stack = _vbox(7)
	toast_stack.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	toast_stack.offset_left = -310
	toast_stack.offset_right = 310
	toast_stack.offset_top = -252
	toast_stack.offset_bottom = -166
	toast_stack.alignment = BoxContainer.ALIGNMENT_END
	toast_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(toast_stack)
	damage_overlay = ColorRect.new()
	damage_overlay.color = Color(0.9,.25,.1,0)
	damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(damage_overlay)

func _build_zombie_alert() -> void:
	zombie_alert = _button("",_on_zombie_alert_pressed,true)
	zombie_alert.name = "ZombieAlert"
	zombie_alert.position = Vector2(30,145)
	zombie_alert.custom_minimum_size = Vector2(68,68)
	zombie_alert.size = Vector2(68,68)
	zombie_alert.mouse_filter = Control.MOUSE_FILTER_STOP
	zombie_alert.tooltip_text = "Zombie · Vai alla postazione del militare"
	zombie_alert.add_theme_stylebox_override("normal",_raised(Color("efd095"),RED,20,false,8))
	zombie_alert.add_theme_stylebox_override("hover",_raised(Color("ffe4b3"),RED,20,false,8))
	zombie_alert.add_theme_stylebox_override("pressed",_raised(Color("e4b67d"),RED,20,true,8))
	# Only this shortcut sits above a modal: other HUD buttons stay covered.
	root.add_child(zombie_alert)
	var face: TextureRect = TextureRect.new()
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	face.texture = HUDIcons.cropped_texture("res://assets/art/characters.png",Rect2i(1002,58,87,93))
	face.custom_minimum_size = Vector2(46,49)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zombie_alert.add_child(face)
	face.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	face.offset_left = -23
	face.offset_right = 23
	face.offset_top = -24.5
	face.offset_bottom = 24.5
	var badge: PanelContainer = PanelContainer.new()
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -23
	badge.offset_bottom = 23
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel",_style(RED,WOOD,12,0))
	var mark: Label = _label("!",18,CREAM,true)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(mark)
	zombie_alert.add_child(badge)
	_update_zombie_alert()
	_update_tutorial()

func _zombies_incoming() -> bool:
	if visible_zombies.is_valid():
		for id: int in visible_zombies.call(): _seen_zombies[id] = true
	var live_ids: Dictionary = {}
	for enemy: Dictionary in Game.threats: live_ids[int(enemy.id)] = true
	for id: int in _seen_zombies.keys():
		if not live_ids.has(id): _seen_zombies.erase(id)
	# A spotted enemy remains known when the player pans back into the village.
	return not _seen_zombies.is_empty()

func _update_zombie_alert() -> void:
	if is_instance_valid(zombie_alert):
		zombie_alert.visible = hud.visible and not main_menu_active and _zombies_incoming() and (not DeviceLayout.mobile or not is_instance_valid(modal))

func _on_zombie_alert_pressed() -> void:
	_close_modal()
	focus_defense.emit()

func _build_tutorial_panel() -> void:
	tutorial_panel = PanelContainer.new()
	tutorial_panel.name = "TutorialGuide"
	tutorial_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	tutorial_panel.offset_left = -422
	tutorial_panel.offset_right = -22
	tutorial_panel.offset_top = -418
	tutorial_panel.offset_bottom = -165
	tutorial_panel.add_theme_stylebox_override("panel",_raised(CARD,Color("8d9b66"),17,false,15))
	root.add_child(tutorial_panel)
	tutorial_panel.hide()

func _tutorial_step() -> Array:
	var site: Dictionary = Game.active_construction()
	if not site.is_empty() and Game.tutorial_stage in ["build_residence","build_cafe"]:
		return [2 if site.type=="residence" else 4,"Stiamo costruendo!","Il cantiere lavora: al termine la casa offrirà i primi letti." if site.type=="residence" else "Ancora pochi secondi: quando il caffè è pronto potrai assegnare il primo lavoratore.","Guarda il cantiere","construction"]
	match Game.tutorial_stage:
		"intro": return [0,"Il rifugio comincia con te","Segui una breve guida per difendere il cancello, accogliere persone e aprire il primo negozio.","Inizia i primi passi", "intro"]
		"first_zombie": return [1,"Aspetta il momento giusto","Quando lo zombie ha un contorno luminoso dorato è a portata della pistola: toccalo per sparare.","Vai alla torretta", "defense"]
		"build_residence": return [2,"Prima di tutto, un tetto","Il rifugio è vuoto. Costruisci la prima casa per avere 5 letti disponibili.","Costruisci una casa", "build"]
		"welcome_visitor": return [3,"C'è qualcuno alla porta" if Game.has_waiting_visitors() else "Una persona si avvicina","Tocca la persona al cancello e accoglila nel rifugio." if Game.has_waiting_visitors() else "Una persona sta percorrendo la strada. Aspetta che raggiunga il cancello per darle il benvenuto.","Vai al cancello", "gate"]
		"build_cafe": return [4,"Accendiamo la caffettiera","Ora serve un lavoro. Costruisci L'ultimo caffè: sarà il tuo primo negozio.","Costruisci il caffè", "build"]
		"assign_worker": return [5,"Il talento al posto giusto","Apri il caffè e scegli Gestisci i lavoratori. Assegna il nuovo cittadino per sbloccare il primo prodotto.","Apri il caffè", "cafe"]
		"restock": return [6,"Prepariamo gli scaffali","Apri il primo prodotto del caffè e premi Avvia rifornimento. Servono poche monete.","Avvia il primo rifornimento", "cafe"]
		"stock": return [7,"Pronti per aprire","Attendi la preparazione, poi premi Riempi gli scaffali. Il caffè venderà i prodotti e guadagnerà monete.","Controlla il caffè", "cafe"]
	return []

func _update_tutorial() -> void:
	if not is_instance_valid(tutorial_panel): return
	var should_show: bool = hud.visible and not main_menu_active and not is_instance_valid(modal) and Game.tutorial_active()
	tutorial_panel.visible = should_show
	var signature: String = Game.tutorial_stage+":"+str(_tutorial_minimized)+":"+str(Game.has_waiting_visitors())+":"+str(Game.active_construction().get("id",-1))
	if signature==_tutorial_signature: return
	_tutorial_signature = signature
	for child: Node in tutorial_panel.get_children():
		tutorial_panel.remove_child(child)
		child.queue_free()
	var step: Array = _tutorial_step()
	if step.is_empty(): return
	var col: VBoxContainer = _vbox(8)
	tutorial_panel.add_child(col)
	var top: HBoxContainer = _hbox(8)
	var heading_label: Label = _label("PRIMI PASSI  ·  %d / 7" % int(step[0]),13,SAGE,true)
	if DeviceLayout.mobile:
		heading_label.text = str(step[1])
		heading_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		heading_label.add_theme_font_size_override("font_size",18)
	heading_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(heading_label)
	var minimize: Button = _button("+" if _tutorial_minimized else "−",_toggle_tutorial_minimized,false,true)
	minimize.custom_minimum_size = Vector2(42,38)
	if DeviceLayout.mobile: minimize.custom_minimum_size = Vector2.ONE*DeviceLayout.TOUCH_TARGET
	minimize.tooltip_text = "Mostra il suggerimento" if _tutorial_minimized else "Riduci il suggerimento"
	top.add_child(minimize)
	col.add_child(top)
	tutorial_panel.offset_top = -235 if _tutorial_minimized else -418
	if _tutorial_minimized:
		_layout_phone_tutorial()
		return
	if not DeviceLayout.mobile: col.add_child(_copy(str(step[1]),22,TEXT))
	col.add_child(_copy(str(step[2]),15,MUTED))
	var action: Button = _button(str(step[3]),_tutorial_action.bind(str(step[4])),true,true)
	action.custom_minimum_size.y = 48
	col.add_child(action)
	if DeviceLayout.mobile:
		_layout_phone_tutorial()
		_apply_mobile_controls.call_deferred()

func _toggle_tutorial_minimized() -> void:
	_tutorial_minimized = not _tutorial_minimized
	_update_tutorial()
	_update_context_visibility()

func _tutorial_action(action: String) -> void:
	match action:
		"intro": _show_tutorial_intro()
		"defense": focus_defense.emit()
		"gate": focus_gate.emit()
		"build": _show_build()
		"construction":
			var site: Dictionary = Game.active_construction()
			if not site.is_empty(): _construction_focus(int(site.id))
		"cafe":
			for b: Dictionary in Game.buildings:
				if b.type=="cafe":
					focus_city.emit()
					show_building(int(b.id))
					break

func _show_tutorial_intro() -> void:
	if main_menu_active or Game.tutorial_stage!="intro": return
	var col: VBoxContainer = _open("tutorial_intro","Un rifugio da costruire, insieme","BENVENUTO AL RIFUGIO 07")
	var card: VBoxContainer = _card(col,SAGE)
	var row: HBoxContainer = _hbox(18)
	row.add_child(_icon("home",76))
	row.add_child(_copy("Per ora ci sono soltanto le mura e il militare sulla torretta. Il resto comincia con te.",24,TEXT))
	card.add_child(row)
	col.add_child(_copy("Ti guiderò nei primi passi: difendi il cancello, costruisci una casa, accogli la prima persona e apri il caffè. I suggerimenti restano sullo schermo mentre giochi.",18))
	col.add_child(_button("Cominciamo · Vai alla torretta",func() -> void:
		Game.start_tutorial()
		_close_modal()
		focus_defense.emit()
	,true))
	col.add_child(_button("So già come fare · Salta il tutorial",func() -> void:
		Game.skip_tutorial()
		_close_modal()
	,false,true))

func _update_hud() -> void:
	if not is_instance_valid(coin_label):
		return
	coin_label.text = _number(Game.coins)
	supply_label.text = _number(Game.supplies)
	gem_label.text = _number(Game.gems)
	day_label.text = str(Game.day)
	population_label.text = "%d / %d" % [Game.citizens.size(),Game.capacity()]
	var ratio: float = Game.gate_hp / maxf(Game.gate_max,1.0)
	gate_bar.value = ratio*100
	gate_label.text = ("%d%%" if DeviceLayout.android_phone() else "CANCELLO %d%%" if DeviceLayout.mobile else "AL CANCELLO  %d%%") % int(ratio*100)
	gate_label.add_theme_color_override("font_color",RED if ratio<.4 else TEXT)
	gate_button.add_theme_stylebox_override("normal",_raised(Color("f4efdf"),RED if not Game.threats.is_empty() else BORDER,22,false,12))
	_update_zombie_alert()
	_update_tutorial()
	objective_label.text = _next_objective()
	_update_town_status()
	_update_context_visibility()
	for binding in bindings:
		if is_instance_valid(binding[0]):
			binding[1].call(binding[0])
	if panel_kind == "building":
		var b: Dictionary = _building(panel_id)
		if not b.is_empty():
			var sig: String = _building_signature(b)
			if sig != _last_panel_signature:
				_refresh_building_if_needed.call_deferred(panel_id)
	elif panel_kind == "visitor":
		if _visitor(panel_id).is_empty():
			_close_missing_visitor.call_deferred(panel_id)
	elif panel_kind=="demolition" and _building(panel_id).is_empty():
		_close_missing_demolition.call_deferred(panel_id)
	elif panel_kind == "expeditions":
		var sig: String = str(Game.expedition.get("status","idle"))
		if sig != _last_panel_signature:
			_refresh_expedition_if_needed.call_deferred()
	elif panel_kind == "build" and _last_panel_signature!=_build_catalog_signature():
		_show_build.call_deferred()
	elif panel_kind in ["assignment","job_select","citizens"] and _last_panel_signature!=Workforce.signature(Game):
		_refresh_workforce_if_needed.call_deferred(panel_kind,panel_id)

func _refresh_workforce_if_needed(kind: String, id: int) -> void:
	if panel_kind!=kind or panel_id!=id: return
	if _last_panel_signature!=Workforce.signature(Game): _refresh_current()

func _refresh_building_if_needed(id: int) -> void:
	if panel_kind!="building" or panel_id!=id: return
	var building: Dictionary = _building(id)
	if not building.is_empty() and _building_signature(building)!=_last_panel_signature:
		show_building(id)

func _refresh_expedition_if_needed() -> void:
	if panel_kind=="expeditions" and str(Game.expedition.get("status","idle"))!=_last_panel_signature:
		_show_expeditions()

func _close_missing_visitor(id: int) -> void:
	# A queued loss/rejection must not close a different card opened meanwhile.
	if panel_kind == "visitor" and panel_id == id and _visitor(id).is_empty():
		_close_modal()

func _close_missing_demolition(id: int) -> void:
	if panel_kind=="demolition" and panel_id==id and _building(id).is_empty(): _close_modal()

func show_demolition(id: int) -> void:
	DemolitionPanel.show_panel(self,id)

func _demolish_building(id: int) -> void:
	if Game.demolish_building(id): _close_modal()
	else: show_demolition(id)

func _next_objective() -> String:
	for q in Game.quests:
		if not q.get("claimed",false):
			if float(q.get("progress",0)) >= float(q.get("target",1)):
				return "Obiettivo completato! Ritira la ricompensa nel diario."
			return "%s  ·  %d/%d" % [q.get("name","Il prossimo passo"),mini(int(q.get("progress",0)),int(q.get("target",1))),int(q.get("target",1))]
	return "Il rifugio cresce. Continua a costruire la tua nuova normalità."

func _number(value: float) -> String:
	if value >= 1000000:
		return ("%.1f" % (value/1000000)).trim_suffix(".0")+" M"
	if value >= 10000:
		return ("%.1f" % (value/1000)).trim_suffix(".0")+" k"
	return str(int(value))

func _time(seconds: float) -> String:
	var s: int = maxi(0,int(ceil(seconds)))
	return "%02d:%02d" % [s/60,s%60]

func _building(id: int) -> Dictionary:
	for b in Game.buildings:
		if int(b.id)==id:
			return b
	return {}

func _citizen(id: int) -> Dictionary:
	for c in Game.citizens:
		if int(c.id)==id:
			return c
	return {}

func _visitor(id: int) -> Dictionary:
	for v in Game.visitors:
		if int(v.id)==id:
			return v
	return {}

func _type_name(kind: String) -> String:
	return Game.BUILDING_NAMES.get(kind,kind)

func _work_name(c: Dictionary) -> String:
	if c.get("away",false):
		return "In spedizione"
	var b: Dictionary = _building(int(c.get("job",-1)))
	return b.get("name","In cerca di un lavoro")

func _navigate(key: String) -> void:
	if key == "rifugio":
		_close_modal()
		focus_city.emit()
	else:
		match key:
			"citizens": _show_citizens()
			"build": _show_build()
			"expeditions": _show_expeditions()
			"armory": _show_armory()
	set_selected_tab(key)

func set_selected_tab(key: String) -> void:
	selected_tab = key
	if DeviceLayout.android_phone():
		Chrome.select_nav(self,key)
		return
	for k in nav_buttons:
		var b: Button = nav_buttons[k]
		b.add_theme_stylebox_override("normal",_raised(HONEY if k==key else Color("e8ddbe"),Color("ac853f") if k==key else Color("b69b71"),15))
		b.add_theme_color_override("font_color",INK if k==key else TEXT)
		var glyph: Glyph = b.get_child(0).get_child(0).get_child(0)
		glyph.tint = INK if k==key else SAGE
		glyph.queue_redraw()
		var caption: Label = b.get_child(0).get_child(1)
		caption.add_theme_color_override("font_color",INK if k==key else TEXT)

func _gate_focus() -> void:
	_close_modal()
	focus_gate.emit()
	_show_toast("Tocca gli zombie per sparare. La pistola ha munizioni infinite.")

func _toggle_sound() -> void:
	Preferences.apply_settings({"sound_enabled":not sound_enabled})
	_show_toast("Audio attivo" if sound_enabled else "Audio disattivato")

func _sync_preferences() -> void:
	sound_enabled = Preferences.sound_enabled
	if not is_instance_valid(sound_button):
		return
	var glyph: Glyph = sound_button.get_child(0)
	glyph.kind = "sound" if sound_enabled else "mute"
	glyph.queue_redraw()
	sound_toggled.emit(sound_enabled)

func _open(kind: String, title: String, subtitle: String = "DOSSIER DEL RIFUGIO", id: int = -1) -> VBoxContainer:
	if is_instance_valid(tutorial_panel): tutorial_panel.hide()
	var previous_key: String = _panel_key(panel_kind,panel_id)
	var new_key: String = _panel_key(kind,id)
	var continuing_panel: bool = is_instance_valid(modal) and previous_key==new_key
	if not continuing_panel:
		_modal_shade_start_alpha = _modal_shade.modulate.a if is_instance_valid(_modal_shade) else 0.0
	if is_instance_valid(modal_scroll):
		_scroll_positions[previous_key] = modal_scroll.scroll_vertical
	var saved_scroll: int = int(_scroll_positions.get(new_key,0)) if previous_key==new_key or _restore_scroll_key==new_key else 0
	_restore_scroll_key = ""
	if is_instance_valid(modal):
		modal.hide()
		modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		modal.queue_free()
	bindings.clear()
	Game.management_open = true
	panel_kind = kind
	_settings_grid = null
	_phone_safe = null
	_phone_page = null
	panel_id = id
	if DeviceLayout.android_phone(): return PhonePages.open_page(self,kind,title,id,saved_scroll,continuing_panel)
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(modal)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(.10,.12,.10,.70)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(shade)
	_modal_shade = shade
	shade.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
			_close_modal()
	)
	var box: PanelContainer = CabinetFrame.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.offset_left = -470
	box.offset_right = 470
	box.offset_top = -350
	box.offset_bottom = 350
	if kind == "pause":
		box.offset_left = -420
		box.offset_right = 420
		box.offset_top = -270
		box.offset_bottom = 270
	elif kind == "tutorial_intro":
		box.offset_top = -270
		box.offset_bottom = 270
	elif kind == "building_help":
		box.offset_top = -300
		box.offset_bottom = 300
	box.add_theme_stylebox_override("panel",_cabinet_style())
	box.set_meta("preferred_size",Vector2(box.offset_right-box.offset_left,box.offset_bottom-box.offset_top))
	modal.add_child(box)
	_modal_box = box
	_modal_rest_top = box.offset_top
	_modal_rest_bottom = box.offset_bottom
	box.pivot_offset = box.size*0.5
	box.resized.connect(_update_modal_motion_pivot.bind(box.get_instance_id()))
	_fit_modal_to_screen()
	var stack: VBoxContainer = _vbox(10 if DeviceLayout.mobile else 18)
	box.add_child(stack)
	var ribbon: PanelContainer = PanelContainer.new()
	ribbon.add_theme_stylebox_override("panel",_raised(Chrome.FOREST,Color("577b53"),14,false,8 if DeviceLayout.mobile else 17))
	stack.add_child(ribbon)
	var header: HBoxContainer = _hbox(15)
	ribbon.add_child(header)
	var kind_icons: Dictionary = {"visitor":"person","building":"home","building_help":"help","citizens":"people","citizen_equipment":"gun","assignment":"people","job_select":"build","build":"build","expeditions":"compass","armory":"gun","weapon_details":"gun","gate":"shield","demolition":"build","quests":"journal","help":"help","pause":"pause","settings":"sound","credits":"heart","reset":"home","tutorial_intro":"home"}
	header.add_child(_icon(str(kind_icons.get(kind,"home")),38 if DeviceLayout.mobile else 58))
	var titles: VBoxContainer = _vbox(2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	var subtitle_label: Label = _label(subtitle,13,Color("e8d5a5"),true)
	subtitle_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	titles.add_child(subtitle_label)
	if DeviceLayout.mobile: subtitle_label.hide()
	var title_label: Label = _label(title,24 if DeviceLayout.mobile else 30,LIGHT,true)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(title_label)
	header.add_child(titles)
	if kind == "building":
		header.add_child(_icon_button("help",_show_building_help.bind(id),"A cosa serve questo edificio?"))
	header.add_child(_icon_button("cross",_close_modal,"Chiudi · Esc"))
	_add_purchase_balances(stack,kind)
	modal_navigation = _hbox(12)
	modal_navigation.name = "DialogNavigation"
	stack.add_child(modal_navigation)
	modal_navigation.hide()
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_theme_stylebox_override("panel",_style(PANEL,PANEL,0,0))
	stack.add_child(scroll)
	modal_scroll = scroll
	modal_content = _vbox(8 if DeviceLayout.android_phone() else 10 if DeviceLayout.mobile else 14)
	modal_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(modal_content)
	modal_actions = _vbox(8)
	modal_actions.name = "DialogActions"
	stack.add_child(modal_actions)
	modal_actions.hide()
	panel_changed.emit(true)
	root.move_child(zombie_alert,root.get_child_count()-1)
	_update_zombie_alert()
	_restore_modal_scroll.call_deferred(scroll.get_instance_id(),saved_scroll)
	_begin_modal_motion(not continuing_panel)
	_update_context_visibility()
	if DeviceLayout.mobile: _apply_mobile_controls.call_deferred()
	return modal_content

func _fixed_actions() -> VBoxContainer:
	if not modal_actions.visible:
		modal_actions.show()
		if not DeviceLayout.android_phone(): _rule(modal_actions)
	return modal_actions

func _add_purchase_balances(parent: Node, kind: String) -> void:
	if not PURCHASE_PANELS.has(kind) and kind!="quests": return
	var row: HFlowContainer = HFlowContainer.new()
	row.add_theme_constant_override("h_separation",16)
	row.add_theme_constant_override("v_separation",6)
	row.name = "DialogBalances"
	parent.add_child(row)
	for entry: Array in [["coin","monete","coins","DialogCoins"],["crate","provviste","supplies","DialogSupplies"],["bill","banconote","gems","DialogBills"],["build","materiali","parts","DialogParts"]]:
		var group: HBoxContainer = _hbox(6)
		group.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		group.add_child(_icon(str(entry[0]),28))
		var key: String = entry[2]
		var label: Label = _label("",17,SAGE)
		label.name = str(entry[3])
		group.tooltip_text = str(entry[1]).capitalize()
		var update: Callable = func(l: Label) -> void: l.text = str(int(Game.community.parts) if key=="parts" else int(Game.get(key)))
		update.call(label)
		bindings.append([label,update])
		group.add_child(label)
		row.add_child(group)
	var legend: VBoxContainer = _card(parent)
	legend.get_parent().name = "ResourceLegend"
	legend.add_child(_copy("Risorse del rifugio",20,TEXT))
	for entry: Array in [["coin","Monete · acquisti e costruzioni"],["crate","Provviste · rifornimenti, cure e spedizioni"],["bill","Banconote · ricompense e azioni speciali"],["build","Materiali · migliorie e progetti"]]:
		var meaning: HBoxContainer = _hbox(10)
		meaning.add_child(_icon(str(entry[0]),28))
		meaning.add_child(_copy(str(entry[1]),17))
		legend.add_child(meaning)
	legend.get_parent().hide()
	var help: Button = _icon_button("help",_toggle_resource_legend.bind(legend.get_parent().get_instance_id()),"Significato delle risorse")
	help.name = "ResourceLegendToggle"
	row.add_child(help)

func _toggle_resource_legend(instance_id: int) -> void:
	if not is_instance_id_valid(instance_id) or not is_instance_valid(modal_content): return
	var legend: Control = instance_from_id(instance_id)
	if legend.visible:
		legend.hide()
		return
	# Even tablet cabinets keep this optional text inside their scroll surface.
	# Expanding a fixed header must never squeeze the usable content to zero.
	if legend.get_parent()!=modal_content: legend.reparent(modal_content)
	modal_content.move_child(legend,0)
	legend.show()
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(legend) and is_instance_valid(modal_scroll) and modal_scroll.is_ancestor_of(legend):
		modal_scroll.ensure_control_visible(legend)

func _citizen_name(parent: Node, citizen: Dictionary, font_size: int=24) -> void:
	var row: HBoxContainer = _hbox(8)
	row.name = "CitizenName_"+str(citizen.get("id",0))
	parent.add_child(row)
	var label: Label = _copy(str(citizen.get("name","Superstite")),font_size,TEXT)
	label.add_theme_font_override("font",heading)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	if SurvivorCatalog.is_nurse(int(citizen.get("look",0))):
		if _cherry_asset==null:
			var path: String = "res://assets/art/cherries.png"
			var pixels: Image = (load(path) as Texture2D).get_image()
			if pixels.is_compressed(): pixels.decompress()
			_cherry_asset = HUDIcons.cropped_texture(path,pixels.get_used_rect())
		var badge: TextureRect = _painted_icon(_cherry_asset,Vector2(30,30),"cherries")
		badge.name = "ChiaraCherries"
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(badge)

func _finish_phone_page(instance_id: int) -> void:
	if not is_instance_valid(_modal_box) or _modal_box.get_instance_id()!=instance_id: return
	PhonePages.polish(self)
	if _modal_box.get_meta("reveal_content",false):
		_modal_box.set_meta("reveal_content",false)
		Chrome.reveal(modal_content)

func _update_modal_motion_pivot(instance_id: int) -> void:
	if not is_instance_id_valid(instance_id): return
	var box: Control = instance_from_id(instance_id) as Control
	if is_instance_valid(box): box.pivot_offset = box.size*0.5

func _apply_modal_motion() -> void:
	if not is_instance_valid(_modal_box) or not is_instance_valid(_modal_shade): return
	var progress: float = _modal_motion_progress
	var motion: float = 1.0-pow(1.0-progress,3.0)
	var fade: float = minf(progress/0.65,1.0)
	fade = 1.0-pow(1.0-fade,2.0)
	var scale_factor: float = lerpf(0.965,1.0,motion)+0.005*sin(PI*progress)
	var lift: float = 18.0*(1.0-motion)
	if DeviceLayout.android_phone():
		# The phone cabinet fades in without slipping outside its safe-area edges.
		scale_factor = 1.0
		lift = 0.0
	_modal_box.modulate.a = fade
	_modal_shade.modulate.a = lerpf(_modal_shade_start_alpha,1.0,fade)
	_modal_box.scale = Vector2.ONE*scale_factor
	_modal_box.offset_top = _modal_rest_top+lift
	_modal_box.offset_bottom = _modal_rest_bottom+lift

func _stop_modal_motion() -> void:
	if is_instance_valid(_modal_motion_tween) and _modal_motion_tween.is_valid():
		_modal_motion_tween.kill()
	_modal_motion_tween = null

func _begin_modal_motion(replay: bool) -> void:
	if Preferences.reduced_motion:
		_stop_modal_motion()
		_modal_motion_progress = 1.0
		return
	if replay:
		_modal_box.set_meta("reveal_content",true)
		_stop_modal_motion()
		_modal_motion_progress = 0.0
	else:
		# Actions rebuild their panel to show new stock, costs or assignments.
		# Keep the existing animation timeline and scroll rather than reopening.
		_apply_modal_motion()
	if _modal_motion_progress>=1.0: return
	if is_instance_valid(_modal_motion_tween) and _modal_motion_tween.is_valid(): return
	# Tween the live UI controller, never a replaceable or freed dialog node.
	_modal_motion_tween = create_tween().bind_node(self)
	_modal_motion_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_modal_motion_tween.tween_property(self,"_modal_motion_progress",1.0,MODAL_APPEAR_DURATION*(1.0-_modal_motion_progress))

func _panel_key(kind: String, id: int) -> String:
	return kind+":"+str(id)

func _restore_modal_scroll(scroll_instance_id: int, value: int) -> void:
	# Containers need a layout frame before their scroll limit is available.
	await get_tree().process_frame
	# A rapid dialog replacement may free the old container before this deferred
	# call even begins. Pass its numeric identity, never a typed freed Object.
	if not is_instance_id_valid(scroll_instance_id): return
	var scroll: ScrollContainer = instance_from_id(scroll_instance_id) as ScrollContainer
	if is_instance_valid(scroll) and scroll==modal_scroll:
		scroll.scroll_vertical = value

func _return_to_building(id: int) -> void:
	_restore_scroll_key = _panel_key("building",id)
	show_building(id)

func _return_to_citizens() -> void:
	_restore_scroll_key = _panel_key("citizens",-1)
	_show_citizens()

func _close_modal() -> void:
	_phone_pause_return = false
	_stop_modal_motion()
	if _pause_owner and not main_menu_active:
		Game.paused = _pause_before_modal
		_pause_owner = false
	if is_instance_valid(modal):
		Chrome.retire(modal)
	modal = null
	modal_content = null
	modal_scroll = null
	modal_actions = null
	modal_navigation = null
	_settings_grid = null
	_phone_safe = null
	_phone_page = null
	_modal_box = null
	_modal_shade = null
	_modal_shade_start_alpha = 0.0
	_modal_motion_progress = 1.0
	Game.management_open = false
	panel_kind = ""
	panel_id = -1
	bindings.clear()
	_scroll_positions.clear()
	panel_changed.emit(main_menu_active)
	set_selected_tab("rifugio")
	_update_tutorial()
	_update_zombie_alert()
	_update_context_visibility()

func _card(parent: Node, tint: Color = BORDER) -> VBoxContainer:
	var p: PanelContainer = PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_style: StyleBoxFlat = _style(CARD,BORDER,22,18)
	card_style.border_width_left = 1
	card_style.border_width_right = 1
	card_style.border_width_top = 1
	card_style.border_width_bottom = 1
	if tint!=BORDER:
		card_style.border_width_left = 4
		card_style.border_color = tint
	card_style.shadow_color = Color(0.12,0.22,0.15,.07)
	card_style.shadow_size = 7
	card_style.shadow_offset = Vector2(0,2)
	p.add_theme_stylebox_override("panel",card_style)
	parent.add_child(p)
	var v: VBoxContainer = _vbox(12)
	p.add_child(v)
	return v

func _title_row(parent: Node, title: String, detail: String = "", tint: Color = GOLD) -> HBoxContainer:
	var h: HBoxContainer = _hbox(10)
	h.add_child(_label(title,20,TEXT,true))
	h.add_child(_spacer())
	if not detail.is_empty():
		h.add_child(_label(detail,12,tint,true))
	parent.add_child(h)
	return h

func _bind_label(parent: Node, callback: Callable, font_size: int = 14, tint: Color = MUTED) -> Label:
	var l: Label = _label("",font_size,tint)
	parent.add_child(l)
	bindings.append([l,callback])
	callback.call(l)
	return l

func _action(callback: Callable) -> void:
	callback.call()
	_refresh_current()

func _refresh_current() -> void:
	match panel_kind:
		"building": show_building(panel_id)
		"citizens": _show_citizens()
		"build": _show_build()
		"expeditions": _show_expeditions()
		"armory": _show_armory()
		"gate": show_gate()
		"quests": _show_quests()
		"assignment": _show_assignment(panel_id)
		"job_select": _show_job_select(panel_id)

func _building_signature(b: Dictionary) -> String:
	var states: Array = [b.workers,Game._available_workers(b),Game.is_under_construction(b),b.get("storage_upgraded",false),b.get("auto_shelves",false)]
	for p in b.get("products",[]):
		states.append(p.get("status","empty"))
	return JSON.stringify(states)

func show_building(id: int) -> void:
	CozyPanel.building(self,id)

func _skill_name(kind: String) -> String:
	var skill: String = str(Game.BUILDING_SKILLS.get(kind,"services"))
	return {"food":"CIBO","goods":"BENI","services":"SERVIZI"}.get(skill,"SERVIZI")

func _restock(bid: int, tier: int) -> void:
	Game.restock(bid,tier)
	show_building(bid)

func _show_building_help(id: int) -> void:
	var b: Dictionary = _building(id)
	if b.is_empty(): return
	var guides: Dictionary = {
		"residence": ["home","Un letto per ricominciare","Ogni casa aggiunge 5 posti al rifugio. Se non ci sono letti liberi, non puoi accogliere altre persone al cancello.","Le case non richiedono lavoratori e non producono merci. Controlla i posti occupati nel dialogo della casa oppure in alto nello schermo."],
		"cafe": ["coffee","Metti in moto il tuo primo negozio","Il caffè prepara bevande, biscotti e colazioni. L'affinità CIBO dei lavoratori rende i rifornimenti più rapidi.","Assegna da 1 a 3 cittadini: ogni lavoratore sblocca un prodotto. Paga Avvia rifornimento, attendi la preparazione e premi Riempi gli scaffali. Da quel momento le vendite generano monete automaticamente."],
		"garden": ["heart","Un orto che fa crescere il rifugio","L'orto vende pomodori, verdure e prodotti della dispensa. L'affinità CIBO aiuta a ridurre i tempi del rifornimento.","Assegna da 1 a 3 lavoratori, avvia un rifornimento e riempi gli scaffali quando è pronto. Le vendite portano monete. Chi sogna di lavorare nell'orto aumenta lo stock disponibile."],
		"workshop": ["build","Dal recupero a qualcosa di utile","L'officina prepara ricambi, attrezzi e kit di riparazione da vendere. L'affinità BENI dei lavoratori riduce i tempi di preparazione.","Ogni lavoratore sblocca un livello di prodotti, fino a 3. Avvia il rifornimento e, quando è pronto, riempi gli scaffali per cominciare a guadagnare monete. Il lavoro dei sogni dà un bonus allo stock."],
		"clinic": ["shield","Un servizio per la nuova comunità","Il pronto soccorso prepara bende, kit e medicinali da vendere. L'affinità SERVIZI rende i rifornimenti più efficienti.","Assegna fino a 3 cittadini, avvia la preparazione e riempi gli scaffali al termine: le vendite generano monete. Per curare un cittadino ferito, apri Cittadini e usa Cura: costa 5 provviste."]
	}
	var guide: Array = guides.get(str(b.type),["build","Un nuovo negozio per la comunità",str(Game.BUILDING_DESCRIPTIONS.get(str(b.type),"Un'attività per vendere merci nel rifugio.")),"Assegna da 1 a 3 lavoratori, rifornisci i prodotti sbloccati e riempi gli scaffali. Le vendite generano monete automaticamente. L'affinità %s riduce tempi e costi; il lavoro dei sogni aumenta lo stock." % _skill_name(str(b.type))])
	var col: VBoxContainer = _open("building_help",b.name,"A COSA SERVE QUESTO EDIFICIO",id)
	col.add_child(_copy(CozyRules.role(Game,str(b.type)),20,SAGE))
	var card: VBoxContainer = _card(col,SAGE)
	var row: HBoxContainer = _hbox(16)
	if str(b.type)=="residence":
		row.add_child(_icon("home",64))
	else:
		row.add_child(_product_icon(str(b.type),1,74))
	row.add_child(_copy(str(guide[1]),24,TEXT))
	card.add_child(row)
	card.add_child(_copy(str(guide[2]),18,TEXT))
	col.add_child(_copy(str(guide[3]),17))
	_fixed_actions().add_child(_button("Ho capito · Torna all'edificio",_return_to_building.bind(id),true))

func _show_assignment(bid: int) -> void:
	Workforce.show_shop(self,bid)

func _assign(cid: int, bid: int) -> void:
	Game.assign(cid,bid)
	_refresh_current()

func _citizen_header(parent: Node, c: Dictionary) -> void:
	Workforce.citizen_header(self,parent,c)

func _portrait(c: Dictionary, dimensions: Vector2) -> PanelContainer:
	var avatar: PanelContainer = PanelContainer.new()
	avatar.custom_minimum_size = dimensions
	avatar.add_theme_stylebox_override("panel",_style(Color("dce1bd"),Color("b1b686"),14,8))
	var portrait: TextureRect = TextureRect.new()
	# Shared identity mapping is exactly the one used by actors in the street.
	portrait.texture = ActorVisuals.texture(int(c.get("look",0)),0,false,str(c.get("appearance","clean")))
	portrait.set_meta("citizen_look",int(c.get("look",0)))
	portrait.set_meta("citizen_appearance",str(c.get("appearance","clean")))
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar.add_child(portrait)
	return avatar

func _show_citizens() -> void:
	set_selected_tab("citizens")
	var col: VBoxContainer = _open("citizens","Un rifugio fatto di persone","POPOLAZIONE  /  %d DI %d POSTI" % [Game.citizens.size(),Game.capacity()])
	_last_panel_signature = Workforce.signature(Game)
	col.add_child(_copy("%d abitanti · %d letti liberi · vendite +%d%% grazie alla comunità." % [Game.citizens.size(),maxi(0,Game.capacity()-Game.citizens.size()),roundi((Game.community_income_bonus()-1.0)*100)],18,SAGE))
	var citizen_grid: GridContainer = GridContainer.new()
	citizen_grid.columns = 2
	citizen_grid.set_meta("phone_grid",true)
	citizen_grid.add_theme_constant_override("h_separation",16)
	citizen_grid.add_theme_constant_override("v_separation",16)
	col.add_child(citizen_grid)
	for c in Game.citizens:
		var card: VBoxContainer = _card(citizen_grid)
		_citizen_header(card,c)
		var actions: HBoxContainer = _hbox(8)
		var work: Button = _button("Assegna lavoro",_show_job_select.bind(int(c.id)),false,true)
		work.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		work.disabled = c.get("away",false)
		actions.add_child(work)
		var gear: Button = _button("Arma e munizioni",_show_citizen_equipment.bind(int(c.id)),false,true)
		gear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gear.disabled = c.get("away",false)
		actions.add_child(gear)
		card.add_child(actions)
		var gear_row: HBoxContainer = _hbox(10)
		var weapon_key: String = str(c.get("weapon","pistol"))
		gear_row.add_child(_weapon_icon(weapon_key,Vector2(62,42)))
		gear_row.add_child(_label(str(Game.WEAPONS.get(weapon_key,Game.WEAPONS.pistol).name),15,SAGE,true))
		gear_row.add_child(_spacer())
		if int(c.get("hp",100))<100:
			var heal: Button = _cost_button("Cura",ResourceUI.costs(0,Game.healing_cost()),_heal.bind(int(c.id)),false,true)
			heal.disabled = c.get("away",false) or Game.supplies<Game.healing_cost()
			gear_row.add_child(heal)
		card.add_child(gear_row)
	if Game.citizens.is_empty():
		col.add_child(_copy("Il rifugio è silenzioso. Accogli i superstiti al cancello per ricominciare."))
	col.add_child(_button("Vai al cancello  →",_gate_focus,true))

func _show_citizen_equipment(cid: int, from_expedition: bool=false) -> void:
	_equipment_from_expedition = from_expedition
	CitizenEquipmentPanel.show_panel(self,cid)

func _equip_citizen(cid: int, key: String) -> void:
	Game.equip_citizen(cid,key)
	_show_citizen_equipment(cid,_equipment_from_expedition)

func _buy_citizen_weapon(cid: int, key: String) -> void:
	Game.buy_citizen_weapon(cid,key)
	_show_citizen_equipment(cid,_equipment_from_expedition)

func _buy_citizen_ammo(cid: int, key: String) -> void:
	Game.buy_citizen_ammo(cid,key)
	_show_citizen_equipment(cid,_equipment_from_expedition)

func _return_from_equipment() -> void:
	if _equipment_from_expedition:
		expedition_step = 2
		_restore_scroll_key = _panel_key("expeditions",2)
		_show_expeditions(true)
	else:
		_return_to_citizens()

func _heal(cid: int) -> void:
	Game.heal_citizen(cid)
	_show_citizens()

func _show_job_select(cid: int) -> void:
	Workforce.show_citizen(self,cid)

func _job_assign(cid: int, bid: int) -> void:
	Game.assign(cid,bid)
	_show_job_select(cid)

func _show_build() -> void:
	BuildPanel.show_catalog(self)

func _build_catalog_signature() -> String:
	return Game.tutorial_stage+":"+str(Game.active_construction().get("id",-1))

func _construction_focus(id: int) -> void:
	focus_city.emit()
	show_building(id)

func _build(kind: String) -> void:
	if Game.build(kind):
		_close_modal()
		focus_city.emit()
	else:
		_show_build()

func show_visitor(id: int) -> void:
	CozyPanel.visitor(self,id)

func _accept_visitor(id: int) -> void:
	if Game.accept_visitor(id):
		_close_modal()
	else:
		show_visitor(id)

func _reject_visitor(id: int) -> void:
	Game.reject_visitor(id)
	_close_modal()

func _show_expeditions(preserve_step: bool=false) -> void:
	ExpeditionPanel.show_panel(self,preserve_step)

func _set_expedition_step(step: int) -> void:
	expedition_step = clampi(step,0,2)
	_restore_scroll_key = _panel_key("expeditions",expedition_step)
	_show_expeditions()

func _select_zone(index: int) -> void:
	if index<0 or index>=Game.zones.size(): return
	selected_zone = index
	expedition_step = 1
	_show_expeditions()

func _select_member(id: int) -> void:
	if selected_members.has(id): selected_members.erase(id)
	elif selected_members.size()<3: selected_members.append(id)
	_show_expeditions()

func _launch_expedition() -> void:
	if Game.start_expedition(selected_zone,selected_members.duplicate()):
		selected_members.clear()
	_show_expeditions()

func _claim_expedition() -> void:
	if Game.claim_expedition(): expedition_step = 0
	_show_expeditions()

func _show_armory() -> void:
	ArmoryPanel.show_catalog(self)

func _show_weapon_details(key: String) -> void:
	ArmoryPanel.show_details(self,key)

func _return_to_armory() -> void:
	_restore_scroll_key = _panel_key("armory",-1)
	_show_armory()

func _equip_from_details(key: String) -> void:
	Game.equip_weapon(key)
	_show_weapon_details(key)

func _equip(key: String) -> void:
	Game.equip_weapon(key)
	_show_armory()

func _ammo() -> void:
	Game.buy_ammo()
	_show_armory()

func show_gate() -> void:
	var col: VBoxContainer = _open("gate","Da qui non si passa.","DIFESA DEL CANCELLO  /  LIVELLO %d" % int(Game.gate_level))
	var card: VBoxContainer = _card(col)
	_title_row(card,"La barricata","%d / %d INTEGRITÀ" % [int(Game.gate_hp),int(Game.gate_max)],SAGE)
	var bar: ProgressBar = _progress(SAGE,12)
	card.add_child(bar)
	bindings.append([bar,func(p: ProgressBar) -> void: p.value=Game.gate_hp/maxf(Game.gate_max,1)*100])
	card.add_child(_copy("I superstiti contano su queste mura. Riparale e rinforzale per difendere il rifugio dagli zombie."))
	var actions: HBoxContainer = _hbox(10)
	var repair: Button = _button("",_repair,true)
	repair.name = "GateRepair"
	repair.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_update_gate_action(repair,false)
	bindings.append([repair,_update_gate_action.bind(false)])
	actions.add_child(repair)
	var upgrade: Button = _button("",_upgrade,false)
	upgrade.name = "GateUpgrade"
	upgrade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_update_gate_action(upgrade,true)
	bindings.append([upgrade,_update_gate_action.bind(true)])
	actions.add_child(upgrade)
	_fixed_actions().add_child(actions)
	col.add_child(_label("Torretta presidiata  ·  %d zombie fuori dalle mura" % Game.threats.size(),17,TEXT,true))
	col.add_child(_copy("Il militare sulla torretta spara al tuo comando: tocca uno zombie. Per il mitragliatore puoi tenere premuto. I cittadini possono dedicarsi al lavoro e alle spedizioni.",14))
	col.add_child(_button("Scegli un'arma",_show_armory,false,true))
	var material_repair: Button = _cost_button("Ripara",ResourceUI.costs(0,0,2),_cozy_action.bind("repair_parts",-1),false,true)
	material_repair.name = "RepairWithMaterials"
	bindings.append([material_repair,func(button: Button) -> void: button.disabled = Game.community.parts<2 or Game.gate_hp>=Game.gate_max])
	col.add_child(material_repair)
	col.add_child(_copy("Gli attacchi si fermano mentre leggi i menu. Una breccia richiede al massimo 50 monete e 2 provviste: abitanti ed edifici restano al sicuro.",17,SAGE))
	_fixed_actions().add_child(_button("Al cancello. Si difende casa.  →",_gate_focus,true))

func _update_gate_action(button: Button, upgrade: bool) -> void:
	var cost: Dictionary = Game.gate_upgrade_cost() if upgrade else Game.repair_cost()
	_update_cost_button(button,"Potenzia" if upgrade else "Ripara",ResourceUI.costs(int(cost.coins),int(cost.supplies)),not upgrade)
	button.disabled = not Game.can_upgrade_gate() if upgrade else (Game.gate_hp>=Game.gate_max-0.01 or Game.coins<int(cost.coins) or Game.supplies<int(cost.supplies))

func _repair() -> void:
	Game.repair_gate()
	show_gate()

func _upgrade() -> void:
	Game.upgrade_gate()
	show_gate()

func _show_quests() -> void:
	CozyPanel.journal(self)

func _claim_quest(index: int) -> void:
	Game.claim_quest(index)
	_show_quests()

func show_help() -> void:
	var col: VBoxContainer = _open("help","La fine del mondo può aspettare.","MANUALE DI SOPRAVVIVENZA")
	var steps: Array = [
		["01","Difendi la porta","Tocca uno zombie: la guardia sulla torretta spara solo al tuo comando. La pistola ha munizioni infinite; le altre armi consumano scorte. Più persone sono presenti nel rifugio, più numerosi e frequenti diventano gli arrivi degli zombie. Le persone fuori dalle mura o in spedizione non contano."],
		["02","Fai entrare la vita","Tocca un superstite e usa Verifica il contagio per sapere con certezza se è sano: è gratis, dura 60 secondi (30 con il Taccuino medico) e non occupa letti. Sporco e graffi da soli non provano il contagio. Accogliere un infiltrato danneggia il cancello e fa comparire un nemico. Gli zombie lasciano in pace chi aspetta fuori; chi viene rifiutato riparte a piedi."],
		["03","Rimetti in moto i negozi","Apri un edificio e assegna fino a 3 lavoratori. Avvia un rifornimento, attendi e tocca Riempi gli scaffali. Le vendite generano monete nel tempo. Tieni premuto su un edificio o sulla sua insegna per aprire la conferma di demolizione."],
		["04","Trova il lavoro giusto","Desiderato indica il lavoro che una persona vorrebbe; Assegnato mostra l'incarico attuale. Le icone sono le stesse dei negozi in città. Assegna una persona libera o trasferiscila da un'altra attività. Il lavoro desiderato sblocca scorte ×2 una sola volta per negozio. Le persone in spedizione conservano il posto e tornano al lavoro al rientro."],
		["05","Guarda oltre le mura","Le spedizioni recuperano monete, provviste e colpi per la torretta. Esamina una destinazione per confrontare costo, ambiente, tempo e bottino; poi scegli da 1 a 3 cittadini. Alla partenza paghi provviste e consumi i colpi personali indicati. Tutti tornano, ma possono perdere salute e riportare meno risorse."],
		["06","Una persona, la sua arma","Da Arma e munizioni compri una copia per quel cittadino, con la prima scorta inclusa. Il pompa aiuta negli spazi stretti, la precisione negli spazi aperti e il mitragliatore nelle zone affollate. La pistola è gratuita e ha colpi infiniti. Le scorte personali si comprano separatamente da quelle della torretta; la squadra mostra consumo e probabilità prima della partenza."],
		["07","Il tuo ritmo","Nei menu gli zombie aspettano mentre produzioni e viaggi proseguono. Orto e officina preparano risorse per il rifugio. I servizi attivi richiedono un lavoratore presente. Dal diario segui quattro capitoli, scopri progetti in ogni destinazione e avvia scambi con i vicini. Puoi osservare gratuitamente una persona dubbia prima di accoglierla."],
		["08","Torna quando vuoi","Il gioco salva automaticamente. I negozi maturano vendite anche mentre sei via, fino a 8 ore. Trascina per esplorare; usa i pulsanti + / – per lo zoom e le frecce per spostare la visuale."]
	]
	for step in steps:
		var card: VBoxContainer = _card(col)
		_title_row(card,step[1],step[0])
		card.add_child(_copy(step[2],14))
	col.add_child(_button(("Torna alla pausa" if _phone_pause_return else "Ho capito") if DeviceLayout.android_phone() else "Va bene. Costruiamo qualcosa.  →",_dismiss_phone_page if DeviceLayout.android_phone() else _close_modal,true))

func show_main_menu() -> void:
	main_menu_active = true
	Game.paused = true
	_pause_owner = false
	_close_modal()
	hud.visible = false
	tutorial_panel.hide()
	zombie_alert.hide()
	_menu_had_save = FileAccess.file_exists(Game.save_path)
	if is_instance_valid(menu_layer):
		menu_layer.queue_free()
	menu_layer = Control.new()
	menu_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(menu_layer)
	var background: TextureRect = TextureRect.new()
	background.texture = load("res://assets/art/background.png")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_layer.add_child(background)
	var shade: ColorRect = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(.08,.24,.16,.24)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_layer.add_child(shade)
	if DeviceLayout.android_phone():
		PhonePages.main_menu(self)
		return
	var margin: MarginContainer = MarginContainer.new()
	_menu_margin = margin
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left","right"]:
		margin.add_theme_constant_override("margin_"+edge,76)
	for edge: String in ["top","bottom"]:
		margin.add_theme_constant_override("margin_"+edge,62)
	menu_layer.add_child(margin)
	var columns: HBoxContainer = _hbox(22 if DeviceLayout.mobile else 58)
	margin.add_child(columns)
	var hero: VBoxContainer = _vbox(14)
	_menu_hero = hero
	hero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	columns.add_child(hero)
	var overline: Label = _label("BENVENUTO AL RIFUGIO 07",16,Color("e8d5a5"),true)
	var brand_row: HBoxContainer = _hbox(15)
	var menu_mark: TextureRect = TextureRect.new()
	menu_mark.texture = preload("res://assets/icon.png")
	menu_mark.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	menu_mark.custom_minimum_size = Vector2(48,48) if DeviceLayout.mobile else Vector2(76,76)
	menu_mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	menu_mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	menu_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brand_row.add_child(menu_mark)
	overline.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brand_row.add_child(overline)
	if DeviceLayout.mobile: overline.hide()
	hero.add_child(brand_row)
	var logo: Label = _label("NIENTE ZOMBIE\nPER FAVORE!",38 if DeviceLayout.mobile else 66,LIGHT,true)
	logo.add_theme_color_override("font_shadow_color",Color(.10,.14,.10,.7))
	logo.add_theme_constant_override("shadow_offset_y",5)
	logo.add_theme_constant_override("outline_size",4)
	logo.add_theme_color_override("font_outline_color",WOOD)
	hero.add_child(logo)
	var tagline: Label = _copy("Un piccolo rifugio.\nUna grande voglia di ricominciare.",18 if DeviceLayout.mobile else 23,Color("eee7cd"))
	hero.add_child(tagline)
	var vignette: HBoxContainer = _hbox(12)
	hero.add_child(vignette)
	if DeviceLayout.mobile: vignette.hide()
	for item: Array in [["home","Costruisci"],["people","Accogli"],["shield","Difendi"]]:
		var badge: PanelContainer = PanelContainer.new()
		badge.custom_minimum_size = Vector2(143,117)
		badge.add_theme_stylebox_override("panel",_raised(Color("e2d5b9"),Color("8b825b"),19,false,12))
		var badge_col: VBoxContainer = _vbox(3)
		badge_col.alignment = BoxContainer.ALIGNMENT_CENTER
		var center: CenterContainer = CenterContainer.new()
		center.add_child(_icon(item[0],57))
		badge_col.add_child(center)
		var caption: Label = _label(item[1],18,TEXT,true)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge_col.add_child(caption)
		badge.add_child(badge_col)
		vignette.add_child(badge)
	var menu_center: CenterContainer = CenterContainer.new()
	menu_center.custom_minimum_size.x = 360 if DeviceLayout.mobile else 440
	if DeviceLayout.mobile:
		menu_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(menu_center)
	var cabinet: PanelContainer = PanelContainer.new()
	_menu_cabinet = cabinet
	cabinet.custom_minimum_size.x = 360 if DeviceLayout.mobile else 440
	cabinet.add_theme_stylebox_override("panel",_floating_group(4))
	menu_center.add_child(cabinet)
	var choices: VBoxContainer = _vbox(14 if DeviceLayout.mobile else 18)
	if DeviceLayout.mobile:
		# Every action remains reachable even with a navigation bar or a short tablet.
		cabinet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var scroll: ScrollContainer = ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		cabinet.add_child(scroll)
		choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(choices)
	else:
		cabinet.add_child(choices)
	var heading_row: HBoxContainer = _hbox(10)
	heading_row.add_child(_icon("coffee",43))
	var menu_titles: VBoxContainer = _vbox(1)
	menu_titles.add_child(_label("Bentornato, vicino.",26,LIGHT,true))
	menu_titles.add_child(_label("Facciamo spazio alla speranza.",14,CREAM))
	heading_row.add_child(menu_titles)
	choices.add_child(heading_row)
	if DeviceLayout.mobile: heading_row.hide()
	var play: Button = _button("Continua la partita  →" if _menu_had_save else "Gioca  →",_start_game,true)
	play.name = "PlayButton"
	play.custom_minimum_size.y = 66
	choices.add_child(play)
	choices.add_child(_button("Nuova partita",_confirm_reset))
	choices.add_child(_button("Impostazioni",_show_settings))
	choices.add_child(_button("Crediti",_show_credits))
	choices.add_child(_button("Esci",_quit_game,false,true))
	var footer: Label = _copy("Ogni piccolo passo conta.\nI tuoi progressi si salvano automaticamente.",13,CREAM)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choices.add_child(footer)
	if DeviceLayout.mobile:
		footer.hide()
		_layout_menu()
		_apply_mobile_controls.call_deferred()
	panel_changed.emit(true)
	main_menu_opened.emit()
	play.grab_focus()

func _start_game() -> void:
	main_menu_active = false
	_pause_owner = false
	_close_modal()
	if is_instance_valid(menu_layer):
		menu_layer.queue_free()
	menu_layer = null
	hud.visible = true
	Game.paused = false
	_update_hud()
	game_started.emit()
	_update_tutorial()
	if Game.tutorial_stage=="intro":
		_tutorial_minimized = false
		_show_tutorial_intro.call_deferred()

func _return_to_main_menu() -> void:
	Game.save_game()
	show_main_menu()

func _quit_game() -> void:
	Game.save_game()
	get_tree().quit()

func _show_settings() -> void:
	if not main_menu_active and not _pause_owner:
		_pause_before_modal = Game.paused
		_pause_owner = true
	Game.paused = true
	var col: VBoxContainer = _open("settings","A modo tuo","IMPOSTAZIONI  /  SALVATE AUTOMATICAMENTE")
	_settings_grid = GridContainer.new()
	_settings_grid.add_theme_constant_override("h_separation",12)
	_settings_grid.add_theme_constant_override("v_separation",10 if DeviceLayout.mobile else 14)
	_settings_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_settings_grid)
	var audio: VBoxContainer = _card(_settings_grid)
	audio.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_row(audio,"Audio" if DeviceLayout.android_phone() else "Un po' di quiete, un po' di coraggio.","" if DeviceLayout.android_phone() else "AUDIO")
	_settings_slider(audio,"Volume generale","master_volume",Preferences.master_volume)
	_settings_slider(audio,"Effetti e spari","effects_volume",Preferences.effects_volume)
	_settings_slider(audio,"Musica d'ambiente","music_volume",Preferences.music_volume)
	_settings_toggle(audio,"Audio attivo","sound_enabled",Preferences.sound_enabled)
	var display: VBoxContainer = _card(_settings_grid)
	display.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_row(display,"Schermo" if DeviceLayout.android_phone() else "Comodo da guardare.","" if DeviceLayout.android_phone() else "SCHERMO")
	display.add_child(_label("Dimensione interfaccia",18,TEXT,true))
	var sizes: HBoxContainer = _hbox(10)
	var size_group: ButtonGroup = ButtonGroup.new()
	for option: Array in [["compact","Compatta"],["medium","Media"],["large","Grande"]]:
		var size_button: Button = _button(option[1],_set_interface_size.bind(option[0]),false,true)
		size_button.name = "InterfaceSize_"+str(option[0])
		size_button.toggle_mode = true
		size_button.button_group = size_group
		size_button.button_pressed = Preferences.interface_size==option[0]
		size_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sizes.add_child(size_button)
	display.add_child(sizes)
	display.add_child(_copy("Regola la grandezza di testi, finestre e pulsanti.",14))
	_settings_toggle(display,"Scuotimento della visuale","screen_shake",Preferences.screen_shake)
	_settings_toggle(display,"Riduci le animazioni","reduced_motion",Preferences.reduced_motion)
	if DisplayPerformance.android:
		_settings_toggle(display,"Fluidità fino a 120 Hz","android_high_refresh",Preferences.android_high_refresh)
		display.add_child(_copy("Sì: fino a 120 Hz · No: 60 Hz, meno consumi. La frequenza effettiva dipende dal dispositivo e dal risparmio energetico.",14))
	if DeviceLayout.mobile:
		display.add_child(_copy("Schermo intero automatico · interfaccia adattata al dispositivo",17,SAGE))
	else:
		_settings_toggle(display,"Schermo intero","fullscreen",Preferences.fullscreen)
	if not DeviceLayout.android_phone(): _fixed_actions().add_child(_button("Fatto  →",_close_modal,true))
	_layout_settings_grid()

func _layout_settings_grid() -> void:
	if not is_instance_valid(_settings_grid): return
	_settings_grid.columns = 2 if DeviceLayout.android_phone() and DeviceLayout.safe_rect().size.x>=900 else 1

func _set_interface_size(value: String) -> void:
	Preferences.apply_settings({"interface_size":value})
	if is_instance_valid(modal_scroll):
		_reveal_interface_size.call_deferred(modal_scroll.get_instance_id(),value)

func _reveal_interface_size(scroll_id: int, value: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_id_valid(scroll_id) or modal_scroll!=instance_from_id(scroll_id): return
	var choice: Control = modal.find_child("InterfaceSize_"+value,true,false)
	if choice!=null: modal_scroll.ensure_control_visible(choice)

func _settings_slider(parent: Node, caption: String, key: String, current: float) -> void:
	var row: HBoxContainer = _hbox(20)
	row.custom_minimum_size.y = 52
	var caption_label: Label = _label(caption,17,TEXT,true)
	if DeviceLayout.android_phone():
		var group: VBoxContainer = _vbox(2)
		parent.add_child(group)
		group.add_child(caption_label)
		group.add_child(row)
	else: row.add_child(caption_label)
	var slider: HSlider = HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = roundf(current*100.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size.x = 220
	slider.custom_minimum_size.y = 38
	if DeviceLayout.mobile:
		row.custom_minimum_size.y = DeviceLayout.TOUCH_TARGET
		slider.custom_minimum_size.y = 64
	if DeviceLayout.android_phone():
		row.custom_minimum_size.y = 56
		slider.custom_minimum_size = Vector2(160,56)
	slider.add_theme_stylebox_override("slider",_style(Color("d3c19c"),Color("c4aa7b"),7,5))
	slider.add_theme_stylebox_override("grabber_area",_style(Color("9ab378"),Color("7b965b"),7,5))
	slider.add_theme_stylebox_override("grabber_area_highlight",_style(Color("b1c78e"),Color("7b965b"),7,5))
	var knob: GradientTexture2D = GradientTexture2D.new()
	knob.width = 32
	knob.height = 32
	if DeviceLayout.mobile:
		knob.width = 48
		knob.height = 48
	knob.fill = GradientTexture2D.FILL_RADIAL
	knob.fill_from = Vector2(.5,.5)
	knob.fill_to = Vector2(1,.5)
	var knob_gradient: Gradient = Gradient.new()
	knob_gradient.offsets = PackedFloat32Array([0,.52,.70,.78,.88,1])
	knob_gradient.colors = PackedColorArray([Color("fff2ce"),Color("f4d28a"),Color("dab363"),Color("997240"),Color("997240"),Color(0,0,0,0)])
	knob.gradient = knob_gradient
	slider.add_theme_icon_override("grabber",knob)
	slider.add_theme_icon_override("grabber_highlight",knob)
	slider.add_theme_icon_override("grabber_disabled",knob)
	var value: Label = _label("%d%%" % int(slider.value),17,SAGE,true)
	value.custom_minimum_size.x = 56
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slider.value_changed.connect(func(amount: float) -> void:
		value.text = "%d%%" % int(amount)
		Preferences.apply_settings({key:amount/100.0})
	)
	if not DeviceLayout.android_phone(): row.add_child(_spacer())
	row.add_child(slider)
	row.add_child(value)
	if not DeviceLayout.android_phone(): parent.add_child(row)

func _settings_toggle(parent: Node, caption: String, key: String, current: bool) -> void:
	var row: HBoxContainer = _hbox(12)
	row.add_child(_label(caption,17,TEXT,true))
	row.add_child(_spacer())
	var toggle: Button = _button("Sì" if current else "No",func() -> void: pass,false,true)
	toggle.name = "Setting_"+key
	toggle.custom_minimum_size.x = 95
	toggle.toggle_mode = true
	toggle.button_pressed = current
	toggle.add_theme_stylebox_override("pressed",_raised(HONEY,Color("b88a3e"),14,true))
	toggle.toggled.connect(func(enabled: bool) -> void:
		toggle.text = "Sì" if enabled else "No"
		Preferences.apply_settings({key:enabled})
	)
	row.add_child(toggle)
	parent.add_child(row)

func _show_credits() -> void:
	var col: VBoxContainer = _open("credits","Nessun rifugio si costruisce da soli.","CREDITI  /  GRAZIE PER ESSERE QUI")
	var card: VBoxContainer = _card(col)
	_title_row(card,"Niente Zombie Per Favore!","RIFUGIO 07")
	card.add_child(_copy("Un piccolo gioco di persone, seconde possibilità e caffè caldo. Un progetto indipendente realizzato insieme a Codex.",17,TEXT))
	var sources: Array = [
		["Motore","Godot Engine 4.5 — licenza MIT. godotengine.org"],
		["Caratteri","Fredoka — The Fredoka Project Authors. Nunito Sans — The Nunito Sans Project Authors. Entrambi distribuiti con SIL Open Font License 1.1."],
		["Illustrazioni","Personaggi, edifici, paesaggio e icone creati per il progetto con OpenAI ImageGen. Composizione e animazione originali del progetto."],
		["Registrazioni di gioco","Spari, ricariche e versi degli zombie forniti dal creatore del progetto, che ne ha dichiarato la libera distribuzione. Montaggio e integrazione audio realizzati per il gioco."],
		["Interfaccia e impatti","Kenney (CC0). Ambiente musicale originale del progetto. Fonti e dettagli in docs/AUDIO_LICENSES.md."]
	]
	for source: Array in sources:
		var entry: VBoxContainer = _card(col)
		entry.add_child(_label(source[0],19,SAGE,true))
		entry.add_child(_copy(source[1],15))
	_fixed_actions().add_child(_button("Torna al rifugio  →",_close_modal,true))

func _show_pause() -> void:
	if main_menu_active:
		return
	if not _pause_owner:
		_pause_before_modal = Game.paused
		_pause_owner = true
	Game.paused = true
	CozyPanel.pause(self)

func _resume_from_pause() -> void:
	_pause_before_modal = false
	_close_modal()
	Game.paused = false

func _pause_options(page: String) -> void:
	_phone_pause_return = true
	if page=="settings": _show_settings()
	else: show_help()

func _dismiss_phone_page() -> void:
	if _phone_pause_return:
		_phone_pause_return = false
		_show_pause()
	elif panel_kind=="pause": _resume_from_pause()
	else: _close_modal()

func _save_from_pause() -> void:
	var saved: bool = Game.save_game()
	var status: Label = modal_content.find_child("PauseSaveStatus",true,false) as Label
	if is_instance_valid(status):
		status.text = "Partita salvata." if saved else "Salvataggio non riuscito. Riprova."
		status.add_theme_color_override("font_color",SAGE if saved else RED)

func _save() -> void:
	Game.save_game()
	_show_toast("Rifugio salvato. Ci ritroviamo qui.")

func _confirm_reset() -> void:
	var col: VBoxContainer = _open("reset","Un nuovo inizio?","RICOMINCIA LA PARTITA")
	col.add_child(_copy("Questo sostituirà la partita salvata con un nuovo rifugio. I progressi attuali verranno persi.",18,TEXT))
	col.add_child(_button("Annulla, conserva il rifugio",_close_modal,true))
	col.add_child(_button("Sì, ricomincia da zero",func() -> void:
		for notification: Node in toast_stack.get_children():
			toast_stack.remove_child(notification)
			notification.queue_free()
		Game.reset_game()
		_seen_zombies.clear()
		_start_game()
	,false))

func _show_toast(message: String) -> void:
	if not is_instance_valid(toast_stack): return
	while toast_stack.get_child_count()>=(1 if DeviceLayout.mobile else 3):
		var old: Node = toast_stack.get_child(0)
		toast_stack.remove_child(old)
		old.queue_free()
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel",_raised(CREAM,WOOD_EDGE,14,false,12))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l: Label = _copy(message,14,TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	toast_stack.add_child(p)
	p.modulate.a = 0
	var tween: Tween = create_tween().bind_node(p)
	tween.tween_property(p,"modulate:a",1.0,.18)
	tween.tween_interval(4.4)
	tween.tween_property(p,"modulate:a",0.0,.35)
	tween.tween_callback(func() -> void:
		if is_instance_valid(p): p.queue_free()
	)

func _on_wave_started() -> void:
	_update_zombie_alert()

func flash_damage() -> void:
	if not is_instance_valid(damage_overlay): return
	damage_overlay.color.a = .17
	var t: Tween = create_tween()
	t.tween_property(damage_overlay,"color:a",0.0,.4)


func _cozy_tab(scope: String, key: String) -> void:
	if is_instance_valid(modal_scroll): modal_scroll.scroll_vertical = 0
	if scope=="building":
		building_tab = key
		show_building(panel_id)
	else:
		journal_tab = key
		_show_quests()

func _cozy_ask(id: int, question: String) -> void:
	CozyRules.ask(Game,id,question)
	show_visitor(id)

func _cozy_action(action: String, id: int=-1) -> void:
	match action:
		"service": CozyRules.service(Game,id)
		"storage": CozyRules.upgrade(Game,id,false)
		"auto": CozyRules.upgrade(Game,id,true)
		"project": CozyRules.complete_project(Game)
		"deliver": CozyRules.deliver(Game)
		"observe": CozyRules.observe(Game,id)
		"batch": Game.batch_production(id,false)
		"expose": Game.batch_production(id,true)
		"repair_parts": Game.repair_with_materials()
	if panel_kind=="visitor": show_visitor(id)
	else: _refresh_current()

func world_input_blocked(point: Vector2) -> bool:
	if main_menu_active or is_instance_valid(modal): return true
	for control: Node in root.find_children("*","Control",true,false):
		if not control.is_visible_in_tree(): continue
		if control.mouse_filter==Control.MOUSE_FILTER_IGNORE: continue
		if not control is BaseButton and not control.has_meta("hud_card"): continue
		var local: Vector2 = control.get_global_transform_with_canvas().affine_inverse()*point
		if Rect2(Vector2.ZERO,control.size).has_point(local): return true
	return false
