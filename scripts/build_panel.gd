extends RefCounted
## Every building has the same header, description area and bottom action.
const Icons = preload("res://scripts/hud_icons.gd")
const OPTIONS = [
	["residence","ALLOGGI","Cinque letti in più per accogliere nuovi abitanti."],
	["cafe","CIBO","Bevande e colazioni da vendere. Lavoratori con affinità CIBO."],
	["garden","CIBO","Verdure e dispense da vendere. Lavoratori con affinità CIBO."],
	["workshop","BENI","Attrezzi e ricambi da vendere. Lavoratori con affinità BENI."],
	["clinic","SERVIZI","Bende e medicinali da vendere. Lavoratori con affinità SERVIZI."],
	["bakery","CIBO","Pane e dolci da vendere. Lavoratori con affinità CIBO."],
	["waterworks","SERVIZI","Acqua pulita da vendere. Lavoratori con affinità SERVIZI."],
	["tailor","BENI","Vestiti e zaini da vendere. Lavoratori con affinità BENI."]]
static var _previews: Dictionary = {}

static func summary(kind: String) -> String:
	match kind:
		"garden": return "Verdure da vendere e raccolti per la comunità."
		"workshop": return "Merci da vendere e materiali di recupero."
		"clinic": return "Cure meno costose e ferite da spedizione dimezzate."
	return Game.Cozy.role(Game,kind)

static func _count_text(kind: String) -> String:
	var ready: int = 0
	var pending: int = 0
	for building: Dictionary in Game.buildings:
		if str(building.type)!=kind: continue
		if Game.is_under_construction(building): pending += 1
		else: ready += 1
	return "Già costruiti: %d" % ready+(" · In costruzione: %d" % pending if pending>0 else "")

static func _art(kind: String) -> Texture2D:
	if _previews.has(kind): return _previews[kind]
	var path: String = "res://assets/art/settlement.png"
	var slots: Dictionary = {"residence":0,"cafe":1,"garden":2,"workshop":3,"clinic":4}
	if not slots.has(kind): path = "res://assets/art/buildings/"+kind+".png"
	var source: Texture2D = load(path)
	var pixels: Image = source.get_image()
	if pixels.is_compressed(): pixels.decompress()
	var region: Rect2i = Rect2i(Vector2i.ZERO,pixels.get_size())
	if slots.has(kind):
		var cell: Vector2i = Vector2i(pixels.get_width()/3,pixels.get_height()/2)
		var slot: int = slots[kind]
		region = Rect2i(Vector2i(slot%3,slot/3)*cell,cell)
	var ink: Rect2i = pixels.get_region(region).get_used_rect()
	if ink.has_area(): region = Rect2i(region.position+ink.position,ink.size)
	_previews[kind] = Icons.cropped_texture(path,region)
	return _previews[kind]

static func show_catalog(ui: CanvasLayer) -> void:
	ui.set_selected_tab("build")
	var col: VBoxContainer = ui._open("build","Costruisci il rifugio","PIANO DI ESPANSIONE")
	ui._last_panel_signature = ui._build_catalog_signature()
	if Game.buildings.size()>=3:
		ui.CozyPanel.heading(ui,col,"Le botteghe, insieme")
		ui.CozyPanel.batch(ui,col)
	var site: Dictionary = Game.active_construction()
	if Game.tutorial_active() and not site.is_empty():
		col.add_child(ui._button("Guarda il cantiere in corso",ui._construction_focus.bind(int(site.id)),true))
	var grid: GridContainer = GridContainer.new()
	grid.name = "ConstructionGrid"
	grid.columns = 2
	grid.set_meta("phone_grid",true)
	grid.add_theme_constant_override("h_separation",16)
	grid.add_theme_constant_override("v_separation",16)
	col.add_child(grid)
	for entry: Array in OPTIONS:
		var kind: String = entry[0]
		if Game.tutorial_active():
			if Game.tutorial_stage in ["intro","first_zombie","build_residence"] and kind!="residence": continue
			if Game.tutorial_stage in ["welcome_visitor","build_cafe"] and kind!="cafe": continue
		var card: VBoxContainer = ui._card(grid)
		card.set_meta("building_kind",kind)
		card.add_theme_constant_override("separation",12)
		var panel: PanelContainer = card.get_parent()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.custom_minimum_size.y = 260 if DeviceLayout.android_phone() else 248
		var header: HBoxContainer = ui._hbox(16)
		header.custom_minimum_size.y = 88
		var picture: TextureRect = ui._painted_icon(_art(kind),Vector2(112,88),"building_"+kind)
		header.add_child(picture)
		var titles: VBoxContainer = ui._vbox(4)
		titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		titles.alignment = BoxContainer.ALIGNMENT_CENTER
		titles.add_child(ui._label(entry[1],14,ui.SAGE,true))
		var title: Label = ui._copy(ui._type_name(kind),24,ui.TEXT)
		title.add_theme_font_override("font",ui.heading)
		titles.add_child(title)
		header.add_child(titles)
		card.add_child(header)
		var count: Label = ui._copy(_count_text(kind),18,ui.SAGE)
		count.name = "BuildCount_"+kind
		card.add_child(count)
		ui.bindings.append([count,func(label: Label) -> void: label.text = _count_text(kind)])
		var description: Label = ui._copy(summary(kind),18)
		description.custom_minimum_size.y = 64 if DeviceLayout.android_phone() else 48
		card.add_child(description)
		var spacer: Control = Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(spacer)
		var cost: int = Game.next_build_cost(kind)
		var build: Button = ui._cost_button("Costruisci",[["coin",cost],["compass",ui._time(Game.next_build_duration(kind))]],ui._build.bind(kind),true,true)
		build.name = "BuildAction_"+kind
		build.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		build.disabled = Game.coins<cost or (Game.tutorial_active() and not site.is_empty())
		ui.bindings.append([build,func(button: Button) -> void: button.disabled = Game.coins<Game.next_build_cost(kind) or (Game.tutorial_active() and not Game.active_construction().is_empty())])
		card.add_child(build)
