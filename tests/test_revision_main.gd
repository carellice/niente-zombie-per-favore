extends SceneTree
## Real input and presentation for the empty refuge, smooth defence and SMG.

var game: Node
var scene: Control
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("REVISION MAIN FAIL: ",description)

func pointer(point: Vector2, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = pressed
	root.push_input(event,true)
	await process_frame

func capture(filename: String) -> void:
	if DisplayServer.get_name()=="headless" or not OS.get_cmdline_user_args().has("--capture-revision"):
		return
	scene.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png("C:/Users/flavi/Desktop/CODEX_niente_zombie_per_favore/docs/"+filename)==OK,"native capture "+filename)

func run() -> void:
	game = root.get_node("Game")
	game.save_path = "user://revision-main-save.json"
	game.set_process(false)
	game._new_game()
	var preferences: Node = root.get_node("Preferences")
	preferences.settings_path = "user://revision-main-settings.cfg"
	preferences.apply_settings({"sound_enabled":false,"screen_shake":false,"fullscreen":false},false)
	root.size = Vector2i(1440,900)
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.set_process(false)
	expect(game.citizens.is_empty() and game.buildings.is_empty() and game.threats.is_empty() and game.visitors.is_empty(),"new world is truly empty")
	expect(scene._guard_ids()==[0] and scene._first_guard_id()==0,"one permanent military post exists without resident guards")
	scene.ui._start_game()
	await process_frame
	await process_frame
	expect(game.tutorial_stage=="intro","playing a fresh refuge presents the tutorial intro")
	await capture("NUOVA-PARTITA-TUTORIAL.png")
	scene.ui._close_modal()
	await capture("RIFUGIO-VUOTO.png")
	game.skip_tutorial()
	game.paused = false
	scene.ui.toast_stack.visible = false
	game._add_threat("walker",-65.0)
	var enemy: Dictionary = game.threats.back()
	# Reveal the zombie first; the shortcut remains useful while exploring.
	scene.ui._update_hud()
	scene.camera_x = 950.0
	scene.target_camera = 950.0
	scene.zoom = 0.72
	scene.target_zoom = 0.72
	scene.ui._update_hud()
	await process_frame
	var alert: Button = scene.ui.zombie_alert
	var start_x: float = scene.camera_x
	var start_zoom: float = scene.zoom
	await pointer(alert.get_global_rect().get_center(),true)
	await pointer(alert.get_global_rect().get_center(),false)
	expect(is_equal_approx(scene.camera_x,start_x) and is_equal_approx(scene.zoom,start_zoom),"alert activation does not snap camera or zoom")
	expect(not scene.camera_transition.is_empty() and scene.target_camera<0.0,"alert starts an eased journey to the military")
	var previous: float = scene.camera_x
	var largest_step: float = 0.0
	var monotonic: bool = true
	var first_step: float = 0.0
	for index: int in range(90):
		scene._update_camera(1.0/60.0)
		var movement: float = absf(scene.camera_x-previous)
		if index==0:
			first_step = movement
		largest_step = maxf(largest_step,movement)
		monotonic = monotonic and scene.camera_x<=previous+0.001
		previous = scene.camera_x
	expect(first_step<5.0 and largest_step<40.0 and monotonic,"camera accelerates gently, moves continuously and never overshoots")
	expect(scene.camera_transition.is_empty() and is_equal_approx(scene.camera_x,scene.target_camera) and is_equal_approx(scene.zoom,scene.target_zoom),"camera settles exactly on the military view")
	expect(scene.shots.is_empty(),"navigation never fires a weapon")
	var point: Vector2 = Vector2(scene._sx(float(enemy.x)),scene._ground()-32.0*scene.zoom)
	scene._update_hover(point)
	await capture("DIFESA-FLUIDA.png")
	await pointer(point,true)
	await pointer(point,false)
	expect(game.threats.is_empty(),"base pistol downs a standard walker in one hit")
	expect(scene.shots.size()==1 and scene.guard_flashes.has(0),"one click produces one permanent military firing animation and tracer")
	game.owned_weapons.append("smg")
	game.equip_weapon("smg")
	game.shot_cooldown = 0.0
	game._add_threat("brute",80.0)
	enemy = game.threats.back()
	point = Vector2(scene._sx(float(enemy.x)),scene._ground()-32.0*scene.zoom)
	var ammo_before: int = game.ammo
	var shots_before: int = scene.shots.size()
	await pointer(point,true)
	expect(scene.smg_held and game.ammo==ammo_before-1 and scene.shots.size()==shots_before+1,"pressing SMG on an enemy starts a real burst with one first shot")
	for index: int in range(4):
		game.advance(0.13)
		scene.held_pointer = Vector2(scene._sx(float(enemy.x)),scene._ground()-32.0*scene.zoom)
		scene._update_held_fire()
	expect(game.ammo==ammo_before-5 and scene.shots.size()==shots_before+5,"holding SMG repeats actual damage, ammo and tracers at its cooldown")
	expect(float(enemy.hp)==5.0,"five SMG rounds each deal their actual 44 damage")
	await pointer(Vector2(50,50),false)
	var released_ammo: int = game.ammo
	game.advance(0.5)
	scene._update_held_fire()
	expect(not scene.smg_held and game.ammo==released_ammo,"releasing over the HUD stops the burst without automatic guard fire")
	expect(not scene.reload_queue.is_empty(),"successful nonpistol shots schedule a mechanical reload cycle")
	scene._update_reload_audio(2.0)
	expect(scene.reload_queue.is_empty(),"reload events are consumed once even with audio muted")
	# Portata belongs to actual world distance, including held SMG input. A
	# failed attempt must not show a muzzle flash, tracer or impact particles.
	game.threats.clear()
	game.equip_weapon("pistol")
	game.shot_cooldown = 0.0
	game._add_threat("walker",-1000.0)
	enemy = game.threats.back()
	var range_ammo: int = game.ammo
	var range_shots: int = scene.shots.size()
	var range_particles: int = scene.particles.size()
	expect(not scene._fire_enemy(enemy),"clicking beyond pistol range cannot fire")
	expect(game.ammo==range_ammo and scene.shots.size()==range_shots and scene.particles.size()==range_particles,"out-of-range click creates no ammo use, tracer or impact")
	game.equip_weapon("smg")
	scene.camera_x = -850.0
	scene.target_camera = -850.0
	scene.smg_held = true
	scene.held_pointer = Vector2(scene._sx(float(enemy.x)),scene._ground()-32.0*scene.zoom)
	for index: int in range(12):
		scene._update_held_fire()
	expect(scene.smg_held and game.ammo==range_ammo and scene.shots.size()==range_shots,"held SMG waits silently for an out-of-range enemy")
	enemy.x = 80.0
	scene.held_pointer = Vector2(scene._sx(float(enemy.x)),scene._ground()-32.0*scene.zoom)
	scene._update_held_fire()
	expect(game.ammo==range_ammo-1 and scene.shots.size()==range_shots+1,"held SMG fires when the followed enemy reaches its range")
	scene.smg_held = false
	game.threats.clear()
	game.visitors.clear()
	scene.camera_x = -850.0
	scene.target_camera = -850.0
	scene.zoom = 1.25
	scene.target_zoom = 1.25
	scene._report_world_view()
	game._spawn_visitor()
	var visitor: Dictionary = game.visitors.back()
	expect(float(visitor.x)<-1000.0 and scene._sx(float(visitor.x))<-100.0,"visitors begin outside even the furthest-left zoomed camera")
	var original_x: float = float(visitor.x)
	game._tick_visitors(1.0)
	expect(float(visitor.x)>original_x,"new visitors enter by walking rather than materializing on the road")
	game._start_wave()
	game._tick_waves(0.1)
	expect(not game.threats.is_empty() and float(game.threats[0].x)<-1000.0,"wave zombies also start beyond the visible world edge")
	var before: float = float(visitor.x)
	game.set_world_view(-1400.0,0.0)
	expect(is_equal_approx(float(visitor.x),before),"new entrance positions never teleport an existing arrival")
	visitor.x = 150.0
	game.threats[0].x = 150.0
	var hp: float = float(visitor.citizen.hp)
	game._tick_threats(5.0)
	expect(float(visitor.citizen.hp)==hp,"zombies ignore survivors even when occupying the same street position")
	scene.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	for path: String in [game.save_path,game.save_path+".tmp",game.save_path+".bak",preferences.settings_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	print("Revision main: %d checks, %d failures." % [checks,failures])
	quit(0 if failures==0 else 1)
