extends SceneTree
## Many simultaneously active survivors must have distinct identities and use all art.

const APPEARANCES: Array[int] = [0,1,2,3,8,9,10,11,12,13,14,15]
const Catalog = preload("res://scripts/survivor_catalog.gd")
var model: Node
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		printerr("FAIL: " + description)

func run() -> void:
	var singleton: Node = root.get_node_or_null("Game")
	if singleton:
		singleton.set_process(false)
	var simulation: Script = load("res://scripts/game_state.gd")
	model = simulation.new()
	model.save_path = "res://tests/.survivor-variety-save.json"
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(model.save_path + suffix):
			DirAccess.remove_absolute(model.save_path + suffix)
	root.add_child(model)
	model.set_process(false)
	model._new_game()
	model._rng.seed = 96187
	model.citizens.clear()
	model.visitors.clear()
	model.departing_visitors.clear()
	model.threats.clear()
	var constants: Dictionary = simulation.get_script_constant_map()
	expect(constants.get("FIRST_NAMES", []).size() >= 72, "First-name pool contains substantially more than the former 24 names")
	expect(constants.get("LAST_NAMES", []).size() >= 48, "Surname pool contains substantially more than the former 12 surnames")
	expect(constants.get("QUIRKS", []).size() >= 20, "Survivor descriptions offer varied personal details")
	var grouped_names: Array = Catalog.FEMALE_FIRST_NAMES + Catalog.MALE_FIRST_NAMES
	var complete_groups: bool = grouped_names.size() == Catalog.FIRST_NAMES.size()
	for first_name in Catalog.FIRST_NAMES:
		complete_groups = complete_groups and grouped_names.count(first_name) == 1
	expect(complete_groups, "Appearance name groups preserve every original first name exactly once")
	var seen_names: Dictionary = {}
	var first_names: Dictionary = {}
	var surnames: Dictionary = {}
	var appearance_counts: Dictionary = {}
	var unique_ids: Dictionary = {}
	var duplicate_name: bool = false
	var duplicate_id: bool = false
	var invalid_look: bool = false
	var incomplete_identity: bool = false
	var mismatched_given_name: bool = false
	# Distribute generated people across all three active populations so duplicate
	# avoidance cannot accidentally consider only the city or only the queue.
	for index: int in range(600):
		var citizen: Dictionary = model._make_citizen()
		var full_name: String = str(citizen.name)
		duplicate_name = duplicate_name or seen_names.has(full_name)
		duplicate_id = duplicate_id or unique_ids.has(int(citizen.id))
		invalid_look = invalid_look or not APPEARANCES.has(int(citizen.look))
		incomplete_identity = incomplete_identity or full_name.strip_edges().is_empty() or str(citizen.get("quirk", "")).is_empty()
		seen_names[full_name] = true
		unique_ids[int(citizen.id)] = true
		var split_name: PackedStringArray = full_name.split(" ", false)
		if split_name.size() >= 2:
			first_names[split_name[0]] = true
			surnames[split_name[split_name.size()-1]] = true
			var expected_names: Array = Catalog.MALE_FIRST_NAMES if Catalog.MALE_LOOK_IDS.has(int(citizen.look)) else Catalog.FEMALE_FIRST_NAMES
			mismatched_given_name = mismatched_given_name or not expected_names.has(split_name[0])
		appearance_counts[int(citizen.look)] = int(appearance_counts.get(int(citizen.look), 0)) + 1
		match index % 3:
			0:
				model.citizens.append(citizen)
			1:
				model.visitors.append({"id":model._id(),"citizen":citizen,"x":-650.0,"suspicious":false,"hint":"In attesa."})
			2:
				model.departing_visitors.append({"id":model._id(),"citizen":citizen,"x":-400.0,"suspicious":false,"hint":"In cammino.","facing_left":true})
	expect(not duplicate_name and seen_names.size() == 600, "600 active survivors across city, queue and departures have distinct full names")
	expect(not duplicate_id and unique_ids.size() == 600, "Generated survivor IDs remain unique")
	expect(not incomplete_identity, "Every generated survivor has a full name and personal detail")
	expect(not mismatched_given_name, "All 600 newly generated given names match their character appearance group")
	expect(not invalid_look, "New survivors use supported art instead of legacy duplicate appearance IDs")
	expect(first_names.size() >= 65, "Long session actually samples the larger first-name pool")
	expect(surnames.size() >= 45, "Long session actually samples the larger surname pool")
	expect(appearance_counts.size() == APPEARANCES.size(), "Long session uses all twelve different survivor appearances")
	var minimum: int = 600
	var maximum: int = 0
	for appearance: int in APPEARANCES:
		var count: int = int(appearance_counts.get(appearance, 0))
		expect(count >= 30, "Appearance %d receives a meaningful share of arrivals" % appearance)
		minimum = mini(minimum, count)
		maximum = maxi(maximum, count)
	expect(maximum - minimum <= 2, "Appearance allocation avoids repeatedly cloning one look while alternatives are absent")
	# Fresh games are intentionally empty; loaded identities retain their art while
	# incompatible given names migrate to the canonical gender group.
	model._new_game()
	expect(model.citizens.is_empty() and model.buildings.is_empty(), "Fresh refuge has no preset people or buildings")
	expect(model.visitors.is_empty() and model.threats.is_empty() and model.tutorial_stage == "intro", "Explicit introduction controls the first arrivals")
	var coherent_person: Dictionary = model._make_citizen()
	coherent_person.name = "Elena Costa"
	coherent_person.look = 0
	model.citizens.append(coherent_person)
	var mismatched_person: Dictionary = model._make_citizen()
	mismatched_person.name = "Marta De Luca"
	mismatched_person.look = 5 # Legacy alias of the male barista, look 1.
	model.citizens.append(mismatched_person)
	model.skip_tutorial()
	model.save_game()
	model.citizens[0].name = "Temporary"
	expect(model.load_game(), "An existing named survivor can be reloaded after grouped names are introduced")
	expect(str(model.citizens[0].name) == "Elena Costa" and int(model.citizens[0].look) == 0, "Loading preserves coherent old names and appearances")
	var migrated_first: String = str(model.citizens[1].name).split(" ")[0]
	expect(Catalog.MALE_FIRST_NAMES.has(migrated_first) and str(model.citizens[1].name).ends_with(" De Luca") and int(model.citizens[1].look) == 5, "Loading fixes incompatible legacy given names while preserving surname and appearance")
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(model.save_path + suffix):
			DirAccess.remove_absolute(model.save_path + suffix)
	print("Survivor variety checks: %d; failures: %d; unique names: %d; visual variants: %d" % [checks, failures.size(), seen_names.size(), appearance_counts.size()])
	model.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
