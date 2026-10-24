extends SceneTree
## Exercises viewport input and a real Button to ensure the decoration never blocks UI.

const PointerFeedback = preload("res://scripts/pointer_feedback.gd")
var checks: int = 0
var failures: int = 0
var activations: int = 0
var starts: int = 0
var feedback: CanvasLayer

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("POINTER FAIL: ", description)

func mouse(point: Vector2, pressed: bool, button: int = MOUSE_BUTTON_LEFT, device: int = 0) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button
	event.pressed = pressed
	event.device = device
	root.push_input(event, true)

func run() -> void:
	# Keep the unrelated autoload simulation away from the user's save.
	var game: Node = root.get_node("Game")
	game.save_path = "res://.runtime/pointer-feedback-test-save.json"
	game.paused = true
	game.set_process(false)
	var button: Button = Button.new()
	button.position = Vector2(90, 80)
	button.size = Vector2(200, 70)
	button.text = "Gioca"
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.pressed.connect(func() -> void: activations += 1)
	root.add_child(button)
	feedback = PointerFeedback.new()
	feedback.pulse_started.connect(func(_point: Vector2) -> void: starts += 1)
	root.add_child(feedback)
	await process_frame
	expect(feedback.layer > 10, "effect is above game menus")
	expect(feedback.surface.mouse_filter == Control.MOUSE_FILTER_IGNORE, "surface ignores pointer handling")
	var point: Vector2 = button.get_global_rect().get_center()
	mouse(point, true)
	expect(starts == 1 and feedback.effect_count == 1, "button press emits one visible pulse")
	mouse(point, false)
	expect(activations == 1, "button still activates exactly once")
	expect(starts == 1, "release does not create a second pulse")
	mouse(Vector2(450, 330), true)
	mouse(Vector2(450, 330), false)
	expect(starts == 2, "empty world click also has feedback")
	mouse(point, true, MOUSE_BUTTON_RIGHT)
	mouse(point, true, MOUSE_BUTTON_WHEEL_UP)
	expect(starts == 2, "right click and scrolling leave no click ripples")
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.position = Vector2(500, 200)
	touch.pressed = true
	root.push_input(touch, true)
	mouse(touch.position, true, MOUSE_BUTTON_LEFT, InputEvent.DEVICE_ID_EMULATION)
	expect(starts == 3, "touch plus its emulated mouse creates a single pulse")
	paused = true
	mouse(point, true)
	mouse(point, false)
	expect(starts == 4 and activations == 2, "feedback and UI work while the scene tree is paused")
	await create_timer(PointerFeedback.LIFETIME + 0.1, true).timeout
	expect(feedback.effect_count == 0, "ripples expire while paused")
	paused = false
	for index: int in range(50):
		feedback.add_pulse(Vector2(index * 3, 400))
	expect(feedback.effect_count == PointerFeedback.MAX_PULSES, "rapid clicks have a fixed memory and drawing cap")
	expect(feedback.surface.pulses[0].position == Vector2(34 * 3, 400), "oldest rapid-click ripple is retired first")
	feedback.surface.advance(PointerFeedback.LIFETIME + 0.01)
	expect(feedback.effect_count == 0, "expired pool is completely empty")
	button.queue_free()
	feedback.queue_free()
	await process_frame
	if "--capture-feedback" in OS.get_cmdline_user_args():
		await capture_menu()
	print("POINTER FEEDBACK: ", checks, " checks; ", failures, " failures")
	quit(0 if failures == 0 else 1)

func find_button(node: Node) -> Button:
	if node is Button and (node.text.begins_with("Gioca") or node.text.begins_with("Continua")):
		return node
	for child: Node in node.get_children():
		var found: Button = find_button(child)
		if found:
			return found
	return null

func capture_menu() -> void:
	var preferences: Node = root.get_node("Preferences")
	preferences.apply_settings({"sound_enabled": false, "fullscreen": false}, false)
	var main: Control = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	feedback = null
	for child: Node in main.get_children():
		if child.get_script() == PointerFeedback:
			feedback = child
	if feedback == null:
		feedback = PointerFeedback.new()
		main.add_child(feedback)
	var button: Button = find_button(main)
	expect(button != null, "capture uses the actual title-menu button")
	if button:
		feedback.add_pulse(button.get_global_rect().get_center())
		await create_timer(0.11, true).timeout
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		expect(image.save_png("res://docs/CLICK-FEEDBACK.png") == OK, "title-menu ripple captures successfully")
	main.queue_free()
	await process_frame
