extends RefCounted
## Personal expedition weapons: no shared copies or ammunition with the tower.
const MAX_AMMO = 9999
const WEAPONS = {
	"pistol":{"cost":0,"supplies":0,"pack":0,"ammo_cost":0,"ammo_supplies":0,"use":0,"step":0,"unit":"colpi",
		"role":"Economica e versatile. Sempre pronta, con colpi infiniti.","best":"mixed","factors":{"mixed":1.0,"close":1.0,"open":1.0,"crowded":1.0}},
	"shotgun":{"cost":310,"supplies":12,"pack":12,"ammo_cost":30,"ammo_supplies":3,"use":2,"step":1,"unit":"cartucce",
		"role":"Il migliore nei corridoi e negli edifici stretti. Meno efficace all'aperto.","best":"close","factors":{"mixed":1.65,"close":2.35,"open":1.25,"crowded":1.55}},
	"sniper":{"cost":625,"supplies":24,"pack":6,"ammo_cost":36,"ammo_supplies":4,"use":1,"step":1,"unit":"proiettili",
		"role":"Il migliore negli spazi aperti. Pochi colpi, ma costosi; soffre negli spazi stretti.","best":"open","factors":{"mixed":1.65,"close":1.25,"open":2.35,"crowded":1.35}},
	"smg":{"cost":490,"supplies":18,"pack":36,"ammo_cost":45,"ammo_supplies":5,"use":8,"step":3,"unit":"colpi",
		"role":"Il migliore nelle zone affollate. Versatile sui percorsi misti, consuma molti colpi.","best":"crowded","factors":{"mixed":1.75,"close":1.55,"open":1.45,"crowded":2.35}}
}
const TERRAINS = {"close":"Spazi stretti","open":"Spazi aperti","crowded":"Zona affollata","mixed":"Percorso misto"}
const ROUTES = {"minimarket":"close","station":"crowded","lab":"close","allotments":"open","pharmacy":"close","depot":"close","campground":"mixed","outpost":"crowded","observatory":"open"}

static func terrain(zone: Dictionary) -> String:
	return str(ROUTES.get(str(zone.get("id","")),"mixed"))

static func required_ammo(key: String, zone: Dictionary) -> int:
	if not WEAPONS.has(key): return 0
	var definition: Dictionary = WEAPONS[key]
	return int(definition.use)+floori(float(zone.get("threat",0))/35.0)*int(definition.step)

static func multiplier(key: String, zone: Dictionary) -> float:
	return float(WEAPONS.get(key,WEAPONS.pistol).factors.get(terrain(zone),1.0))

static func ammo_label(key: String, amount: int) -> String:
	var unit: String = str(WEAPONS.get(key,WEAPONS.pistol).unit)
	if amount==1: unit = "cartuccia" if key=="shotgun" else "proiettile" if key=="sniper" else "colpo"
	return "%d %s" % [amount,unit]
