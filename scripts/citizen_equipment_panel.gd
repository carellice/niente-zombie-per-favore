extends RefCounted
## Explain each role and sell one personal copy and ammunition per citizen.

static func _action(ui: CanvasLayer, button: Button, id: int, key: String, mode: String) -> void:
	var preview: Dictionary = Game.citizen_gear_preview(id,key)
	match mode:
		"buy": button.disabled = not preview.get("can_buy",false)
		"ammo": button.disabled = not preview.get("can_refill",false)
		"equip": button.disabled = not preview.get("owned",false) or preview.get("equipped",false) or bool(Game.get_citizen(id).get("away",true))

static func _ammo_text(id: int, key: String) -> String:
	if key=="pistol": return "Colpi infiniti · Sempre pronta"
	var preview: Dictionary = Game.citizen_gear_preview(id,key)
	return "Scorta personale: "+Game.ExpeditionGear.ammo_label(key,int(preview.get("ammo",0)))

static func show_panel(ui: CanvasLayer, id: int) -> void:
	var citizen: Dictionary = Game.get_citizen(id)
	if citizen.is_empty(): return
	var col: VBoxContainer = ui._open("citizen_equipment","Armi e munizioni personali",str(citizen.name).to_upper(),id)
	ui._citizen_name(col,citizen)
	col.add_child(ui._copy("Una copia e una scorta per questa persona. Acquistare equipaggia l’arma e include i primi colpi. La pistola resta sempre gratuita.",18))
	if bool(citizen.get("away",false)):
		col.add_child(ui._copy("In spedizione: potrai acquistare, rifornire o cambiare arma al rientro.",20,ui.GOLD))
	var zone_index: int = ui.selected_zone if ui._equipment_from_expedition else -1
	if zone_index>=0:
		var zone: Dictionary = Game.zones[zone_index]
		col.add_child(ui._copy("Per %s · %s" % [zone.name,Game.ExpeditionGear.TERRAINS[Game.ExpeditionGear.terrain(zone)]],21,ui.SAGE))
	else:
		col.add_child(ui._copy("Pompa per spazi stretti, precisione per spazi aperti, mitragliatore per zone affollate. La schermata della squadra confronta potenza e consumo per la destinazione scelta.",18,ui.SAGE))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.set_meta("phone_grid",true)
	grid.add_theme_constant_override("h_separation",16)
	grid.add_theme_constant_override("v_separation",16)
	col.add_child(grid)
	for key: String in ["pistol","shotgun","sniper","smg"]:
		var definition: Dictionary = Game.ExpeditionGear.WEAPONS[key]
		var preview: Dictionary = Game.citizen_gear_preview(id,key,zone_index)
		var card: VBoxContainer = ui._card(grid,ui.SAGE if preview.equipped else ui.BORDER)
		card.set_meta("personal_weapon",key)
		var row: HBoxContainer = ui._hbox(16)
		row.add_child(ui._weapon_icon(key,Vector2(78,54)))
		var info: VBoxContainer = ui._vbox(4)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(ui._label(str(Game.WEAPONS[key].name),23,ui.TEXT,true))
		info.add_child(ui._copy(str(definition.role),18))
		row.add_child(info)
		card.add_child(row)
		if zone_index>=0:
			var factor: Label = ui._copy("Qui: ×%.2f potenza · %s" % [float(preview.factor),"colpi infiniti" if key=="pistol" else Game.ExpeditionGear.ammo_label(key,int(preview.required))+" alla partenza"],20,ui.GOLD)
			factor.name = "GearRoute_"+key
			card.add_child(factor)
		if preview.owned:
			ui._bind_label(card,func(label: Label) -> void: label.text = _ammo_text(id,key),19,ui.SAGE)
		else:
			card.add_child(ui._copy("Prima scorta inclusa: %d %s." % [int(definition.pack),definition.unit],18,ui.SAGE))
		var actions: HBoxContainer = ui._hbox(12)
		card.add_child(actions)
		var mode: String = "equip" if preview.owned else "buy"
		var callback: Callable = ui._equip_citizen.bind(id,key) if preview.owned else ui._buy_citizen_weapon.bind(id,key)
		var caption: String = ("In uso" if preview.equipped else "Equipaggia") if preview.owned else "Compra copia personale\n%d monete + %d provviste" % [int(definition.cost),int(definition.supplies)]
		var action: Button = ui._button(caption,callback,not preview.equipped,true)
		action.name = ("PersonalEquip_" if preview.owned else "PersonalBuy_")+key
		action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_action(ui,action,id,key,mode)
		ui.bindings.append([action,func(button: Button) -> void: _action(ui,button,id,key,mode)])
		actions.add_child(action)
		if preview.owned and key!="pistol":
			var refill: Button = ui._button("+%d %s personali\n%d monete + %d provviste" % [int(definition.pack),definition.unit,int(definition.ammo_cost),int(definition.ammo_supplies)],ui._buy_citizen_ammo.bind(id,key),false,true)
			refill.name = "PersonalAmmo_"+key
			refill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_action(ui,refill,id,key,"ammo")
			ui.bindings.append([refill,func(button: Button) -> void: _action(ui,button,id,key,"ammo")])
			actions.add_child(refill)
	col.add_child(ui._copy("Le spedizioni scalano i colpi personali una sola volta alla partenza. Se la scorta non basta, rifornisci oppure scegli la pistola gratuita. Le armi restano di proprietà del cittadino anche quando cambi equipaggiamento.",18))
	var back: Button = ui._button("← Torna alla squadra" if ui._equipment_from_expedition else "← Torna ai cittadini",ui._return_from_equipment,false,true)
	back.name = "EquipmentBack"
	ui._fixed_actions().add_child(back)
