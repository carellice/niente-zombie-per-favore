extends SceneTree
## Real scene regression: live admission health and a continuous rejected walk.

const Actors = preload("res://scripts/actor_visuals.gd")
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
		printerr("SURVIVOR SCENE FAIL: ",description)

func portrait(node: Node) -> TextureRect:
	if node is TextureRect and node.has_meta("citizen_look"):
		return node
	for child: Node in node.get_children():
		var found: TextureRect = portrait(child)
		if found != null:
			return found
	return null

func health_bar(node: Node, id: int) -> ProgressBar:
	if node is ProgressBar and int(node.get_meta("visitor_health_id",-1)) == id:
		return node
	for child: Node in node.get_children():
		var found: ProgressBar = health_bar(child,id)
		if found != null:
			return found
	return null

func snapshot(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	scene.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var folder: String = ProjectSettings.globalize_path("res://docs")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-folder="):
			folder = arg.trim_prefix("--evidence-folder=")
	expect(root.get_texture().get_image().save_png(folder.path_join(filename)) == OK,"native capture "+filename)

func add_visitor(look: int, world_x: float) -> Dictionary:
	game._spawn_visitor()
	var visitor: Dictionary = game.visitors.back()
	visitor.citizen.look = look
	visitor.citizen.name = game._unique_citizen_name(look)
	visitor.x = world_x
	visitor.suspicious = false
	return visitor

func run() -> void:
	game = root.get_node("Game")
	game.save_path = "user://survivor-scene-save.json"
	game.set_process(false)
	game._new_game()
	var preferences: Node = root.get_node("Preferences")
	preferences.settings_path = "user://survivor-scene-settings.cfg"
	preferences.apply_settings({"sound_enabled":false,"screen_shake":false,"fullscreen":false},false)
	root.size = Vector2i(1440,900)
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.ui._start_game()
	scene.set_process(false)
	scene.camera_x = -420.0
	scene.target_camera = -420.0
	scene.zoom = 1.0
	scene.target_zoom = 1.0
	scene.ui.toast_stack.visible = false
	game.visitors.clear()
	game.departing_visitors.clear()
	game.threats.clear()
	var visitor: Dictionary = add_visitor(8,195.0)
	var key: String = "visitor:%d" % int(visitor.id)
	scene._update_actor_gaits(0.1)
	var phase: float = float(scene.actor_gaits[key].phase)
	var start_x: float = float(visitor.x)
	scene.ui.show_visitor(int(visitor.id))
	expect(not game.paused,"admission preserves live simulation")
	expect(portrait(scene.ui.modal).texture == Actors.texture(8),"new visitor portrait matches world appearance")
	var bar: ProgressBar = health_bar(scene.ui.modal,int(visitor.id))
	expect(bar != null and bar.value == 100.0,"admission shows selected survivor health")
	game._add_threat("walker",start_x-28.0)
	game._tick_threats(2.0)
	scene.ui._update_hud()
	expect(float(visitor.citizen.hp)<100.0 and is_equal_approx(bar.value,float(visitor.citizen.hp)),"open admission updates actual health during attack")
	game.threats.clear()
	scene.ui._reject_visitor(int(visitor.id))
	expect(scene.ui.panel_kind.is_empty(),"rejection closes admission")
	expect(game.visitors.is_empty() and game.departing_visitors.size()==1,"rejected actor remains visible outside admission queue")
	expect(is_equal_approx(float(game.departing_visitors[0].x),start_x),"rejection retains exact world position")
	scene._update_actor_gaits(0.0)
	expect(is_equal_approx(float(scene.actor_gaits[key].phase),phase),"rejection retains walking phase")
	game._tick_visitors(0.4)
	scene._update_actor_gaits(0.4)
	expect(float(visitor.x)<start_x and bool(visitor.facing_left),"rejected actor turns left and walks away")
	expect(not is_equal_approx(float(scene.actor_gaits[key].phase),phase) and float(scene.actor_gaits[key].blend)>0.0,"rejected walk is articulated and follows displacement")
	expect(scene._pick_actor(Vector2(scene._sx(float(visitor.x)),scene._ground()-28)).is_empty(),"departing actor cannot reopen an admission card")
	# Capture the actual checkpoint with a threatened newcomer and a departing one.
	visitor.x = -125.0
	visitor.citizen.look = 10
	var newcomer: Dictionary = add_visitor(9,120.0)
	newcomer.citizen.hp = 61.0
	add_visitor(11,195.0)
	game._add_threat("runner",92.0)
	game._tick_threats(0.15)
	scene._update_actor_gaits(0.1)
	scene.actor_gaits[key].phase = 0.25
	scene.actor_gaits[key].blend = 1.0
	await snapshot("SUPERSTITI-ESTERNO.png")
	scene.ui.show_visitor(int(newcomer.id))
	scene.ui._update_hud()
	await process_frame
	expect(portrait(scene.ui.modal).texture == Actors.texture(9),"wounded newcomer keeps the same admission portrait")
	bar = health_bar(scene.ui.modal,int(newcomer.id))
	expect(bar != null and is_equal_approx(bar.value,float(newcomer.citizen.hp)),"wounded card reflects current health")
	await snapshot("SUPERSTITI-AMMISSIONE.png")
	newcomer.citizen.hp = 0.1
	game._tick_threats(1.0)
	scene.ui._update_hud()
	await process_frame
	await process_frame
	expect(scene.ui.panel_kind.is_empty(),"loss closes stale admission card")
	scene.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	print("Survivor scene: %d checks, %d failures." % [checks,failures])
	quit(0 if failures == 0 else 1)
