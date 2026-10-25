extends SceneTree
## Citizens remain human; gate status belongs only to the bottom HUD.
const Actors = preload("res://scripts/actor_visuals.gd")
var checks: int = 0
var failures: int = 0
var game: Node
var layout: Node
var preferences: Node
var scene: Control

func _initialize() -> void: run.call_deferred()
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("CITIZEN RENDER FAIL: ",message)
func settle(frames: int=3) -> void:
	for frame: int in range(frames): await process_frame
func redraw() -> void:
	scene.queue_redraw()
	await settle()
func capture(name: String) -> void:
	var folder: String = OS.get_environment("NZPF_CAPTURE_DIR")
	if folder.is_empty() or DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png(folder.path_join("FIX-RENDER-"+name+".png"))==OK,"Capture saved: "+name)
func run() -> void:
	game = root.get_node("Game")
	layout = root.get_node("DeviceLayout")
	preferences = root.get_node("Preferences")
	game.set_process(false)
	var data: String = OS.get_environment("NZPF_TEST_DATA_DIR")
	if data.is_empty(): data = ProjectSettings.globalize_path("res://.runtime/citizen-render-gate")
	DirAccess.make_dir_recursive_absolute(data)
	game.save_path = data.path_join("colony.json")
	preferences.settings_path = data.path_join("preferences.cfg")
	game._new_game()
	game.skip_tutorial()
	game.coins = 100000
	game.supplies = 10000
	for kind: String in ["residence","cafe","garden"]: ready_build(game,kind)
	game._is_loading = true
	var person: Dictionary = game._make_citizen()
	person.id = 9001
	person.job = -1
	person.away = false
	person.guard = false
	for profile: Array in [["DESKTOP",Vector2i(1440,900),false,0.0],["PHONE169",Vector2i(1920,1080),true,400.0],["PHONE",Vector2i(2400,1080),true,400.0],["TABLET",Vector2i(2048,1536),true,800.0]]:
		if is_instance_valid(scene):
			scene.queue_free()
			await settle()
		root.min_size = Vector2i.ZERO
		root.size = profile[1]
		layout.mobile = profile[2]
		layout.preview_android_shortest_dp = profile[3]
		layout.preview_insets = Vector4(24,6,12,8) if profile[2] else Vector4.ZERO
		preferences.apply_settings({"interface_size":"compact","sound_enabled":false,"screen_shake":false,"fullscreen":false},false)
		layout.refresh()
		game.citizens.clear()
		game.visitors.clear()
		game.departing_visitors.clear()
		game.threats.clear()
		scene = load(get_script().resource_path.get_base_dir().path_join("world_render_probe.gd")).new()
		scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(scene)
		scene.set_process(false)
		await settle()
		scene.ui._start_game()
		scene.ui.toast_stack.hide()
		game.paused = false
		game.citizens.append(person)
		scene.focus_city()
		scene.zoom = scene.target_zoom
		scene.camera_x = scene.target_camera
		var path: Dictionary = scene.citizen_roaming._ensure(9001,scene._roaming_width())
		for look: int in [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]:
			person.look = look
			for appearance: String in ["clean","dirty","infected"]:
				person.appearance = appearance
				for left: bool in [false,true]:
					path.x = 200.0
					path.target = 100.0 if left else 300.0
					path.wait = 0.0
					path.left = left
					scene.citizen_roaming.advance(game.citizens,scene._roaming_width(),game.CITIZEN_WALK_SPEED,0.1)
					scene._update_actor_gaits(0.1)
					await redraw()
					var label: String = "%s look %d %s left=%s" % [profile[0],look,appearance,left]
					expect(scene.rendered_actors.size()==1,label+": one resident draw call")
					if scene.rendered_actors.is_empty(): continue
					var rendered: Dictionary = scene.rendered_actors[0]
					expect(not rendered.zombie,label+": renderer always uses civilian artwork")
					expect(rendered.left==left,label+": sprite faces the actual direction of travel")
					expect(rendered.look==Actors.civilian_column(look) and rendered.appearance==appearance,label+": identity and painted condition survive reversal")
		# Real movement through a turn advances the existing alternating gait.
		person.look = 3
		person.appearance = "clean"
		scene.actor_gaits.clear()
		path.x = 200.0
		path.target = 300.0
		path.wait = 0.0
		path.left = false
		scene._update_actor_gaits(0.01)
		scene._process(0.1)
		var right_phase: float = scene.actor_gaits["citizen:9001"].phase
		await redraw()
		await capture(str(profile[0])+"-RIGHT")
		# Let the real random-destination picker choose a leftward journey.
		var picker: RandomNumberGenerator = RandomNumberGenerator.new()
		for seed: int in range(100):
			picker.seed = seed
			if picker.randf_range(30.0,scene._roaming_width()-30.0)<float(path.x)-80.0:
				path.rng.seed = seed
				break
		path.wait = 0.01
		scene._process(0.1)
		await redraw()
		expect(scene.rendered_actors[0].left and not scene.rendered_actors[0].zombie,str(profile[0])+": actual scene update reverses the human sprite")
		expect(not is_equal_approx(scene.actor_gaits["citizen:9001"].phase,right_phase),str(profile[0])+": legs keep alternating while walking left")
		await capture(str(profile[0])+"-LEFT")
		# A worker's action pose also remains human after a past leftward walk.
		person.job = int(game.buildings[0].id)
		scene.actor_clock = 3.3-fposmod(9001*0.7,4.0)
		await redraw()
		expect(scene.rendered_actors[0].frame==3 and not scene.rendered_actors[0].zombie and not scene.rendered_actors[0].left,str(profile[0])+": working pose does not inherit an idle walker direction")
		person.job = -1
		for scale_name: String in ["compact","medium","large"]:
			preferences.apply_settings({"interface_size":scale_name},false)
			layout.refresh()
			await settle()
			scene.focus_gate()
			scene.zoom = scene.target_zoom
			scene.camera_x = scene.target_camera
			await redraw()
			var bounds: Rect2 = scene.ui.gate_button.get_global_rect()
			expect(scene.ui.gate_button.is_visible_in_tree() and scene.ui.gate_label.text.contains("100%"),str(profile[0])+" "+scale_name+": bottom HUD retains the gate indicator")
			if scale_name=="compact": await capture(str(profile[0])+"-GATE-OVERVIEW")
			for factor: float in [scene._zoom_max(),scene._zoom_min(),scene._zoom_min()*1.3]:
				scene.zoom = factor
				scene.target_zoom = factor
				# Keep the actual tower in view without an overlaid status plaque.
				var tower_center: float = scene.CHECKPOINT_LEFT+scene.CHECKPOINT_HEIGHT/3.0*layout.gate_scale()
				scene.camera_x = tower_center-scene.size.x*0.33/factor
				await redraw()
				expect(scene.ui.gate_button.get_global_rect().is_equal_approx(bounds),str(profile[0])+" "+scale_name+": zoom and camera leave the bottom indicator fixed")
				expect(not scene.rendered_labels.has("INGRESSO RIFUGIO"),str(profile[0])+": no duplicate gate label is drawn in the world")
				expect(is_equal_approx(scene.ui.gate_bar.value,100.0),str(profile[0])+": bottom bar shows full integrity")
				if scale_name=="compact" and is_equal_approx(factor,scene._zoom_max()): await capture(str(profile[0])+"-GATE-ZOOM")
			game.gate_hp = 80.0
			scene.ui._update_hud()
			await redraw()
			expect(absf(scene.ui.gate_bar.value-80.0/game.gate_max*100.0)<=1.0 and scene.ui.gate_button.get_global_rect().is_equal_approx(bounds),str(profile[0])+": damage updates the remaining bottom bar without moving it")
			game.gate_hp = game.gate_max
			scene.ui._update_hud()
	game._is_loading = false
	if is_instance_valid(scene): scene.queue_free()
	await settle()
	await create_timer(1.6).timeout
	print("CITIZEN RENDER GATE: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)

func ready_build(model: Node, kind: String) -> bool:
	var fixture: Script = load(get_script().resource_path.get_base_dir().path_join("construction_fixture.gd"))
	return fixture.build_ready(model,kind)
