extends RefCounted
const Rules = preload("res://scripts/cozy_rules.gd")
const Build = preload("res://scripts/build_panel.gd")
const Observation = preload("res://scripts/visitor_observation.gd")

static func heading(ui: CanvasLayer, parent: Node, title: String, text: String="") -> void:
	var label: Label = ui._copy(title,25,ui.TEXT)
	label.add_theme_font_override("font",ui.heading)
	parent.add_child(label)
	if not text.is_empty(): parent.add_child(ui._copy(text,17))

static func tabs(ui: CanvasLayer, parent: Node, entries: Array, selected: String, scope: String) -> void:
	var row: HBoxContainer = ui._hbox(10)
	row.name = "CozyTabs"
	parent.add_child(row)
	for entry: Array in entries:
		var button: Button = ui._button(entry[1],ui._cozy_tab.bind(scope,entry[0]),selected==entry[0],true)
		button.name = "Tab_"+str(entry[0])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(button)

static func batch(ui: CanvasLayer, parent: Node, id: int=-1) -> void:
	var quote: Dictionary = Game.batch_preview(id)
	var row: HBoxContainer = ui._hbox(12)
	parent.add_child(row)
	var start: Button = ui._cost_button("Avvia tutti",ui.ResourceUI.costs(int(quote.cost),int(quote.supplies)),ui._cozy_action.bind("batch",id),true,true)
	start.name = "BatchStart"
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.bindings.append([start,func(b: Button) -> void:
		var q: Dictionary = Game.batch_preview(id)
		ui._update_cost_button(b,"Avvia tutti",ui.ResourceUI.costs(int(q.cost),int(q.supplies)))
		b.disabled = q.start==0 or Game.coins<int(q.cost) or Game.supplies<int(q.supplies)
	])
	row.add_child(start)
	var expose: Button = ui._button("Esponi tutta la merce pronta",ui._cozy_action.bind("expose",id),false,true)
	expose.name = "BatchExpose"
	expose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.bindings.append([expose,func(b: Button) -> void: b.disabled = Game.batch_preview(id).ready==0])
	row.add_child(expose)

static func building(ui: CanvasLayer, id: int) -> void:
	var b: Dictionary = Game.get_building(id)
	if b.is_empty(): return
	if ui.panel_kind!="building" or ui.panel_id!=id: ui.building_tab = "production"
	var col: VBoxContainer = ui._open("building",str(b.name),"LA VITA NEL RIFUGIO",id)
	ui._last_panel_signature = ui._building_signature(b)
	if Game.is_under_construction(b):
		ui.ConstructionPanel.show_site(ui,col,b)
		return
	var hero: HBoxContainer = ui._hbox(18)
	hero.add_child(ui._painted_icon(Build._art(str(b.type)),Vector2(110,100)))
	var intro: VBoxContainer = ui._vbox(5)
	intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.add_child(intro)
	if DeviceLayout.android_phone(): intro.add_child(ui._copy(Build.summary(str(b.type)),19,ui.SAGE))
	else: heading(ui,intro,str(b.name),Build.summary(str(b.type)))
	col.add_child(hero)
	if b.type=="residence":
		var home: VBoxContainer = ui._card(col,ui.SAGE)
		heading(ui,home,"Un posto per ricominciare","%d abitanti · %d letti liberi" % [Game.citizens.size(),maxi(0,Game.capacity()-Game.citizens.size())])
		home.add_child(ui._button("Conosci i cittadini",ui._show_citizens,true))
		col.add_child(ui._copy("Tieni premuto sull'edificio in città per aprire la demolizione. Gli alloggi necessari agli abitanti sono protetti.",16))
		return
	tabs(ui,col,[["production","Bottega"],["service","Contributo"],["upgrades","Migliorie"]],ui.building_tab,"building")
	match ui.building_tab:
		"service": service(ui,col,b)
		"upgrades": upgrades(ui,col,b)
		_: production(ui,col,b)

static func production(ui: CanvasLayer, col: Node, b: Dictionary) -> void:
	var staff: VBoxContainer = ui._card(col)
	var row: HBoxContainer = ui._hbox(14)
	row.add_child(ui._copy("Squadra · %d / 3 al lavoro%s" % [Game._available_workers(b)," · Sogno realizzato, scorte ×2" if b.dream_bonus else ""],19,ui.SAGE))
	row.add_child(ui._button("Gestisci i lavoratori",ui._show_assignment.bind(int(b.id)),false,true))
	staff.add_child(row)
	batch(ui,col,int(b.id))
	for p: Dictionary in b.products:
		var tier: int = int(p.tier)
		var unlocked: bool = Game._available_workers(b)>=tier
		var card: VBoxContainer = ui._card(col,ui.SAGE if p.status=="ready" else ui.BORDER)
		var product: HBoxContainer = ui._hbox(16)
		product.add_child(ui._product_icon(str(b.type),tier,64))
		var info: VBoxContainer = ui._vbox(4)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading(ui,info,str(p.name))
		info.add_child(ui._amounts([["coin",str(int(p.price))+" / pezzo"],["stock","×"+str(int(p.max_stock))]]))
		product.add_child(info)
		card.add_child(product)
		if not unlocked and p.status=="empty":
			card.add_child(ui._copy("Servono %d lavoratori disponibili." % tier,17))
		elif p.status=="stocked":
			ui._bind_label(card,func(l: Label) -> void: l.text = "In vendita · %d pezzi rimasti" % int(p.stock),18,ui.SAGE)
		elif p.status=="restocking":
			ui._bind_label(card,func(l: Label) -> void: l.text = "In preparazione · "+ui._time(float(p.remaining)),18,ui.GOLD)
			var progress: ProgressBar = ui._progress(ui.SAGE)
			card.add_child(progress)
			ui.bindings.append([progress,func(v: ProgressBar) -> void: v.value = 100.0*(1.0-float(p.remaining)/float(p.duration))])
		elif p.status=="ready":
			card.add_child(ui._button("Riempi gli scaffali  →",ui._restock.bind(int(b.id),tier),true))
		else:
			var action: Button = ui._cost_button("Avvia rifornimento",ui.ResourceUI.costs(int(p.cost),int(p.supply_cost)),ui._restock.bind(int(b.id),tier),true)
			ui.bindings.append([action,func(v: Button) -> void: v.disabled = Game.coins<int(p.cost) or Game.supplies<int(p.supply_cost) or Game._available_workers(b)<tier])
			card.add_child(action)

static func service(ui: CanvasLayer, col: Node, b: Dictionary) -> void:
	var card: VBoxContainer = ui._card(col,ui.SAGE)
	heading(ui,card,"Contributo",Build.summary(str(b.type)))
	card.add_child(ui._copy("Richiede un lavoratore. I bonus dello stesso tipo non si sommano.",17))
	var p: Dictionary = Rules.service_preview(Game,int(b.id))
	if p.get("valid",false):
		heading(ui,card,str(p.name))
		card.add_child(ui._amounts([["crate" if b.type=="garden" else "build",int(p.amount)],["compass",ui._time(float(p.duration))]]))
		var label: Label = ui._bind_label(card,func(l: Label) -> void:
			var current: Dictionary = Rules.service_preview(Game,int(b.id))
			l.text = "Pronto da ritirare" if current.status=="ready" else "In preparazione · "+ui._time(current.remaining) if current.status=="working" else ""
			l.visible = not l.text.is_empty()
		,20,ui.SAGE)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var action: Button = ui._cost_button("Ritira" if p.status=="ready" else "In preparazione" if p.status=="working" else "Prepara",ui.ResourceUI.costs(int(p.cost)) if p.status=="idle" else [],ui._cozy_action.bind("service",int(b.id)),true)
		action.name = "VillageService"
		ui.bindings.append([action,func(v: Button) -> void:
			var current: Dictionary = Rules.service_preview(Game,int(b.id))
			v.disabled = (not current.available and current.status!="ready") or current.status=="working" or (current.status=="idle" and Game.coins<int(current.cost))
			ui._update_cost_button(v,"Ritira" if current.status=="ready" else "In preparazione" if current.status=="working" else "Prepara",ui.ResourceUI.costs(int(current.cost)) if current.status=="idle" else [])
		])
		card.add_child(action)
	else:
		card.add_child(ui._copy("Bonus attivo" if Rules.staffed(Game,str(b.type)) else "Assegna una persona per attivare il bonus.",20,ui.SAGE))
	card.add_child(ui._button("Gestisci la squadra",ui._show_assignment.bind(int(b.id)),false,true))

static func upgrades(ui: CanvasLayer, col: Node, b: Dictionary) -> void:
	for automatic: bool in [false,true]:
		var card: VBoxContainer = ui._card(col)
		var source: String = "depot" if automatic else "minimarket"
		var key: String = "auto_shelves" if automatic else "storage_upgraded"
		heading(ui,card,"Scaffali automatici" if automatic else "Magazzino capiente","La merce pronta va sugli scaffali da sola. Avviare produzioni resta sempre una tua scelta." if automatic else "Raddoppia le scorte di tutti i prodotti, anche con il bonus del lavoro ideale.")
		var cost: int = 500 if automatic else 350
		var parts: int = 6 if automatic else 4
		if not Rules.found(Game,source): card.add_child(ui._copy("Progetto da trovare: "+str(Game.zones[["minimarket","station","lab","allotments","pharmacy","depot"].find(source)].name),17,ui.GOLD))
		var action: Button = ui._cost_button("Già attivo" if b.get(key,false) else "Migliora",[] if b.get(key,false) else ui.ResourceUI.costs(cost,0,parts),ui._cozy_action.bind("auto" if automatic else "storage",int(b.id)),true)
		ui.bindings.append([action,func(v: Button) -> void: v.disabled = not Rules.found(Game,source) or b.get(key,false) or Game.coins<cost or int(Game.community.parts)<parts])
		card.add_child(action)
	col.add_child(ui._copy("Per demolire, chiudi la scheda e tieni premuto sull'edificio o sull'insegna.",16))

static func journal(ui: CanvasLayer) -> void:
	var col: VBoxContainer = ui._open("quests","Il diario del rifugio","UN PASSO ALLA VOLTA")
	tabs(ui,col,[["projects","La nostra storia"],["goals","Obiettivi"],["discoveries","Scoperte"]],ui.journal_tab,"journal")
	if ui.journal_tab=="goals":
		var completed: int = Game.quests.filter(func(q: Dictionary) -> bool: return q.claimed).size()
		heading(ui,col,"Piccole soddisfazioni","%d / %d ricompense già ricevute. I traguardi restano acquisiti." % [completed,Game.quests.size()])
		for i: int in range(Game.quests.size()):
			var q: Dictionary = Game.quests[i]
			if q.claimed: continue
			var card: VBoxContainer = ui._card(col)
			heading(ui,card,str(q.name),str(q.description))
			card.add_child(ui._copy("%d / %d" % [int(q.progress),int(q.target)],18,ui.SAGE))
			var action: Button = ui._cost_button("Ritira",ui.ResourceUI.costs(int(q.reward),0,0,int(q.reward_gems)),ui._claim_quest.bind(i),true,true)
			action.disabled = int(q.progress)<int(q.target)
			card.add_child(action)
		return
	if ui.journal_tab=="discoveries":
		heading(ui,col,"Una scoperta a ogni primo viaggio","Il progetto è garantito anche con un bottino ridotto. Ogni effetto si applica una sola volta.")
		for zone: Dictionary in Game.zones:
			var discovered: bool = Rules.found(Game,str(zone.id))
			var card: VBoxContainer = ui._card(col,ui.SAGE if discovered else ui.BORDER)
			heading(ui,card,str(Rules.DISCOVERIES[zone.id][0]),str(Rules.DISCOVERIES[zone.id][1]))
			card.add_child(ui._copy(("Trovato · " if discovered else "Da cercare · ")+str(zone.name),18,ui.SAGE if discovered else ui.GOLD))
		return
	var p: Dictionary = Rules.project_preview(Game)
	var card: VBoxContainer = ui._card(col,ui.SAGE)
	card.add_child(ui._painted_icon(load("res://assets/art/community-radio.png"),Vector2(150,112),"community_radio"))
	if not p.complete:
		heading(ui,card,"Capitolo %d · %s" % [int(p.index)+1,p.name],str(p.goal))
		var action: Button = ui._cost_button("Completa il progetto" if int(p.coins)>0 else "Completa e ritira",ui.ResourceUI.costs(int(p.coins),0,int(p.parts)) if int(p.coins)>0 else ui.ResourceUI.costs(int(p.reward),0,int(p.gift)),ui._cozy_action.bind("project",-1),true)
		action.name = "CommunityProject"
		ui.bindings.append([action,func(v: Button) -> void:
			var current: Dictionary = Rules.project_preview(Game)
			v.disabled = current.complete or not current.get("eligible",false) or not current.get("affordable",false)
		])
		card.add_child(action)
	else: heading(ui,card,"La radio è accesa. Il vicinato cresce.","Puoi continuare a espandere il rifugio e aiutare i vicini quanto vuoi.")
	for project_id: String in Game.community.projects:
		for done: Dictionary in Rules.PROJECTS:
			if done.id!=project_id: continue
			var memory: VBoxContainer = ui._card(col)
			heading(ui,memory,"✓ "+str(done.name),str(done.story))
	var request: Dictionary = Rules.request_preview(Game)
	if request.unlocked:
		var neighbors: VBoxContainer = ui._card(col,ui.GOLD)
		heading(ui,neighbors,str(request.name))
		neighbors.add_child(ui._copy("Consegna",17))
		neighbors.add_child(ui._amounts([[{"coins":"coin","supplies":"crate","parts":"build"}.get(str(request.resource),"crate"),int(request.amount)]]))
		neighbors.add_child(ui._copy("Ricevi",17))
		neighbors.add_child(ui._amounts(ui.ResourceUI.costs(int(request.coins),int(request.supplies),int(request.parts))))
		var deliver: Button = ui._button("Consegna ai vicini" if request.ready else "Il prossimo scambio arriva domani",ui._cozy_action.bind("deliver",-1),true)
		deliver.disabled = not request.ready or not request.affordable
		neighbors.add_child(deliver)
	col.add_child(ui._amounts([["build",int(Game.community.parts)],["discoveries","%d / 9" % Game.community.discoveries.size()]]))

static func visitor(ui: CanvasLayer, id: int) -> void:
	var v: Dictionary = ui._visitor(id)
	if v.is_empty(): return
	var c: Dictionary = v.citizen
	var col: VBoxContainer = ui._open("visitor","Una porta aperta","ACCOGLIENZA",id)
	var row: HBoxContainer = ui._hbox(20)
	row.add_child(ui._portrait(c,Vector2(132,154)))
	var info: VBoxContainer = ui._vbox(8)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui._citizen_name(info,c,28)
	info.add_child(ui._amounts([["coffee",int(c.food)],["goods",int(c.goods)],["heart",int(c.services)]]))
	info.add_child(ui._copy("Sogno: "+ui._type_name(str(c.dream)),18,ui.GOLD))
	info.add_child(ui._copy(str(c.quirk),17))
	row.add_child(info)
	col.add_child(row)
	Observation.show_card(ui,col,v)
	var observation: VBoxContainer = ui._card(col)
	heading(ui,observation,"Indizi e domande")
	var report: Label = ui._bind_label(observation,func(l: Label) -> void:
		l.text = str(v.get("hint",""))
		l.visible = v.get("observation","")!="done"
	,18,ui.TEXT)
	report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var questions: HBoxContainer = ui._hbox(10)
	observation.add_child(questions)
	for entry: Array in [["journey","Com'è stato il viaggio?"],["health","Come ti senti?"]]:
		var question: Button = ui._button(entry[1],ui._cozy_ask.bind(id,entry[0]),false,true)
		question.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		question.disabled = v.get("answers",{}).has(entry[0])
		questions.add_child(question)
	for answer: String in v.get("answers",{}).values(): observation.add_child(ui._copy(answer,18,ui.SAGE))
	var decisions: HBoxContainer = ui._hbox(12)
	col.add_child(ui._copy("Letti liberi: %d" % maxi(0,Game.capacity()-Game.citizens.size()),19,ui.SAGE))
	col.add_child(decisions)
	var accept: Button = ui._button("Accogli nel rifugio",ui._accept_visitor.bind(id),true)
	accept.name = "AcceptVisitor"
	accept.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.bindings.append([accept,func(button: Button) -> void:
		var status: String = str(v.get("observation",""))
		button.disabled = Game.citizens.size()>=Game.capacity() or status=="waiting" or (status=="done" and v.suspicious)
		button.text = "Attendi l'esito" if status=="waiting" else "Ingresso bloccato" if status=="done" and v.suspicious else "Accogli nel rifugio"
	])
	decisions.add_child(accept)
	var reject: Button = ui._button("Accompagna verso l'uscita",ui._reject_visitor.bind(id),false)
	reject.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	decisions.add_child(reject)

static func pause(ui: CanvasLayer) -> void:
	var col: VBoxContainer = ui._open("pause","Una piccola pausa","IL RIFUGIO TI ASPETTA")
	col.add_child(ui._amounts([["sun",Game.day],["people",Game.citizens.size()]]))
	var resume: Button = ui._button("Torniamo al rifugio",ui._resume_from_pause,true)
	resume.name = "PauseResume"
	col.add_child(resume)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.set_meta("phone_grid",true)
	grid.add_theme_constant_override("h_separation",14)
	grid.add_theme_constant_override("v_separation",14)
	col.add_child(grid)
	for entry: Array in [["sound","Impostazioni","Audio e comodità","settings"],["help","Come si gioca","Un aiuto, quando serve","help"]]:
		var card: VBoxContainer = ui._card(grid)
		var row: HBoxContainer = ui._hbox(12)
		row.add_child(ui._icon(entry[0],40))
		row.add_child(ui._copy(entry[2],18))
		card.add_child(row)
		var button: Button = ui._button(entry[1],ui._pause_options.bind(entry[3]),false,true)
		button.name = "PauseSettings" if entry[3]=="settings" else "PauseHelp"
		card.add_child(button)
	var saving: VBoxContainer = ui._card(col)
	var status: Label = ui._copy("Salvataggio automatico attivo. Puoi tornare quando vuoi.",17,ui.SAGE)
	status.name = "PauseSaveStatus"
	saving.add_child(status)
	var actions: HBoxContainer = ui._hbox(12)
	saving.add_child(actions)
	var save: Button = ui._button("Salva adesso",ui._save_from_pause,false,true)
	save.name = "PauseSave"
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(save)
	var menu: Button = ui._button("Salva e torna al menu",ui._return_to_main_menu,false,true)
	menu.name = "PauseMainMenu"
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(menu)
