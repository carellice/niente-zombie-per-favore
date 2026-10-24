extends SceneTree
## Real viewport event routing smoke test; isolated save file.
var failures: Array[String] = []
var checks: int = 0
var game: Node
var scene: Control

func _initialize() -> void:
	call_deferred("run")

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: ",message)

func click(pos: Vector2) -> void:
	for pressed: bool in [true,false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = pos
		event.global_position = pos
		root.push_input(event,true)
		await process_frame

func find_button(node: Node, caption: String) -> Button:
	if node is Button and node.text == caption:
		return node
	for child: Node in node.get_children():
		var found: Button = find_button(child,caption)
		if found != null:
			return found
	return null

func run() -> void:
	game = root.get_node("Game")
	game.save_path = "res://tests/.interaction-save.json"
	game._new_game()
	game.set_process(false)
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.ui._start_game()
	await process_frame
	expect(scene.mouse_filter == Control.MOUSE_FILTER_IGNORE,"World root does not consume gameplay clicks")
	var enemy: Dictionary = game.threats[0]
	var hp: float = enemy.hp
	await click(Vector2(scene._sx(enemy.x),scene._ground()-32.0))
	expect(enemy.hp < hp,"Click through viewport fires at zombie")
	expect(not scene.shots.is_empty(),"A real shot creates visible tracer feedback")
	var building: Dictionary = game.buildings[1]
	await click(scene._building_rect(int(building.id)).get_center())
	expect(scene.ui.panel_kind == "building","Building click opens shop panel by stable ID")
	expect(scene.panel_open,"An open panel blocks world clicks")
	var hp_before_modal: float = enemy.hp
	await click(Vector2(scene._sx(enemy.x),scene._ground()-32.0))
	expect(enemy.hp == hp_before_modal,"Modal consumes clicks instead of accidentally firing")
	scene.ui._close_modal()
	await process_frame
	expect(not scene.panel_open,"Closing panel restores gameplay input")
	var visitor: Dictionary = game.visitors[0]
	# Move the visitor away from the gate and enemies for an unambiguous hit.
	visitor.x = 155.0
	enemy.x = 120.0
	var before_visitor_click: float = enemy.hp
	await click(Vector2(scene._sx(visitor.x),scene._ground()-28.0))
	expect(scene.ui.panel_kind == "visitor","Visitor click opens admission decision")
	expect(enemy.hp == before_visitor_click,"The closest visitor is selected even beside an enemy")
	scene.ui._close_modal()
	await process_frame
	var guard_id: int = scene._first_guard_id()
	var guard_post: Vector2 = scene._guard_post(guard_id)
	var guard_muzzle: Vector2 = scene._guard_muzzle(guard_id)
	expect(guard_post.y < scene._ground()-120.0*scene.zoom,"Guard stands on elevated deck above the street")
	expect(guard_post.x > game.GATE_X and guard_post.x < scene.CITY_START,"Guard position belongs to checkpoint between arrivals and city")
	expect(guard_muzzle.x < guard_post.x,"Guard weapon points outward toward the zombie approach")
	expect(float(visitor.x) < game.GATE_X and scene.CITY_START > game.GATE_X,"Visitors stay outside the residential zone")
	var shot_count: int = scene.shots.size()
	game._guard_timer = 0.0
	game._tick_guards(0.1)
	expect(scene.shots.size() == shot_count,"A waiting defender creates no automatic tracer")
	game.shot_cooldown = 0.0
	game.shoot(int(enemy.id))
	expect(scene.shots.size() == shot_count+1,"An explicit player shot creates one tower tracer")
	expect(scene.guard_flashes.has(guard_id),"Tower firing pose follows the player's shot")
	var support_shot: Dictionary = scene.shots.back()
	expect(support_shot.from.y < support_shot.to.y,"Support tracer travels down from tower to the street")
	var old_zoom: float = scene.target_zoom
	var wheel: InputEventMouseButton = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = Vector2(700,350)
	root.push_input(wheel,true)
	await process_frame
	expect(scene.target_zoom > old_zoom,"Mouse wheel zoom routes through viewport")
	var plus: Button = find_button(scene.ui,"+")
	expect(plus != null and plus.size.x>=48 and plus.size.y>=48,"On-screen zoom has a generous target")
	var before_button_zoom: float = scene.target_zoom
	if plus != null:
		await click(plus.get_global_rect().get_center())
	expect(scene.target_zoom > before_button_zoom,"On-screen zoom button works without keyboard or wheel")
	scene.focus_gate()
	expect(scene.target_camera < 0.0,"Gate shortcut brings the dangerous street into view")
	scene.focus_city()
	expect(scene.target_camera >= -210.0,"City shortcut respects camera bounds")
	game.save_game()
	expect(FileAccess.file_exists(game.save_path),"Interaction session saves to isolated test file")
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(game.save_path+suffix):
			DirAccess.remove_absolute(game.save_path+suffix)
	scene.queue_free()
	await process_frame
	await process_frame
	print("INTERACTION: ",checks-failures.size(),"/",checks," passed")
	quit(0 if failures.is_empty() else 1)
