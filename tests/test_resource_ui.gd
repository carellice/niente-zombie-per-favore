extends SceneTree
var checks: int = 0
var failures: int = 0
var game: Node
var ui: CanvasLayer
func _initialize() -> void: run.call_deferred()
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("RESOURCE UI FAIL: ",message)
func settle() -> void:
	for frame: int in range(5): await process_frame
func opened() -> void:
	await settle()
	ui._stop_modal_motion()
	await settle()
func tap(control: Control) -> void:
	var button: Control = control
	while not button is Button and button.get_parent() is Control: button = button.get_parent()
	if is_instance_valid(ui.modal_scroll) and ui.modal_scroll.is_ancestor_of(button):
		ui.modal_scroll.ensure_control_visible(button)
	await settle()
	var point: Vector2 = control.get_global_transform_with_canvas()*(control.size*0.5)
	for down: bool in [true,false]:
		var touch: InputEventScreenTouch = InputEventScreenTouch.new()
		touch.pressed = down
		touch.position = point
		root.push_input(touch,true)
		var mouse: InputEventMouseButton = InputEventMouseButton.new()
		mouse.device = InputEvent.DEVICE_ID_EMULATION
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = down
		mouse.position = point
		root.push_input(mouse,true)
		await process_frame
	await opened()
func run() -> void:
	game = root.get_node("Game")
	game.set_process(false)
	game.save_path = "user://resource-ui-colony.json"
	root.get_node("Preferences").settings_path = "user://resource-ui-preferences.cfg"
	var fixture: Script = load(get_script().resource_path.get_base_dir().path_join("construction_fixture.gd"))
	for profile: Array in [[Vector2i(1920,1080),400,true],[Vector2i(2400,1080),400,true],[Vector2i(2048,1536),800,true],[Vector2i(1440,900),0,false]]:
		root.min_size = Vector2i.ZERO
		root.size = profile[0]
		root.get_node("DeviceLayout").mobile = profile[2]
		root.get_node("DeviceLayout").preview_android_shortest_dp = profile[1]
		root.get_node("Preferences").apply_settings({"interface_size":"large"},false)
		root.get_node("DeviceLayout").refresh()
		game._new_game()
		game.skip_tutorial()
		game.coins = 20000
		game.supplies = 1000
		game.community.parts = 50
		fixture.build_ready(game,"residence")
		fixture.build_ready(game,"cafe")
		ui = load("res://scripts/game_ui.gd").new()
		root.add_child(ui)
		await settle()
		ui._start_game()
		ui._show_build()
		await opened()
		for key: String in ["DialogCoins","DialogSupplies","DialogBills","DialogParts"]:
			var value: Label = ui.modal.find_child(key,true,false)
			expect(value!=null and value.text.is_valid_int(),"Wallet uses an icon and integer, without repeated units")
		var legend: Control = ui.modal.find_child("ResourceLegend",true,false)
		expect(not legend.visible,"Currency descriptions are folded by default")
		await tap(ui.modal.find_child("ResourceLegendToggle",true,false))
		expect(legend.visible and ui.panel_kind=="build","Legend opens without losing the current panel")
		expect(ui.modal_scroll.is_ancestor_of(legend) and ui.modal_scroll.size.y>40,"Legend remains in the scroll surface, including tablet/desktop at large scale")
		await tap(ui.modal.find_child("ResourceLegendToggle",true,false))
		expect(not legend.visible,"Legend closes without a modal navigation round trip")
		var build: Button = ui.modal.find_child("BuildAction_bakery",true,false)
		var price: int = game.next_build_cost("bakery")
		expect(build.text=="Costruisci","Action is readable separately from its cost")
		expect(build.get_node("CostButtonContent/ButtonCosts/Amount_coin/Quantity").text==str(price),"Visible quantity matches the authoritative construction cost")
		var money: float = game.coins
		await tap(build.get_node("CostButtonContent/ButtonCosts/Amount_coin"))
		expect(game.buildings.back().type=="bakery" and game.coins==money-price,"Touching the painted cost builds once and pays exactly once")
		ui._show_armory()
		await opened()
		var buy: Button = ui.modal.find_child("WeaponAction_sniper",true,false)
		expect(buy.get_meta("displayed_amounts")==ui.ResourceUI.costs(int(game.WEAPONS.sniper.cost),int(game.WEAPONS.sniper.supplies)),"Weapon shows both required currencies")
		money = game.coins
		var supplies: int = game.supplies
		await tap(buy.get_node("CostButtonContent/ButtonCosts/Amount_crate"))
		expect(game.weapon=="sniper" and game.coins==money-int(game.WEAPONS.sniper.cost) and game.supplies==supplies-int(game.WEAPONS.sniper.supplies),"Touching the second currency purchases the real weapon once")
		game.gate_hp = game.gate_max-25
		ui.show_gate()
		await opened()
		var repair: Button = ui.modal.find_child("GateRepair",true,false)
		var before: String = repair.get_node("CostButtonContent/ButtonCosts/Amount_coin/Quantity").text
		game.gate_hp -= 50
		ui._update_hud()
		expect(repair.get_node("CostButtonContent/ButtonCosts/Amount_coin/Quantity").text!=before,"Live damage refreshes the actual visible amount")
		var visual: Node = repair.get_node("CostButtonContent/ButtonCosts/Amount_coin")
		ui._update_hud()
		expect(repair.get_node("CostButtonContent/ButtonCosts/Amount_coin")==visual,"Periodic updates reuse visual nodes")
		game.coins = 0
		ui._update_hud()
		expect(repair.disabled,"Insufficient funds disable illustrated actions")
		await tap(visual)
		expect(game.coins==0 and game.gate_hp<game.gate_max,"Disabled illustrated costs never charge or trigger the action")
		ui._close_modal()
		ui.queue_free()
		await settle()
	print("RESOURCE UI: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
