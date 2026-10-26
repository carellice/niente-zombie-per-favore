extends RefCounted
## Optional village services and long-term projects. All costs are rechecked by the model.

const ROLES = {
	"residence":"Cinque letti e una casa per chi ricomincia.",
	"cafe":"Una pausa insieme: +20% di tranquillità fra gli arrivi degli zombie.",
	"garden":"Raccolto per la comunità: prepara 12 provviste con 20 monete in 2 minuti.",
	"workshop":"Recupera materiali: prepara 3 materiali con 35 monete in 2 minuti e mezzo.",
	"clinic":"Cure a 2 provviste e ferite da spedizione dimezzate.",
	"bakery":"Pranzi al sacco: +15% di monete e provviste dalle spedizioni.",
	"waterworks":"Acqua per il viaggio: -25% di provviste richieste dalle spedizioni.",
	"tailor":"Zaini robusti: +10 punti percentuali di probabilità di bottino completo."
}
const DISCOVERIES = {
	"minimarket":["Scaffali capienti","Magazzini ampliabili per tutte le attività."],
	"station":["Schema della radio","Serve per rimettere in contatto i rifugi."],
	"lab":["Taccuino medico","Osservazione dei nuovi arrivati ridotta a 30 secondi."],
	"allotments":["Semi resistenti","Raccolti dell'orto aumentati da 12 a 18 provviste."],
	"pharmacy":["Ricettario di primo soccorso","Le cure costano una provvista in meno."],
	"depot":["Carrelli di servizio","Sblocca gli scaffali automatici: espongono la merce pronta senza spendere."],
	"campground":["Ricette da viaggio","Il bonus del panificio sale dal 15% al 25%."],
	"outpost":["Pannelli di recupero","Con la radio attiva, +1 materiale da ogni spedizione."],
	"observatory":["Mappa dei segnali","Il bonus della sartoria sale da 10 a 15 punti percentuali."]
}
const PROJECTS = [
	{"id":"home","name":"Un posto da chiamare casa","story":"Tre persone, una casa e il profumo del primo caffè. Il rifugio comincia a vivere.","goal":"Una casa e un caffè pronti, almeno 3 abitanti.","coins":0,"parts":0,"reward":350,"gift":3},
	{"id":"pantry","name":"La dispensa di quartiere","story":"Acqua pulita e un piccolo orto: possiamo prenderci cura gli uni degli altri.","goal":"Orto e depuratore pronti, una spedizione ritirata.","coins":0,"parts":0,"reward":450,"gift":5},
	{"id":"radio","name":"Una voce nella radio","story":"Un crepitio, poi una voce: là fuori ci sono altre persone. La torre ha di nuovo una radio accesa.","goal":"Officina pronta e schema trovato alla Stazione ferroviaria.","coins":600,"parts":8,"reward":0,"gift":0},
	{"id":"network","name":"Una rete di piccoli rifugi","story":"Nessuno deve ricominciare da solo. I vicini possono ora mandarci richieste di scambio.","goal":"Radio attiva, 10 abitanti e 4 destinazioni esplorate.","coins":900,"parts":12,"reward":0,"gift":0}
]

static func fresh() -> Dictionary:
	return {"parts":0,"discoveries":[],"projects":[],"request_index":0,"request_day":0}

static func staffed(game: Node, kind: String) -> bool:
	for b: Dictionary in game.buildings:
		if b.type==kind and not game.is_under_construction(b) and game._available_workers(b)>0: return true
	return false

static func ready(game: Node, kind: String) -> bool:
	for b: Dictionary in game.buildings:
		if b.type==kind and not game.is_under_construction(b): return true
	return false

static func found(game: Node, zone: String) -> bool:
	return game.community.discoveries.has(zone)

static func role(game: Node, kind: String) -> String:
	var text: String = str(ROLES.get(kind,""))
	if kind=="garden" and found(game,"allotments"): text = text.replace("12 provviste","18 provviste")
	if kind=="bakery" and found(game,"campground"): text = text.replace("15%","25%")
	if kind=="tailor" and found(game,"observatory"): text = text.replace("10 punti","15 punti")
	return text

static func tick(game: Node, delta: float, offline: bool=false) -> void:
	for b: Dictionary in game.buildings:
		var service: Dictionary = b.get("service",{})
		if service.get("status","")=="working" and game._available_workers(b)>0:
			service.remaining = maxf(0.0,float(service.remaining)-delta)
			if service.remaining<=0:
				service.status = "ready"
				if not offline: game.toast.emit(str(b.name)+": il contributo per il rifugio è pronto.")
	for visitor: Dictionary in game.visitors:
		if visitor.get("observation","")=="waiting":
			visitor.observation_remaining = maxf(0.0,float(visitor.get("observation_remaining",0))-delta)
			if visitor.observation_remaining<=0:
				visitor.observation = "done"
				if not offline: game.toast.emit("Controllo concluso: contagio confermato. Tieni chiuso l'ingresso." if visitor.suspicious else "Controllo concluso: nessun contagio. Puoi accogliere "+str(visitor.citizen.name)+".")

static func service_preview(game: Node, id: int) -> Dictionary:
	var b: Dictionary = game.get_building(id)
	if b.is_empty() or not ["garden","workshop"].has(str(b.type)): return {"valid":false}
	var garden: bool = b.type=="garden"
	var status: String = str(b.get("service",{}).get("status","idle"))
	return {"valid":true,"status":status,"name":"Raccolto condiviso" if garden else "Materiali di recupero",
		"cost":20 if garden else 35,"amount":(18 if found(game,"allotments") else 12) if garden else 3,
		"unit":"provviste" if garden else "materiali","duration":120.0 if garden else 150.0,
		"remaining":float(b.get("service",{}).get("remaining",0)),
		"available":not game.is_under_construction(b) and game._available_workers(b)>0}

static func service(game: Node, id: int) -> bool:
	var p: Dictionary = service_preview(game,id)
	if not p.get("valid",false) or (not p.available and p.status!="ready"): return false
	var b: Dictionary = game.get_building(id)
	if p.status=="ready":
		var amount: int = int(b.service.amount)
		if b.type=="garden": game.supplies += amount
		else: game.community.parts += amount
		b.service = {"status":"idle"}
		game.toast.emit("Contributo ricevuto: +%d %s." % [amount,p.unit])
	elif p.status=="idle" and game.coins>=int(p.cost):
		game.coins -= int(p.cost)
		b.service = {"status":"working","remaining":p.duration,"amount":int(p.amount)}
	else: return false
	game._commit()
	return true

static func upgrade(game: Node, id: int, automatic: bool) -> bool:
	var b: Dictionary = game.get_building(id)
	if b.is_empty() or b.type=="residence" or game.is_under_construction(b): return false
	var key: String = "auto_shelves" if automatic else "storage_upgraded"
	var source: String = "depot" if automatic else "minimarket"
	var parts: int = 6 if automatic else 4
	var cost: int = 500 if automatic else 350
	if not found(game,source) or b.get(key,false) or game.community.parts<parts or game.coins<cost: return false
	game.community.parts -= parts
	game.coins -= cost
	b[key] = true
	if not automatic:
		for product: Dictionary in b.products: product.max_stock = int(product.max_stock)*2
	game.toast.emit("Scaffali automatici attivati: nessuna spesa automatica." if automatic else "Magazzino ampliato: scorte raddoppiate.")
	game._commit()
	return true

static func project_preview(game: Node) -> Dictionary:
	var index: int = game.community.projects.size()
	if index>=PROJECTS.size(): return {"complete":true}
	var p: Dictionary = PROJECTS[index].duplicate()
	var eligible: bool = false
	match p.id:
		"home": eligible = ready(game,"residence") and ready(game,"cafe") and game.citizens.size()>=3
		"pantry": eligible = ready(game,"garden") and ready(game,"waterworks") and int(game.stats.get("expeditions",0))>=1
		"radio": eligible = ready(game,"workshop") and found(game,"station")
		"network": eligible = game.community.projects.has("radio") and game.citizens.size()>=10 and int(game.stats.get("zones_explored",0))>=4
	p.merge({"complete":false,"index":index,"eligible":eligible,"affordable":game.coins>=int(p.coins) and int(game.community.parts)>=int(p.parts)})
	return p

static func complete_project(game: Node) -> bool:
	var p: Dictionary = project_preview(game)
	if p.complete or not p.eligible or not p.affordable: return false
	game.coins += int(p.reward)-int(p.coins)
	game.community.parts += int(p.gift)-int(p.parts)
	game.community.projects.append(p.id)
	game.toast.emit(str(p.story))
	game.sfx.emit("reward")
	game._commit()
	return true

static func request_preview(game: Node) -> Dictionary:
	var options: Array = [
		{"name":"Una cena per i vicini","resource":"supplies","unit":"provviste","amount":18,"coins":180,"supplies":0,"parts":1},
		{"name":"Ripariamo il loro pozzo","resource":"parts","unit":"materiali","amount":3,"coins":160,"supplies":24,"parts":0},
		{"name":"Un piccolo fondo comune","resource":"coins","unit":"monete","amount":200,"coins":0,"supplies":20,"parts":3}]
	var p: Dictionary = options[int(game.community.request_index)%options.size()].duplicate()
	p["unlocked"] = game.community.projects.has("network")
	p["ready"] = game.day>=int(game.community.request_day)
	var owned: int = int(game.community.parts) if p.resource=="parts" else int(game.get(p.resource))
	p["affordable"] = owned>=int(p.amount)
	return p

static func deliver(game: Node) -> bool:
	var p: Dictionary = request_preview(game)
	if not p.unlocked or not p.ready or not p.affordable: return false
	if p.resource=="parts": game.community.parts -= int(p.amount)
	else: game.set(p.resource,game.get(p.resource)-int(p.amount))
	game.coins += int(p.coins)
	game.supplies += int(p.supplies)
	game.community.parts += int(p.parts)
	game.community.request_index += 1
	game.community.request_day = game.day+1
	game.toast.emit("I vicini ringraziano! Il prossimo scambio arriverà domani, senza scadenza.")
	game._commit()
	return true

static func observation_duration(game: Node) -> float:
	return 30.0 if found(game,"lab") else 60.0

static func observe(game: Node, id: int) -> bool:
	var target: Dictionary = {}
	for v: Dictionary in game.visitors:
		if v.get("observation","")=="waiting": return false
		if int(v.id)==id: target = v
	if target.is_empty() or not game.visitor_at_gate(target) or target.get("observation","")=="done": return false
	target.observation = "waiting"
	target.observation_duration = observation_duration(game)
	target.observation_remaining = target.observation_duration
	game.toast.emit("Controllo del contagio avviato: %d secondi, gratis. Puoi continuare a giocare." % int(target.observation_duration))
	game._commit()
	return true

static func visitor_report(visitor: Dictionary) -> String:
	if visitor.get("observation","")=="done":
		return "Osservazione conclusa: segni di contagio confermati. L'ingresso resta chiuso." if visitor.suspicious else "Osservazione conclusa: nessun segno di contagio. Puoi accoglierlo se hai un letto."
	if visitor.get("observation","")=="waiting": return "In osservazione: ancora %d secondi. L'ingresso attende l'esito." % ceili(float(visitor.observation_remaining))
	return str(visitor.get("hint","Osserva i segni e ascolta il suo racconto."))

static func ask(game: Node, id: int, question: String) -> bool:
	if not ["journey","health"].has(question): return false
	for v: Dictionary in game.visitors:
		if int(v.id)!=id: continue
		var answers: Dictionary = v.get("answers",{})
		var marked: bool = str(v.get("appearance","clean"))!="clean"
		if question=="journey": answers[question] = "«Ho camminato fra polvere e rovi. Cerco un posto dove riposare.»" if marked else "«Vengo dalla strada a sud. Ho tenuto le distanze dalle persone contagiate.»"
		else: answers[question] = "«Mi sento strano. Credo sia solo stanchezza...»" if v.suspicious else "«Sono stanco, ma riesco a mangiare e a raccontarti il viaggio.»"
		v.answers = answers
		game._commit()
		return true
	return false
