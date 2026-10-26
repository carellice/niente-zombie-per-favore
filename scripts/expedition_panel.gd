extends RefCounted
## Three clear stages: choose a route, understand the trade-offs, prepare a team.

static func _heading(ui: CanvasLayer, parent: Node, text: String) -> Label:
	var label: Label = ui._copy(text,25,ui.TEXT)
	label.add_theme_font_override("font",ui.heading)
	parent.add_child(label)
	return label

static func _grid(parent: Node, columns: int=2) -> GridContainer:
	var grid: GridContainer = GridContainer.new()
	grid.columns = columns
	grid.set_meta("phone_grid",true)
	grid.add_theme_constant_override("h_separation",16)
	grid.add_theme_constant_override("v_separation",16)
	parent.add_child(grid)
	return grid

static func _signed(amount: int) -> String:
	return ("+" if amount>=0 else "")+str(amount)

static func _difficulty(threat: int) -> String:
	if threat<=25: return "Passeggiata"
	if threat<=40: return "Breve viaggio"
	if threat<=62: return "Esplorazione"
	if threat<=78: return "Avventura"
	return "Lungo viaggio"

static func _loot(ui: CanvasLayer, parent: Node, rewards: Dictionary, title: String) -> void:
	var card: VBoxContainer = ui._card(parent,ui.SAGE)
	_heading(ui,card,title)
	var amounts: Array = []
	for entry: Array in [["parts","build","materiali"],["coins","coin","monete"],["supplies","crate","provviste"],["ammo","ammo","colpi torretta"],["gems","bill","banconote"]]:
		var amount: int = int(rewards.get(entry[0],0))
		if amount>0: amounts.append([entry[1],amount])
	card.add_child(ui._amounts(amounts))

static func _fact(ui: CanvasLayer, parent: Node, icon: String, title: String, value: String) -> void:
	var card: VBoxContainer = ui._card(parent)
	card.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row: HBoxContainer = ui._hbox(12)
	row.add_child(ui._icon(icon,34))
	var content: VBoxContainer = ui._vbox(4)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(ui._copy(title,18))
	var number: Label = ui._copy(value,24,ui.TEXT)
	number.add_theme_font_override("font",ui.heading)
	content.add_child(number)
	row.add_child(content)
	card.add_child(row)

static func show_panel(ui: CanvasLayer, preserve_step: bool=false) -> void:
	if ui.panel_kind!="expeditions" and not preserve_step: ui.expedition_step = 0
	ui.set_selected_tab("expeditions")
	var status: String = str(Game.expedition.get("status","idle"))
	var col: VBoxContainer = ui._open("expeditions","Spedizioni","ESPLORA OLTRE LE MURA",ui.expedition_step if status=="idle" else -1)
	ui._last_panel_signature = status
	if status=="running":
		_show_running(ui,col)
		return
	if status=="ready":
		_show_rewards(ui,col)
		return
	ui.selected_zone = clampi(ui.selected_zone,0,Game.zones.size()-1)
	ui.selected_members = ui.selected_members.filter(func(id: Variant) -> bool:
		var citizen: Dictionary = Game.get_citizen(int(id))
		return not citizen.is_empty() and not bool(citizen.get("away",false))
	)
	var steps: Array[String] = ["Destinazione","Dettagli","Squadra"]
	var stage: Label = ui._copy("%d / 3 · %s" % [ui.expedition_step+1,steps[ui.expedition_step]],19,ui.SAGE)
	stage.name = "ExpeditionStage"
	col.add_child(stage)
	match ui.expedition_step:
		0: _show_destinations(ui,col)
		1: _show_details(ui,col)
		2: _show_team(ui,col)
	_show_controls(ui)

static func _show_destinations(ui: CanvasLayer, col: VBoxContainer) -> void:
	var list: GridContainer = _grid(col)
	for index: int in range(Game.zones.size()):
		var zone: Dictionary = Game.zones[index]
		var card: VBoxContainer = ui._card(list)
		card.set_meta("expedition_zone",index)
		card.add_theme_constant_override("separation",12)
		var panel: PanelContainer = card.get_parent()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.custom_minimum_size.y = 286 if DeviceLayout.android_phone() else 248
		card.add_child(ui._icon("compass",36))
		var name: Label = _heading(ui,card,str(zone.name))
		name.custom_minimum_size.y = 58
		card.add_child(ui._copy(("Scoperta recuperata · " if Game.Cozy.found(Game,str(zone.id)) else "Da scoprire · ")+str(Game.Cozy.DISCOVERIES[zone.id][0]),18,ui.SAGE))
		card.add_child(ui._amounts([["compass",ui._time(float(zone.duration))]]))
		card.add_child(ui._copy(_difficulty(int(zone.threat)),18,ui.SAGE))
		card.add_child(ui._copy(str(Game.ExpeditionGear.TERRAINS[Game.ExpeditionGear.terrain(zone)]),18,ui.GOLD))
		card.add_child(ui._copy("Bottino",17))
		card.add_child(ui._amounts(ui.ResourceUI.costs(int(zone.coins),int(zone.supplies))))
		var space: Control = Control.new()
		space.size_flags_vertical = Control.SIZE_EXPAND_FILL
		space.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(space)
		card.add_child(ui._copy("Alla partenza",17))
		card.add_child(ui._amounts([["crate",Game.expedition_cost(index)]],ui.GOLD))
		var inspect: Button = ui._button("Esamina",ui._select_zone.bind(index),true,true)
		inspect.name = "ExpeditionZone_"+str(index)
		card.add_child(inspect)

static func _show_details(ui: CanvasLayer, col: VBoxContainer) -> void:
	var zone: Dictionary = Game.zones[ui.selected_zone]
	var preview: Dictionary = Game.expedition_preview(ui.selected_zone,[])
	_heading(ui,col,str(zone.name))
	var discovery: VBoxContainer = ui._card(col,ui.SAGE)
	_heading(ui,discovery,str(Game.Cozy.DISCOVERIES[zone.id][0]))
	discovery.add_child(ui._copy(str(Game.Cozy.DISCOVERIES[zone.id][1])+" Progetto garantito al primo rientro, anche con bottino ridotto.",18,ui.SAGE))
	col.add_child(ui._copy(str(zone.description),18))
	col.add_child(ui._copy("Ambiente: "+str(Game.ExpeditionGear.TERRAINS[preview.terrain])+". "+_recommended(str(preview.terrain)),19,ui.SAGE))
	var facts: GridContainer = _grid(col)
	_fact(ui,facts,"compass","Tempo di assenza",ui._time(float(preview.duration)))
	_fact(ui,facts,"crate","Costo partenza",str(int(preview.cost)))
	col.add_child(ui._copy("Paghi solo quando parti. Si consumano le munizioni personali; il bottino rifornisce la torretta.",18,ui.SAGE))
	_loot(ui,col,preview.full_rewards,"Se ottieni il bottino completo")
	col.add_child(ui._copy("Guadagno netto",17))
	col.add_child(ui._amounts([["crate",_signed(int(preview.full_net_supplies))]]))
	var downside: VBoxContainer = ui._card(col,ui.GOLD)
	_heading(ui,downside,"Se la spedizione incontra difficoltà")
	downside.add_child(ui._copy("Bottino al 40%, senza banconote. Il costo resta speso.",18))
	downside.add_child(ui._amounts([["coin",int(preview.reduced_rewards.coins)],["crate",int(preview.reduced_rewards.supplies)],["ammo",int(preview.reduced_rewards.ammo)]]))
	downside.add_child(ui._copy("Guadagno netto",17))
	downside.add_child(ui._amounts([["crate",_signed(int(preview.reduced_net_supplies))]],ui.GOLD))
	var care: VBoxContainer = ui._card(col)
	_heading(ui,care,"Squadra e salute")
	care.add_child(ui._copy("Tutti rientrano. Perdono fino a %d salute se riescono, %d in caso di difficoltà; minimo %d. Durante il viaggio non lavorano e non attirano zombie." % [int(preview.success_damage),int(preview.failure_damage),int(preview.health_floor)],18))
	care.add_child(ui._copy("La prossima pagina confronta armi, salute e probabilità della squadra.",18,ui.SAGE))

static func _recommended(terrain: String) -> String:
	match terrain:
		"close": return "Consigliato: fucile a pompa."
		"open": return "Consigliato: fucile di precisione."
		"crowded": return "Consigliato: mitragliatore."
	return "Mitragliatore versatile; la pistola evita ogni costo di munizioni."

static func _chance_text(preview: Dictionary) -> String:
	if preview.members.is_empty(): return "Seleziona la squadra per vedere la probabilità."
	if not preview.loadout_ready: return "Munizioni personali insufficienti: rifornisci oppure scegli la pistola."
	return "Probabilità di bottino completo: %d%%" % roundi(float(preview.chance)*100)

static func _show_team(ui: CanvasLayer, col: VBoxContainer) -> void:
	var zone: Dictionary = Game.zones[ui.selected_zone]
	var initial: Dictionary = Game.expedition_preview(ui.selected_zone,ui.selected_members)
	_heading(ui,col,str(zone.name))
	col.add_child(ui._copy(str(Game.ExpeditionGear.TERRAINS[initial.terrain])+" · "+_recommended(str(initial.terrain)),20,ui.SAGE))
	col.add_child(ui._amounts([["compass",ui._time(float(zone.duration))],["crate",Game.expedition_cost(ui.selected_zone)],["people","1–3"]],ui.GOLD))
	var outlook: VBoxContainer = ui._card(col,ui.SAGE)
	var chance: Label = ui._copy(_chance_text(initial),24,ui.SAGE)
	chance.name = "ExpeditionChance"
	outlook.add_child(chance)
	ui.bindings.append([chance,func(label: Label) -> void:
		var preview: Dictionary = Game.expedition_preview(ui.selected_zone,ui.selected_members)
		label.text = _chance_text(preview)
	])
	var progress: ProgressBar = ui._progress(ui.SAGE,10)
	progress.value = float(initial.chance)*100.0 if initial.loadout_ready else 0.0
	outlook.add_child(progress)
	ui.bindings.append([progress,func(bar: ProgressBar) -> void:
		var preview: Dictionary = Game.expedition_preview(ui.selected_zone,ui.selected_members)
		bar.value = float(preview.chance)*100.0 if preview.loadout_ready else 0.0
	])
	outlook.add_child(ui._copy("Confronta la probabilità anche con la pistola: se resta al 100%, puoi risparmiare colpi. Chi parte sospende il lavoro fino al rientro.",18))
	var available: int = 0
	for citizen: Dictionary in Game.citizens:
		if citizen.get("away",false): continue
		available += 1
		var id: int = int(citizen.id)
		var chosen: bool = ui.selected_members.has(id)
		var card: VBoxContainer = ui._card(col,ui.SAGE if chosen else ui.BORDER)
		card.set_meta("expedition_citizen",id)
		var row: HBoxContainer = ui._hbox(14)
		row.add_child(ui._portrait(citizen,Vector2(64,84)))
		var info: VBoxContainer = ui._vbox(4)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ui._citizen_name(info,citizen,23)
		info.add_child(ui._copy("%s · Salute %d%%" % [ui._work_name(citizen),int(citizen.hp)],18))
		info.add_child(ui._copy("Potenza qui: %.0f" % Game.expedition_power([id],ui.selected_zone),18,ui.SAGE))
		var key: String = str(citizen.get("weapon","pistol"))
		var gear: Dictionary = Game.citizen_gear_preview(id,key,ui.selected_zone)
		info.add_child(ui._copy(str(Game.WEAPONS[key].name)+(" · Colpi infiniti" if key=="pistol" else " · Scorta %d / Consumo %d" % [int(gear.ammo),int(gear.required)]),18,ui.SAGE if gear.ready else ui.RED))
		row.add_child(info)
		row.add_child(ui._weapon_icon(str(citizen.get("weapon","pistol")),Vector2(62,44)))
		var select: Button = ui._button("✓ In squadra" if chosen else "Seleziona",ui._select_member.bind(id),chosen,true)
		var actions: HBoxContainer = ui._hbox(12)
		select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		select.custom_minimum_size.x = 155
		select.disabled = not chosen and ui.selected_members.size()>=3
		card.add_child(row)
		actions.add_child(select)
		var equipment: Button = ui._button("Arma e munizioni",ui._show_citizen_equipment.bind(id,true),false,true)
		equipment.name = "TeamEquipment_"+str(id)
		equipment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(equipment)
		card.add_child(actions)
	if available==0:
		col.add_child(ui._copy("Nessun cittadino disponibile. Accogli nuove persone al cancello o attendi il rientro della squadra già fuori.",22,ui.GOLD))

static func _show_controls(ui: CanvasLayer) -> void:
	if ui.expedition_step==0: return
	var footer: VBoxContainer = ui._fixed_actions()
	if ui.expedition_step==1:
		var actions: HBoxContainer = ui._hbox(12)
		footer.add_child(actions)
		var back: Button = ui._button("← Destinazioni",ui._set_expedition_step.bind(0),false,true)
		back.name = "BackToDestinations"
		actions.add_child(back)
		var prepare: Button = ui._button("Prepara la squadra  →",ui._set_expedition_step.bind(2),true)
		prepare.name = "PrepareTeam"
		prepare.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(prepare)
		return
	var summary: Label = ui._copy("%d / 3 in squadra" % ui.selected_members.size(),19,ui.SAGE)
	summary.name = "DepartureSummary"
	footer.add_child(summary)
	ui.bindings.append([summary,func(label: Label) -> void: label.text = "%d / 3 in squadra" % ui.selected_members.size()])
	var consumption: HFlowContainer = ui._amounts([["ammo",0]])
	consumption.name = "PersonalAmmoConsumption"
	footer.add_child(consumption)
	ui.bindings.append([consumption.get_child(0).get_node("Quantity"),func(label: Label) -> void:
		var preview: Dictionary = Game.expedition_preview(ui.selected_zone,ui.selected_members)
		var rounds: int = 0
		for entry: Dictionary in preview.loadout: rounds += int(entry.ammo)
		label.text = str(rounds)+" personali"
	])
	var initial: Dictionary = Game.expedition_preview(ui.selected_zone,ui.selected_members)
	var state: Label = ui._copy(str(initial.reason) if not initial.can_depart else "Pronta a partire. Rientro garantito; il bottino completo dipende dalla probabilità mostrata.",18,ui.GOLD)
	state.name = "DepartureReason"
	footer.add_child(state)
	ui.bindings.append([state,func(label: Label) -> void:
		var preview: Dictionary = Game.expedition_preview(ui.selected_zone,ui.selected_members)
		label.text = str(preview.reason) if not preview.can_depart else "Pronta a partire. Rientro garantito; il bottino completo dipende dalla probabilità mostrata."
	])
	var actions: HBoxContainer = ui._hbox(12)
	footer.add_child(actions)
	var back: Button = ui._button("← Dettagli",ui._set_expedition_step.bind(1),false,true)
	back.name = "BackToDetails"
	actions.add_child(back)
	var launch: Button = ui._cost_button("Parti",ui.ResourceUI.costs(0,Game.expedition_cost(ui.selected_zone)),ui._launch_expedition,true)
	launch.name = "LaunchExpedition"
	launch.disabled = not bool(initial.can_depart)
	launch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(launch)
	ui.bindings.append([launch,func(button: Button) -> void:
		button.disabled = not bool(Game.expedition_preview(ui.selected_zone,ui.selected_members).can_depart)
	])

static func _show_running(ui: CanvasLayer, col: VBoxContainer) -> void:
	var exp: Dictionary = Game.expedition
	var card: VBoxContainer = ui._card(col,ui.GOLD)
	_heading(ui,card,str(exp.get("name","Spedizione in corso")))
	ui._bind_label(card,func(label: Label) -> void: label.text = "Rientro fra %s" % ui._time(float(Game.expedition.get("remaining",0))),27,ui.GOLD)
	card.add_child(ui._copy("La partenza è già pagata. Non devi versare altre risorse.",18,ui.SAGE))
	var progress: ProgressBar = ui._progress(ui.GOLD,10)
	card.add_child(progress)
	ui.bindings.append([progress,func(bar: ProgressBar) -> void:
		bar.value = (1.0-float(Game.expedition.get("remaining",0))/maxf(float(Game.expedition.get("duration",1)),1))*100.0
	])
	var names: PackedStringArray = []
	for id: Variant in exp.get("members",[]): names.append(str(Game.get_citizen(int(id)).get("name","")))
	card.add_child(ui._copy("In squadra: "+", ".join(names),19,ui.TEXT))
	for entry: Dictionary in exp.get("loadout",[]):
		card.add_child(ui._copy("%s · %s · Scorta personale usata: %s" % [entry.name,Game.WEAPONS[str(entry.weapon)].name,Game.ExpeditionGear.ammo_label(str(entry.weapon),int(entry.ammo))],18,ui.SAGE))
	col.add_child(ui._copy("Queste persone riprenderanno il lavoro al rientro. Potrai ritirare il bottino dalla stessa pagina, anche se torni più tardi.",18))
	if exp.has("zone"):
		var preview: Dictionary = Game.expedition_preview(int(exp.zone),[])
		if preview.valid: _loot(ui,col,preview.full_rewards,"Bottino completo possibile")
	ui._fixed_actions().add_child(ui._button("Torna al rifugio",ui._close_modal,true))

static func _show_rewards(ui: CanvasLayer, col: VBoxContainer) -> void:
	var exp: Dictionary = Game.expedition
	_heading(ui,col,"Spedizione riuscita" if exp.get("success",false) else "Un rientro difficile")
	col.add_child(ui._copy("La squadra è rientrata e ha ripreso i propri incarichi.",20,ui.SAGE))
	if not exp.get("success",false):
		col.add_child(ui._copy("Tutti sono tornati. Il bottino è ridotto al 40% e non contiene banconote.",18,ui.GOLD))
	_loot(ui,col,exp.get("rewards",{}),"Risorse da ritirare")
	for id: Variant in exp.get("members",[]):
		var citizen: Dictionary = Game.get_citizen(int(id))
		if not citizen.is_empty():
			col.add_child(ui._copy("%s · Salute %d%%" % [str(citizen.name),int(citizen.hp)],18,ui.GOLD if int(citizen.hp)<100 else ui.SAGE))
	col.add_child(ui._copy("Se serve, cura i cittadini dalla pagina Cittadini. La clinica e il ricettario riducono il costo; ritirare il bottino è gratuito.",18))
	var claim: Button = ui._button("Ritira tutto il bottino",ui._claim_expedition,true)
	claim.name = "ClaimExpedition"
	ui._fixed_actions().add_child(claim)
