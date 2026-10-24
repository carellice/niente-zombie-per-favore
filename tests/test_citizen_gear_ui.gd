extends SceneTree
## Actual shopping, refill, comparison, team navigation and departure input.
var checks: int = 0
var failures: int = 0
var game: Node
var layout: Node
var preferences: Node
var ui: CanvasLayer
func _initialize() -> void: run.call_deferred()
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("PERSONAL GEAR UI FAIL: ",message)
func settle(frames: int=4) -> void:
	for frame: int in range(frames): await process_frame
func opened() -> void:
	await settle()
	ui._stop_modal_motion()
	ui._modal_motion_progress = 1.0
	await settle()
func control(name: String) -> Control: return ui.modal.find_child(name,true,false) as Control
func tap(button: Control) -> void:
	expect(is_instance_valid(button),"Visible action exists")
	if not is_instance_valid(button): return
	# Allow changed affordability messages to wrap before scrolling to the action.
	await settle()
	if ui.modal_scroll.is_ancestor_of(button):
		ui.modal_scroll.ensure_control_visible(button)
		await settle()
		expect(ui.modal_scroll.get_global_rect().grow(2).encloses(button.get_global_rect()),"The actual tap target is visible after layout and scrolling")
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
func check_page(label: String) -> void:
	expect(ui.modal_scroll.size.x+2>=ui.modal_content.get_combined_minimum_size().x,label+": page has no horizontal clipping")
	for card: Node in ui.modal_content.find_children("*","VBoxContainer",true,false):
		if not card.has_meta("personal_weapon"): continue
		var rect: Rect2 = card.get_global_rect()
		for button: Node in card.find_children("*","Button",true,false):
			expect(button.get_global_rect().position.x>=rect.position.x-1 and button.get_global_rect().end.x<=rect.end.x+1,label+": personal action fits inside its card")
func capture(name: String) -> void:
	var folder: String = OS.get_environment("NZPF_CAPTURE_DIR")
	if folder.is_empty() or DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png(folder.path_join("GEAR-"+name+".png"))==OK,"Capture saved: "+name)
func run() -> void:
	game = root.get_node("Game")
	layout = root.get_node("DeviceLayout")
	preferences = root.get_node("Preferences")
	game.set_process(false)
	var data: String = OS.get_environment("NZPF_TEST_DATA_DIR")
	if data.is_empty(): data = ProjectSettings.globalize_path("res://.runtime/personal-gear-ui")
	DirAccess.make_dir_recursive_absolute(data)
	game.save_path = data.path_join("colony.json")
	preferences.settings_path = data.path_join("preferences.cfg")
	for profile: Array in [["DESKTOP",Vector2i(1440,900),false,0.0],["PHONE169",Vector2i(1920,1080),true,400.0],["PHONE",Vector2i(2400,1080),true,400.0],["TABLET",Vector2i(2048,1536),true,800.0]]:
		if is_instance_valid(ui):
			ui.queue_free()
			await settle()
		root.min_size = Vector2i.ZERO
		root.size = profile[1]
		layout.mobile = profile[2]
		layout.preview_android_shortest_dp = profile[3]
		layout.preview_insets = Vector4(24,6,40,8) if profile[2] else Vector4.ZERO
		preferences.apply_settings({"interface_size":"compact","sound_enabled":false,"fullscreen":false},false)
		layout.refresh()
		ui = load("res://scripts/game_ui.gd").new()
		root.add_child(ui)
		await settle()
		for scale_name: String in ["compact","medium","large"]:
			game._new_game()
			game._is_loading = true
			game.skip_tutorial()
			game.coins = 10000
			game.supplies = 1000
			for index: int in range(2): game.citizens.append(game._make_citizen())
			var person: Dictionary = game.citizens[0]
			var id: int = person.id
			preferences.apply_settings({"interface_size":scale_name},false)
			layout.refresh()
			ui._start_game()
			ui.toast_stack.hide()
			ui.selected_zone = 8
			ui.selected_members = [id]
			ui.expedition_step = 2
			ui._show_expeditions(true)
			await opened()
			var label: String = str(profile[0])+" "+scale_name
			var baseline: float = game.expedition_preview(8,[id]).chance
			await tap(control("TeamEquipment_"+str(id)))
			expect(ui.panel_kind=="citizen_equipment" and ui.panel_id==id,label+": team opens the selected person's gear")
			expect(control("GearRoute_sniper").text.contains("2.35") and control("GearRoute_shotgun").text.contains("1.25"),label+": the open route explains the actual advantage of precision over shotgun")
			check_page(label+" before purchase")
			var money: float = game.coins
			var tower_ammo: int = game.ammo
			await tap(control("PersonalBuy_sniper"))
			expect(person.weapon=="sniper" and game.coins==money-625 and person.personal_ammo.sniper==6,label+": actual purchase buys one personal copy, equips it and grants the included pack")
			expect(game.owned_weapons==["pistol"] and game.citizens[1].personal_weapons==["pistol"] and game.ammo==tower_ammo,label+": the tower and other citizen receive nothing")
			check_page(label+" owned")
			if scale_name=="compact": await capture(str(profile[0])+"-LOADOUT")
			await tap(control("EquipmentBack"))
			expect(ui.panel_kind=="expeditions" and ui.expedition_step==2 and ui.selected_zone==8 and ui.selected_members==[id],label+": returning preserves route, squad and preparation stage")
			expect(game.expedition_preview(8,[id]).chance>baseline,label+": buying suitable gear improves the actual chance shown to the player")
			if scale_name=="compact":
				ui.modal_scroll.scroll_vertical = 0
				await settle()
				await capture(str(profile[0])+"-TEAM")
			person.personal_ammo.sniper = 0
			ui._update_hud()
			expect(control("LaunchExpedition").disabled and control("ExpeditionChance").text.contains("insufficienti"),label+": empty personal ammo visibly blocks departure")
			await tap(control("TeamEquipment_"+str(id)))
			money = game.coins
			game.coins = 35.75
			ui._update_hud()
			expect(control("PersonalAmmo_sniper").disabled,label+": refill checks the current balance without reopening")
			game.coins = money
			ui._update_hud()
			await tap(control("PersonalAmmo_sniper"))
			expect(person.personal_ammo.sniper==6 and game.coins==money-36 and game.ammo==tower_ammo,label+": refill charges its own price and never uses the tower's stock")
			await tap(control("EquipmentBack"))
			var preview: Dictionary = game.expedition_preview(8,[id])
			expect(not control("LaunchExpedition").disabled and control("DepartureSummary").text.contains("3 colpi personali"),label+": exact personal departure expense is advertised")
			await tap(control("LaunchExpedition"))
			expect(game.expedition.status=="running" and person.away and person.personal_ammo.sniper==3 and game.ammo==tower_ammo,label+": input launches once with exactly the shown personal ammunition")
			expect(is_equal_approx(game.expedition.chance,preview.chance),label+": actual success probability matches the prepared team")
			ui._show_citizen_equipment(id,true)
			await opened()
			expect(control("PersonalAmmo_sniper").disabled and control("PersonalEquip_pistol").disabled and control("PersonalBuy_smg").disabled,label+": all loadout changes wait for the citizen's return")
			ui._close_modal()
		game._is_loading = false
	if is_instance_valid(ui): ui.queue_free()
	await settle()
	await create_timer(0.5).timeout
	print("PERSONAL GEAR UI: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
