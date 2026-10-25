extends RefCounted
## Own a finger from press to release. Single-finger pan never depends on mouse emulation.
const SLOP = 8.0
const FRICTION = 7.5
var claimed: Dictionary = {}
var primary: int = -1
var panning: bool = false
var pinched: bool = false
var velocity: float = 0.0
var momentum: float = 0.0
var last_position: Vector2
var last_motion_ms: int = 0
var press_elapsed: float = 0.0

func cancel(scene: Control, forget: bool=false) -> void:
	primary = -1
	panning = false
	pinched = false
	velocity = 0.0
	momentum = 0.0
	press_elapsed = 0.0
	scene.dragging = false
	scene.smg_held = false
	scene._cancel_building_hold(true)
	if forget:
		claimed.clear()
		scene.touch_points.clear()
		scene.pinch_distance = 0.0

func handle(scene: Control, event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		if not event.pressed:
			if event.canceled:
				var owned: bool = claimed.has(event.index)
				cancel(scene,true)
				return owned
			if not claimed.has(event.index): return false
			claimed.erase(event.index)
			scene.touch_points.erase(event.index)
			var tap: bool = event.index==primary and not panning and not pinched and not event.canceled and not scene._suppress_world_release and not scene.panel_open and not scene.in_main_menu
			if event.index==primary:
				if panning and not pinched and not Preferences.reduced_motion and Time.get_ticks_msec()-last_motion_ms<120:
					momentum = clampf(-velocity/scene.zoom,-1800.0/scene.zoom,1800.0/scene.zoom)
				primary = -1
				scene.dragging = false
				scene.smg_held = false
				scene._cancel_building_hold()
				if tap: scene._world_click(event.position)
			if claimed.is_empty():
				panning = false
				pinched = false
				scene.pinch_distance = 0.0
				scene._suppress_world_release = false
			return true
		if scene.in_main_menu or scene.panel_open: return false
		if claimed.is_empty() and scene.ui.world_input_blocked(event.position): return false
		if claimed.is_empty() and scene.dragging:
			# A real mouse already owns a press. A second input source cancels it.
			cancel(scene)
			claimed[event.index] = true
			scene.touch_points[event.index] = event.position
			pinched = true
			return true
		claimed[event.index] = true
		scene.touch_points[event.index] = event.position
		if claimed.size()==1:
			scene._cancel_camera_transition()
			primary = event.index
			panning = false
			pinched = false
			velocity = 0.0
			momentum = 0.0
			press_elapsed = 0.0
			last_position = event.position
			last_motion_ms = Time.get_ticks_msec()
			scene.held_pointer = event.position
			scene._world_pointer_active = true
			scene._suppress_world_release = false
			scene.dragging = true
			scene.drag_start = event.position
			scene.drag_camera = scene.camera_x
			scene.drag_distance = 0.0
			scene.target_camera = scene.camera_x
			scene.target_zoom = scene.zoom
			scene._begin_building_hold(event.position)
		else:
			pinched = true
			panning = false
			scene.dragging = false
			scene.smg_held = false
			scene._cancel_building_hold(true)
			var points: Array = scene.touch_points.values()
			scene.pinch_distance = points[0].distance_to(points[1])
		return true
	if event is InputEventScreenDrag and claimed.has(event.index):
		scene.touch_points[event.index] = event.position
		if scene.panel_open or scene.in_main_menu: return true
		if claimed.size()>=2:
			var points: Array = scene.touch_points.values()
			var distance: float = points[0].distance_to(points[1])
			if scene.pinch_distance>1:
				var center: Vector2 = (points[0]+points[1])*0.5
				var before: float = scene.target_camera+center.x/scene.target_zoom
				scene.target_zoom = scene._clamp_zoom(scene.target_zoom*distance/scene.pinch_distance)
				scene.target_camera = before-center.x/scene.target_zoom
				scene._limit_camera()
			scene.pinch_distance = distance
			return true
		if event.index!=primary or pinched: return true
		scene.held_pointer = event.position
		scene.drag_distance = maxf(scene.drag_distance,event.position.distance_to(scene.drag_start))
		if scene.drag_distance>SLOP:
			panning = true
			scene.dragging = true
			scene.smg_held = false
			scene._cancel_building_hold(true)
			scene.target_camera = scene.drag_camera-(event.position.x-scene.drag_start.x)/scene.zoom
			scene._limit_camera()
			# Absolute positions survive sparse/coalesced Android motion events.
			var now: int = Time.get_ticks_msec()
			var instant: float = event.velocity.x if absf(event.velocity.x)>1.0 else (event.position.x-last_position.x)/maxf(0.008,float(now-last_motion_ms)/1000.0)
			velocity = lerpf(velocity,clampf(instant,-2400,2400),0.6)
			last_motion_ms = now
			last_position = event.position
			scene.camera_x = scene.target_camera
		return true
	return false

func advance(scene: Control, delta: float) -> void:
	if scene.in_main_menu or scene.panel_open or Game.paused:
		momentum = 0
		return
	if primary>=0 and not panning and not pinched:
		press_elapsed += delta
		if press_elapsed>=0.12 and Game.weapon=="smg" and not scene.smg_held:
			var picked: Dictionary = scene._pick_actor(scene.held_pointer)
			if not picked.is_empty() and str(picked.kind)=="enemy":
				scene.smg_held = true
				scene._suppress_world_release = true
				scene._fire_enemy(picked.actor)
	if not claimed.is_empty() or absf(momentum)<2.0: return
	var desired: float = scene.target_camera+momentum*(1.0-exp(-FRICTION*delta))/FRICTION
	scene.target_camera = desired
	scene._limit_camera()
	if not is_equal_approx(desired,scene.target_camera): momentum = 0
	else: momentum *= exp(-FRICTION*delta)
