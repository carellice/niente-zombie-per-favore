extends SceneTree
## UI behavior checks use a disposable colony, never the player's save.

var checks: int = 0
var failures: Array[String] = []
var ui: CanvasLayer
var game: Node
var capture_enabled: bool = false

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		printerr("FAIL: ",description)

func button(node: Node, text: String) -> Button:
	if node is Button and node.text==text: return node
	for child: Node in node.get_children():
		var found: Button = button(child,text)
		if found!=null: return found
	return null

func text_contains(node: Node, fragment: String) -> bool:
	if (node is Label or node is Button) and fragment in node.text: return true
	for child: Node in node.get_children():
		if text_contains(child,fragment): return true
	return false

func icon_count(node: Node) -> int:
	var count: int = 1 if node.has_meta("weapon_icon") else 0
	for child: Node in node.get_children(): count+=icon_count(child)
	return count

func settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func capture(path: String) -> void:
	if not capture_enabled: return
	await settle()
	await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png(path)==OK,"Native capture: "+path)

func run() -> void:
	game = root.get_node("Game")
	game.save_path = "user://revision-ui-save.json"
	game.set_process(false)
	game._new_game()
	game.skip_tutorial()
	game.coins = 20000
	game.supplies = 1000
	for kind: String in ["residence","residence","cafe","garden","workshop","clinic","bakery","waterworks","tailor"]:
		ready_build(game,kind)
	for i: int in range(7):
		var citizen: Dictionary = game._make_citizen()
		citizen.hp = 80
		game.citizens.append(citizen)
	var cafe: Dictionary = game.buildings[2]
	for i: int in range(3): game.assign(int(game.citizens[i].id),int(cafe.id))
	game.owned_weapons = ["pistol","shotgun","sniper","smg"]
	capture_enabled = OS.get_cmdline_user_args().has("--capture-ui")
	root.size = Vector2i(1440,900)
	ui = load("res://scripts/game_ui.gd").new()
	root.add_child(ui)
	await settle()
	expect(not text_contains(ui.hud,"NUOVA NORMALITÀ"),"Footer motto removed")
	for building: Dictionary in game.buildings:
		ui.show_building(int(building.id))
		await settle()
		var question: bool = false
		for node: Node in ui.modal.find_children("*","Button",true,false):
			if node.tooltip_text=="A cosa serve questo edificio?": question=true
		expect(question,"Every building has contextual question button: "+str(building.type))
		ui._show_building_help(int(building.id))
		await settle()
		expect(ui.panel_kind=="building_help" and ui.panel_id==int(building.id),"Help preserves building identity")
		expect(text_contains(ui.modal,"Torna all'edificio"),"Help has a return action")
	ui.show_building(int(cafe.id))
	await settle()
	ui.modal_scroll.scroll_vertical = 240
	var building_scroll: int = ui.modal_scroll.scroll_vertical
	expect(building_scroll>0,"Building products genuinely scroll")
	ui._restock(int(cafe.id),1)
	await settle()
	var building_limit: int = int(ui.modal_scroll.get_v_scroll_bar().max_value-ui.modal_scroll.get_v_scroll_bar().page)
	expect(abs(ui.modal_scroll.scroll_vertical-mini(building_scroll,building_limit))<=2,"Rifornimento keeps scroll position within shorter content")
	building_scroll = ui.modal_scroll.scroll_vertical
	ui._show_building_help(int(cafe.id))
	await settle()
	await capture("res://docs/REVISIONE-AIUTO-EDIFICI.png")
	ui._return_to_building(int(cafe.id))
	await settle()
	expect(abs(ui.modal_scroll.scroll_vertical-building_scroll)<=2,"Building help returns to same scroll position")
	ui._show_citizens()
	await settle()
	expect(not text_contains(ui.modal,"Di guardia"),"Citizen guard control removed")
	expect(not text_contains(ui.modal,"Rimuovi guardia"),"Guard removal control removed")
	expect(button(ui.modal,"Equipaggiamento  →")!=null,"Citizens have a clear equipment action")
	ui.modal_scroll.scroll_vertical = 410
	var citizen_scroll: int = ui.modal_scroll.scroll_vertical
	ui._heal(int(game.citizens[3].id))
	await settle()
	expect(abs(ui.modal_scroll.scroll_vertical-citizen_scroll)<=2,"Healing keeps citizen scroll position")
	ui._show_citizen_equipment(int(game.citizens[3].id))
	await settle()
	expect(icon_count(ui.modal)==4,"Equipment panel has one distinct icon per weapon")
	ui._buy_citizen_weapon(int(game.citizens[3].id),"smg")
	await settle()
	expect(game.citizens[3].weapon=="smg","SMG can be equipped for a citizen")
	await capture("res://docs/REVISIONE-EQUIPAGGIAMENTO.png")
	ui._return_to_citizens()
	await settle()
	expect(abs(ui.modal_scroll.scroll_vertical-citizen_scroll)<=2,"Equipment returns to same citizen position")
	ui._show_armory()
	await settle()
	expect(ui.modal_scroll.scroll_vertical==0,"Changing dialog resets scroll")
	expect(icon_count(ui.modal)==5,"Armory contains four weapons and ammo icons")
	expect(text_contains(ui.modal,"Mitragliatore"),"Armory shows the mitragliatore")
	ui.modal_scroll.scroll_vertical = 530
	var armory_scroll: int = ui.modal_scroll.scroll_vertical
	ui._ammo()
	await settle()
	expect(abs(ui.modal_scroll.scroll_vertical-armory_scroll)<=2,"Ammo purchase preserves scroll")
	ui._show_armory()
	await settle()
	ui.modal_scroll.scroll_vertical=0
	await capture("res://docs/REVISIONE-ARMERIA.png")
	ui.modal_scroll.scroll_vertical = int(ui.modal_scroll.get_v_scroll_bar().max_value)
	await capture("res://docs/ARMERIA-MUNIZIONI-DIPINTE.png")
	ui._close_modal()
	ui._show_pause()
	await settle()
	expect(game.paused,"Pause menu pauses game")
	expect(button(ui.modal,"Riprendi la partita  →")!=null,"Pause prioritizes resume")
	expect(ui.modal_scroll.get_v_scroll_bar().max_value<=ui.modal_scroll.size.y+1,"Pause actions fit without scrolling")
	await capture("res://docs/REVISIONE-PAUSA.png")
	# A dialog may be replaced several times before deferred layout callbacks run.
	# Explicitly free one obsolete dialog to exercise the same lifetime boundary
	# as a queued replacement completed by another signal in the actual scene.
	ui._show_armory()
	var obsolete_modal: Control = ui.modal
	obsolete_modal.free()
	ui._show_citizens()
	ui._show_armory()
	ui._close_modal()
	ui._show_citizens()
	await settle()
	expect(ui.panel_kind=="citizens" and is_instance_valid(ui.modal_scroll),"Rapid modal replacement leaves the latest dialog intact")
	expect(ui.modal_scroll.scroll_vertical==0,"Obsolete deferred callbacks cannot change the latest scroll")
	ui._return_to_main_menu()
	await settle()
	var new_game: Button = button(ui.menu_layer,"Nuova partita")
	expect(new_game!=null,"Populated save exposes New Game in menu")
	if new_game!=null: new_game.pressed.emit()
	await settle()
	expect(ui.panel_kind=="reset","New Game asks to replace the populated refuge")
	var confirm: Button = button(ui.modal,"Sì, ricomincia da zero")
	expect(confirm!=null,"New Game has an explicit destructive confirmation")
	if confirm!=null: confirm.pressed.emit()
	await settle()
	expect(ui.panel_kind=="tutorial_intro","Fresh game opens tutorial introduction")
	expect(game.citizens.is_empty() and game.buildings.is_empty(),"Fresh tutorial starts with empty refuge")
	expect(ui.modal_scroll.scroll_vertical==0,"New Game does not retain old dialog scroll")
	expect(ui.population_label.text=="0 / 0","Reset updates population immediately")
	expect(ui.toast_stack.get_child_count()<=1 and not text_contains(ui.toast_stack,"munizioni"),"New Game clears old notifications and retains its own welcome")
	var start: Button = button(ui.modal,"Cominciamo · Vai alla torretta")
	expect(start!=null,"Tutorial has a clear start action")
	await capture("res://docs/REVISIONE-TUTORIAL.png")
	if start!=null: start.pressed.emit()
	await settle()
	expect(game.tutorial_stage=="first_zombie","Start begins real tutorial stage")
	expect(ui.tutorial_panel.visible,"Tutorial guidance is nonmodal while playing")
	ui._toggle_tutorial_minimized()
	expect(button(ui.tutorial_panel,"+")!=null,"Tutorial may be minimized")
	ui._toggle_tutorial_minimized()
	expect(button(ui.tutorial_panel,"Vai alla torretta")!=null,"Tutorial can be expanded")
	root.size=Vector2i(960,600)
	await settle()
	var guide_rect: Rect2 = ui.tutorial_panel.get_global_rect()
	var viewport_rect: Rect2 = root.get_visible_rect()
	expect(viewport_rect.encloses(guide_rect),"Expanded tutorial fits minimum landscape window")
	expect(guide_rect.end.y<=ui.gate_button.get_global_rect().position.y,"Tutorial stays above bottom navigation")
	await capture("res://docs/REVISIONE-TUTORIAL-960.png")
	ui._show_pause()
	await settle()
	expect(ui.modal_scroll.get_v_scroll_bar().max_value<=ui.modal_scroll.size.y+1,"Pause actions fit minimum window without scrolling")
	await capture("res://docs/REVISIONE-PAUSA-960.png")
	ui._close_modal()
	ui.queue_free()
	await settle()
	if FileAccess.file_exists(game.save_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path))
	print("REVISION_UI_CHECKS ",checks," FAILURES ",failures.size())
	quit(1 if not failures.is_empty() else 0)

func ready_build(model: Node, kind: String) -> bool:
	var fixture: Script = load(get_script().resource_path.get_base_dir().path_join("construction_fixture.gd"))
	return fixture.build_ready(model,kind)
