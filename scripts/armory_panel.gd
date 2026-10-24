extends RefCounted
## Compact comparison rows, with full specifications available on demand.

static func _caption(key: String) -> String:
	if Game.weapon==key: return "In uso"
	if Game.owned_weapons.has(key): return "Equipaggia"
	var cost: Dictionary = Game.WEAPONS[key]
	return "Sblocca · %d monete\n+ %d provviste" % [int(cost.cost),int(cost.supplies)]

static func _available(key: String) -> bool:
	var cost: Dictionary = Game.WEAPONS[key]
	return Game.weapon!=key and (Game.owned_weapons.has(key) or (Game.coins>=int(cost.cost) and Game.supplies>=int(cost.supplies)))

static func show_catalog(ui: CanvasLayer) -> void:
	if DeviceLayout.android_phone():
		_show_phone(ui)
		return
	ui.set_selected_tab("armory")
	var col: VBoxContainer = ui._open("armory","Meglio essere preparati","ARMERIA DEL RIFUGIO")
	col.add_child(ui._copy("Tocca un'arma per vedere danno, portata e cadenza di tiro.",16))
	for key: String in ["pistol","shotgun","sniper","smg"]:
		var copy: Array = ui.WEAPON_COPY[key]
		var active: bool = Game.weapon==key
		var card: VBoxContainer = ui._card(col,ui.GOLD if active else ui.BORDER)
		card.set_meta("armory_weapon",key)
		var row: HBoxContainer = ui._hbox(12)
		var inspect: Button = ui._button("",ui._show_weapon_details.bind(key),false,true)
		inspect.name = "WeaponDetails_"+key
		inspect.custom_minimum_size = Vector2(370,72 if DeviceLayout.android_phone() else 76)
		inspect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inspect.tooltip_text = "Caratteristiche · "+str(copy[0])
		inspect.add_theme_stylebox_override("normal",ui._floating_group(4))
		inspect.add_theme_stylebox_override("hover",ui._style(ui.CREAM,ui.CREAM_EDGE,12,4))
		inspect.add_theme_stylebox_override("pressed",ui._style(ui.PANEL,ui.GOLD,12,4))
		var content: HBoxContainer = ui._hbox(12)
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 4
		content.offset_right = -4
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inspect.add_child(content)
		var icon: Control = ui._weapon_icon(key,Vector2(78,52))
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		content.add_child(icon)
		var detail: VBoxContainer = ui._vbox(3)
		detail.alignment = BoxContainer.ALIGNMENT_CENTER
		detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		detail.add_child(ui._label(str(copy[0]),20,ui.TEXT,true))
		detail.add_child(ui._label(str(copy[2]),14,ui.SAGE))
		var reach: ProgressBar = ui._progress(ui.SAGE,5)
		reach.value = float(Game.WEAPONS[key].range)/1800.0*100.0
		reach.set_meta("weapon_range",key)
		reach.mouse_filter = Control.MOUSE_FILTER_IGNORE
		detail.add_child(reach)
		content.add_child(detail)
		row.add_child(inspect)
		var action: Button = ui._button(_caption(key),ui._equip.bind(key),Game.owned_weapons.has(key) and not active,true)
		action.name = "WeaponAction_"+key
		action.custom_minimum_size.x = 250
		action.disabled = not _available(key)
		row.add_child(action)
		card.add_child(row)
	var footer: VBoxContainer = ui._fixed_actions()
	var ammo: HBoxContainer = ui._hbox(12)
	var ammo_icon: Control = ui._weapon_icon("ammo",Vector2(54,46))
	ammo_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ammo.add_child(ammo_icon)
	var count: Label = ui._copy("Munizioni\n%d colpi" % Game.ammo,18,ui.SAGE)
	ammo.add_child(count)
	var buy: Button = ui._button("Prepara 30 munizioni\n40 monete + 10 provviste",ui._ammo,false,true)
	buy.name = "BuyAmmo"
	buy.custom_minimum_size.x = 290
	buy.disabled = Game.coins<40 or Game.supplies<10
	ammo.add_child(buy)
	ammo.add_child(ui._icon_button("shield",ui.show_gate,"Controlla la barricata"))
	footer.add_child(ammo)

static func _show_phone(ui: CanvasLayer) -> void:
	ui.set_selected_tab("armory")
	var col: VBoxContainer = ui._open("armory","Armeria","ARMERIA DEL RIFUGIO")
	var ammo: VBoxContainer = ui._card(col,ui.SAGE)
	var row: HBoxContainer = ui._hbox(16)
	row.add_child(ui._weapon_icon("ammo",Vector2(60,52)))
	var count: Label = ui._copy("%d munizioni · la pistola ha colpi infiniti" % Game.ammo,22,ui.SAGE)
	row.add_child(count)
	var buy: Button = ui._button("+30 colpi · 40 monete\n+10 provviste",ui._ammo)
	buy.name = "BuyAmmo"
	buy.disabled = Game.coins<40 or Game.supplies<10
	row.add_child(buy)
	ammo.add_child(row)
	var grid: GridContainer = GridContainer.new()
	grid.set_meta("phone_grid",true)
	grid.columns = 2
	grid.add_theme_constant_override("h_separation",16)
	grid.add_theme_constant_override("v_separation",16)
	col.add_child(grid)
	for key: String in ["pistol","shotgun","sniper","smg"]:
		var active: bool = Game.weapon==key
		var card: VBoxContainer = ui._card(grid,ui.GOLD if active else ui.BORDER)
		card.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.set_meta("armory_weapon",key)
		var inspect: Button = ui._button("",ui._show_weapon_details.bind(key))
		inspect.name = "WeaponDetails_"+key
		inspect.custom_minimum_size.y = 80
		inspect.tooltip_text = "Tocca per i dettagli dell'arma"
		inspect.add_theme_stylebox_override("normal",ui._floating_group(4))
		var content: HBoxContainer = ui._hbox(14)
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 8
		content.offset_right = -8
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inspect.add_child(content)
		var icon: Control = ui._weapon_icon(key,Vector2(96,64))
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		content.add_child(icon)
		var info: VBoxContainer = ui._vbox(4)
		info.alignment = BoxContainer.ALIGNMENT_CENTER
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_label: Label = ui._copy(str(ui.WEAPON_COPY[key][0]),24,ui.TEXT)
		name_label.add_theme_font_override("font",ui.heading)
		info.add_child(name_label)
		info.add_child(ui._copy(str(ui.WEAPON_COPY[key][2]),22,ui.SAGE))
		content.add_child(info)
		card.add_child(inspect)
		var action: Button = ui._button(_caption(key),ui._equip.bind(key),not active)
		action.name = "WeaponAction_"+key
		action.disabled = not _available(key)
		card.add_child(action)
	col.move_child(ammo.get_parent(),col.get_child_count()-1)

static func show_details(ui: CanvasLayer, key: String) -> void:
	if not Game.WEAPONS.has(key): return
	var copy: Array = ui.WEAPON_COPY[key]
	var definition: Dictionary = Game.WEAPONS[key]
	var identity: int = ["pistol","shotgun","sniper","smg"].find(key)
	var col: VBoxContainer = ui._open("weapon_details",str(copy[0]),"CARATTERISTICHE DELL'ARMA",identity)
	var hero: CenterContainer = CenterContainer.new()
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_child(ui._weapon_icon(key,Vector2(260,120)))
	col.add_child(hero)
	col.add_child(ui._copy(str(copy[1]),18,ui.TEXT))
	var facts: VBoxContainer = ui._card(col,ui.SAGE)
	facts.add_child(ui._copy(str(copy[2]),20,ui.SAGE))
	facts.add_child(ui._copy("Danno %d · %.2f s tra i colpi" % [int(definition.damage),float(definition.cooldown)],18,ui.TEXT))
	facts.add_child(ui._copy("Colpi infiniti." if key=="pistol" else "Usa le munizioni condivise del rifugio: %d colpi disponibili." % Game.ammo,16))
	col.add_child(ui._copy("Il contorno dorato degli zombie indica quando sono a portata. Un bersaglio lontano richiede un'arma con più portata.",16))
	var footer: VBoxContainer = ui._fixed_actions()
	var actions: HBoxContainer = ui._hbox(12)
	actions.add_child(ui._button("← Armeria",ui._return_to_armory,false,true))
	var action: Button = ui._button(_caption(key),ui._equip_from_details.bind(key),true)
	action.name = "WeaponDetailsAction"
	action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action.disabled = not _available(key)
	actions.add_child(action)
	footer.add_child(actions)
