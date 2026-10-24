extends SceneTree
## Defence actions must reflect the actual, current purchase eligibility.
var checks: int = 0
var failures: int = 0
var pressed_count: int = 0
var notice_count: int = 0
var game: Node
var layout: Node
var preferences: Node
var ui: CanvasLayer

func _initialize() -> void: run.call_deferred()
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("GATE AFFORDABILITY FAIL: ",message)
func settle(frames: int=3) -> void:
	for frame: int in range(frames): await process_frame
func opened() -> void:
	await settle()
	ui._stop_modal_motion()
	ui._modal_motion_progress = 1.0
	await settle()
func action(name: String) -> Button:
	return ui.modal.find_child(name,true,false) as Button
func on_pressed() -> void: pressed_count += 1
func on_notice(_message: String) -> void: notice_count += 1
func tap(button: Button) -> void:
	if ui.modal_scroll.is_ancestor_of(button):
		ui.modal_scroll.ensure_control_visible(button)
		await settle()
	var point: Vector2 = button.get_global_transform_with_canvas()*(button.size*0.5)
	for down: bool in [true,false]:
		var touch: InputEventScreenTouch = InputEventScreenTouch.new()
		touch.index = 0
		touch.position = point
		touch.pressed = down
		root.push_input(touch,true)
		var mouse: InputEventMouseButton = InputEventMouseButton.new()
		mouse.device = InputEvent.DEVICE_ID_EMULATION
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.position = point
		mouse.global_position = point
		mouse.pressed = down
		root.push_input(mouse,true)
		await process_frame
	await opened()
func refresh() -> void: game.changed.emit()
func run() -> void:
	game = root.get_node("Game")
	layout = root.get_node("DeviceLayout")
	preferences = root.get_node("Preferences")
	game.set_process(false)
	var data: String = OS.get_environment("NZPF_TEST_DATA_DIR")
	if data.is_empty(): data = ProjectSettings.globalize_path("res://.runtime/gate-affordability")
	DirAccess.make_dir_recursive_absolute(data)
	game.save_path = data.path_join("colony.json")
	preferences.settings_path = data.path_join("preferences.cfg")
	game.toast.connect(on_notice)
	for profile: Array in [["DESKTOP",Vector2i(1440,900),false,0.0],["PHONE169",Vector2i(1920,1080),true,400.0],["PHONE",Vector2i(2400,1080),true,400.0],["TABLET",Vector2i(2048,1536),true,800.0]]:
		if is_instance_valid(ui):
			ui.queue_free()
			await settle()
		root.min_size = Vector2i.ZERO
		root.size = profile[1]
		layout.mobile = profile[2]
		layout.preview_android_shortest_dp = profile[3]
		layout.preview_insets = Vector4(24,6,12,8) if profile[2] else Vector4.ZERO
		preferences.apply_settings({"interface_size":"compact","sound_enabled":false,"fullscreen":false},false)
		layout.refresh()
		ui = load("res://scripts/game_ui.gd").new()
		root.add_child(ui)
		await settle()
		for scale_name: String in ["compact","medium","large"]:
			game._new_game()
			game._is_loading = true
			game.skip_tutorial()
			preferences.apply_settings({"interface_size":scale_name},false)
			layout.refresh()
			ui._start_game()
			var label: String = str(profile[0])+" "+scale_name
			var cost: Dictionary = game.gate_upgrade_cost()
			game.coins = cost.coins-0.25
			game.supplies = cost.supplies
			ui.show_gate()
			await opened()
			var upgrade: Button = action("GateUpgrade")
			expect(upgrade!=null,label+": actual upgrade action exists")
			if upgrade==null: continue
			expect(upgrade.disabled,label+": initially disabled even if only a fraction of a coin is missing")
			pressed_count = 0
			upgrade.pressed.connect(on_pressed)
			var level: int = game.gate_level
			await tap(upgrade)
			expect(pressed_count==0 and game.gate_level==level and game.coins==cost.coins-0.25,label+": disabled input emits no purchase action and spends nothing")
			game.coins = cost.coins
			game.supplies = cost.supplies-1
			refresh()
			expect(upgrade.disabled,label+": supplies are also required")
			game.supplies = cost.supplies
			refresh()
			expect(not upgrade.disabled,label+": exact funds enable the same open button")
			game.coins -= 1
			refresh()
			expect(upgrade.disabled,label+": spending elsewhere immediately disables it again")
			game.coins += 1
			ui._process(0.26)
			expect(not upgrade.disabled,label+": the periodic refresh also detects income")
			await tap(upgrade)
			expect(pressed_count==1 and game.gate_level==level+1 and game.coins==0 and game.supplies==0,label+": exact-budget input upgrades once and charges the displayed cost")
			upgrade = action("GateUpgrade")
			var next_cost: Dictionary = game.gate_upgrade_cost()
			expect(upgrade.disabled and upgrade.text.contains(str(next_cost.coins)+" monete") and upgrade.text.contains(str(next_cost.supplies)+" provviste"),label+": the next level shows its increased cost and is disabled")
			game.gate_hp = game.gate_max-35
			refresh()
			var repair: Button = action("GateRepair")
			expect(repair.disabled,label+": repair also requires funds")
			var repair_cost: Dictionary = game.repair_cost()
			game.coins = repair_cost.coins
			game.supplies = repair_cost.supplies
			refresh()
			expect(not repair.disabled,label+": affordable damage can be repaired")
			game.gate_hp -= 35
			refresh()
			repair_cost = game.repair_cost()
			expect(repair.disabled and repair.text.contains(str(repair_cost.coins)+" monete"),label+": new damage refreshes both the price and eligibility")
			game.coins = repair_cost.coins
			game.supplies = repair_cost.supplies-1
			refresh()
			expect(repair.disabled,label+": repair cannot ignore insufficient supplies")
			game.supplies += 1
			refresh()
			await tap(repair)
			expect(game.gate_hp==game.gate_max and game.coins==0 and game.supplies==0 and action("GateRepair").disabled,label+": repair charges once and a full gate cannot be repaired again")
			# Affordability queries must respect the tutorial's protected budget,
			# without emitting a rejection toast every quarter second.
			game._new_game()
			game._is_loading = true
			cost = game.gate_upgrade_cost()
			var reserve: int = 22+game.next_build_cost("residence")+game.next_build_cost("cafe")
			game.coins = cost.coins+reserve-1
			game.supplies = cost.supplies
			ui.show_gate()
			await opened()
			notice_count = 0
			for index: int in range(4): ui._update_hud()
			expect(action("GateUpgrade").disabled and notice_count==0,label+": tutorial reserve disables silently without repeated notices")
			game.coins += 1
			refresh()
			expect(not action("GateUpgrade").disabled,label+": tutorial funds above the reserve remain spendable")
			ui._close_modal()
		game._is_loading = false
	if is_instance_valid(ui): ui.queue_free()
	await settle()
	await create_timer(0.5).timeout
	print("GATE AFFORDABILITY: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
