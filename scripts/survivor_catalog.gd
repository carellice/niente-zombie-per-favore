extends RefCounted
## Existing look ids 4–7 are aliases of the original four people in version 2 saves.
## New appearances have their own stable ids so an existing survivor never changes face.
const LOOK_IDS = [0, 1, 2, 3, 8, 9, 10, 11, 12, 13, 14, 15]

static func canonical_look(look: int) -> int:
	return look % 4 if look >= 4 and look <= 7 else look

static func gender_for_look(look: int) -> String:
	return "male" if MALE_LOOK_IDS.has(canonical_look(look)) else "female"

static func names_for_look(look: int) -> Array:
	if is_nurse(look): return ["Chiara"]
	return MALE_FIRST_NAMES if gender_for_look(look) == "male" else FEMALE_FIRST_NAMES

static func is_nurse(look: int) -> bool:
	return canonical_look(look)==3
const FIRST_NAMES = [
	"Marta", "Bruno", "Nina", "Leo", "Ada", "Rocco", "Iris", "Pietro", "Luna", "Teo", "Olivia", "Enea",
	"Zoe", "Amir", "Cleo", "Dario", "Yuki", "Sofia", "Milo", "Elena", "Omar", "Bianca", "Diego", "Viola",
	"Alma", "Andrea", "Anita", "Arturo", "Aurora", "Beatrice", "Boris", "Camilla", "Carlo", "Caterina", "Cesare", "Chiara",
	"Clara", "Cosimo", "Dalia", "Daniele", "Dina", "Edoardo", "Elsa", "Emilio", "Emma", "Enrico", "Eva", "Fabio",
	"Fatima", "Filippo", "Flora", "Frida", "Gabriele", "Gaia", "Giacomo", "Giada", "Gioele", "Giorgia", "Giulio", "Greta",
	"Hana", "Ida", "Iman", "Isabel", "Karim", "Lara", "Lidia", "Luca", "Luisa", "Manuel", "Maya", "Mina",
	"Mirko", "Nadia", "Naomi", "Nico", "Noemi", "Nora", "Oscar", "Paola", "Paolo", "Rania", "Remo", "Rita",
	"Rosa", "Samir", "Sara", "Saul", "Silvia", "Stella", "Tania", "Tito", "Tommaso", "Valeria", "Vera", "Vittorio"
]
const FEMALE_LOOK_IDS = [0, 2, 3, 8, 9, 12, 15]
const MALE_LOOK_IDS = [1, 10, 11, 13, 14]
const FEMALE_FIRST_NAMES = [
	"Marta", "Nina", "Ada", "Iris", "Luna", "Olivia", "Zoe", "Cleo", "Yuki", "Sofia", "Elena", "Bianca", "Viola",
	"Alma", "Anita", "Aurora", "Beatrice", "Camilla", "Caterina", "Chiara", "Clara", "Dalia", "Dina", "Elsa", "Emma", "Eva",
	"Fatima", "Flora", "Frida", "Gaia", "Giada", "Giorgia", "Greta", "Hana", "Ida", "Iman", "Isabel", "Lara", "Lidia", "Luisa",
	"Maya", "Mina", "Nadia", "Naomi", "Noemi", "Nora", "Paola", "Rania", "Rita", "Rosa", "Sara", "Silvia", "Stella", "Tania", "Valeria", "Vera"
]
const MALE_FIRST_NAMES = [
	"Bruno", "Leo", "Rocco", "Pietro", "Teo", "Enea", "Amir", "Dario", "Milo", "Omar", "Diego", "Andrea", "Arturo", "Boris",
	"Carlo", "Cesare", "Cosimo", "Daniele", "Edoardo", "Emilio", "Enrico", "Fabio", "Filippo", "Gabriele", "Giacomo", "Gioele", "Giulio",
	"Karim", "Luca", "Manuel", "Mirko", "Nico", "Oscar", "Paolo", "Remo", "Samir", "Saul", "Tito", "Tommaso", "Vittorio"
]
const LAST_NAMES = [
	"Rossi", "Ferri", "Costa", "Moretti", "Ricci", "Riva", "Gallo", "Marini", "Fontana", "Conti", "Greco", "Serra",
	"Alberti", "Amato", "Barbieri", "Bassi", "Bellucci", "Bernardi", "Bianchi", "Biondi", "Bruni", "Cappelli", "Caruso", "Cattani",
	"Colombo", "Corvi", "D'Angelo", "De Luca", "Fabbri", "Falco", "Farina", "Fiore", "Forte", "Gentile", "Giusti", "Grassi",
	"Leone", "Lombardi", "Longo", "Lupi", "Mancini", "Marchetti", "Martini", "Mazza", "Monti", "Neri", "Orlandi", "Pace",
	"Palma", "Pellegrini", "Piras", "Rinaldi", "Romano", "Rosati", "Sala", "Sanna", "Sarti", "Silvestri", "Testa", "Valenti",
	"Venturi", "Villa", "Vitale", "Zanetti"
]
const QUIRKS = [
	"Tiene sempre una tazza in tasca.", "Sa aggiustare quasi tutto. Quasi.",
	"Parla con le piante. Funziona.", "Non ha perso il senso dell'umorismo.",
	"Dice di fare un tiramisù leggendario.", "Ha salvato il suo gatto. Il gatto non ringrazia.",
	"Conosce tutte le scorciatoie.", "Colleziona cartoline del mondo di prima.",
	"Cuce tasche extra su qualsiasi vestito.", "Distingue le erbe buone a occhi chiusi.",
	"Non parte mai senza il suo quaderno.", "Sa fare il pane anche senza una ricetta.",
	"Porta dadi da gioco per le serate difficili.", "Ricorda il compleanno di tutti.",
	"Ha una bussola che punta quasi sempre a nord.", "Trasforma le scatole vuote in piccoli mobili.",
	"Racconta storie che finiscono sempre bene.", "Il suo zaino profuma di rosmarino.",
	"Fischietta quando cerca di concentrarsi.", "Ha insegnato a un corvo a riportare bottoni.",
	"Sa riparare una bicicletta con tre attrezzi.", "Custodisce una ricetta segreta per i biscotti.",
	"Ha una riserva di calzini per le emergenze.", "Sa leggere le nuvole e prevedere la pioggia.",
	"Dipinge fiori sulle cose rotte.", "Cerca un posto dove piantare il suo limone.",
	"Si orienta seguendo i vecchi binari.", "Conserva un seme per ogni nuovo inizio.",
	"Tiene una lista di cose per cui essere felici.", "Ha imparato a pescare con una graffetta.",
	"Chiama ogni attrezzo con un nome diverso.", "Dona l'ultimo biscotto, ma prima lo annusa.",
	"Fa nodi perfetti e battute discutibili.", "Ha attraversato mezza regione per salvare un violino.",
	"Porta sempre cerotti colorati.", "Crede che una buona zuppa risolva quasi tutto."
]
