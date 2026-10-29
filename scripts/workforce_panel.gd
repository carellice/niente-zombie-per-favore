extends RefCounted
## The same illustrated job vocabulary is used from citizens and from shops.
const Signs = preload("res://scripts/building_signage.gd")
const NAMES = {"cafe":"Caffè","garden":"Orto","workshop":"Officina","clinic":"Clinica","bakery":"Panificio","waterworks":"Depuratore","tailor":"Sartoria"}
const SKILLS = {"food":["coffee","Cibo"],"goods":["goods","Beni"],"services":["heart","Servizi"]}

static func job_name(kind: String) -> String:
	return str(NAMES.get(kind,kind))

static func vacancies(count: int) -> String:
	return "1 posto libero" if count==1 else "%d posti liberi" % count

static func building_name(game: Node, building: Dictionary) -> String:
	var copies: Array = game.buildings.filter(func(b: Dictionary) -> bool: return b.type==building.type)
	return job_name(str(building.type))+(" · %d" % (copies.find(building)+1) if copies.size()>1 else "")

static func signature(game: Node) -> String:
	var data: Array = []
	for c: Dictionary in game.citizens: data.append([c.id,c.job,c.dream,c.get("away",false),c.food,c.goods,c.services])
	for b: Dictionary in game.buildings: data.append([b.id,b.type,b.workers,b.get("dream_bonus",false),game.is_under_construction(b)])
	return JSON.stringify(data)

static func preview(game: Node, citizen: Dictionary, building: Dictionary) -> Dictionary:
	var current: bool = int(citizen.job)==int(building.id)
	var away: bool = bool(citizen.get("away",false))
	var pending: bool = game.is_under_construction(building)
	var full: bool = building.workers.size()>=3
	var skill: String = str(game.BUILDING_SKILLS.get(str(building.type),"services"))
	var action: String = "Già assegnato" if current else "In spedizione" if away else "In costruzione" if pending else "Completo" if full else "Trasferisci qui" if int(citizen.job)>=0 else "Assegna qui"
	return {"current":current,"away":away,"dream":str(citizen.dream)==str(building.type),"full":full,"pending":pending,"skill":skill,"talent":int(citizen.get(skill,1)),"action":action,"can_assign":not current and not away and not pending and not full and building.type!="residence"}

static func _grid(ui: CanvasLayer, parent: Node) -> GridContainer:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.set_meta("phone_grid",true)
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	parent.add_child(grid)
	return grid

static func _emblem(ui: CanvasLayer, kind: String, size: int=40) -> Control:
	return ui._painted_icon(Signs.texture(kind),Vector2(size,size),"job_"+kind)

static func _role(ui: CanvasLayer, parent: Node, title: String, kind: String, text: String, note: String, desired: bool) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "DesiredJob" if desired else "AssignedJob"
	panel.set_meta("job_kind",kind)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel",ui._style(Color("fbf1d7") if desired else Color("edf3e8"),Color("d8bd82") if desired else Color("bdcbb4"),14,10))
	parent.add_child(panel)
	var row: HBoxContainer = ui._hbox(8)
	panel.add_child(row)
	var icon: Control = _emblem(ui,kind) if NAMES.has(kind) else ui._icon("people",36)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var labels: VBoxContainer = ui._vbox(2)
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(labels)
	labels.add_child(ui._copy(title,14,ui.GOLD if desired else ui.SAGE))
	var name: Label = ui._copy(text,20,ui.TEXT)
	name.name = "JobName"
	name.add_theme_font_override("font",ui.heading)
	labels.add_child(name)
	if not note.is_empty(): labels.add_child(ui._copy(note,14,ui.GOLD if desired else ui.MUTED))

static func citizen_header(ui: CanvasLayer, parent: Node, citizen: Dictionary, show_skills: bool=true) -> void:
	var game: Node = ui.get_node("/root/Game")
	var identity: HBoxContainer = ui._hbox(12)
	parent.add_child(identity)
	identity.add_child(ui._portrait(citizen,Vector2(64,80)))
	var names: VBoxContainer = ui._vbox(4)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_child(names)
	ui._citizen_name(names,citizen,23)
	if citizen.get("away",false): names.add_child(ui._copy("In spedizione",16,ui.GOLD))
	var roles: GridContainer = GridContainer.new()
	roles.columns = 2
	roles.name = "JobComparison_"+str(citizen.id)
	roles.add_theme_constant_override("h_separation",10)
	parent.add_child(roles)
	var desired: String = str(citizen.dream)
	var built: bool = false
	var ready: bool = false
	for b: Dictionary in game.buildings:
		if b.type==desired:
			built = true
			if not game.is_under_construction(b): ready = true
	_role(ui,roles,"Desiderato",desired,job_name(desired),"" if ready else "In costruzione" if built else "Da costruire",true)
	var assigned: Dictionary = game.get_building(int(citizen.job))
	var note: String = "Posto mantenuto" if citizen.get("away",false) and not assigned.is_empty() else "Al rientro" if citizen.get("away",false) else "Disponibile" if assigned.is_empty() else ""
	_role(ui,roles,"Assegnato",str(assigned.get("type","")),building_name(game,assigned) if not assigned.is_empty() else "Nessun lavoro",note,false)
	if show_skills:
		parent.add_child(ui._amounts([["coffee",int(citizen.food)],["goods",int(citizen.goods)],["heart",int(citizen.services)],["health",str(int(citizen.hp))+"% salute"]]))

static func _heading(ui: CanvasLayer, parent: Node, title: String) -> void:
	var label: Label = ui._copy(title,23,ui.TEXT)
	label.add_theme_font_override("font",ui.heading)
	parent.add_child(label)

static func _shop_header(ui: CanvasLayer, parent: Node, building: Dictionary) -> void:
	var game: Node = ui.get_node("/root/Game")
	var card: VBoxContainer = ui._card(parent)
	var row: HBoxContainer = ui._hbox(14)
	card.add_child(row)
	row.add_child(_emblem(ui,str(building.type),64))
	var text: VBoxContainer = ui._vbox(4)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	_heading(ui,text,building_name(game,building))
	var count: Label = ui._copy("%d / 3 assegnati · %d al lavoro" % [building.workers.size(),game._available_workers(building)],19,ui.SAGE)
	count.name = "StaffCount"
	text.add_child(count)
	var skill: Array = SKILLS[str(game.BUILDING_SKILLS.get(str(building.type),"services"))]
	text.add_child(ui._copy("Talento utile: "+str(skill[1]),16,ui.MUTED))
	card.add_child(ui._copy("Scorte ×2 già sbloccate" if building.get("dream_bonus",false) else "Un lavoratore nel posto desiderato sblocca scorte ×2.",17,ui.GOLD))

static func _talent(ui: CanvasLayer, parent: Node, citizen: Dictionary, building: Dictionary, mark_desired: bool=true) -> void:
	var game: Node = ui.get_node("/root/Game")
	var view: Dictionary = preview(game,citizen,building)
	var skill: Array = SKILLS[view.skill]
	parent.add_child(ui._amounts([[skill[0],str(view.talent)+" "+str(skill[1])]]))
	if view.dream and mark_desired: parent.add_child(ui._copy("Desidera questo lavoro",17,ui.GOLD))

static func _sorted(game: Node, citizens: Array, building: Dictionary) -> Array:
	var result: Array = citizens.duplicate()
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left: Dictionary = preview(game,a,building)
		var right: Dictionary = preview(game,b,building)
		if left.dream!=right.dream: return left.dream
		if left.talent!=right.talent: return left.talent>right.talent
		return str(a.name).naturalnocasecmp_to(str(b.name))<0
	)
	return result

static func show_shop(ui: CanvasLayer, id: int) -> void:
	var game: Node = ui.get_node("/root/Game")
	var building: Dictionary = game.get_building(id)
	if building.is_empty(): return
	if building.type=="residence" or game.is_under_construction(building):
		ui.show_building(id)
		return
	var col: VBoxContainer = ui._open("assignment","La squadra del negozio",str(building.name).to_upper(),id)
	ui._last_panel_signature = signature(game)
	_shop_header(ui,col,building)
	_heading(ui,col,"Assegnati a questo negozio")
	var staff: Array = game.citizens.filter(func(c: Dictionary) -> bool: return int(c.job)==id)
	if staff.is_empty(): col.add_child(ui._copy("Nessun lavoratore. Scegli una persona qui sotto.",18,ui.MUTED))
	else:
		var grid: GridContainer = _grid(ui,col)
		for citizen: Dictionary in staff:
			var card: VBoxContainer = ui._card(grid,ui.SAGE)
			card.set_meta("staff_citizen",int(citizen.id))
			citizen_header(ui,card,citizen,false)
			var release: Button = ui._button("In spedizione" if citizen.get("away",false) else "Libera il posto",ui._assign.bind(int(citizen.id),-1),false,true)
			release.name = "ReleaseWorker_"+str(citizen.id)
			release.disabled = citizen.get("away",false)
			card.add_child(release)
	var free: Array = []
	var transfers: Array = []
	var away: int = 0
	for citizen: Dictionary in game.citizens:
		if int(citizen.job)==id: continue
		if citizen.get("away",false): away += 1
		elif int(citizen.job)<0: free.append(citizen)
		else: transfers.append(citizen)
	for group: Array in [["Persone disponibili",free],["Trasferisci da un altro negozio",transfers]]:
		if group[1].is_empty(): continue
		_heading(ui,col,group[0])
		var grid: GridContainer = _grid(ui,col)
		for citizen: Dictionary in _sorted(game,group[1],building):
			var view: Dictionary = preview(game,citizen,building)
			var card: VBoxContainer = ui._card(grid,ui.GOLD if view.dream else ui.BORDER)
			card.set_meta("candidate_citizen",int(citizen.id))
			citizen_header(ui,card,citizen,false)
			_talent(ui,card,citizen,building)
			var action: Button = ui._button("Completo" if view.full else "Trasferisci qui" if int(citizen.job)>=0 else "Assegna al negozio",ui._assign.bind(int(citizen.id),id),true,true)
			action.name = "AssignWorker_"+str(citizen.id)
			action.disabled = not view.can_assign
			card.add_child(action)
	if free.is_empty() and transfers.is_empty(): col.add_child(ui._copy("Tutte le persone disponibili hanno già un posto qui." if not staff.is_empty() else "Attendi il rientro delle persone in spedizione." if away>0 else "Accogli nuovi cittadini per formare la squadra.",18,ui.MUTED))
	if away>0: col.add_child(ui._copy("In spedizione: %d. Disponibili al rientro." % away,17,ui.GOLD))
	col.add_child(ui._copy("Ogni persona presente sblocca un prodotto. Più talento rende i rifornimenti più rapidi.",16,ui.MUTED))
	ui._fixed_actions().add_child(ui._button("← Torna al negozio",ui._return_to_building.bind(id),false,true))

static func show_citizen(ui: CanvasLayer, id: int) -> void:
	var game: Node = ui.get_node("/root/Game")
	var citizen: Dictionary = game.get_citizen(id)
	if citizen.is_empty(): return
	var col: VBoxContainer = ui._open("job_select","Scegli il lavoro","ASSEGNAZIONE LAVORO",id)
	ui._last_panel_signature = signature(game)
	var profile: VBoxContainer = ui._card(col)
	citizen_header(ui,profile,citizen,false)
	var desired: Array = []
	var others: Array = []
	for building: Dictionary in game.buildings:
		if building.type=="residence": continue
		if building.type==citizen.dream: desired.append(building)
		else: others.append(building)
	for group: Array in [["Il lavoro desiderato",desired],["Altri negozi",others]]:
		if group[1].is_empty(): continue
		_heading(ui,col,group[0])
		var grid: GridContainer = _grid(ui,col)
		for building: Dictionary in group[1]:
			var view: Dictionary = preview(game,citizen,building)
			var card: VBoxContainer = ui._card(grid,ui.SAGE if view.current else ui.GOLD if view.dream else ui.BORDER)
			card.set_meta("job_building",int(building.id))
			var header: HBoxContainer = ui._hbox(12)
			card.add_child(header)
			header.add_child(_emblem(ui,str(building.type),48))
			var text: VBoxContainer = ui._vbox(3)
			text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			header.add_child(text)
			_heading(ui,text,building_name(game,building))
			text.add_child(ui._copy("Incarico attuale" if view.current else "Lavoro desiderato" if view.dream else vacancies(maxi(0,3-building.workers.size())),17,ui.SAGE if view.current else ui.GOLD if view.dream else ui.MUTED))
			card.add_child(ui._copy("%d / 3 posti occupati" % building.workers.size(),18,ui.SAGE))
			_talent(ui,card,citizen,building,false)
			if view.dream: card.add_child(ui._copy("Scorte ×2 già sbloccate" if building.get("dream_bonus",false) else "Sblocca scorte ×2 per questo negozio",16,ui.GOLD))
			var action: Button = ui._button(view.action,ui._job_assign.bind(id,int(building.id)),not view.current,true)
			action.name = "ChooseJob_"+str(building.id)
			action.disabled = not view.can_assign
			header.add_child(action)
	if desired.is_empty() and others.is_empty(): col.add_child(ui._copy("Non ci sono ancora negozi. Costruisci un'attività per assegnare il primo lavoro.",19))
	for kind: String in NAMES:
		if game.buildings.filter(func(b: Dictionary) -> bool: return b.type==kind).size()>1:
			col.add_child(ui._copy("I negozi uguali sono numerati da sinistra a destra.",16,ui.MUTED))
			break
	var release: Button = ui._button("Senza incarico" if int(citizen.job)<0 else "Lascia senza incarico",ui._job_assign.bind(id,-1),false,true)
	release.name = "ReleaseCitizen"
	release.disabled = int(citizen.job)<0 or citizen.get("away",false)
	col.add_child(release)
	col.add_child(ui._copy("Il lavoro desiderato sblocca scorte ×2 una sola volta: il bonus resta anche se la persona cambia incarico.",16,ui.MUTED))
	ui._fixed_actions().add_child(ui._button("← Torna ai cittadini",ui._return_to_citizens,false,true))

static func overview(ui: CanvasLayer, parent: Node, building: Dictionary) -> void:
	var game: Node = ui.get_node("/root/Game")
	var card: VBoxContainer = ui._card(parent)
	var row: HBoxContainer = ui._hbox(12)
	row.add_child(ui._copy("%d / 3 assegnati · %d al lavoro" % [building.workers.size(),game._available_workers(building)],19,ui.SAGE))
	row.add_child(ui._button("Gestisci i lavoratori",ui._show_assignment.bind(int(building.id)),false,true))
	card.add_child(row)
	var slots: HFlowContainer = HFlowContainer.new()
	slots.name = "ShopWorkerSlots"
	slots.add_theme_constant_override("h_separation",12)
	slots.add_theme_constant_override("v_separation",8)
	card.add_child(slots)
	for index: int in range(3):
		var slot: HBoxContainer = ui._hbox(6)
		slots.add_child(slot)
		if index<building.workers.size():
			var citizen: Dictionary = game.get_citizen(int(building.workers[index]))
			slot.add_child(ui._portrait(citizen,Vector2(32,40)))
			slot.add_child(ui._label(str(citizen.name)+(" · in viaggio" if citizen.get("away",false) else ""),16,ui.GOLD if citizen.get("away",false) else ui.TEXT))
		else:
			slot.add_child(ui._icon("people",28))
			slot.add_child(ui._label("Posto libero",16,ui.MUTED))
