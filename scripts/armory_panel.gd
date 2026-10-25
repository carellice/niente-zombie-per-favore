extends RefCounted
## Compact comparison rows, with full specifications available on demand.

static func _caption(key: String) -> String:
	if Game.weapon==key: return "In uso"
	if Game.owned_weapons.has(key): return "Equipaggia"
	var cost: Dictionary = Game.WEAPONS[key]
	return "Torretta · %d monete\n+ %d provviste" % [int(cost.cost),int(cost.supplies)]

static func _available(key: String) -> bool:
	var cost: Dictionary = Game.WEAPONS[key]
	return Game.weapon!=key and (Game.owned_weapons.has(key) or (Game.coins>=int(cost.cost) and Game.supplies>=int(cost.supplies)))

static func show_catalog(ui: CanvasLayer) -> void:
	ui.set_selected_tab("armory")
	var col: VBoxContainer = ui._open("armory","L'armeria della torretta","OGNI ARMA HA IL SUO MOMENTO")
	col.add_child(ui._copy("Scegli l’arma per il militare. Le scorte dei cittadini si gestiscono dalla loro scheda.",18,ui.SAGE))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.set_meta("phone_grid",true)
	grid.add_theme_constant_override("h_separation",16)
	grid.add_theme_constant_override("v_separation",16)
	col.add_child(grid)
	for key: String in ["pistol","shotgun","sniper","smg"]:
		var card: VBoxContainer = ui._card(grid,ui.SAGE if Game.weapon==key else ui.BORDER)
		card.set_meta("armory_weapon",key)
		var hero: HBoxContainer = ui._hbox(16)
		hero.add_child(ui._weapon_icon(key,Vector2(110,76)))
		var info: VBoxContainer = ui._vbox(4)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ui.CozyPanel.heading(ui,info,str(Game.WEAPONS[key].name),str(ui.WEAPON_COPY[key][2]))
		hero.add_child(info)
		card.add_child(hero)
		card.add_child(ui._copy(str(ui.WEAPON_COPY[key][1]),18))
		var spacer: Control = ui._spacer()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.add_child(spacer)
		var actions: HBoxContainer = ui._hbox(10)
		card.add_child(actions)
		var details: Button = ui._button("Dettagli",ui._show_weapon_details.bind(key),false,true)
		details.name = "WeaponDetails_"+key
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(details)
		var action: Button = ui._button(_caption(key),ui._equip.bind(key),Game.weapon!=key,true)
		action.name = "WeaponAction_"+key
		action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action.disabled = not _available(key)
		ui.bindings.append([action,func(b: Button) -> void: b.disabled = not _available(key)])
		actions.add_child(action)
	var ammo: VBoxContainer = ui._card(col,ui.SAGE)
	var row: HBoxContainer = ui._hbox(16)
	ammo.add_child(row)
	row.add_child(ui._weapon_icon("ammo",Vector2(74,54)))
	var caption: Label = ui._bind_label(row,func(l: Label) -> void: l.text = "Munizioni della torretta · %d colpi" % Game.ammo,20,ui.TEXT)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var buy: Button = ui._button("+30 colpi · 40 monete + 10 provviste",ui._ammo,true,true)
	buy.name = "BuyAmmo"
	buy.disabled = Game.coins<40 or Game.supplies<10
	ui.bindings.append([buy,func(b: Button) -> void: b.disabled = Game.coins<40 or Game.supplies<10])
	ammo.add_child(buy)

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
	facts.add_child(ui._copy("Colpi infiniti." if key=="pistol" else "Scorta della torretta: %d colpi disponibili. I cittadini hanno munizioni personali." % Game.ammo,16))
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
