extends SceneTree
## Exercise outside civilians through combat, rejection and version-2 persistence.
## All transactions use a disposable save, never the player's profile.

var model: Node
var checks: int = 0
var failures: Array[String] = []
var attacks: Array = []
var losses: Array = []

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		printerr("FAIL: " + description)

func reset_fixture() -> void:
	model._new_game()
	model.visitors.clear()
	model.departing_visitors.clear()
	model.threats.clear()
	model._spawn_queue.clear()
	model._visitor_timer = 1000000.0
	model.wave_clock = 1000000.0
	model._save_timer = -1000000.0
	model._rng.seed = 4481
	attacks.clear()
	losses.clear()

func survivor(x: float, hp: float = 100.0) -> Dictionary:
	model._spawn_visitor()
	var visitor: Dictionary = model.visitors.back()
	visitor.x = x
	visitor.suspicious = false
	visitor.citizen.hp = hp
	visitor.citizen.max_hp = 100.0
	return visitor

func zombie(x: float, kind: String = "walker") -> Dictionary:
	model._add_threat(kind, x)
	return model.threats.back()

func alive_outside(visitor_id: int) -> bool:
	for visitor: Dictionary in model.visitors + model.departing_visitors:
		if int(visitor.id) == visitor_id:
			return true
	return false

func write_save(data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(model.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func _attacked(visitor_id: int, x: float, damage: float) -> void:
	attacks.append({"id":visitor_id, "x":x, "damage":damage})

func _lost(visitor_id: int, x: float, survivor_name: String) -> void:
	losses.append({"id":visitor_id, "x":x, "name":survivor_name})

func run() -> void:
	var singleton: Node = root.get_node_or_null("Game")
	if singleton:
		singleton.set_process(false)
	model = load("res://scripts/game_state.gd").new()
	model.save_path = "res://tests/.survivor-lifecycle-save.json"
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(model.save_path + suffix):
			DirAccess.remove_absolute(model.save_path + suffix)
	root.add_child(model)
	model.set_process(false)
	model.visitor_attacked.connect(_attacked)
	model.visitor_lost.connect(_lost)

	# An attacker visibly stops beside a waiting survivor instead of phasing through.
	reset_fixture()
	var waiting: Dictionary = survivor(100.0)
	var attacker: Dictionary = zombie(72.0)
	var gate_before: float = model.gate_hp
	var population_before: int = model.citizens.size()
	model._tick_threats(1.0)
	expect(float(waiting.citizen.hp) < 100.0, "Waiting survivor loses health to a nearby zombie")
	expect(float(waiting.citizen.hp) > 0.0, "One normal hit leaves time to react")
	expect(is_equal_approx(float(attacker.x), 72.0), "Zombie stops at attack distance")
	expect(int(attacker.target_visitor_id) == int(waiting.id), "Attacker identifies the actual outside survivor")
	expect(is_equal_approx(model.gate_hp, gate_before), "Attacking a survivor does not also damage the gate")
	expect(model.citizens.size() == population_before, "Damage outside does not remove a resident")
	expect(not attacks.is_empty() and int(attacks[0].id) == int(waiting.id), "Damage event identifies the survivor for presentation")
	expect(not attacks.is_empty() and float(attacks[0].damage) > 0.0, "Damage feedback carries positive damage")
	expect(losses.is_empty(), "Living survivor does not emit a death event")

	# Pursuit works from either side, including turning back from the city gate.
	reset_fixture()
	waiting = survivor(100.0)
	attacker = zombie(20.0)
	model._tick_threats(1.0)
	expect(float(attacker.x) > 20.0 and float(attacker.x) < 72.0, "Zombie approaches a survivor to its right")
	expect(not bool(attacker.facing_left), "Rightward pursuer faces the survivor")
	expect(is_equal_approx(float(waiting.citizen.hp), 100.0), "Pursuit deals no damage before physical contact")
	for _step: int in range(40):
		model._tick_threats(0.1)
	expect(float(waiting.citizen.hp) < 100.0, "Approaching zombie starts attacking after reaching the survivor")
	expect(absf(float(attacker.x) - float(waiting.x)) >= 27.99, "Pursuer keeps separation from the survivor")
	reset_fixture()
	waiting = survivor(195.0)
	attacker = zombie(float(model.GATE_X))
	gate_before = model.gate_hp
	model._tick_threats(1.0)
	expect(float(attacker.x) < float(model.GATE_X), "Zombie at the gate turns toward a nearby survivor behind it")
	expect(bool(attacker.facing_left), "Leftward pursuer faces the survivor")
	expect(is_equal_approx(model.gate_hp, gate_before), "Turning to a survivor interrupts gate damage")
	for _step: int in range(30):
		model._tick_threats(0.1)
	expect(float(waiting.citizen.hp) < 100.0, "Zombie can attack a survivor on its left")

	# A remote civilian does not magically intercept every zombie in the world.
	reset_fixture()
	waiting = survivor(-650.0)
	attacker = zombie(0.0)
	model._tick_threats(1.0)
	expect(float(attacker.x) > 0.0, "Zombie beyond awareness range continues toward the gate")
	expect(int(attacker.target_visitor_id) == -1, "Remote survivor is not an active attack target")
	expect(is_equal_approx(float(waiting.citizen.hp), 100.0), "Remote survivor takes no invisible damage")

	# Target acquisition uses distance rather than admission-array order.
	reset_fixture()
	var far_survivor: Dictionary = survivor(195.0)
	var near_survivor: Dictionary = survivor(50.0)
	attacker = zombie(20.0)
	model._tick_threats(1.0)
	expect(float(near_survivor.citizen.hp) < 100.0, "Nearest survivor is attacked even when appended last")
	expect(is_equal_approx(float(far_survivor.citizen.hp), 100.0), "Farther survivor is not damaged through the nearest one")
	expect(int(attacker.target_visitor_id) == int(near_survivor.id), "Target ID follows nearest geometry")

	# Only the remainder of a frame after movement can contribute attack damage.
	reset_fixture()
	waiting = survivor(100.0)
	attacker = zombie(40.0)
	var speed: float = float(attacker.speed)
	var damage: float = float(attacker.damage)
	var travel_time: float = (60.0 - 28.0) / speed
	model._tick_threats(travel_time + 0.4)
	expect(absf(float(waiting.citizen.hp) - (100.0 - damage * 0.4)) < 0.02, "Movement time is excluded from melee damage")
	expect(is_equal_approx(float(attacker.x), 72.0), "A long frame stops at the survivor instead of overshooting")

	# Death removes the waiting admission exactly once and keeps following targets usable.
	reset_fixture()
	waiting = survivor(100.0, 1.0)
	var dead_id: int = int(waiting.id)
	var dead_name: String = str(waiting.citizen.name)
	near_survivor = survivor(150.0)
	attacker = zombie(72.0)
	model._tick_threats(1.0)
	expect(not alive_outside(dead_id), "A killed waiting survivor is removed from all outside actor lists")
	expect(model.visitors.size() == 1 and int(model.visitors[0].id) == int(near_survivor.id), "Losing one survivor preserves the next admission")
	expect(losses.size() == 1 and int(losses[0].id) == dead_id, "Lethal damage emits one death event with stable identity")
	expect(losses.size() == 1 and str(losses[0].name) == dead_name, "Death feedback names the correct survivor")
	expect(not model.accept_visitor(dead_id), "A killed survivor cannot be admitted from a stale dialog")
	model.reject_visitor(dead_id)
	expect(model.departing_visitors.is_empty(), "Rejecting a stale dead ID cannot resurrect that survivor")
	for _step: int in range(45):
		model._tick_threats(0.1)
	expect(float(near_survivor.citizen.hp) < 100.0, "Attacker reacquires the remaining survivor after a death")
	expect(losses.size() == 1, "Subsequent ticks do not announce the same death again")

	# Two zombies resolving the same frame must not kill or announce a removed actor twice.
	reset_fixture()
	waiting = survivor(100.0, 1.0)
	dead_id = int(waiting.id)
	near_survivor = survivor(154.0)
	zombie(72.0)
	zombie(72.0)
	model._tick_threats(0.5)
	expect(losses.size() == 1 and int(losses[0].id) == dead_id, "Simultaneous attackers announce one survivor death once")
	expect(model.visitors.size() == 1 and int(model.visitors[0].id) == int(near_survivor.id), "Simultaneous attacks preserve the next queue member")
	expect(float(near_survivor.citizen.hp) >= 0.0 and float(near_survivor.citizen.hp) <= 100.0, "Retargeting within a frame keeps remaining health valid")
	var stale_target: bool = false
	model._tick_threats(0.1)
	for threat: Dictionary in model.threats:
		stale_target = stale_target or int(threat.target_visitor_id) == dead_id
	expect(not stale_target, "Every attacker clears a dead survivor target on its next tick")

	# Player shooting can save someone; guards never rescue civilians automatically.
	reset_fixture()
	waiting = survivor(100.0)
	attacker = zombie(72.0)
	var threat_id: int = int(attacker.id)
	var threat_hp: float = float(attacker.hp)
	model._tick_guards(20.0)
	expect(is_equal_approx(float(attacker.hp), threat_hp), "Guards do not shoot automatically to defend waiting survivors")
	model.shot_cooldown = 0.0
	expect(model.shoot(threat_id), "Player can shoot the zombie attacking a survivor")
	model.shot_cooldown = 0.0
	expect(model.shoot(threat_id), "Second player shot defeats the starter attacker")
	expect(model.threats.is_empty(), "Lethal player shots remove the melee attacker")
	var hp_after_rescue: float = float(waiting.citizen.hp)
	model._tick_threats(10.0)
	expect(is_equal_approx(float(waiting.citizen.hp), hp_after_rescue), "Rescued survivor no longer takes ghost damage")
	waiting.citizen.hp = 46.0
	var resident_id: int = int(waiting.citizen.id)
	expect(model.accept_visitor(int(waiting.id)), "An injured survivor can still be admitted")
	expect(is_equal_approx(float(model.get_citizen(resident_id).hp), 46.0), "Admission preserves the injury rather than replacing identity")
	expect(model.visitors.is_empty() and model.departing_visitors.is_empty(), "Admission leaves no duplicate outside actor")

	# Rejection transitions to a walking actor with the same identity and position.
	reset_fixture()
	waiting = survivor(195.0, 64.0)
	waiting.citizen.look = 12
	var rejected_id: int = int(waiting.id)
	var rejected_citizen_id: int = int(waiting.citizen.id)
	var rejected_name: String = str(waiting.citizen.name)
	model.reject_visitor(rejected_id)
	expect(model.visitors.is_empty(), "Rejected survivor immediately leaves the admission queue")
	expect(model.departing_visitors.size() == 1, "Rejected survivor remains visible as a departing actor")
	var departing: Dictionary = model.departing_visitors[0]
	expect(int(departing.id) == rejected_id and int(departing.citizen.id) == rejected_citizen_id, "Walking departure retains both stable IDs")
	expect(str(departing.citizen.name) == rejected_name and int(departing.citizen.look) == 12, "Departure preserves the selected name and artwork")
	expect(is_equal_approx(float(departing.x), 195.0), "Rejection does not teleport the survivor")
	expect(is_equal_approx(float(departing.citizen.hp), 64.0), "Rejection preserves existing injuries")
	expect(bool(departing.facing_left), "Rejected survivor faces the road out")
	expect(not model.accept_visitor(rejected_id), "Departing survivors are no longer admission targets")
	model.reject_visitor(rejected_id)
	expect(model.departing_visitors.size() == 1, "Duplicate rejection cannot duplicate a walking survivor")
	model._tick_visitors(0.5)
	expect(float(departing.x) < 195.0 and float(departing.x) > 150.0, "Rejected survivor walks left at a readable pace")
	expect(model.departing_visitors.size() == 1, "Walking departure is not removed on its first animation tick")
	for _step: int in range(100):
		model._tick_visitors(0.5)
	expect(model.departing_visitors.is_empty(), "Departing survivor is cleaned up after walking beyond the road")

	# Closing a gap in the admission line is also movement, never a positional jump.
	reset_fixture()
	waiting = survivor(195.0)
	near_survivor = survivor(141.0)
	far_survivor = survivor(87.0)
	model.reject_visitor(int(waiting.id))
	expect(is_equal_approx(float(near_survivor.x), 141.0) and is_equal_approx(float(far_survivor.x), 87.0), "Rejection leaves the other queue positions unchanged immediately")
	model._tick_visitors(0.1)
	expect(float(near_survivor.x) > 141.0 and float(near_survivor.x) < 145.0, "Next survivor walks smoothly into the free first slot")
	expect(float(far_survivor.x) > 87.0 and float(far_survivor.x) < 91.0, "Rear survivor walks smoothly into the free second slot")
	expect(float(waiting.x) < 195.0, "Rejected survivor continues moving out while the line closes")

	# A civilian cannot tunnel through an enemy to reach either the gate or the exit.
	reset_fixture()
	waiting = survivor(-100.0)
	attacker = zombie(0.0)
	model._tick_visitors(5.0)
	expect(float(waiting.x) <= float(attacker.x) - 28.0, "Arriving survivor stops before a zombie even during a long movement frame")
	reset_fixture()
	waiting = survivor(100.0)
	model.reject_visitor(int(waiting.id))
	attacker = zombie(0.0)
	model._tick_visitors(5.0)
	expect(float(waiting.x) >= float(attacker.x) + 28.0, "Departing survivor stops before a zombie instead of crossing through it")
	expect(model.departing_visitors.size() == 1, "Blocked departing survivor remains outside and vulnerable")

	# A rejected survivor remains a physical, vulnerable person outside the walls.
	reset_fixture()
	waiting = survivor(100.0, 1.0)
	rejected_id = int(waiting.id)
	model.reject_visitor(rejected_id)
	attacker = zombie(72.0)
	model._tick_threats(1.0)
	expect(model.departing_visitors.is_empty(), "A zombie can kill a rejected survivor while they leave")
	expect(losses.size() == 1 and int(losses[0].id) == rejected_id, "Departure death emits the correct survivor event")
	expect(model.visitors.is_empty(), "Departure death does not reinsert the survivor into the queue")

	# Pausing freezes both combat and departures, while residents stay protected.
	reset_fixture()
	waiting = survivor(100.0)
	far_survivor = survivor(195.0)
	model.reject_visitor(int(far_survivor.id))
	attacker = zombie(72.0)
	model.paused = true
	model._process(3.0)
	expect(is_equal_approx(float(waiting.citizen.hp), 100.0), "Paused simulation does not injure waiting civilians")
	expect(is_equal_approx(float(far_survivor.x), 195.0), "Paused simulation does not advance departures")
	expect(is_equal_approx(float(attacker.x), 72.0), "Paused simulation does not advance attackers")
	model.paused = false
	model._process(0.2)
	expect(float(waiting.citizen.hp) < 100.0, "Resuming simulation restores outside combat")
	expect(float(far_survivor.x) < 195.0, "Resuming simulation restores walking departures")
	var residents_safe: bool = true
	for citizen: Dictionary in model.citizens:
		residents_safe = residents_safe and is_equal_approx(float(citizen.hp), 100.0)
	expect(residents_safe, "Outside attacks leave residents inside the walls unharmed")

	# New optional fields round-trip without invalidating existing version-2 saves.
	reset_fixture()
	waiting = survivor(195.0, 46.0)
	waiting.citizen.look = 15
	departing = survivor(87.0, 63.0)
	departing.citizen.look = 8
	model.reject_visitor(int(departing.id))
	model._tick_visitors(0.5)
	var waiting_id: int = int(waiting.id)
	rejected_id = int(departing.id)
	var saved_departure_x: float = float(departing.x)
	var saved_departure_name: String = str(departing.citizen.name)
	model.save_game()
	var new_save: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(model.save_path))
	expect(int(new_save.version) == 2, "Outside lifecycle additions preserve the version-2 save format")
	expect(new_save.get("departing_visitors", []).size() == 1, "Save serializes walking departures")
	model.visitors.clear()
	model.departing_visitors.clear()
	expect(model.load_game(), "Save containing new appearances and departures reloads")
	expect(model.visitors.size() == 1 and int(model.visitors[0].id) == waiting_id, "Load restores the waiting admission ID")
	expect(is_equal_approx(float(model.visitors[0].citizen.hp), 46.0) and int(model.visitors[0].citizen.look) == 15, "Load restores waiting health and appearance")
	expect(model.departing_visitors.size() == 1 and int(model.departing_visitors[0].id) == rejected_id, "Load restores departure ID")
	departing = model.departing_visitors[0]
	expect(is_equal_approx(float(departing.x), saved_departure_x), "Load restores a departure without teleporting it")
	expect(str(departing.citizen.name) == saved_departure_name and int(departing.citizen.look) == 8, "Load preserves the departing person's identity")
	expect(is_equal_approx(float(departing.citizen.hp), 63.0) and bool(departing.facing_left), "Load preserves departure health and direction")
	model._tick_visitors(0.1)
	expect(float(departing.x) < saved_departure_x, "Loaded departure continues walking left")
	new_save.departing_visitors[0].id = 99100
	new_save.departing_visitors[0].citizen.id = 99101
	new_save.next_id = 100
	write_save(new_save)
	expect(model.load_game(), "Save can recover a stale next-ID counter")
	expect(int(model._id()) > 99101, "ID allocation accounts for both IDs of a saved departure")

	var legacy_save: Dictionary = new_save.duplicate(true)
	legacy_save.erase("departing_visitors")
	legacy_save.visitors[0].citizen.look = 4
	for field: String in ["hit_flash", "facing_left", "attack_clock"]:
		legacy_save.visitors[0].erase(field)
	write_save(legacy_save)
	expect(model.load_game(), "Version-2 save from before outside lifecycle changes remains valid")
	expect(model.departing_visitors.is_empty(), "Legacy save defaults to no departing survivors")
	expect(model.visitors.size() == 1 and int(model.visitors[0].citizen.look) == 4, "Legacy appearance IDs retain their original identity")
	model._tick_visitors(0.1)
	attacker = zombie(float(model.visitors[0].x) - 28.0)
	model._tick_threats(0.2)
	expect(float(model.visitors[0].citizen.hp) < 46.0, "Legacy waiting survivor participates in new combat after load")

	# Closing the app never lets the new civilian combat run invisibly offline.
	new_save.timestamp = Time.get_unix_time_from_system() - 1800.0
	new_save.highest_timestamp = new_save.timestamp
	write_save(new_save)
	expect(model.load_game(), "Offline save with walking departures reloads")
	expect(is_equal_approx(float(model.visitors[0].citizen.hp), 46.0), "Offline elapsed time does not injure waiting survivors")
	expect(is_equal_approx(float(model.departing_visitors[0].citizen.hp), 63.0), "Offline elapsed time does not injure departing survivors")
	expect(is_equal_approx(float(model.departing_visitors[0].x), saved_departure_x), "Offline elapsed time does not finish a walking departure")

	# Optional departure data is validated before loading mutates the active world.
	var invalid_save: Dictionary = new_save.duplicate(true)
	invalid_save.departing_visitors = "invalid"
	write_save(invalid_save)
	var preserved_waiting_id: int = int(model.visitors[0].id)
	expect(not model.load_game(), "Malformed optional departure list is rejected")
	expect(model.visitors.size() == 1 and int(model.visitors[0].id) == preserved_waiting_id, "Rejected save preserves the active waiting survivor")
	invalid_save = new_save.duplicate(true)
	invalid_save.departing_visitors[0].citizen.hp = "invalid"
	write_save(invalid_save)
	expect(not model.load_game(), "Malformed departing health is rejected")
	invalid_save = new_save.duplicate(true)
	invalid_save.departing_visitors[0].facing_left = "invalid"
	write_save(invalid_save)
	expect(not model.load_game(), "Malformed departing direction is rejected")

	reset_fixture()
	expect(model.departing_visitors.is_empty(), "Starting a new game removes all previous walking departures")
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(model.save_path + suffix):
			DirAccess.remove_absolute(model.save_path + suffix)
	print("Survivor lifecycle checks: %d; failures: %d" % [checks, failures.size()])
	model.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
