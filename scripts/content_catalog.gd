extends RefCounted
## Stable content identifiers keep existing settlements and diary rewards intact.

const QUEST_VERSION = 1
const BUILDING_NAMES = {
	"residence": "Casa dolce rifugio", "cafe": "L'ultimo caffè", "garden": "Orto del domani",
	"workshop": "Ferri & miracoli", "clinic": "Pronto soccorso", "bakery": "Panificio del mattino",
	"waterworks": "Acqua di domani", "tailor": "Ago & coraggio"
}
const BUILDING_COSTS = {"residence": 320, "cafe": 420, "garden": 460, "workshop": 540, "clinic": 650, "bakery": 580, "waterworks": 610, "tailor": 690}
const BUILDING_SKILLS = {"cafe": "food", "garden": "food", "bakery": "food", "workshop": "goods", "tailor": "goods", "clinic": "services", "waterworks": "services"}
const BUILDING_DESCRIPTIONS = {
	"residence": "Offre cinque letti: ogni letto libero permette di accogliere una persona al cancello.",
	"cafe": "Prepara colazioni da vendere. I talenti Cibo riducono i tempi di preparazione.",
	"garden": "Coltiva verdure da vendere. I talenti Cibo aiutano a riempire prima gli scaffali.",
	"workshop": "Ripara attrezzi e ricambi da vendere. Qui sono utili i talenti Beni.",
	"clinic": "Prepara materiali sanitari da vendere. I talenti Servizi velocizzano il lavoro; le cure dei cittadini usano provviste.",
	"bakery": "Sforna pane, panini e dolci da vendere. Assegna persone con un buon talento Cibo.",
	"waterworks": "Filtra acqua e prepara riserve da vendere. I talenti Servizi rendono più rapido il rifornimento.",
	"tailor": "Rammenda vestiti e cuce zaini da vendere. I talenti Beni fanno lavorare meglio la sartoria."
}
const PRODUCT_NAMES = {
	"cafe": ["Caffè di sopravvivenza", "Biscotti della nonna", "Colazione dei coraggiosi"],
	"garden": ["Pomodori felici", "Cassetta di verdure", "Dispensa del rifugio"],
	"workshop": ["Pezzi di ricambio", "Attrezzi riparati", "Kit del riparatore"],
	"clinic": ["Bende pulite", "Kit di pronto soccorso", "Scorta di medicinali"],
	"bakery": ["Pane della ripartenza", "Panini del viaggio", "Torta del buonumore"],
	"waterworks": ["Borracce d'acqua", "Scorta filtrata", "Riserva cristallina"],
	"tailor": ["Calze rammendate", "Giacche resistenti", "Zaini d'avventura"]
}
const PRODUCT_DESCRIPTIONS = {
	"cafe": ["Una tazza calda da vendere ai clienti del rifugio.", "Una piccola dolcezza: più scorte e ricavi del caffè.", "Il servizio completo: richiede tre lavoratori e offre il ricavo maggiore."],
	"garden": ["Il primo raccolto, pronto per il banco del mercato.", "Un assortimento di verdure da vendere in cassette.", "Un raccolto abbondante che tiene attive le vendite più a lungo."],
	"workshop": ["Ricambi recuperati e ripuliti per il mercato.", "Attrezzi rimessi in sesto, pronti per una seconda vita.", "Una cassetta completa per i piccoli lavori del rifugio."],
	"clinic": ["Bende confezionate per la vendita ai residenti.", "Una borsa sanitaria completa da mettere in vendita.", "La scorta più capiente della clinica, con vendite più remunerative."],
	"bakery": ["Una pagnotta appena sfornata da mettere sul banco.", "Panini pronti per chi ha una lunga giornata davanti.", "Un dolce per tutto il rifugio: la produzione più ricca del forno."],
	"waterworks": ["Acqua filtrata in piccole borracce da vendere.", "Una scorta d'acqua pulita per le necessità quotidiane.", "La riserva più capiente, per vendite che durano più a lungo."],
	"tailor": ["Calze riparate e calde da vendere al mercato.", "Giacche robuste rimesse a nuovo per i residenti.", "Zaini capienti cuciti a mano, il prodotto migliore della sartoria."]
}

const ZONES = [
	{"id": "minimarket", "name": "Minimarket abbandonato", "duration": 45.0, "threat": 18, "supplies": 18, "coins": 145, "gems": 1, "ammo": 8, "cost": 4, "description": "Scaffali impolverati, occasioni preziose. Ideale per iniziare."},
	{"id": "station", "name": "Stazione ferroviaria", "duration": 95.0, "threat": 36, "supplies": 38, "coins": 310, "gems": 2, "ammo": 18, "cost": 9, "description": "I vecchi vagoni nascondono provviste. E qualche passeggero."},
	{"id": "lab", "name": "Laboratorio 13", "duration": 165.0, "threat": 58, "supplies": 70, "coins": 590, "gems": 4, "ammo": 32, "cost": 14, "description": "Una zona per squadre preparate. Ricompense fuori dal comune."},
	{"id": "allotments", "name": "Orti di periferia", "duration": 65.0, "threat": 24, "supplies": 30, "coins": 170, "gems": 1, "ammo": 6, "cost": 6, "description": "Serre dimenticate e semi preziosi. Una tappa accessibile a una piccola squadra."},
	{"id": "pharmacy", "name": "Farmacia della piazza", "duration": 110.0, "threat": 40, "supplies": 52, "coins": 285, "gems": 2, "ammo": 12, "cost": 11, "description": "Cassetti chiusi e vecchi medicinali: prepara una squadra in salute."},
	{"id": "depot", "name": "Deposito municipale", "duration": 140.0, "threat": 49, "supplies": 58, "coins": 410, "gems": 2, "ammo": 28, "cost": 13, "description": "Scatoloni di attrezzi tra corridoi stretti. Beni e buon equipaggiamento aiutano."},
	{"id": "campground", "name": "Campeggio sul lago", "duration": 185.0, "threat": 62, "supplies": 82, "coins": 555, "gems": 3, "ammo": 24, "cost": 18, "description": "Tende silenziose e dispense da recuperare. Meglio partire in compagnia."},
	{"id": "outpost", "name": "Avamposto dimenticato", "duration": 225.0, "threat": 78, "supplies": 90, "coins": 710, "gems": 4, "ammo": 65, "cost": 23, "description": "Un deposito militare ben fornito. Richiede armi e persone preparate."},
	{"id": "observatory", "name": "Osservatorio sulla collina", "duration": 280.0, "threat": 96, "supplies": 120, "coins": 980, "gems": 6, "ammo": 48, "cost": 28, "description": "Il percorso più lungo e impegnativo, con grandi scorte sulla vetta."}
]

static func make_quests() -> Array:
	# The first eight keep their historical order, stat keys and rewards.
	var definitions = [
		["welcome", "Un posto a tavola", "Accogli un nuovo sopravvissuto al cancello.", "accepted", 1, 120, 1],
		["kills_5", "Vietato entrare", "Abbatti 5 zombie e proteggi il rifugio.", "kills", 5, 180, 1],
		["stock_2", "Aperti per miracolo", "Rifornisci gli scaffali di un'attività 2 volte.", "restocked", 2, 160, 1],
		["build_any", "C'è spazio per tutti", "Costruisci un nuovo edificio.", "built", 1, 220, 2],
		["expedition_first", "Fuori dai cancelli", "Completa e ritira una spedizione.", "expeditions", 1, 260, 2],
		["dream_first", "Il lavoro dei sogni", "Assegna un cittadino al suo lavoro ideale.", "dreams", 1, 180, 2],
		["income_2000", "Una piccola fortuna", "Guadagna 2.000 monete con vendite e difesa.", "earned", 2000, 500, 3],
		["defense_3", "Qui restiamo", "Respingi tre gruppi di zombie.", "waves", 3, 450, 3],
		["bakery_first", "Il profumo del pane", "Costruisci un Panificio del mattino.", "built_bakery", 1, 260, 2],
		["waterworks_first", "Un sorso di futuro", "Costruisci Acqua di domani.", "built_waterworks", 1, 280, 2],
		["tailor_first", "Ago, filo e speranza", "Costruisci Ago & coraggio.", "built_tailor", 1, 300, 2],
		["clinic_first", "Un posto per guarire", "Costruisci un Pronto soccorso.", "built_clinic", 1, 260, 2],
		["garden_first", "Pollice verde", "Costruisci un Orto del domani.", "built_garden", 1, 200, 1],
		["workshop_first", "Si può riparare", "Costruisci Ferri & miracoli.", "built_workshop", 1, 240, 2],
		["workers_5", "Tutti al lavoro", "Assegna un lavoro cinque volte.", "assignments", 5, 250, 2],
		["bread_first", "Il pane quotidiano", "Metti in vendita una produzione del panificio.", "stocked_bakery", 1, 180, 1],
		["water_first", "Acqua per tutti", "Metti in vendita una produzione del depuratore.", "stocked_waterworks", 1, 180, 1],
		["clothes_first", "Un vestito nuovo", "Metti in vendita una produzione della sartoria.", "stocked_tailor", 1, 180, 1],
		["production_12", "Scaffali sempre pieni", "Metti in vendita dodici produzioni.", "restocked", 12, 380, 3],
		["sold_100", "Clienti affezionati", "Vendi cento prodotti nelle attività.", "sold", 100, 300, 2],
		["team_explorer", "Orizzonti diversi", "Ritira spedizioni da quattro zone differenti.", "zones_explored", 4, 420, 3],
		["expedition_6", "La strada è di casa", "Completa e ritira sei spedizioni.", "expeditions", 6, 450, 3],
		["pharmacy_trip", "Una farmacia lontana", "Ritira il bottino della Farmacia della piazza.", "zone_pharmacy", 1, 230, 2],
		["outpost_trip", "Scorte d'emergenza", "Ritira il bottino dell'Avamposto dimenticato.", "zone_outpost", 1, 320, 3],
		["observatory_trip", "Sotto le stelle", "Ritira il bottino dell'Osservatorio sulla collina.", "zone_observatory", 1, 400, 4],
		["weapons_3", "Un'armeria fornita", "Possiedi tre armi diverse, inclusa la pistola.", "weapons_owned", 3, 320, 2],
		["heal_3", "Come nuovi", "Cura tre cittadini al rientro dalle spedizioni.", "healed", 3, 240, 2],
		["repair_3", "Mura salde", "Ripara il cancello tre volte.", "repaired", 3, 260, 2],
		["runner_5", "Fermate quei piedi", "Abbatti cinque zombie corridori.", "kills_runner", 5, 280, 2],
		["brute_3", "Giganti respinti", "Abbatti tre zombie colossi.", "kills_brute", 3, 360, 3],
		["residents_10", "Una piccola comunità", "Accogli dieci sopravvissuti.", "accepted", 10, 450, 3],
		["gate_3", "Il nostro bastione", "Porta il cancello al livello tre.", "gate_level", 3, 450, 3]
	]
	var result: Array = []
	for entry in definitions:
		result.append({"id": entry[0], "name": entry[1], "description": entry[2], "key": entry[3], "target": entry[4], "progress": 0, "reward": entry[5], "reward_gems": entry[6], "claimed": false})
	return result
