extends SceneTree
## Regression for the admission portrait: real pointer input must select geometry,
## never the first overlapping visitor in the simulation's array.

const ActorVisuals = preload("res://scripts/actor_visuals.gd")
var game: Node
var preferences: Node
var scene: Control
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ",description)

func click(point: Vector2) -> void:
	for pressed: bool in [true,false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame

func move_pointer(point: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	root.push_input(event,true)
	await process_frame

func portrait(node: Node) -> TextureRect:
	if node is TextureRect and node.has_meta("citizen_look"):
		return node
	for child: Node in node.get_children():
		var found: TextureRect = portrait(child)
		if found:
			return found
	return null

func has_label(node: Node, caption: String) -> bool:
	if node is Label and node.text == caption:
		return true
	for child: Node in node.get_children():
		if has_label(child,caption):
			return true
	return false

func button_named(node: Node, caption: String) -> Button:
	if node is Button and node.text == caption:
		return node
	for child: Node in node.get_children():
		var found: Button = button_named(child,caption)
		if found:
			return found
	return null

func queue_fixture() -> void:
	game.visitors.clear()
	game.threats.clear()
	for i: int in range(3):
		var citizen: Dictionary = game._make_citizen()
		citizen.name = ["Ada Barista","Marta Berretto","Iris Dottoressa"][i]
		citizen.look = [1,0,3][i]
		game.visitors.append({"id":900+i,"citizen":citizen,"x":195.0-i*54.0,"suspicious":false,"hint":"In attesa."})

func point_for(visitor: Dictionary, body_height: float = 32.0) -> Vector2:
	return Vector2(scene._sx(float(visitor.x)),scene._ground()-body_height*scene.zoom)

func assert_admission(visitor: Dictionary, context: String) -> void:
	expect(scene.ui.panel_kind == "visitor" and scene.ui.panel_id == int(visitor.id),context+": admission is for clicked ID")
	var photograph: TextureRect = portrait(scene.ui.modal) if is_instance_valid(scene.ui.modal) else null
	expect(photograph != null and int(photograph.get_meta("citizen_look",-1)) == int(visitor.citizen.look),context+": portrait preserves clicked look")
	expect(photograph != null and photograph.texture == ActorVisuals.texture(int(visitor.citizen.look)),context+": actual portrait texture matches street identity")
	expect(is_instance_valid(scene.ui.modal) and has_label(scene.ui.modal,str(visitor.citizen.name)),context+": displayed name belongs to clicked survivor")

func close_dialog() -> void:
	scene.ui._close_modal()
	await process_frame
	await process_frame

func select_and_check(visitor: Dictionary, body_height: float, context: String) -> void:
	var point: Vector2 = point_for(visitor,body_height)
	await move_pointer(point)
	expect(scene.hover == "visitor:%d" % int(visitor.id),context+": hover and click identify the same survivor")
	await click(point)
	assert_admission(visitor,context)
	await close_dialog()

func run() -> void:
	game = root.get_node("Game")
	preferences = root.get_node("Preferences")
	game.save_path = "user://visitor-selection-save.json"
	preferences.settings_path = "user://visitor-selection-settings.cfg"
	game._new_game()
	game.skip_tutorial()
	ready_build(game,"residence")
	game.set_process(false)
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
	await process_frame
	await process_frame
	queue_fixture()
	for scale: float in [0.6,0.82,1.25]:
		scene.zoom = scale
		scene.target_zoom = scale
		for visitor: Dictionary in game.visitors.duplicate(true):
			for body_height: float in [60.0,32.0,-3.0]:
				await select_and_check(visitor,body_height,"zoom %.2f, ID %d, y %.0f" % [scale,int(visitor.id),body_height])
	# Reversing array order must not reverse who opens under the cursor.
	game.visitors.reverse()
	for visitor: Dictionary in game.visitors.duplicate(true):
		await select_and_check(visitor,32.0,"reversed array, ID %d" % int(visitor.id))
	# A close zombie's generous target must not steal a tap on a survivor.
	queue_fixture()
	game._add_threat("walker",164.0)
	var enemy: Dictionary = game.threats[0]
	var original_hp: float = float(enemy.hp)
	await select_and_check(game.visitors[1],32.0,"center survivor with zombie 23 units away")
	expect(float(enemy.hp) == original_hp,"Selecting a survivor does not shoot its zombie neighbor")
	# Reverse interaction: the directly tapped zombie still receives the shot.
	game.shot_cooldown = 0.0
	await move_pointer(Vector2(scene._sx(float(enemy.x)),scene._ground()-32.0*scene.zoom))
	expect(scene.hover == "enemy:%d" % int(enemy.id),"Hover identifies directly targeted nearby zombie")
	await click(Vector2(scene._sx(float(enemy.x)),scene._ground()-32.0*scene.zoom))
	expect(float(enemy.hp) < original_hp and scene.ui.panel_kind != "visitor","Direct zombie tap fires rather than opening a neighbor")
	# Actions carry the selected ID all the way into the simulation.
	queue_fixture()
	var rejected: Dictionary = game.visitors[1].duplicate(true)
	await click(point_for(rejected))
	assert_admission(rejected,"before rejecting center")
	await process_frame
	await process_frame
	var reject: Button = button_named(scene.ui.modal,"Rifiuta l'ingresso")
	expect(reject != null,"Reject button exists for selected survivor")
	if reject:
		await click(reject.get_global_rect().get_center())
	expect(game.visitors.size() == 2 and int(game.visitors[0].id) == 900 and int(game.visitors[1].id) == 902,"Reject removes only the clicked center survivor")
	await close_dialog()
	game._tick_visitors(10.0)
	for visitor: Dictionary in game.visitors.duplicate(true):
		await select_and_check(visitor,32.0,"queue closes after rejection, ID %d" % int(visitor.id))
	queue_fixture()
	game.citizens.clear()
	game.citizens.append(game._make_citizen())
	var accepted: Dictionary = game.visitors[2].duplicate(true)
	await click(point_for(accepted))
	assert_admission(accepted,"before accepting back survivor")
	await process_frame
	await process_frame
	var accept: Button = button_named(scene.ui.modal,"✓  Accogli nel rifugio")
	expect(accept != null and not accept.disabled,"Accept button is available with a free bed")
	if accept:
		await click(accept.get_global_rect().get_center())
	expect(game.visitors.size() == 2 and int(game.visitors[0].id) == 900 and int(game.visitors[1].id) == 901,"Accept removes only the clicked back survivor from queue")
	expect(game.citizens.size() == 2 and game.citizens[1].name == accepted.citizen.name and int(game.citizens[1].look) == int(accepted.citizen.look),"Admitted citizen keeps selected name and look")
	await close_dialog()
	# Optional normal-renderer evidence, using the exact screenshot composition.
	if OS.get_cmdline_user_args().has("--capture-selection"):
		queue_fixture()
		scene.zoom = 1.25
		scene.shots.clear()
		scene.particles.clear()
		scene.guard_flashes.clear()
		scene.ui.toast_stack.visible = false
		scene.queue_redraw()
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/SELEZIONE-CODA.png")
		await click(point_for(game.visitors[1]))
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/SELEZIONE-CENTRALE.png")
	scene.queue_free()
	await process_frame
	for path: String in [game.save_path,game.save_path+".tmp",game.save_path+".bak",preferences.settings_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	print("VISITOR SELECTION: ",checks," checks; ",failures," failures")
	quit(0 if failures == 0 else 1)

func ready_build(model: Node, kind: String) -> bool:
	var fixture: Script = load(get_script().resource_path.get_base_dir().path_join("construction_fixture.gd"))
	return fixture.build_ready(model,kind)
