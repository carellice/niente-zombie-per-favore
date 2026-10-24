extends SceneTree
## Actual viewport entry, gate arrivals, faster movement and save migration.
var checks: int = 0
var failures: int = 0
var knocks: int = 0
var visitor_sounds: int = 0
var game: Node
var ui: CanvasLayer
var scene: Control

func _initialize() -> void:
	run.call_deferred()
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("ARRIVAL FAIL: ",message)
func settle(frames: int=4) -> void:
	for frame: int in range(frames): await process_frame
func refresh() -> void:
	ui._update_hud()
	await settle()
func click(point: Vector2) -> void:
	for down: bool in [true,false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event,true)
		await process_frame
	await settle()
func run() -> void:
	game = root.get_node("Game")
	var layout: Node = root.get_node("DeviceLayout")
	var preferences: Node = root.get_node("Preferences")
	var data: String = OS.get_environment("NZPF_TEST_DATA_DIR")
	if data.is_empty(): data = ProjectSettings.globalize_path("res://.runtime/arrival-feedback")
	DirAccess.make_dir_recursive_absolute(data)
	game.save_path = data.path_join("colony.json")
	preferences.settings_path = data.path_join("preferences.cfg")
	preferences.apply_settings({"sound_enabled":false,"screen_shake":false,"fullscreen":false},false)
	game.set_process(false)
	game._new_game()
	game.skip_tutorial()
	ready_build(game,"residence")
	ready_build(game,"cafe")
	layout.mobile = false
	root.size = Vector2i(1440,900)
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	ui = scene.ui
	ui.set_process(false)
	await settle()
	ui._start_game()
	scene.focus_gate()
	scene.zoom = scene.target_zoom
	scene.camera_x = scene.target_camera
	await refresh()
	var alert: Button = ui.zombie_alert
	expect(not alert.visible,"An empty street has no arrival icon")
	game.wave_clock = 11.0
	await refresh()
	expect(not alert.visible,"A countdown cannot announce zombies before they appear")
	game._start_wave()
	await refresh()
	expect(not alert.visible,"Queued zombies do not reveal an unseen arrival")
	game._spawn_queue.clear()
	game._add_threat("brute",-1600.0)
	var enemy: Dictionary = game.threats.back()
	await refresh()
	expect(not alert.visible and scene._visible_zombie_ids().is_empty(),"An offscreen spawn never shows the icon")
	enemy.x = scene.camera_x-300.0
	await refresh()
	expect(not alert.visible,"Walking toward the viewport remains unannounced outside it")
	enemy.x = scene.camera_x+10.0
	await refresh()
	expect(alert.visible and scene._visible_zombie_ids().has(int(enemy.id)),"The icon appears as the first zombie enters the viewport")
	expect(alert.text.is_empty(),"The warning remains an icon without a wave banner")
	enemy.x = -65.0
	scene.camera_x = 950.0
	scene.target_camera = 950.0
	await refresh()
	expect(scene._visible_zombie_ids().is_empty() and alert.visible,"A spotted zombie remains signalled while exploring the city")
	var camera_before: float = scene.camera_x
	var hp_before: float = enemy.hp
	await click(alert.get_global_transform_with_canvas()*(alert.size*0.5))
	expect(is_equal_approx(scene.camera_x,camera_before) and not scene.camera_transition.is_empty(),"A real HUD tap starts smooth camera motion without snapping")
	for step: int in range(90): scene._update_camera(1.0/60.0)
	expect(is_equal_approx(scene.camera_x,scene.target_camera) and scene.camera_x<0,"The camera reaches the firing post")
	expect(enemy.hp==hp_before and scene.shots.is_empty(),"The alert tap cannot shoot through the HUD")
	game.shot_cooldown = 0.0
	await click(Vector2(scene._sx(enemy.x),scene._ground()-32.0*scene.zoom))
	expect(enemy.hp<hp_before and scene.shots.size()==1,"The next world tap fires a manual shot")
	game.threats.clear()
	await refresh()
	expect(not alert.visible,"Removing the last spotted enemy clears the icon")
	game._spawn_queue.append("walker")
	await refresh()
	expect(not alert.visible,"Unseen reinforcements cannot keep an old alert alive")
	game._spawn_queue.clear()
	game._add_threat("walker",-2000.0)
	await refresh()
	expect(not alert.visible,"A new offscreen zombie must enter the viewport before being announced")
	game.threats[0].x = -65.0
	ui.show_main_menu()
	await refresh()
	expect(not alert.visible,"Menu coverage hides the world and its alerts")
	ui._start_game()
	await refresh()
	expect(alert.visible,"Returning to gameplay reveals an onscreen threat")
	game.threats.clear()
	await refresh()
	layout.mobile = true
	layout.preview_android_shortest_dp = 400.0
	layout.refresh()
	scene.focus_gate()
	scene.zoom = scene.target_zoom
	scene.camera_x = scene.target_camera
	ui._show_armory()
	game._add_threat("walker",100.0)
	await refresh()
	expect(not alert.visible and scene._visible_zombie_ids().is_empty(),"A fullscreen phone dialog does not discover covered zombies")
	ui._close_modal()
	await refresh()
	expect(alert.visible,"Closing the phone dialog reveals the zombie and its warning together")
	game.threats.clear()
	await refresh()
	game.toast.connect(func(message: String) -> void:
		if message.contains("bussa"): knocks += 1
	)
	game.sfx.connect(func(kind: String) -> void:
		if kind=="visitor": visitor_sounds += 1
	)
	game._visitor_timer = 10000.0
	game.entrance_x = -1500.0
	game._spawn_visitor()
	var visitor: Dictionary = game.visitors[0]
	expect(knocks==0 and visitor_sounds==0 and not game.has_waiting_visitors(),"Spawning a survivor creates no gate message or sound")
	var start_x: float = visitor.x
	game._tick_visitors(1.0)
	expect(is_equal_approx(visitor.x-start_x,52.0),"Survivors walk at 52 units per second")
	expect(knocks==0 and not game.visitor_at_gate(visitor),"The approach cannot claim someone is already knocking")
	visitor.x = 195.0-53.0
	game._tick_visitors(1.0)
	expect(visitor.x==194.0 and knocks==0 and not game.has_waiting_visitors(),"One unit before the queue slot is still an approach")
	game._tick_visitors(0.1)
	expect(visitor.x==195.0 and knocks==1 and visitor_sounds==1 and game.has_waiting_visitors(),"Reaching the actual gate slot emits message and sound once")
	game._tick_visitors(4.0)
	expect(knocks==1 and visitor_sounds==1,"Waiting at the gate does not repeat announcements")
	game._spawn_visitor()
	var second: Dictionary = game.visitors[1]
	second.x = game.visitor_destination(1)-1.0
	game._tick_visitors(0.1)
	expect(second.x==game.visitor_destination(1) and knocks==2 and game.visitor_at_gate(second),"The second queue slot counts as reaching the entrance")
	game.reject_visitor(int(visitor.id))
	var departure_x: float = visitor.x
	game._tick_visitors(1.0)
	expect(is_equal_approx(departure_x-visitor.x,62.0),"Rejected survivors depart at the faster pace")
	game._tick_visitors(2.0)
	expect(second.x==195.0 and knocks==2,"Moving forward in the queue does not repeat a knock")
	game._spawn_visitor()
	game.reject_visitor(int(game.visitors.back().id))
	game._tick_visitors(0.1)
	expect(knocks==2,"An early rejection never announces a gate arrival")
	game._spawn_visitor()
	game.visitors.back().x = -500.0
	game.save_game()
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.save_path))
	for person: Dictionary in legacy.visitors:
		person.erase("arrival_notified")
		person.walk_speed = 32.0
	var save: FileAccess = FileAccess.open(game.save_path,FileAccess.WRITE)
	save.store_string(JSON.stringify(legacy))
	save.close()
	expect(game.load_game(),"A save without arrival state remains loadable")
	expect(game.visitors[0].x==195.0 and game.visitors[0].arrival_notified,"A previously waiting visitor is not announced again after migration")
	expect(game.visitors[1].x==-500.0 and not game.visitors[1].arrival_notified and game.visitors[1].walk_speed==52.0,"A legacy traveller keeps position, receives the faster pace and awaits arrival")
	game._visitor_timer = 10000.0
	game._tick_visitors(20.0)
	expect(knocks==3 and game.visitors[1].arrival_notified,"A migrated traveller is announced on the actual arrival")
	game.save_game()
	game.load_game()
	game._tick_visitors(0.1)
	expect(knocks==3,"Saving and reloading cannot repeat a notification")
	game.threats.clear()
	for kind: String in ["walker","runner","brute","infiltrator"]: game._add_threat(kind,0.0)
	game._tick_threats(1.0)
	for index: int in range(4):
		var expected: float = [54.0,104.0,37.0,46.0][index]
		expect(game.threats[index].x==expected,"Zombie archetype %d covers its faster distance in one second" % index)
	game.save_game()
	game.load_game()
	expect(game.threats[0].speed==54.0 and game.threats[1].speed==104.0 and game.threats[2].speed==37.0,"Loaded zombies keep the updated speeds")
	var citizen: Dictionary = game._make_citizen()
	citizen.id = 500
	scene.actor_clock = 0.0
	var city_x: float = scene._citizen_world_x(citizen)
	scene.actor_clock = 1.0
	expect(is_equal_approx(scene._citizen_world_x(citizen)-city_x,30.0),"Residents also walk faster in the village")
	scene.queue_free()
	await settle()
	print("ARRIVAL FEEDBACK: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)

func ready_build(model: Node, kind: String) -> bool:
	var fixture: Script = load(get_script().resource_path.get_base_dir().path_join("construction_fixture.gd"))
	return fixture.build_ready(model,kind)
