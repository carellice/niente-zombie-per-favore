extends Control
## Presentation and input. All persistent gameplay lives in the Game autoload.

const WorldTouch = preload("res://scripts/world_touch.gd")
const UI = preload("res://scripts/game_ui.gd")
const Typography = preload("res://scripts/typography.gd")
const ActorVisuals = preload("res://scripts/actor_visuals.gd")
const GaitMotion = preload("res://scripts/gait_motion.gd")
const WalkingRig = preload("res://scripts/walking_rig.gd")
const SoundBank = preload("res://scripts/sound_bank.gd")
const PointerFeedback = preload("res://scripts/pointer_feedback.gd")
const ZombieSoundscape = preload("res://scripts/zombie_soundscape.gd")
const TargetOutline = preload("res://scripts/target_outline.gd")
const BuildingFeedback = preload("res://scripts/building_feedback.gd")
const CitizenRoaming = preload("res://scripts/citizen_roaming.gd")
const ConstructionVisual = preload("res://scripts/construction_visual.gd")
const BuildingSignage = preload("res://scripts/building_signage.gd")
const Activity = preload("res://scripts/activity_indicator.gd")
const Chrome = preload("res://scripts/ui_chrome.gd")
var _sky_fade: Texture2D = Chrome.fade_texture(Color(0.07,0.12,0.13,0.34),Color(0.07,0.12,0.13,0.0))
var _ground_fade: Texture2D = Chrome.fade_texture(Color(0.04,0.08,0.08,0.0),Color(0.04,0.08,0.08,0.42))
const CITY_START = 600.0
const LOT_STEP = 330.0
const EXPANSION_RECT = Rect2(20.0, -210.0, 240.0, 210.0)
const CHECKPOINT_LEFT = 245.0
const CHECKPOINT_HEIGHT = 510.0
const BUILDING_HOLD_SECONDS = 0.65
const BUILDING_HOLD_SLOP = 8.0
const CREAM = Color("eee8d6")
const GOLD = Color("efc46d")
const SAGE = Color("a6bd95")
const INK = Color("1b292b")
var heading: Font
var body: Font
var background: Texture2D
var checkpoint: Texture2D
var road: Texture2D
var building_art: Array[Texture2D] = []
var extra_building_art: Dictionary = {}
var character_art: Array[Texture2D] = []
var ui: CanvasLayer
var camera_x: float = -150.0
var target_camera: float = -150.0
var zoom: float = 0.82
var target_zoom: float = 0.82
var _phone_layout_active: bool = false
var _last_phone_overview: float = 0.0
var elapsed: float = 0.0
var actor_clock: float = 0.0
var actor_gaits: Dictionary = {}
var citizen_roaming: RefCounted = CitizenRoaming.new()
var drag_start: Vector2
var drag_camera: float = 0.0
var dragging: bool = false
var drag_distance: float = 0.0
var panel_open: bool = false
var hover: String = ""
var particles: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var last_coins: float = 0.0
var shake: float = 0.0
var last_gate_hp: float = 0.0
var sound_enabled: bool = true
var audio_pool: Array[AudioStreamPlayer] = []
var ambience_player: AudioStreamPlayer
var character_ambience: Node
var capture_path: String = ""
var capture_clock: float = 0.0
var touch_points: Dictionary = {}
var world_touch = WorldTouch.new()
var pinch_distance: float = 0.0
var hit_flashes: Dictionary = {}
var guard_flashes: Dictionary = {}
var in_main_menu: bool = false
var camera_transition: Dictionary = {}
var reload_queue: Array[Dictionary] = []
var smg_held: bool = false
var held_pointer: Vector2 = Vector2.ZERO
var target_outlines: Dictionary = {}
var building_feedback = BuildingFeedback.new()
var community_radio: Texture2D = preload("res://assets/art/community-radio.png")
var _world_pointer_active: bool = false
var _building_hold: Dictionary = {}
var _suppress_world_release: bool = false
var _world_release_serial: int = 0

func _ready() -> void:
	_sync_device_layout()
	DeviceLayout.changed.connect(_sync_device_layout)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().mouse_exited.connect(_on_pointer_exited)
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--fresh-preview":
			Game.save_path = "user://preview-save.json"
			Game._new_game()
			Game.paused = true
	heading = Typography.heading()
	body = Typography.body()
	_load_art()
	ui = UI.new()
	ui.visible_zombies = _visible_zombie_ids
	add_child(ui)
	add_child(PointerFeedback.new())
	character_ambience = ZombieSoundscape.new()
	add_child(character_ambience)
	character_ambience.setup(self)
	ui.panel_changed.connect(character_ambience.on_panel_changed)
	ui.focus_gate.connect(focus_gate)
	ui.focus_defense.connect(focus_defense)
	ui.focus_city.connect(focus_city)
	ui.panel_changed.connect(func(opened: bool):
		panel_open = opened
		if opened:
			world_touch.cancel(self)
			hover = ""
			_cancel_building_hold(true)
			dragging = false
	)
	ui.sound_toggled.connect(func(enabled: bool): sound_enabled = enabled)
	ui.zoom_requested.connect(_zoom_button)
	ui.camera_pan.connect(_pan_button)
	ui.game_started.connect(_on_game_started)
	ui.main_menu_opened.connect(_on_main_menu_opened)
	Game.sfx.connect(_play_sound)
	Game.shot_fired.connect(func(id: int, _damage: float): hit_flashes[id] = 0.16)
	Game.guard_fired.connect(_on_guard_fired)
	Game.reload_started.connect(_on_reload_started)
	Game.building_completed.connect(func(id: int) -> void: building_feedback.click(id))
	Game.building_demolished.connect(_on_building_demolished)
	Game.visitor_lost.connect(_on_visitor_lost)
	last_coins = Game.coins
	last_gate_hp = Game.gate_hp
	_setup_audio()
	Preferences.changed.connect(_apply_preferences)
	_apply_preferences()
	var skip_menu: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg in ["--skip-menu","--fresh-preview"]:
			skip_menu = true
		if arg.begins_with("--capture="):
			capture_path = arg.trim_prefix("--capture=")
			ui.toast_stack.visible = false
		if arg == "--live-preview":
			Game.paused = false
		if arg == "--preview-city":
			target_camera = 180.0
			camera_x = 180.0
		if arg == "--preview-citizens":
			ui.call_deferred("_navigate", "citizens")
		if arg == "--preview-build":
			ui.call_deferred("_navigate", "build")
		if arg == "--preview-admission" and not Game.visitors.is_empty():
			Game.paused = true
			ui.call_deferred("show_visitor",int(Game.visitors[0].id))
		if arg == "--preview-gate":
			target_camera = -420.0
			camera_x = target_camera
			target_zoom = _view_zoom(1.0)
			zoom = target_zoom
	if not skip_menu:
		Game.paused = true
		in_main_menu = true
		ui.call_deferred("show_main_menu")
	queue_redraw()
	_report_world_view()

func _on_game_started() -> void:
	world_touch.cancel(self,true)
	_cancel_building_hold(true)
	dragging = false
	touch_points.clear()
	in_main_menu = false
	Game.paused = false
	shots.clear()
	particles.clear()
	hit_flashes.clear()
	guard_flashes.clear()
	actor_gaits.clear()
	reload_queue.clear()
	smg_held = false
	camera_transition.clear()
	building_feedback.reset()
	hover = ""
	_clear_target_outlines()
	if Game.tutorial_stage == "intro":
		citizen_roaming.reset()
		character_ambience.reset()
		camera_x = -420.0
		target_camera = camera_x
		zoom = _view_zoom(0.82)
		target_zoom = zoom
	_report_world_view()
	last_coins = Game.coins
	last_gate_hp = Game.gate_hp

func _load_art() -> void:
	if ResourceLoader.exists("res://assets/art/background.png"):
		background = load("res://assets/art/background.png")
	if ResourceLoader.exists("res://assets/art/checkpoint.png"):
		checkpoint = load("res://assets/art/checkpoint.png")
	if ResourceLoader.exists("res://assets/art/road-painted.png"):
		road = load("res://assets/art/road-painted.png")
	building_art = _sheet("res://assets/art/settlement.png", 3, 2)
	for kind: String in ["bakery","waterworks","tailor"]:
		var path: String = "res://assets/art/buildings/%s.png" % kind
		if ResourceLoader.exists(path):
			var texture: Texture2D = load(path)
			var region: Rect2i = texture.get_image().get_used_rect()
			if region.has_area():
				var trimmed: AtlasTexture = AtlasTexture.new()
				trimmed.atlas = texture
				trimmed.region = Rect2(region)
				trimmed.filter_clip = true
				extra_building_art[kind] = trimmed
	character_art = _sheet("res://assets/art/characters.png", 8, 4)
	var feedback_textures: Array[Texture2D] = building_art.duplicate()
	for texture: Texture2D in extra_building_art.values():
		feedback_textures.append(texture)
	building_feedback.prepare(feedback_textures)
	for kind: String in Game.BUILDING_NAMES:
		BuildingSignage.texture(kind)

func _sheet(path: String, columns: int, rows: int) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	if not ResourceLoader.exists(path):
		return result
	var texture: Texture2D = load(path)
	var image: Image = texture.get_image()
	var cell: Vector2i = Vector2i(image.get_width() / columns, image.get_height() / rows)
	var row_edges: Array[int] = [0, 304, 560, 800, 1024]
	var actor_bounds: Array = [
		[Rect2i(26,58,142,227),Rect2i(228,51,118,234),Rect2i(394,46,155,239),Rect2i(588,52,130,234),Rect2i(761,49,176,238),Rect2i(949,60,168,226),Rect2i(1131,56,147,230),Rect2i(1299,35,225,253)],
		[Rect2i(29,320,138,218),Rect2i(211,313,138,225),Rect2i(395,310,156,229),Rect2i(591,316,129,226),Rect2i(768,314,179,229),Rect2i(945,322,170,222),Rect2i(1120,318,173,226),Rect2i(1305,302,219,239)],
		[Rect2i(31,575,136,211),Rect2i(206,568,139,219),Rect2i(401,565,150,221),Rect2i(587,570,132,218),Rect2i(769,569,173,220),Rect2i(938,583,179,208),Rect2i(1120,572,167,220),Rect2i(1305,554,219,233)],
		[Rect2i(19,813,181,194),Rect2i(218,808,165,198),Rect2i(396,801,192,206),Rect2i(589,813,144,194),Rect2i(762,806,195,202),Rect2i(961,817,171,191),Rect2i(1150,825,157,180),Rect2i(1310,799,221,207)]
	]
	for row: int in range(rows):
		for col: int in range(columns):
			var source: Rect2i = Rect2i(Vector2i(col, row) * cell, cell)
			if columns == 8 and image.get_height() == 1024:
				source = Rect2i(col*cell.x, row_edges[row], cell.x, row_edges[row+1]-row_edges[row])
				if row < actor_bounds.size():
					source = actor_bounds[row][col]
			var bounds: Rect2i = image.get_region(source).get_used_rect()
			if bounds.size.x < 2 or bounds.size.y < 2:
				bounds = Rect2i(Vector2i.ZERO, cell)
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(source.position + bounds.position, bounds.size)
			atlas.filter_clip = true
			result.append(atlas)
	return result

func _process(delta: float) -> void:
	elapsed += delta
	world_touch.advance(self,delta)
	_update_building_hold(delta)
	if not Game.paused:
		actor_clock += delta
		citizen_roaming.advance(Game.citizens,_roaming_width(),Game.CITIZEN_WALK_SPEED,delta)
		_update_actor_gaits(delta)
	_update_camera(delta)
	ui.set_world_context(camera_x < -300.0)
	_update_building_feedback(delta)
	_report_world_view()
	_update_held_fire()
	_update_reload_audio(delta)
	shake = maxf(0.0, shake - delta * 20.0)
	for id: Variant in hit_flashes.keys():
		hit_flashes[id] -= delta
		if hit_flashes[id] <= 0.0:
			hit_flashes.erase(id)
	for id: Variant in guard_flashes.keys():
		guard_flashes[id] -= delta
		if guard_flashes[id] <= 0.0:
			guard_flashes.erase(id)
	if Game.gate_hp < last_gate_hp:
		shake = 4.0
		ui.flash_damage()
	last_gate_hp = Game.gate_hp
	if Game.coins - last_coins >= 3.0:
		var bidx: int = randi_range(0, maxi(Game.buildings.size() - 1, 0))
		particles.append({"x":_city_start() + bidx * _lot_step() + 150.0*DeviceLayout.building_scale(),"y":_ground() - 85.0,"life":1.6,"text":"+%d" % int(Game.coins - last_coins),"color":GOLD})
		last_coins = Game.coins
	elif Game.coins < last_coins:
		last_coins = Game.coins
	for p: Dictionary in particles:
		p.life -= delta
		p.y -= delta * 26.0
	particles = particles.filter(func(p: Dictionary): return p.life > 0.0)
	for shot: Dictionary in shots:
		shot.life -= delta
	shots = shots.filter(func(s: Dictionary): return s.life > 0.0)
	if not Preferences.screen_shake:
		shake = 0.0
	# Match the final hit/walk pose after shots and expired hit flashes.
	_sync_target_outlines()
	if not capture_path.is_empty():
		capture_clock += delta
		if capture_clock > 2.0:
			var destination: String = capture_path
			capture_path = ""
			await RenderingServer.frame_post_draw
			var screenshot: Image = get_viewport().get_texture().get_image()
			var error: Error = screenshot.save_png(destination)
			print("CAPTURE ", destination, " ", error)
			get_tree().quit()
	queue_redraw()

func _roaming_width() -> float:
	return maxf(Game.buildings.size()*LOT_STEP-50.0,100.0)

func _citizen_world_x(citizen: Dictionary) -> float:
	var id: int = int(citizen.id)
	if int(citizen.get("job",-1)) >= 0:
		return _city_start()+_building_index(int(citizen.job))*_lot_step()+(65.0+id%3*58.0)*DeviceLayout.building_scale()
	return _city_start()+citizen_roaming.position(id,_roaming_width())*DeviceLayout.building_scale()

func _visible_zombie_ids() -> Array[int]:
	var visible_ids: Array[int] = []
	if in_main_menu or (panel_open and DeviceLayout.android_phone()): return visible_ids
	var viewport_rect: Rect2 = Rect2(Vector2.ZERO,size)
	for enemy: Dictionary in Game.threats:
		var column: int = _enemy_column(enemy)
		var height: float = (108.0 if column==7 else 80.0)*_actor_zoom()
		var source: Rect2i = ActorVisuals.source_bounds(column,_is_zombie(enemy))
		var width: float = height*float(source.size.x)/maxf(1.0,float(source.size.y))
		var bounds: Rect2 = Rect2(_sx(float(enemy.x))-width*0.5,_ground()+7.0-height,width,height)
		if viewport_rect.intersects(bounds): visible_ids.append(int(enemy.id))
	return visible_ids

func _enemy_column(enemy: Dictionary) -> int:
	match str(enemy.kind):
		"runner": return 6
		"brute": return 7
		"infiltrator": return ActorVisuals.civilian_column(int(enemy.get("look",1)))
	return 5

func _is_zombie(enemy: Dictionary) -> bool:
	return str(enemy.kind) != "infiltrator"

func _update_actor_gaits(delta: float) -> void:
	var present: Dictionary = {}
	for citizen: Dictionary in Game.citizens:
		if citizen.get("away",false) or citizen.get("guard",false):
			continue
		var key: String = "citizen:%d" % int(citizen.id)
		present[key] = true
		var placement: int = int(citizen.get("job",-1))
		if actor_gaits.has(key) and int(actor_gaits[key].get("placement",placement)) != placement:
			actor_gaits.erase(key)
		_advance_gait(key,_citizen_world_x(citizen),int(citizen.get("look",0)),70.0*DeviceLayout.actor_scale(),false,delta)
		actor_gaits[key].placement = placement
	for visitor: Dictionary in Game.visitors:
		var key: String = "visitor:%d" % int(visitor.id)
		present[key] = true
		_advance_gait(key,float(visitor.x),int(visitor.citizen.get("look",0)),78.0*DeviceLayout.actor_scale(),false,delta)
	# Rejection changes the destination, never the actor or its walking phase.
	for visitor: Dictionary in Game.departing_visitors:
		var key: String = "visitor:%d" % int(visitor.id)
		present[key] = true
		_advance_gait(key,float(visitor.x),int(visitor.citizen.get("look",0)),78.0*DeviceLayout.actor_scale(),false,delta)
	for enemy: Dictionary in Game.threats:
		var key: String = "enemy:%d" % int(enemy.id)
		var column: int = _enemy_column(enemy)
		present[key] = true
		_advance_gait(key,float(enemy.x),column,(108.0 if column == 7 else 80.0)*DeviceLayout.actor_scale(),_is_zombie(enemy),delta)
	for key: String in actor_gaits.keys():
		if not present.has(key):
			actor_gaits.erase(key)

func _advance_gait(key: String, world_x: float, look: int, height: float, zombie: bool, delta: float) -> void:
	if not actor_gaits.has(key):
		actor_gaits[key] = {"phase": fposmod(float(key.hash())*0.137,1.0), "x": world_x, "blend": 0.0}
	var gait: Dictionary = actor_gaits[key]
	var distance: float = absf(world_x - float(gait.x))
	# Assigning a job relocates actors; ordinary steps use actual world distance.
	var moving: bool = distance > 0.0001 and distance < maxf(140.0,delta*150.0)
	if moving:
		gait.phase = fposmod(float(gait.phase)+distance/(GaitMotion.stride_length(look,zombie)*height),1.0)
	gait.blend = move_toward(float(gait.blend),1.0 if moving else 0.0,delta*8.0)
	gait.x = world_x

func _actor_gait(key: String) -> Dictionary:
	return actor_gaits.get(key,{"phase":0.0,"blend":0.0})

func _scaled_zoom(value: float) -> float:
	return value*_phone_overview_zoom()/0.98 if DeviceLayout.android_phone() else value

func _actor_zoom() -> float:
	return zoom*DeviceLayout.actor_scale()

func _building_zoom() -> float:
	return zoom*DeviceLayout.building_scale()

func _city_start() -> float:
	return CHECKPOINT_LEFT+CHECKPOINT_HEIGHT*2.0/3.0*DeviceLayout.gate_scale()+36.0 if DeviceLayout.android_phone() else CITY_START

func _lot_step() -> float:
	return LOT_STEP*DeviceLayout.building_scale()

func _phone_overview_zoom() -> float:
	# Fit the tallest art AND its sign between the HUD and the street labels.
	var top: float = (DeviceLayout.safe_rect().position.y+DeviceLayout.PHONE_HEADER_HEIGHT+12.0)*DeviceLayout.ui_scale()
	var available: float = maxf(150.0,_ground()-top)
	var buildings_fit: float = (available-62.0)/(325.0*DeviceLayout.building_scale())
	var gate_fit: float = (available-110.0)/(385.0*DeviceLayout.gate_scale())
	var guard_fit: float = available/(237.0*DeviceLayout.gate_scale()+82.0*DeviceLayout.actor_scale())
	return clampf(minf(buildings_fit,minf(gate_fit,guard_fit)),0.3,1.1)

func _view_zoom(desktop_zoom: float) -> float:
	return _phone_overview_zoom() if DeviceLayout.android_phone() else desktop_zoom

func _zoom_min() -> float:
	return _phone_overview_zoom() if DeviceLayout.android_phone() else 0.6

func _zoom_max() -> float:
	return _phone_overview_zoom()*1.8 if DeviceLayout.android_phone() else 1.25

func _clamp_zoom(value: float) -> float:
	return clampf(value,_zoom_min(),_zoom_max())

func _sync_device_layout() -> void:
	world_touch.cancel(self)
	_cancel_building_hold(true)
	var phone: bool = DeviceLayout.android_phone()
	var overview: float = _phone_overview_zoom() if phone else 0.0
	if phone:
		if _phone_layout_active and _last_phone_overview>0:
			var ratio: float = overview/_last_phone_overview
			zoom *= ratio
			target_zoom *= ratio
			if not camera_transition.is_empty(): camera_transition.from_zoom *= ratio
		else:
			zoom = overview
			target_zoom = overview
	elif _phone_layout_active:
		zoom = 0.82
		target_zoom = zoom
	_phone_layout_active = phone
	_last_phone_overview = overview
	if is_node_ready():
		_limit_camera()
		_report_world_view()
	queue_redraw()

func _update_camera(delta: float) -> void:
	if not camera_transition.is_empty():
		camera_transition.elapsed = minf(float(camera_transition.elapsed)+delta,float(camera_transition.duration))
		var t: float = float(camera_transition.elapsed)/float(camera_transition.duration)
		var weight: float = smoothstep(0.0,1.0,t)
		camera_x = lerpf(float(camera_transition.from_x),target_camera,weight)
		zoom = lerpf(float(camera_transition.from_zoom),target_zoom,weight)
		if t>=1.0:
			camera_transition.clear()
	else:
		camera_x = lerpf(camera_x,target_camera,1.0-exp(-delta*9.0))
		zoom = lerpf(zoom,target_zoom,1.0-exp(-delta*8.0))

func _report_world_view() -> void:
	# Spawns stay beyond the furthest reachable left edge, including a pan
	# already in flight. Opening the village or zooming cannot reveal a pop-in.
	var left: float = minf(-850.0,minf(camera_x,target_camera))
	var right: float = maxf(camera_x+size.x/maxf(zoom,0.1),target_camera+size.x/maxf(target_zoom,0.1))
	Game.set_world_view(left,right)
	Game.set_visitor_spacing(54.0*DeviceLayout.actor_scale())

func _cancel_camera_transition() -> void:
	world_touch.cancel(self)
	_cancel_building_hold(true)
	if not camera_transition.is_empty():
		camera_transition.clear()
		target_camera = camera_x
		target_zoom = zoom

func _ground() -> float:
	if DeviceLayout.mobile:
		var bottom_inset: float = DeviceLayout.ui_size().y-DeviceLayout.safe_rect().end.y
		if DeviceLayout.android_phone():
			# A fixed street baseline: camera movement is exclusively horizontal.
			return size.y-(DeviceLayout.PHONE_FOOTER_HEIGHT+bottom_inset)*DeviceLayout.ui_scale()-136.0
		return minf(size.y-270.0,size.y-(DeviceLayout.PHONE_FOOTER_HEIGHT+bottom_inset)*DeviceLayout.ui_scale()-100.0)
	return size.y - 270.0

func _sx(world_x: float) -> float:
	return (world_x - camera_x) * zoom + sin(elapsed * 78.0) * shake

func _wx(screen_x: float) -> float:
	return screen_x / zoom + camera_x

func _limit_camera() -> void:
	# Keep a complete empty lot beyond every occupied or unfinished lot.
	# The old fixed 220-unit allowance clipped even the desktop button, and
	# ignored the larger smartphone buildings entirely.
	var right: float = _expansion_x() + _lot_step()
	if heading != null and body != null:
		var text_scale: float = _world_text_scale()
		var label_width: float = maxf(heading.get_string_size("QUI C'È FUTURO",HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(20*text_scale)).x,heading.get_string_size("LOTTO LIBERO",HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(19*text_scale)).x)
		label_width = maxf(label_width,body.get_string_size("Tocca per costruire",HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(13*text_scale)).x)
		right = maxf(right,_expansion_x()+EXPANSION_RECT.get_center().x*DeviceLayout.building_scale()+(label_width*0.5+2.0)/target_zoom)
	var margin: float = 24.0
	if DeviceLayout.mobile:
		margin += maxf(0.0,size.x-DeviceLayout.safe_rect().end.x*DeviceLayout.ui_scale())
	target_camera = clampf(target_camera, -850.0, maxf(-210.0, right - (size.x-margin) / target_zoom))

func _expansion_x() -> float:
	return _city_start() + Game.buildings.size() * _lot_step()

func _expansion_rect() -> Rect2:
	return Rect2(Vector2(_sx(_expansion_x()),_ground())+EXPANSION_RECT.position*_building_zoom(),EXPANSION_RECT.size*_building_zoom())

func focus_gate() -> void:
	world_touch.cancel(self)
	_cancel_building_hold(true)
	dragging = false
	camera_transition.clear()
	target_camera = -420.0
	target_zoom = _view_zoom(0.98)
	if DeviceLayout.android_phone(): target_camera = CHECKPOINT_LEFT-size.x*0.67/target_zoom
	_limit_camera()

func focus_defense() -> void:
	focus_gate()
	if Game.tutorial_stage == "first_zombie":
		target_camera = -850.0
		target_zoom = _view_zoom(0.82)
		_limit_camera()
	camera_transition = {"from_x":camera_x,"from_zoom":zoom,"elapsed":0.0,"duration":clampf(0.55+absf(target_camera-camera_x)/2200.0,0.55,1.1)}
	dragging = false
	smg_held = false
	touch_points.clear()
	pinch_distance = 0.0
	hover = ""
	queue_redraw()

func focus_city() -> void:
	world_touch.cancel(self)
	_cancel_building_hold(true)
	dragging = false
	camera_transition.clear()
	target_camera = 280.0
	target_zoom = _view_zoom(0.98)
	if DeviceLayout.android_phone(): target_camera = _city_start()+155.0*DeviceLayout.building_scale()-size.x/(2.0*target_zoom)
	_limit_camera()

func _zoom_button(direction: int) -> void:
	_cancel_camera_transition()
	var world_center: float = camera_x + size.x/(zoom*2.0)
	target_zoom = _clamp_zoom(target_zoom+direction*_scaled_zoom(0.12))
	target_camera = world_center-size.x/(target_zoom*2.0)
	_limit_camera()

func _pan_button(direction: int) -> void:
	_cancel_camera_transition()
	target_camera += direction*280.0/zoom
	_limit_camera()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag: return
	if DeviceLayout.mobile and (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device==InputEvent.DEVICE_ID_EMULATION: return
	if in_main_menu:
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_G: focus_gate()
			KEY_C: focus_city()
			KEY_1: Game.equip_weapon("pistol")
			KEY_2: Game.equip_weapon("shotgun")
			KEY_3: Game.equip_weapon("sniper")
			KEY_4: Game.equip_weapon("smg")
			KEY_F11:
				var full: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
				Preferences.apply_settings({"fullscreen":not full})
			KEY_LEFT, KEY_A:
				_cancel_camera_transition()
				target_camera -= 220.0
				_limit_camera()
			KEY_RIGHT, KEY_D:
				_cancel_camera_transition()
				target_camera += 220.0
				_limit_camera()
			KEY_SPACE: Game.paused = not Game.paused
			KEY_F1: ui.show_help()
	if panel_open:
		return
	if event is InputEventMagnifyGesture:
		_cancel_camera_transition()
		target_zoom = _clamp_zoom(target_zoom * event.factor)
		_limit_camera()
	if event is InputEventMouseButton:
		var pos: Vector2 = event.position
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cancel_camera_transition()
			var world_before: float = _wx(pos.x)
			target_zoom = _clamp_zoom(target_zoom+_scaled_zoom(0.08 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -0.08))
			target_camera = world_before - pos.x / target_zoom
			_limit_camera()
		if event.button_index == MOUSE_BUTTON_LEFT and (dragging or not ui.world_input_blocked(pos)):
			if event.pressed:
				_cancel_camera_transition()
				_suppress_world_release = false
				var picked: Dictionary = _pick_actor(pos)
				if Game.weapon=="smg" and not picked.is_empty() and str(picked.kind)=="enemy":
					smg_held = true
					held_pointer = pos
					dragging = false
					_fire_enemy(picked.actor)
					return
				dragging = true
				drag_start = pos
				drag_camera = target_camera
				drag_distance = 0.0
				_begin_building_hold(pos)
			else:
				if not _suppress_world_release and dragging and drag_distance < 12.0:
					_world_click(pos)
				dragging = false
	if event is InputEventMouseMotion:
		held_pointer = event.position
		if smg_held:
			return
		if dragging:
			drag_distance = maxf(drag_distance, event.position.distance_to(drag_start))
			if drag_distance > 8.0:
				target_camera = drag_camera - (event.position.x - drag_start.x) / zoom
				_limit_camera()
		else:
			_update_hover(event.position)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if world_touch.handle(self,event): get_viewport().set_input_as_handled()
		return
	if DeviceLayout.mobile and (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device==InputEvent.DEVICE_ID_EMULATION: return
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		held_pointer = event.position
		_world_pointer_active = true
	# Releases over the HUD are consumed there, so stop a held burst before GUI
	# routing as well. No weapon fires without a continuing player press.
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		smg_held = false
		_cancel_building_hold()
		if _suppress_world_release: dragging = false
		_finish_world_release.call_deferred(_world_release_serial)
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		_world_release_serial += 1
		_cancel_building_hold(true)
	if event is InputEventMouseMotion and not _building_hold.is_empty():
		if event.position.distance_to(_building_hold.origin)>BUILDING_HOLD_SLOP: _cancel_building_hold(true)

func _finish_world_release(serial: int) -> void:
	if serial!=_world_release_serial: return
	dragging = false
	_suppress_world_release = false
	_cancel_building_hold()

func _cancel_building_hold(suppress_release: bool=false) -> void:
	_building_hold.clear()
	if suppress_release: _suppress_world_release = true

func _building_at(point: Vector2) -> int:
	if not _pick_actor(point).is_empty() or _gate_rect().has_point(point): return -1
	for building: Dictionary in Game.buildings:
		var id: int = int(building.id)
		if _building_rect(id).has_point(point) or _building_logo_rect(id).has_point(point): return id
	return -1

func _begin_building_hold(point: Vector2) -> void:
	if touch_points.size()>1: return
	var id: int = _building_at(point)
	if id<0: return
	# A held building should not drift away during camera easing.
	target_camera = camera_x
	target_zoom = zoom
	drag_camera = camera_x
	_building_hold = {"id":id,"origin":point,"elapsed":0.0}

func _update_building_hold(delta: float) -> void:
	if _building_hold.is_empty(): return
	if in_main_menu or panel_open or not dragging or not _world_pointer_active or touch_points.size()>1 or _building_at(held_pointer)!=int(_building_hold.id):
		_cancel_building_hold(true)
		return
	_building_hold.elapsed = float(_building_hold.elapsed)+delta
	if float(_building_hold.elapsed)<BUILDING_HOLD_SECONDS: return
	var id: int = int(_building_hold.id)
	_cancel_building_hold(true)
	dragging = false
	building_feedback.click(id)
	Game.sfx.emit("ui")
	ui.show_demolition(id)

func _draw_building_hold() -> void:
	if _building_hold.is_empty() or float(_building_hold.elapsed)<0.12: return
	var rect: Rect2 = _building_logo_rect(int(_building_hold.id))
	var progress: float = clampf(float(_building_hold.elapsed)/BUILDING_HOLD_SECONDS,0.0,1.0)
	draw_arc(rect.get_center(),rect.size.x*0.5+5.0,-PI*0.5,-PI*0.5+TAU*progress,36,GOLD,4.0,true)

func _on_pointer_exited() -> void:
	if not world_touch.claimed.is_empty(): return
	_world_pointer_active = false
	hover = ""
	_cancel_building_hold(true)
	dragging = false

func _on_main_menu_opened() -> void:
	world_touch.cancel(self)
	in_main_menu = true
	_on_pointer_exited()
	touch_points.clear()
	building_feedback.reset()
	_clear_target_outlines()

func _on_building_demolished(_id: int) -> void:
	_cancel_building_hold(true)
	dragging = false
	hover = ""
	building_feedback.reset()
	_cancel_camera_transition()
	_limit_camera()
	_report_world_view()
	queue_redraw()

func _update_building_feedback(delta: float) -> void:
	var hovered_id: int = -1
	var available: bool = _world_pointer_active and (not DeviceLayout.android_phone() or world_touch.primary>=0) and not in_main_menu and not panel_open and not (dragging and drag_distance>8.0)
	var gui_control: Control = get_viewport().gui_get_hovered_control()
	if available and (gui_control==null or gui_control==self) and Rect2(Vector2.ZERO,size).has_point(held_pointer):
		# Re-evaluate after camera movement even when the mouse is stationary.
		_update_hover(held_pointer)
		if hover.begins_with("building:"):
			hovered_id = int(hover.trim_prefix("building:"))
	else:
		hover = ""
	building_feedback.update(delta,hovered_id)

func _update_held_fire() -> void:
	if not smg_held:
		return
	if Game.paused or in_main_menu or panel_open or Game.weapon!="smg" or Game.ammo<=0:
		smg_held = false
		return
	var picked: Dictionary = _pick_actor(held_pointer,true)
	if not picked.is_empty() and str(picked.kind)=="enemy" and Game.can_shoot_target(int(picked.id)):
		_fire_enemy(picked.actor)

func _update_hover(pos: Vector2) -> void:
	hover = ""
	if pos.y <= 119.0 or pos.y >= size.y - 152.0:
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		return
	var picked: Dictionary = _pick_actor(pos)
	if not picked.is_empty():
		hover = "%s:%d" % [str(picked.kind), int(picked.id)]
	else:
		for b: Dictionary in Game.buildings:
			if _building_rect(int(b.id)).has_point(pos) or _building_logo_rect(int(b.id)).has_point(pos):
				hover = "building:%d" % int(b.id)
		if _gate_rect().has_point(pos):
			hover = "gate"
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not hover.is_empty() else Control.CURSOR_DRAG

func _pick_actor(pos: Vector2, enemies_only: bool=false) -> Dictionary:
	if pos.y <= 119.0 or pos.y >= size.y - 152.0:
		return {}
	var closest: Dictionary = {}
	var best_distance_squared: float = INF
	# Queue spacing is smaller than the generous hit areas. Scan EVERY actor
	# before choosing, so the first visitor in the list cannot steal the click.
	for visitor: Dictionary in Game.visitors:
		if enemies_only:
			break
		var center: Vector2 = Vector2(_sx(float(visitor.x)), _ground()-28.0*_actor_zoom())
		var distance_squared: float = pos.distance_squared_to(center)
		if distance_squared <= pow(65.0*_actor_zoom(), 2.0) and distance_squared <= best_distance_squared:
			best_distance_squared = distance_squared
			closest = {"kind":"visitor", "id":int(visitor.id), "actor":visitor}
	# Enemies are drawn after visitors. Only an exact distance tie follows
	# that foreground order; otherwise the nearest person always wins.
	for enemy: Dictionary in Game.threats:
		var center: Vector2 = Vector2(_sx(float(enemy.x)), _ground()-32.0*_actor_zoom())
		var distance_squared: float = pos.distance_squared_to(center)
		if distance_squared <= pow(82.0*_actor_zoom(), 2.0) and distance_squared <= best_distance_squared:
			best_distance_squared = distance_squared
			closest = {"kind":"enemy", "id":int(enemy.id), "actor":enemy}
	return closest

func _world_click(pos: Vector2) -> void:
	var picked: Dictionary = _pick_actor(pos)
	if not picked.is_empty() and str(picked.kind) == "visitor":
		Game.sfx.emit("ui")
		ui.show_visitor(int(picked.id))
		return
	if not picked.is_empty() and str(picked.kind) == "enemy":
		_fire_enemy(picked.actor)
		return
	if _gate_rect().has_point(pos):
		Game.sfx.emit("ui")
		ui.show_gate()
		return
	for b: Dictionary in Game.buildings:
		if _building_rect(int(b.id)).grow(6.0).has_point(pos) or _building_logo_rect(int(b.id)).has_point(pos):
			building_feedback.click(int(b.id))
			Game.sfx.emit("ui")
			ui.show_building(int(b.id))
			return
	# Include the caption below the illustrated lot in the clickable area.
	if _expansion_rect().grow_individual(6.0,6.0,6.0,56.0).has_point(pos):
		Game.sfx.emit("ui")
		ui._navigate("build")

func _fire_enemy(enemy: Dictionary) -> bool:
	var impact: Vector2 = Vector2(float(enemy.x),_ground()-42.0*_actor_zoom())
	if not Game.shoot(int(enemy.id)):
		return false
	shake = 1.8 if Game.weapon in ["pistol","smg"] else 3.6
	for i: int in range(4 if Game.weapon=="smg" else 6):
		particles.append({"x":impact.x+randf_range(-18.0,18.0),"y":impact.y+randf_range(-14.0,14.0),"life":randf_range(0.15,0.4),"text":"•","color":GOLD})
	return true

func _building_rect(id: int) -> Rect2:
	return Rect2(_sx(_city_start() + _building_index(id) * _lot_step()), _ground() - 315.0 * _building_zoom(), 310.0 * _building_zoom(), 325.0 * _building_zoom())

func _building_index(id: int) -> int:
	for i: int in range(Game.buildings.size()):
		if int(Game.buildings[i].id) == id:
			return i
	return 0

func _building_logo_rect(id: int) -> Rect2:
	return BuildingSignage.bounds(self,id)

func _draw_building_logo(building: Dictionary) -> void:
	BuildingSignage.draw_sign(self,building)

func _draw_building_logos() -> void:
	for index: int in range(Game.buildings.size()):
		var x: float = _sx(_city_start()+index*_lot_step())
		if x<=size.x+80.0 and x+315.0*_building_zoom()>=-80.0:
			_draw_building_logo(Game.buildings[index])

func _draw() -> void:
	if body == null:
		return
	var bottom: float = size.y
	var background_top: float = 0.0
	var ground: float = _ground()
	# The generated panorama is a separate parallax layer.
	if background:
		var background_width: float = size.x * 1.24
		var bg_x: float = -fposmod(camera_x * 0.12 + 150.0, background_width - size.x)
		draw_texture_rect(background, Rect2(bg_x, background_top, background_width, bottom-background_top), false)
	else:
		draw_rect(Rect2(0, background_top, size.x, bottom-background_top), Color("858f83"))
	# Soft sky fade keeps the HUD readable without a visible band.
	draw_texture_rect(_sky_fade, Rect2(0, 0, size.x, 210), false)
	_draw_road()
	_draw_boundary()
	for building: Dictionary in Game.buildings:
		_draw_building(building)
	_draw_expansion()
	_draw_lights()
	_draw_building_logos()
	_draw_building_hold()
	_draw_characters()
	# The solid checkpoint occludes arrivals at the boundary. Guards stand above it.
	_draw_gate()
	_draw_guards()
	# Medical badges stay above the checkpoint and follow the observed person.
	for visitor: Dictionary in Game.visitors:
		if Activity.visitor_visible(visitor):
			Activity.draw_visitor(self,Game,visitor,BuildingSignage.texture("clinic"))
	_draw_combat()
	for p: Dictionary in particles:
		var color: Color = p.color
		color.a = clampf(float(p.life), 0.0, 1.0)
		_text(Vector2(_sx(float(p.x)), float(p.y)), str(p.text), 23, color, heading, true)
	# Ground fade settles the footer onto the road like a camera vignette.
	draw_texture_rect(_ground_fade, Rect2(0, bottom-180.0, size.x, 180.0), false)
	_draw_scene_labels()
	# Ambient drifting dust in front of the scene, never in the HUD.
	for i: int in range(22):
		var px: float = fposmod(i * 137.3 + elapsed * (3.0 + i % 4) - camera_x * 0.03, size.x)
		var py: float = 220.0 + fposmod(i * 73.1 + sin(elapsed * 0.3 + i) * 11.0, maxf(ground - 260.0, 10.0))
		draw_circle(Vector2(px, py), 1.0 if i % 3 else 1.6, Color(1.0,0.86,0.59,0.23))

func _draw_road() -> void:
	if road == null:
		return
	# Paint the same textured strip on both sides, with cooler exterior lighting.
	var tile_width: float = 1300.0
	var strip_y: float = _ground()-19.0*zoom
	var strip_height: float = 220.0*zoom
	var first_tile: int = int(floor(camera_x/tile_width))-1
	var last_tile: int = int(ceil((camera_x+size.x/zoom)/tile_width))+1
	var safe_edge: float = _sx(550.0)
	for tile: int in range(first_tile,last_tile+1):
		var dest: Rect2 = Rect2(_sx(tile*tile_width),strip_y,tile_width*zoom+0.5,strip_height)
		var cut: float = clampf(safe_edge-dest.position.x,0.0,dest.size.x)
		var mirrored: bool = posmod(tile,2)==1
		if cut > 0.0:
			_draw_road_piece(dest,0.0,cut,mirrored,Color(0.81,0.85,0.86))
		if cut < dest.size.x:
			_draw_road_piece(dest,cut,dest.size.x-cut,mirrored,Color(1.0,0.97,0.87))

func _draw_road_piece(tile: Rect2, start: float, width: float, mirrored: bool, tint: Color) -> void:
	var piece: Rect2 = Rect2(tile.position+Vector2(start,0),Vector2(width,tile.size.y))
	var source_x: float = road.get_width()*(1.0-(start+width)/tile.size.x if mirrored else start/tile.size.x)
	var source: Rect2 = Rect2(source_x,0,road.get_width()*width/tile.size.x,road.get_height())
	if mirrored:
		draw_set_transform(Vector2(piece.end.x,piece.position.y),0,Vector2(-1,1))
		draw_texture_rect_region(road,Rect2(Vector2.ZERO,piece.size),source,tint)
		draw_set_transform(Vector2.ZERO)
	else:
		draw_texture_rect_region(road,piece,source,tint)
	# The floating navigation also reveals the foreground below the old HUD band.
	# Reflect the lower asphalt, keeping the curb and painted lane at their size.
	if piece.end.y < size.y:
		var fill_size: Vector2 = Vector2(piece.size.x,size.y-piece.end.y)
		var asphalt: Rect2 = Rect2(source.position.x,road.get_height()*0.74,source.size.x,road.get_height()*0.26)
		var origin: Vector2 = Vector2(piece.end.x if mirrored else piece.position.x,size.y)
		draw_set_transform(origin,0,Vector2(-1 if mirrored else 1,-1))
		draw_texture_rect_region(road,Rect2(Vector2.ZERO,fill_size),asphalt,tint)
		draw_set_transform(Vector2.ZERO)

func _draw_boundary() -> void:
	var y: float = _ground()
	var outside_edge: float = _sx(265.0)
	var inside_edge: float = _sx(550.0)
	# A soft contact shadow anchors the full-depth gate foundation to the asphalt.
	draw_set_transform(Vector2((outside_edge+inside_edge)/2,y+86*zoom),0,Vector2(1,0.18))
	draw_circle(Vector2.ZERO,(inside_edge-outside_edge)*0.56,Color(0.09,0.10,0.08,0.22))
	draw_set_transform(Vector2.ZERO)
	# Pool of warm light stays on the protected side of the barrier.
	draw_circle(Vector2(inside_edge+40*zoom,y-10),95*zoom,Color(1.0,0.75,0.36,0.06))

func _gate_rect() -> Rect2:
	var gate_zoom: float = zoom*DeviceLayout.gate_scale()
	return Rect2(_sx(CHECKPOINT_LEFT),_ground()-(CHECKPOINT_HEIGHT-125.0)*gate_zoom,CHECKPOINT_HEIGHT*2.0/3.0*gate_zoom,CHECKPOINT_HEIGHT*gate_zoom)

func _draw_gate() -> void:
	var y: float = _ground()
	var rect: Rect2 = _gate_rect()
	if checkpoint:
		draw_texture_rect(checkpoint,rect,false)
	elif building_art.size() >= 6:
		_draw_fitted(building_art[5],rect)
	else:
		draw_rect(rect,Color("697668"))
	if Game.community.projects.has("radio"):
		var radio_size: Vector2 = Vector2(65,56)*zoom*DeviceLayout.gate_scale()
		var radio_pos: Vector2 = rect.position+rect.size*Vector2(0.59,0.19)
		draw_texture_rect(community_radio,Rect2(radio_pos,radio_size),false)
	var center: float = rect.get_center().x
	if hover == "gate":
		_text(Vector2(center,y+113*zoom),"GESTISCI DIFESE",14,GOLD,heading,true)
	if not Game.threats.is_empty():
		var alpha: float = 0.65 + sin(elapsed * 5.0) * 0.25
		draw_circle(Vector2(rect.position.x+rect.size.x*0.20,rect.position.y+rect.size.y*0.22),6.0*zoom,Color(0.95,0.36,0.27,alpha))

func _guard_ids() -> Array[int]:
	return [0]

func _first_guard_id() -> int:
	var ids: Array[int] = _guard_ids()
	return ids[0] if not ids.is_empty() else -1

func _guard_post(citizen_id: int) -> Vector2:
	var index: int = maxi(_guard_ids().find(citizen_id),0)
	# Feet align with the generated deck; extra defenders share sheltered rows.
	var image_x: float = 370.0+(index%3)*150.0
	var rect: Rect2 = _gate_rect()
	return Vector2(CHECKPOINT_LEFT+image_x/1024.0*CHECKPOINT_HEIGHT*2.0/3.0*DeviceLayout.gate_scale(),rect.position.y+rect.size.y*445.0/1536.0-(index/3)*4.0*zoom)

func _guard_muzzle(citizen_id: int) -> Vector2:
	var post: Vector2 = _guard_post(citizen_id)
	return Vector2(post.x-30.0*DeviceLayout.actor_scale(),post.y-43.0*_actor_zoom())

func _on_guard_fired(citizen_id: int, threat_id: int, target_x: float) -> void:
	guard_flashes[citizen_id] = 0.22
	hit_flashes[threat_id] = 0.16
	shots.append({"from":_guard_muzzle(citizen_id),"to":Vector2(target_x,_ground()-38.0*_actor_zoom()),"life":0.17})

func _on_reload_started(weapon_key: String, duration: float) -> void:
	var delay: float = {"shotgun":0.25,"sniper":0.35,"smg":0.04}.get(weapon_key,0.15)
	reload_queue.append({"weapon":weapon_key,"remaining":minf(delay,duration*0.35)})

func _update_reload_audio(delta: float) -> void:
	if in_main_menu or not sound_enabled:
		reload_queue.clear()
		return
	if Game.paused:
		return
	for entry: Dictionary in reload_queue.duplicate():
		entry.remaining = float(entry.remaining)-delta
		if float(entry.remaining)<=0.0:
			_play_sound("reload_"+str(entry.weapon))
			reload_queue.erase(entry)

func _draw_guards() -> void:
	if character_art.is_empty():
		return
	for citizen_id: int in _guard_ids():
		var post: Vector2 = _guard_post(citizen_id)
		var frame: int = 3 if guard_flashes.has(citizen_id) else 0
		var recoil: float = 3.0 if frame==3 else 0.0
		_draw_person(4,frame,post.x+recoil,post.y,82.0*_actor_zoom(),true,false)
	# The existing painted parapet is drawn again in front of the soldiers' feet.
	if checkpoint:
		var region: Rect2 = Rect2(220,325,570,185)
		var rect: Rect2 = _gate_rect()
		var scale_factor: Vector2 = rect.size/checkpoint.get_size()
		draw_texture_rect_region(checkpoint,Rect2(rect.position+region.position*scale_factor,region.size*scale_factor),region)

func _draw_building(b: Dictionary) -> void:
	var id: int = int(b.id)
	var x: float = _sx(_city_start() + _building_index(id)*_lot_step())
	var y: float = _ground()
	if x > size.x+80 or x+315*_building_zoom() < -80:
		return
	var rect: Rect2 = _building_rect(id)
	var art_index: int = {"residence":0,"cafe":1,"garden":2,"workshop":3,"clinic":4}.get(str(b.type),0)
	# Warm pool of light beneath inhabited cutaway buildings.
	draw_circle(Vector2(x+150*_building_zoom(),y-12),102*_building_zoom(),Color(0.96,0.72,0.35,0.045))
	var texture: Texture2D = extra_building_art.get(str(b.type),null)
	if texture == null and building_art.size() > art_index and str(b.type) in ["residence","cafe","garden","workshop","clinic"]:
		texture = building_art[art_index]
	if Game.is_under_construction(b):
		ConstructionVisual.draw_site(self,texture,Rect2(x,y-310*_building_zoom(),310*_building_zoom(),315*_building_zoom()),Game.construction_progress(b),actor_clock)
		_building_subtitle(Vector2(x+155*_building_zoom(),y+(52 if DeviceLayout.android_phone() else 38)),"CANTIERE · %s · %d%%" % [ui._time(float(b.construction_remaining)),floori(Game.construction_progress(b)*100.0)],GOLD)
		return
	if texture != null:
		var tint: Color = Color.WHITE
		if b.type != "residence" and b.workers.is_empty():
			tint = Color(0.78,0.80,0.73,1.0)
		building_feedback.draw(self,texture,Rect2(x,y-310*_building_zoom(),310*_building_zoom(),315*_building_zoom()),tint,id)
	else:
		draw_rect(rect,Color("a9b89b"))
	var subtitle: String = "ALLOGGI · %d POSTI" % (5 * int(b.level))
	var color: Color = SAGE
	if b.type != "residence":
		var workers: int = b.workers.size()
		subtitle = "%d / 3 AL LAVORO" % workers
		var stocked: bool = false
		var ready: bool = false
		var working: bool = false
		var remaining: float = 0.0
		for p: Dictionary in b.products:
			stocked = stocked or p.status == "stocked"
			ready = ready or p.status == "ready"
			if p.status == "restocking":
				working = true
				remaining = maxf(remaining,float(p.remaining))
		if ready:
			subtitle += "   /   MERCE PRONTA"
		elif working:
			subtitle += "   /   RIFORNIMENTO · %ds" % int(remaining)
			color = GOLD
		elif stocked:
			subtitle += "   /   IN VENDITA"
		else:
			subtitle += "   /   DA RIFORNIRE" if workers>0 else ""
		if workers == 0:
			color = Color("c0b09a")
	_building_subtitle(Vector2(x+155*_building_zoom(),y+(52 if DeviceLayout.android_phone() else 38)),subtitle,color)

func _building_subtitle(baseline: Vector2, text: String, color: Color) -> void:
	var lines: PackedStringArray = PackedStringArray([text])
	var font_size: int = roundi(13*_world_text_scale())
	var padding: float = 10.0*_world_text_scale()
	var width: float = body.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	# At the widest city view, keep the full status readable without allowing
	# neighbouring plaques to overlap or shrinking the font.
	if width+padding*2 > _lot_step()*zoom-10.0 and text.contains("   /   "):
		lines = text.split("   /   ")
		width = 0.0
		for line: String in lines:
			width = maxf(width,body.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x)
	var line_height: float = body.get_height(font_size)
	var badge: Rect2 = Rect2(baseline.x-width*0.5-padding,baseline.y-body.get_ascent(font_size)-padding*0.3,width+padding*2,line_height*lines.size()+padding*0.6)
	_pill(badge,INK)
	for index: int in range(lines.size()):
		_text(baseline+Vector2(0,line_height*index),lines[index],13,color,body,true)

func _draw_expansion() -> void:
	var y: float = _ground()
	var rect: Rect2 = _expansion_rect()
	if rect.position.x > size.x+100 or rect.end.x < 0:
		return
	draw_rect(rect,Color(0.1,0.2,0.18,0.12))
	for i: int in range(8):
		var dx: float = rect.position.x + i*30*_building_zoom()
		draw_line(Vector2(dx,rect.position.y),Vector2(dx+16*_building_zoom(),rect.position.y),Color(0.85,0.82,0.64,0.4),2)
		draw_line(Vector2(dx,y),Vector2(dx+16*_building_zoom(),y),Color(0.85,0.82,0.64,0.4),2)
	_text(Vector2(rect.get_center().x,y-106*_building_zoom()),"+",60,Color(0.91,0.86,0.68,0.7),heading,true)
	_text(Vector2(rect.get_center().x,y-70*_building_zoom()),"QUI C'È FUTURO",20,CREAM,heading,true)
	_text(Vector2(rect.get_center().x,y-45*_building_zoom()),"Tocca per costruire",13,Color("c5c9af"),body,true)
	_text(Vector2(rect.get_center().x,y+38),"LOTTO LIBERO",19,Color("a8b79c"),heading,true)

func _draw_lights() -> void:
	# Sagging string lights strengthen the welcoming character of the settlement.
	if Game.buildings.is_empty():
		return
	var y: float = _ground()-263*_building_zoom()
	var end_world: float = _city_start()+Game.buildings.size()*_lot_step()
	var start_world: float = 550.0
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in range(41):
		var t: float = i/40.0
		points.append(Vector2(_sx(start_world+t*(end_world-start_world)),y+sin(t*PI)*33*_building_zoom()))
	draw_polyline(points,Color("3e4c42"),1.5)
	for i: int in range(int((end_world-start_world)/70.0)):
		var t: float = float(i)/maxf((end_world-start_world)/70.0,1.0)
		var pos: Vector2 = Vector2(_sx(start_world+t*(end_world-start_world)),y+sin(t*PI)*33*_building_zoom()+5)
		draw_circle(pos,10.0*_building_zoom(),Color(1,0.75,0.35,0.05))
		draw_circle(pos,3.0*_building_zoom(),Color("f4d18a"))

func _enemy_in_weapon_range(enemy: Dictionary) -> bool:
	# This marks reach, not reload readiness: keep the contour steady between
	# shots and use the same empty-ammo fallback as Game.shoot().
	if in_main_menu or float(enemy.get("hp",0.0))<=0.0:
		return false
	var effective_weapon: String = "pistol" if Game.weapon!="pistol" and Game.ammo<=0 else Game.weapon
	return Game.is_target_in_range(int(enemy.get("id",-1)),effective_weapon)

func _clear_target_outlines() -> void:
	for visual: Node in target_outlines.values():
		visual.queue_free()
	target_outlines.clear()

func _sync_target_outlines() -> void:
	var visible_ids: Dictionary = {}
	if not in_main_menu:
		for enemy: Dictionary in Game.threats:
			var screen_x: float = _sx(float(enemy.x))
			if not _enemy_in_weapon_range(enemy) or screen_x < -120.0 or screen_x > size.x+120.0:
				continue
			var id: int = int(enemy.id)
			visible_ids[id] = true
			if not target_outlines.has(id):
				var visual: Node = TargetOutline.new()
				add_child(visual)
				target_outlines[id] = visual
			var column: int = _enemy_column(enemy)
			var zombie: bool = _is_zombie(enemy)
			var frame: int = 3 if hit_flashes.has(id) else 0
			var gait: Dictionary = _actor_gait("enemy:%d" % id)
			var appearance: String = str(enemy.get("appearance","infected"))
			var texture: Texture2D = character_art[clampi(frame*8+column,0,character_art.size()-1)] if zombie else ActorVisuals.texture(column,frame,false,appearance)
			target_outlines[id].configure(column,frame,float(gait.phase),float(gait.blend),zombie,bool(enemy.get("facing_left",false)),appearance,texture)
	for id: Variant in target_outlines.keys():
		if not visible_ids.has(id):
			target_outlines[id].queue_free()
			target_outlines.erase(id)

func _draw_characters() -> void:
	if character_art.is_empty():
		return
	var ground: float = _ground()
	for citizen: Dictionary in Game.citizens:
		if citizen.get("away",false) or citizen.get("guard",false):
			continue
		var id: int = int(citizen.id)
		var world_x: float = _citizen_world_x(citizen)
		var moving: bool = false
		var base_y: float = ground+7.0
		if int(citizen.get("job",-1)) >= 0:
			base_y = ground-14*_building_zoom()
		else:
			moving = true
		var look: int = ActorVisuals.civilian_column(int(citizen.get("look",id)))
		var frame: int = 0
		if not moving and int(citizen.get("job",-1)) >= 0 and fposmod(actor_clock+id*0.7,4.0)>3.0:
			frame = 3
		var gait: Dictionary = _actor_gait("citizen:%d" % id)
		var facing_left: bool = moving and citizen_roaming.facing_left(id)
		_draw_person(look,frame,world_x,base_y,70.0*_actor_zoom(),facing_left,true,float(gait.phase),false,float(gait.blend),str(citizen.get("appearance","clean")))
	for visitor: Dictionary in Game.departing_visitors:
		_draw_visitor(visitor,true)
	for visitor_index: int in range(Game.visitors.size()):
		_draw_visitor(Game.visitors[visitor_index],false,visitor_index)
	for enemy: Dictionary in Game.threats:
		var col: int = _enemy_column(enemy)
		var frame: int = 0
		if hit_flashes.has(int(enemy.id)):
			frame = 3
		var h: float = (108.0 if col==7 else 80.0)*_actor_zoom()
		var ex: float = _sx(float(enemy.x))
		var gait: Dictionary = _actor_gait("enemy:%d" % int(enemy.id))
		if target_outlines.has(int(enemy.id)) and _enemy_in_weapon_range(enemy):
			target_outlines[int(enemy.id)].draw_halo(self,Vector2(ex,ground+7),h,0.90+0.10*sin(actor_clock*2.6))
		_draw_person(col,frame,float(enemy.x),ground+7,h,bool(enemy.get("facing_left",false)),true,float(gait.phase),_is_zombie(enemy),float(gait.blend),str(enemy.get("appearance","infected")))
		if float(enemy.hp) < float(enemy.max_hp):
			draw_rect(Rect2(ex-20*_actor_zoom(),ground-h-12,40*_actor_zoom(),4),Color("3a3f37"))
			draw_rect(Rect2(ex-20*_actor_zoom(),ground-h-12,40*_actor_zoom()*float(enemy.hp)/float(enemy.max_hp),4),Color("de8a68"))

func _draw_visitor(visitor: Dictionary, departing: bool, queue_index: int=0) -> void:
	var look: int = ActorVisuals.civilian_column(int(visitor.citizen.get("look",0)))
	var x: float = float(visitor.x)
	var screen_x: float = _sx(x)
	if screen_x < -100.0 or screen_x > size.x+100.0:
		return
	var ground: float = _ground()
	var gait: Dictionary = _actor_gait("visitor:%d" % int(visitor.id))
	var attacked: bool = bool(visitor.get("under_attack",false))
	var flash: float = clampf(float(visitor.get("hit_flash",0.0))/0.24,0.0,1.0)
	if flash > 0.0:
		draw_set_transform(Vector2(screen_x,ground+7.0),0,Vector2(1,0.28))
		draw_circle(Vector2.ZERO,37.0*_actor_zoom(),Color(0.91,0.47,0.31,flash*0.3))
		draw_set_transform(Vector2.ZERO)
	_draw_person(look,0,x,ground+7.0,78*_actor_zoom(),bool(visitor.get("facing_left",departing)),true,float(gait.phase),false,float(gait.blend),str(visitor.citizen.get("appearance","clean")))
	if ((not departing and Game.visitor_at_gate(visitor)) or attacked) and not Activity.visitor_visible(visitor,departing):
		var text: String = "POSSO ENTRARE?"
		# Queue slots are closer than a whole speech balloon. Separate their
		# heights so a neighbour's request never hides a call for help.
		var bubble_y: float = ground-(100.0+mini(queue_index,2)*34.0)*_actor_zoom()+sin(elapsed*2)*3
		_status_bubble(Vector2(screen_x,bubble_y),text,Color("f2aa86") if attacked else CREAM)
	elif departing:
		# Keep the farewell above the health bar and leave click targets clear.
		_text(Vector2(screen_x,ground-100*_actor_zoom()),"IN PARTENZA",11,Color("dbc8a6"),heading,true)
	var hp: float = float(visitor.citizen.get("hp",100.0))
	var max_hp: float = maxf(float(visitor.citizen.get("max_hp",100.0)),1.0)
	if hp < max_hp or attacked:
		var bar: Rect2 = Rect2(screen_x-23.0*_actor_zoom(),ground-86.0*_actor_zoom(),46.0*_actor_zoom(),6.0)
		_pill(bar,Color("37453b"))
		_pill(Rect2(bar.position+Vector2(1,1),Vector2(maxf(0.0,(bar.size.x-2.0)*clampf(hp/max_hp,0.0,1.0)),4.0)),Color("df906f") if hp/max_hp<0.4 else SAGE)
	if flash > 0.0:
		draw_arc(Vector2(screen_x,ground-37.0*_actor_zoom()),29.0*_actor_zoom(),-0.7,0.6,12,Color(1.0,0.79,0.54,flash),2.5,true)

func _on_visitor_lost(_id: int, world_x: float, _person_name: String) -> void:
	# A short dust cloud communicates the loss without gore or a new click target.
	for i: int in range(6):
		particles.append({"x":world_x+randf_range(-17.0,17.0),"y":_ground()-randf_range(5.0,45.0)*_actor_zoom(),"life":randf_range(0.35,0.7),"text":"•","color":Color("c4b294")})

func _draw_person(column: int, frame: int, world_x: float, base_y: float, height: float, facing_left: bool=false, ground_shadow: bool=true, walk_phase: float=-1.0, zombie: bool=false, gait_blend: float=1.0, appearance: String="clean") -> void:
	var x: float = _sx(world_x)
	var margin: float = maxf(100.0,height*0.75)
	if x < -margin or x>size.x+margin:
		return
	if ground_shadow:
		draw_set_transform(Vector2(x,base_y),0,Vector2(1,0.22))
		draw_circle(Vector2(0,0),height*0.25,Color(0.08,0.13,0.13,0.25))
		draw_set_transform(Vector2.ZERO)
	if walk_phase >= 0.0 and frame == 0:
		WalkingRig.draw_actor(self,column,walk_phase,height,Vector2(x,base_y),zombie,facing_left,gait_blend,false,appearance)
		return
	var texture: Texture2D
	if zombie:
		texture = character_art[clampi(frame*8+column,0,character_art.size()-1)]
	else:
		texture = ActorVisuals.texture(column,frame,column==4,appearance)
	var w: float = height*texture.get_width()/maxf(texture.get_height(),1)
	if facing_left:
		draw_set_transform(Vector2(x,0),0,Vector2(-1,1))
		draw_texture_rect(texture,Rect2(-w/2,base_y-height,w,height),false)
	else:
		draw_set_transform(Vector2.ZERO)
		draw_texture_rect(texture,Rect2(x-w/2,base_y-height,w,height),false)
	draw_set_transform(Vector2.ZERO)

func _draw_combat() -> void:
	for shot: Dictionary in shots:
		var from: Vector2 = Vector2(_sx(shot.from.x),shot.from.y)
		var to: Vector2 = Vector2(_sx(shot.to.x),shot.to.y)
		var a: float = clampf(shot.life/0.17,0,1)
		draw_line(from,to,Color(1,0.83,0.42,a*0.6),2.0)
		draw_circle(from,12*a,Color(1,0.77,0.24,a))
		draw_circle(to,9*a,Color(1,0.91,0.6,a))

func _draw_scene_labels() -> void:
	var ground: float = _ground()
	var incoming: bool = ui._zombies_incoming()
	if Game.has_waiting_visitors() and not incoming:
		var factor: float = _world_text_scale()
		_pill(Rect2(30,190,300*factor,64*factor),Color(0.15,0.22,0.20,0.92))
		_text(Vector2(30+14*factor,190+24*factor),"QUALCUNO ALLA PORTA",16,SAGE,heading)
		_text(Vector2(30+14*factor,190+48*factor),"Tocca il visitatore per conoscerlo",14,CREAM,body)
	# A compact on-world camera control, with no requirement to open a menu.
	if Game.paused:
		var factor: float = _world_text_scale()
		_pill(Rect2(size.x/2-120*factor,141,240*factor,36*factor),INK)
		_text(Vector2(size.x/2,141+25*factor),"RIFUGIO IN PAUSA",18,GOLD,heading,true)

func _draw_fitted(texture: Texture2D, box: Rect2, tint: Color=Color.WHITE) -> void:
	var factor: float = minf(box.size.x/texture.get_width(),box.size.y/texture.get_height())
	var dimensions: Vector2 = texture.get_size()*factor
	var destination: Rect2 = Rect2(Vector2(box.get_center().x-dimensions.x/2,box.end.y-dimensions.y),dimensions)
	draw_texture_rect(texture,destination,false,tint)

func _status_bubble(center: Vector2, text: String, color: Color) -> void:
	var factor: float = _world_text_scale()
	var width: float = heading.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(14*factor)).x+24*factor
	_pill(Rect2(center.x-width/2,center.y-23*factor,width,29*factor),INK.lightened(0.03))
	draw_colored_polygon(PackedVector2Array([center+Vector2(-4,6)*factor,center+Vector2(4,6)*factor,center+Vector2(0,11)*factor]),INK.lightened(0.03))
	_text(center+Vector2(0,-3)*factor,text,14,color,heading,true)

func _world_text_scale() -> float:
	return 2.0 if DeviceLayout.android_phone() else 1.0

func _pill(rect: Rect2, color: Color) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(5)
	draw_style_box(style,rect)

func _text(pos: Vector2, text: String, font_size: int, color: Color, font: Font, center: bool=false) -> void:
	font_size = roundi(font_size*_world_text_scale())
	var location: Vector2 = pos
	if center:
		location.x -= font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x/2
	draw_string_outline(font,location,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,2,Color(0.10,0.13,0.12,0.8))
	draw_string(font,location,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _setup_audio() -> void:
	# Batch/headless runs need no playback objects or audio-thread cleanup.
	if DisplayServer.get_name() == "headless":
		return
	for i: int in range(12):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(player)
		audio_pool.append(player)
	ambience_player = AudioStreamPlayer.new()
	add_child(ambience_player)
	ambience_player.stream = SoundBank.ambient()
	if ambience_player.stream:
		ambience_player.play()

func _apply_preferences() -> void:
	sound_enabled = Preferences.sound_enabled
	if not sound_enabled:
		reload_queue.clear()
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(Preferences.master_volume,0.0001)))
	AudioServer.set_bus_mute(0,not sound_enabled)
	if is_instance_valid(ambience_player):
		ambience_player.volume_db = linear_to_db(maxf(Preferences.music_volume*0.5,0.0001))
	var desired_mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_FULLSCREEN if Preferences.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DeviceLayout.mobile:
		DeviceLayout.ensure_fullscreen()
	elif DisplayServer.get_name() != "headless" and DisplayServer.window_get_mode() != desired_mode:
		DisplayServer.window_set_mode(desired_mode)

func _play_sound(kind: String) -> void:
	if not sound_enabled:
		return
	var stream: AudioStream = SoundBank.sound(kind)
	if stream == null or Preferences.effects_volume <= 0.0:
		return
	for player: AudioStreamPlayer in audio_pool:
		if not player.playing:
			player.stream = stream
			player.volume_db = (-8.0 if kind.begins_with("reload_") else -3.0)+linear_to_db(maxf(Preferences.effects_volume,0.0001))
			player.pitch_scale = randf_range(0.98,1.02)
			player.play()
			return
	# Keep the player's weapon audible even during a busy run of UI/reward sounds.
	if kind.begins_with("shot_") and not audio_pool.is_empty():
		var priority_player: AudioStreamPlayer = audio_pool[0]
		priority_player.stop()
		priority_player.stream = stream
		priority_player.volume_db = -3.0+linear_to_db(maxf(Preferences.effects_volume,0.0001))
		priority_player.play()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_cancel_building_hold(true)
		Game.save_game()
		get_tree().quit()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
		world_touch.cancel(self,true)
		_cancel_building_hold(true)
		smg_held = false
		dragging = false
		touch_points.clear()
		_world_pointer_active = false
		hover = ""

func _exit_tree() -> void:
	for player: AudioStreamPlayer in audio_pool:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	if is_instance_valid(ambience_player):
		ambience_player.stop()
		ambience_player.stream = null


