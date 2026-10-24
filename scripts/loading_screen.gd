extends Control
## Render the game's identity first, then load the refuge without a frozen screen.

signal completed(scene: Node)
signal loading_failed(path: String)

const Typography = preload("res://scripts/typography.gd")
const BACKGROUND: Color = Color("173735")
const CREAM: Color = Color("fff1d4")
const GOLD: Color = Color("efc46d")
const ASSETS: Array[String] = [
	"res://assets/fonts/fredoka.ttf", "res://assets/fonts/body.ttf",
	"res://assets/art/background.png", "res://assets/art/checkpoint.png",
	"res://assets/art/road-painted.png", "res://assets/art/settlement.png",
	"res://assets/art/characters.png", "res://assets/art/ui_icons.png",
	"res://assets/art/population.png", "res://assets/art/survivors-expanded.png",
	"res://assets/art/characters-dirty.png", "res://assets/art/characters-infected.png",
	"res://assets/art/survivors-expanded-dirty.png", "res://assets/art/survivors-expanded-infected.png",
	"res://assets/art/buildings/bakery.png", "res://assets/art/buildings/waterworks.png",
	"res://assets/art/buildings/tailor.png"
]

@export_file("*.tscn") var next_scene_path: String = "res://main.tscn"
var auto_start: bool = true
var phase: String = "waiting"
var target_progress: float = 0.0
var progress_bar: ProgressBar
var status_label: Label
var percent_label: Label
var content: VBoxContainer
var screen: Control
var _center: CenterContainer
var _logo: TextureRect
var _title: Label
var _layer: CanvasLayer
var _pending: Array[String] = []
var _inflight: Dictionary = {}
var _resources: Array[Resource] = []
var _packed_scene: PackedScene
var _finished: int = 0
var _total: int = 0

func _ready() -> void:
	Game.paused = true
	_build_screen()
	DeviceLayout.changed.connect(_layout)
	_layout()
	if auto_start: start_loading.call_deferred()

func _style(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	return style

func _label(text: String, pixels: int, color: Color, heading: bool = false) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font",Typography.heading() if heading else Typography.body())
	label.add_theme_font_size_override("font_size",pixels)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _build_screen() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 200
	add_child(_layer)
	screen = Control.new()
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(screen)
	var background: ColorRect = ColorRect.new()
	background.color = BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(background)
	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(_center)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation",12)
	_center.add_child(content)
	var logo_center: CenterContainer = CenterContainer.new()
	content.add_child(logo_center)
	_logo = TextureRect.new()
	_logo.texture = load("res://assets/icon.png")
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	logo_center.add_child(_logo)
	_title = _label("NIENTE ZOMBIE\nPER FAVORE!",42,CREAM,true)
	content.add_child(_title)
	var tagline: Label = _label("Un piccolo rifugio. Una grande voglia di ricominciare.",18,Color("c8d9c5"))
	tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(tagline)
	var spacer: Control = Control.new()
	spacer.custom_minimum_size.y = 6
	content.add_child(spacer)
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size.y = 14
	progress_bar.show_percentage = false
	progress_bar.add_theme_stylebox_override("background",_style(Color("0e2725")))
	progress_bar.add_theme_stylebox_override("fill",_style(GOLD))
	content.add_child(progress_bar)
	var status: HBoxContainer = HBoxContainer.new()
	content.add_child(status)
	status_label = _label("Prepariamo il rifugio…",18,CREAM)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	status.add_child(status_label)
	percent_label = _label("0%",18,GOLD,true)
	percent_label.custom_minimum_size.x = 60
	percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.add_child(percent_label)

func _layout() -> void:
	_layer.scale = Vector2.ONE*DeviceLayout.ui_scale()
	screen.size = DeviceLayout.ui_size()
	var safe: Rect2 = DeviceLayout.safe_rect()
	_center.offset_left = safe.position.x+16
	_center.offset_top = safe.position.y+12
	_center.offset_right = safe.end.x-screen.size.x-16
	_center.offset_bottom = safe.end.y-screen.size.y-12
	content.custom_minimum_size.x = minf(580,safe.size.x-48)
	_logo.custom_minimum_size = Vector2.ONE*(164 if DeviceLayout.mobile else 230)
	_title.add_theme_font_size_override("font_size",32 if DeviceLayout.mobile else 42)

func start_loading() -> void:
	if phase not in ["waiting","failed"]: return
	# Ensure the logo has reached the display before starting any expensive work.
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	phase = "loading"
	_pending.assign(ASSETS)
	_inflight.clear()
	_resources.clear()
	_finished = 0
	_total = _pending.size()
	target_progress = 0.0
	_packed_scene = null

func _process(delta: float) -> void:
	if phase == "loading": _poll_resources()
	progress_bar.value = move_toward(progress_bar.value,target_progress,delta*150.0)
	percent_label.text = "%d%%" % int(progress_bar.value)

func _poll_resources() -> void:
	for path: String in _inflight.keys():
		var fraction: Array = []
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(path,fraction)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var resource: Resource = ResourceLoader.load_threaded_get(path)
			_resources.append(resource)
			_inflight.erase(path)
			_finished += 1
		elif status in [ResourceLoader.THREAD_LOAD_FAILED,ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]:
			_fail(path)
			return
		elif not fraction.is_empty():
			_inflight[path] = float(fraction[0])
	while _inflight.size()<3 and not _pending.is_empty():
		var path: String = _pending.pop_front()
		if ResourceLoader.load_threaded_request(path) != OK:
			_fail(path)
			return
		_inflight[path] = 0.0
	var actual: float = float(_finished)
	for fraction: float in _inflight.values(): actual += fraction
	target_progress = maxf(target_progress,90.0*actual/maxi(_total,1))
	if _finished == _total:
		phase = "opening"
		target_progress = 95.0
		status_label.text = "Apriamo il rifugio…"
		_open_refuge.call_deferred()

func _open_refuge() -> void:
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	# Scene scripts and audio initialize on the main thread. Their large artwork
	# is already cached, and the loading screen remains in front until UI is ready.
	_packed_scene = load(next_scene_path) as PackedScene
	if _packed_scene == null:
		_fail(next_scene_path)
		return
	var scene: Node = _packed_scene.instantiate()
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	# Main's deferred menu setup finishes behind the loading screen.
	await get_tree().process_frame
	await get_tree().process_frame
	phase = "ready"
	target_progress = 100.0
	progress_bar.value = 100.0
	percent_label.text = "100%"
	status_label.text = "Benvenuto al rifugio."
	scene.process_mode = Node.PROCESS_MODE_INHERIT
	var fade: Tween = create_tween()
	fade.tween_property(screen,"modulate:a",0.0,0.22)
	await fade.finished
	completed.emit(scene)
	queue_free()

func _fail(path: String) -> void:
	phase = "failed"
	status_label.text = "Caricamento non riuscito. Chiudi e riapri il gioco."
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	percent_label.hide()
	loading_failed.emit(path)
	push_error("Unable to prepare refuge resource: "+path)
