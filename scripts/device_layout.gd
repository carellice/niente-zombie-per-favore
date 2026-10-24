extends Node
## Keep the illustrated world at its design scale, with a separate phone UI.

signal changed

const PHONE_UI_HEIGHT: float = 640.0
const PHONE_UI_MIN_WIDTH: float = 1024.0
const TOUCH_TARGET: float = 72.0
const PHONE_HEADER_HEIGHT: float = 84.0
const PHONE_FOOTER_HEIGHT: float = 92.0
const ANDROID_TABLET_MIN_DP: float = 600.0
const ANDROID_PHONE_ACTOR_SCALE: float = 2.2
const ANDROID_PHONE_BUILDING_SCALE: float = 1.6
const ANDROID_PHONE_GATE_SCALE: float = 1.15
var mobile: bool = OS.has_feature("android") or OS.has_feature("ios")
var _signature: String = ""
var _clock: float = 0.0
var preview_insets: Vector4 = Vector4.ZERO
var preview_android_shortest_dp: float = 0.0

func _ready() -> void:
	# The same layout can be checked with the native desktop renderer.
	if OS.get_cmdline_user_args().has("--mobile-preview"):
		mobile = true
	if OS.get_cmdline_user_args().has("--android-phone-preview"):
		mobile = true
		preview_android_shortest_dp = 400.0
	elif OS.get_cmdline_user_args().has("--android-tablet-preview"):
		mobile = true
		preview_android_shortest_dp = 800.0
	var window: Window = get_tree().root
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	if mobile:
		window.min_size = Vector2i.ZERO
		ensure_fullscreen()
	window.size_changed.connect(refresh)
	_connect_preferences.call_deferred()
	refresh.call_deferred()

func _connect_preferences() -> void:
	var preferences: Node = get_node_or_null("/root/Preferences")
	if preferences!=null and not preferences.changed.is_connected(refresh):
		preferences.changed.connect(refresh)
	refresh()

func ensure_fullscreen() -> void:
	if not mobile or DisplayServer.get_name() == "headless": return
	# A phone has no windowed mode. Ignore desktop preferences saved by older APKs.
	if OS.has_feature("android") or OS.has_feature("ios"):
		if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and is_inside_tree():
		ensure_fullscreen()
		refresh.call_deferred()

func _process(delta: float) -> void:
	if not mobile: return
	_clock += delta
	if _clock >= 0.5:
		_clock = 0.0
		refresh()

func ui_scale() -> float:
	var visible: Vector2 = get_viewport().get_visible_rect().size
	var base: float = minf(visible.y/PHONE_UI_HEIGHT,visible.x/PHONE_UI_MIN_WIDTH) if mobile else 1.0
	var preferences: Node = get_node_or_null("/root/Preferences")
	var preference: String = str(preferences.interface_size) if preferences!=null else "compact"
	var factor: float = float({"compact":1.0,"medium":1.1,"large":1.2}.get(preference,1.0))
	return base*factor

func ui_size() -> Vector2:
	return get_viewport().get_visible_rect().size / maxf(ui_scale(), 0.01)

static func android_phone_for_display(android: bool, pixels: Vector2i, density_dpi: int) -> bool:
	# Android densityDpi measures logical dp, not the panel's raw resolution.
	if not android or density_dpi<=0 or pixels.x<=0 or pixels.y<=0: return false
	return float(mini(pixels.x,pixels.y))*160.0/float(density_dpi)<ANDROID_TABLET_MIN_DP

func android_phone() -> bool:
	if not mobile: return false
	if preview_android_shortest_dp>0:
		return preview_android_shortest_dp<ANDROID_TABLET_MIN_DP
	if not OS.has_feature("android"): return false
	return android_phone_for_display(true,DisplayServer.screen_get_size(),DisplayServer.screen_get_dpi())

func actor_scale() -> float:
	return ANDROID_PHONE_ACTOR_SCALE if android_phone() else 1.0

func building_scale() -> float:
	return ANDROID_PHONE_BUILDING_SCALE if android_phone() else 1.0

func gate_scale() -> float:
	return ANDROID_PHONE_GATE_SCALE if android_phone() else 1.0

static func safe_rect_in_ui(window_rect: Rect2, display_safe_rect: Rect2, logical_size: Vector2) -> Rect2:
	if not window_rect.has_area() or not display_safe_rect.has_area():
		return Rect2(Vector2.ZERO, logical_size)
	var visible: Rect2 = window_rect.intersection(display_safe_rect)
	if not visible.has_area(): return Rect2(Vector2.ZERO, logical_size)
	var factor: Vector2 = logical_size / window_rect.size
	return Rect2((visible.position-window_rect.position)*factor, visible.size*factor)

func safe_rect() -> Rect2:
	var dimensions: Vector2 = ui_size()
	if not mobile: return Rect2(Vector2.ZERO, dimensions)
	if preview_insets != Vector4.ZERO:
		return Rect2(Vector2(preview_insets.x,preview_insets.y),dimensions-Vector2(preview_insets.x+preview_insets.z,preview_insets.y+preview_insets.w))
	if not OS.has_feature("android") and not OS.has_feature("ios"):
		return Rect2(Vector2.ZERO, dimensions)
	var window_rect: Rect2 = Rect2(Vector2(DisplayServer.window_get_position()),Vector2(DisplayServer.window_get_size()))
	return safe_rect_in_ui(window_rect,Rect2(DisplayServer.get_display_safe_area()),dimensions)

func refresh() -> void:
	var signature: String = str(ui_size())+str(safe_rect())+str(mobile)+str(android_phone())
	if signature == _signature: return
	_signature = signature
	changed.emit()
