extends SceneTree
## Header, illustrated economy, expanded catalog and hidden admission state.

var checks: int = 0
var failures: Array[String] = []
var ui: CanvasLayer
var game: Node
var capture_enabled: bool = false
const ProductIcons = preload("res://scripts/product_icons.gd")

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		printerr("FAIL: ",description)

func texts(node: Node) -> String:
	var result: String = node.text+"\n" if node is Label or node is Button else ""
	for child: Node in node.get_children(): result+=texts(child)
	return result

func marked(node: Node, key: String) -> Array[Node]:
	var result: Array[Node] = []
	if node.has_meta(key): result.append(node)
	for child: Node in node.get_children(): result.append_array(marked(child,key))
	return result

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
	game.save_path = "res://.runtime/v04-ui-disposable.json"
	game.set_process(false)
	game._new_game()
	game.skip_tutorial()
	game.coins = 100000
	game.supplies = 1000
	for kind: String in ["residence","residence","cafe","garden","workshop","clinic","bakery","waterworks","tailor"]:
		expect(game.build(kind),"Catalog builds "+kind)
	for index: int in range(8): game.citizens.append(game._make_citizen())
	var cafe: Dictionary = game.buildings[2]
	for index: int in range(3): game.assign(int(game.citizens[index].id),int(cafe.id))
	game.day = 5
	root.size = Vector2i(1440,900)
	capture_enabled = OS.get_cmdline_user_args().has("--capture-v04-ui")
	ui = load("res://scripts/game_ui.gd").new()
	root.add_child(ui)
	await settle()
	var hud_text: String = texts(ui.hud)
	expect("NIENTE ZOMBIE" not in hud_text and "PER FAVORE!" not in hud_text,"Game brand removed from in-game appbar")
	expect("RIFUGIO 07" not in hud_text,"Refuge name removed from appbar")
	expect(ui.day_label.text=="5","Day has no leading zero")
	expect(ui.population_label.text=="8 / 10","Population displays current people and total housing")
	var cards: Array[Node] = marked(ui.hud,"hud_card")
	expect(cards.size()==5,"Resources, day and population have five separate cards")
	var viewport: Rect2 = root.get_visible_rect()
	for card: Node in cards: expect(viewport.encloses(card.get_global_rect()),"Header card fits visible area: "+str(card.get_meta("hud_card")))
	var people_icons: Array[Node] = marked(ui.hud,"painted_icon")
	expect(people_icons.size()==1 and people_icons[0].get_meta("painted_icon")=="population","Population has dedicated painted icon")
	expect(ProductIcons.population().resource_path=="res://assets/art/population.png","Population uses the dedicated generated PNG")
	for key: String in ["biscuit","breakfast","vegetables","tools","repair","bandage","medkit","medicine","bread","water","cloth"]:
		var icon_path: String = "res://assets/art/products/%s.png" % key
		expect(ResourceLoader.exists(icon_path),"Generated product illustration is imported: "+key)
	await capture("res://docs/V04-HUD.png")
	for building: Dictionary in game.buildings:
		ui.show_building(int(building.id))
		await settle()
		if building.type=="residence": continue
		expect("PRODOTTO IN VENDITA" in texts(ui.modal),"Product is clearly described as merchandise: "+str(building.type))
		expect("si vendono da sole" in texts(ui.modal),"Shop explains automatic sales: "+str(building.type))
		expect(ui._skill_name(str(building.type)) in texts(ui.modal),"Shop names the useful affinity: "+str(building.type))
		expect(marked(ui.modal,"painted_icon").size()==4,"Shop has painted summary and all three product illustrations: "+str(building.type))
		ui._show_building_help(int(building.id))
		await settle()
		expect("vend" in texts(ui.modal).to_lower(),"Building help explains sales: "+str(building.type))
		if building.type in ["bakery","waterworks","tailor"]: expect("Un letto per ricominciare" not in texts(ui.modal),"New shop receives its own help rather than residence guide")
	ui.show_building(int(cafe.id))
	await settle()
	expect("Caffè di sopravvivenza" in texts(ui.modal),"Cafe merchandise keeps its identity")
	expect("Ogni vendita:" in texts(ui.modal),"Cafe shows the amount earned on each sale")
	var first_restock: Button
	for control: Node in ui.modal.find_children("*","Button",true,false):
		if control.text.begins_with("Avvia rifornimento"):
			first_restock = control
			break
	expect(first_restock!=null and ui.modal_scroll.get_global_rect().encloses(first_restock.get_global_rect()),"First product action is visible when opening a staffed shop")
	await capture("res://docs/V04-CAFFE-PRODOTTI.png")
	ui._show_build()
	await settle()
	for kind: String in game.BUILDING_NAMES: expect(str(game.BUILDING_NAMES[kind]) in texts(ui.modal),"Construction offers "+kind)
	await capture("res://docs/V04-COSTRUISCI.png")
	ui._show_expeditions()
	await settle()
	expect(game.zones.size()==9,"Expedition selection has nine destinations")
	for index: int in range(game.zones.size()):
		var zone: Dictionary = game.zones[index]
		expect(str(zone.name) in texts(ui.modal),"Expedition lists "+str(zone.name))
		ui._select_zone(index)
		await settle()
		expect(str(zone.description) in texts(ui.modal),"Selecting a destination exposes its description: "+str(zone.name))
	expect("Costo partenza:" in texts(ui.modal),"Each destination exposes departure supplies")
	await capture("res://docs/V04-SPEDIZIONI.png")
	ui._select_zone(8)
	await settle()
	expect("Partenza: %d provviste" % game.expedition_cost(8) in texts(ui.modal),"Selected destination uses its authoritative cost")
	ui._show_quests()
	await settle()
	expect(game.quests.size()>=24,"Journal has expanded progression")
	await capture("res://docs/V04-DIARIO.png")
	ui._show_armory()
	await settle()
	expect(marked(ui.modal,"weapon_range").size()==4,"All weapons show relative reach")
	for range_text: String in ["Gittata corta","Gittata medio-corta","Gittata media","Gittata molto lunga"]:
		expect(range_text in texts(ui.modal),"Armory explains "+range_text)
	var person: Dictionary = game._make_citizen()
	person.appearance = "dirty"
	game.visitors.append({"id":9999,"citizen":person,"x":0.0,"suspicious":false})
	ui.show_visitor(9999)
	await settle()
	var harmless_copy: String = texts(ui.modal)
	var portraits: Array[Node] = marked(ui.modal,"citizen_appearance")
	expect(portraits.size()==1 and portraits[0].get_meta("citizen_appearance")=="dirty","Admission portrait preserves visible appearance")
	game.visitors[-1].suspicious = true
	ui.show_visitor(9999)
	await settle()
	expect(texts(ui.modal)==harmless_copy,"Hidden infection state does not change admission copy")
	expect("possono somigliare al contagio" in harmless_copy,"Admission explains uncertainty of dirt and infection")
	await capture("res://docs/V04-AMMISSIONE-DUBBIO.png")
	ui._close_modal()
	root.size=Vector2i(960,600)
	await settle()
	viewport = root.get_visible_rect()
	for card: Node in cards: expect(viewport.encloses(card.get_global_rect()),"Header card fits minimum window: "+str(card.get_meta("hud_card")))
	await capture("res://docs/V04-HUD-960.png")
	# Stress the actual labels at minimum physical size without allocating a
	# fictitious city merely to exercise container widths.
	ui.coin_label.text = "1000.0 M"
	ui.supply_label.text = "999.9 M"
	ui.gem_label.text = "123.4 M"
	ui.day_label.text = "12345"
	ui.population_label.text = "9999 / 10000"
	ui._hud_clock = -10.0
	await settle()
	for card: Node in cards: expect(viewport.encloses(card.get_global_rect()),"Large-count card remains inside minimum window: "+str(card.get_meta("hud_card")))
	var previous_end: float = -1.0
	for item: Node in cards[0].get_parent().get_children():
		if not item is Control or not item.visible: continue
		var rect: Rect2 = item.get_global_rect()
		expect(rect.position.x>=previous_end,"Header controls do not overlap at large counts")
		previous_end = rect.end.x
		expect(viewport.encloses(rect),"Header action remains reachable at large counts")
	ui.queue_free()
	await settle()
	if FileAccess.file_exists(game.save_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path))
	print("V04_UI_CHECKS ",checks," FAILURES ",failures.size())
	quit(1 if not failures.is_empty() else 0)
