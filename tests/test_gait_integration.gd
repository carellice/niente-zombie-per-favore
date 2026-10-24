extends SceneTree
## Exercise the scene's real actor tracking: world travel, stopping and pause.
## Simulation and settings use isolated paths; no player save is written.

const Motion = preload("res://scripts/gait_motion.gd")
const Actors = preload("res://scripts/actor_visuals.gd")
var game: Node
var preferences: Node
var scene: Control
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("GAIT INTEGRATION FAIL: ", description)

func near_phase(actual: float, expected: float) -> bool:
	return absf(wrapf(actual - expected, -0.5, 0.5)) < 0.00002

func phase(key: String) -> float:
	return float(scene.actor_gaits[key].phase)

func snapshot_phases() -> Dictionary:
	var result: Dictionary = {}
	for key: String in scene.actor_gaits:
		result[key] = phase(key)
	return result

func moved_expected(key: String, previous: Dictionary, distance: float, look: int, height: float, zombie: bool) -> void:
	var expected: float = fposmod(float(previous[key]) + distance / (Motion.stride_length(look, zombie) * height), 1.0)
	expect(near_phase(phase(key), expected), "%s follows actual world travel, independent of frame time" % key)

func run() -> void:
	game = root.get_node("Game")
	preferences = root.get_node("Preferences")
	game.save_path = "res://.runtime/gait-integration-save.json"
	preferences.settings_path = "res://.runtime/gait-integration-settings.cfg"
	game.set_process(false)
	game._new_game()
	game.skip_tutorial()
	game.build("residence")
	game.build("cafe")
	preferences.apply_settings({"sound_enabled": false}, false)
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.set_process(false)
	scene.ui._start_game()
	scene.visible = false

	var citizen: Dictionary = game._make_citizen()
	citizen.merge({"id": 500, "job": -1, "guard": false, "away": false, "look": 2}, true)
	var second: Dictionary = citizen.duplicate(true)
	second.id = 501
	var guard: Dictionary = citizen.duplicate(true)
	guard.merge({"id": 502, "guard": true}, true)
	var away: Dictionary = citizen.duplicate(true)
	away.merge({"id": 503, "away": true}, true)
	var citizens: Array[Dictionary] = [citizen, second, guard, away]
	game.citizens = citizens
	var visitors: Array[Dictionary] = [{"id": 701, "x": -100.0, "citizen": citizen.duplicate(true), "suspicious": false}]
	game.visitors = visitors
	game._add_threat("walker",-300.0)
	var threats: Array[Dictionary] = []
	for kind: String in ["walker", "runner", "brute", "infiltrator"]:
		var enemy: Dictionary = game.threats[0].duplicate(true)
		enemy.merge({"id": 800 + threats.size(), "kind": kind, "x": -300.0}, true)
		threats.append(enemy)
	game.threats = threats
	scene.actor_gaits.clear()
	scene.actor_clock = 0.0
	for id: int in [500,501]:
		var path: Dictionary = scene.citizen_roaming._ensure(id,scene._roaming_width())
		path.x = 100.0+(id-500)*100
		path.target = float(path.x)+100
		path.wait = 0.0
	scene._update_actor_gaits(0.01)
	expect(scene.actor_gaits.size() == 7, "Only two free citizens, one visitor and four threats receive gait state")
	expect(not scene.actor_gaits.has("citizen:502") and not scene.actor_gaits.has("citizen:503"), "Guard on tower and expedition citizen are excluded from walking")
	for key: String in scene.actor_gaits:
		expect(is_zero_approx(float(scene.actor_gaits[key].blend)), "%s starts without a false first-frame stride" % key)

	var previous: Dictionary = snapshot_phases()
	scene.actor_clock += 0.1
	scene.citizen_roaming.advance(game.citizens,scene._roaming_width(),game.CITIZEN_WALK_SPEED,0.1)
	game.visitors[0].x += 3.2
	game.threats[0].x += 1.8
	game.threats[1].x += 4.3
	game.threats[2].x += 1.1
	game.threats[3].x += 2.0
	scene._update_actor_gaits(0.1)
	moved_expected("citizen:500", previous, 3.0, 2, 70.0, false)
	moved_expected("citizen:501", previous, 3.0, 2, 70.0, false)
	moved_expected("visitor:701", previous, 3.2, 2, 78.0, false)
	moved_expected("enemy:800", previous, 1.8, 5, 80.0, true)
	moved_expected("enemy:801", previous, 4.3, 6, 80.0, true)
	moved_expected("enemy:802", previous, 1.1, 7, 108.0, true)
	moved_expected("enemy:803", previous, 2.0, 1, 80.0, false)

	# The same travel at another zoom and elapsed time must produce the same
	# phase increment. This catches screen-space and global-clock animation.
	previous = snapshot_phases()
	scene.zoom = 1.65
	scene.camera_x = -600.0
	scene.actor_clock += 0.1
	scene.citizen_roaming.advance(game.citizens,scene._roaming_width(),game.CITIZEN_WALK_SPEED,0.1)
	game.visitors[0].x += 3.2
	game.threats[0].x += 1.8
	scene._update_actor_gaits(0.047)
	moved_expected("citizen:500", previous, 3.0, 2, 70.0, false)
	moved_expected("visitor:701", previous, 3.2, 2, 78.0, false)
	moved_expected("enemy:800", previous, 1.8, 5, 80.0, true)
	expect(near_phase(phase("enemy:801"), previous["enemy:801"]), "A stationary runner does not inherit another actor's phase advance")
	expect(near_phase(phase("enemy:802"), previous["enemy:802"]), "A stationary brute has an independent gait")

	previous = snapshot_phases()
	scene._update_actor_gaits(0.2)
	for key: String in scene.actor_gaits:
		expect(near_phase(phase(key), previous[key]), "%s stops advancing its cycle when stationary" % key)
		expect(is_zero_approx(float(scene.actor_gaits[key].blend)), "%s settles onto two feet after stopping" % key)

	# A job can move a citizen only a short distance, below the large-jump
	# threshold. Changing placement must still start at rest, not snap a step.
	scene.actor_clock = 0.0
	var job_x: float = scene.LOT_STEP+65.0+500%3*58.0
	scene.citizen_roaming.states[500].x = job_x-10
	scene.citizen_roaming.states[500].target = job_x+100
	scene.citizen_roaming.states[500].wait = 0.0
	scene.actor_gaits.clear()
	scene._update_actor_gaits(0.01)
	scene.actor_clock += 0.1
	scene.citizen_roaming.advance(game.citizens,scene._roaming_width(),game.CITIZEN_WALK_SPEED,0.1)
	scene._update_actor_gaits(0.1)
	var old_position: float = scene._citizen_world_x(game.citizens[0])
	game.citizens[0].job = int(game.buildings[1].id)
	var relocated_distance: float = absf(scene._citizen_world_x(game.citizens[0]) - old_position)
	expect(relocated_distance > 1.0 and relocated_distance < 140.0, "Job fixture exercises a small semantic relocation")
	scene._update_actor_gaits(0.1)
	expect(is_zero_approx(float(scene.actor_gaits["citizen:500"].blend)), "Taking a nearby job does not animate the relocation as a stride")
	var new_job_phase: float = phase("citizen:500")
	scene._update_actor_gaits(0.1)
	expect(near_phase(phase("citizen:500"), new_job_phase), "New worker stays at rest after a job relocation")
	game.citizens[0].job = -1

	# Reaching the city boundary is a short final step followed by a stop.
	var boundary: float = scene._roaming_width()-30.0
	scene.citizen_roaming.states[500].x = boundary-0.5
	scene.citizen_roaming.states[500].target = boundary
	scene.citizen_roaming.states[500].wait = 0.0
	scene.actor_gaits.clear()
	scene._update_actor_gaits(0.01)
	previous = snapshot_phases()
	scene.actor_clock += 0.1
	scene.citizen_roaming.advance(game.citizens,scene._roaming_width(),game.CITIZEN_WALK_SPEED,0.1)
	scene._update_actor_gaits(0.1)
	moved_expected("citizen:500",previous,0.5,2,70.0,false)
	expect(is_equal_approx(scene._citizen_world_x(game.citizens[0]),scene._city_start()+boundary),"The resident stops at the boundary instead of wrapping across the city")
	game.visitors[0].x += 500.0
	var visitor_before: float = phase("visitor:701")
	scene._update_actor_gaits(0.1)
	expect(near_phase(phase("visitor:701"), visitor_before), "An explicitly relocated visitor does not stride across the teleport")

	var clock_before: float = scene.actor_clock
	var citizen_before: float = scene._citizen_world_x(game.citizens[0])
	previous = snapshot_phases()
	game.paused = true
	scene._process(0.5)
	expect(is_equal_approx(scene.actor_clock, clock_before), "Pause freezes the actual scene's movement clock")
	expect(is_equal_approx(scene._citizen_world_x(game.citizens[0]),citizen_before),"Pause freezes the roaming position as well as the gait")
	for key: String in scene.actor_gaits:
		expect(near_phase(phase(key), previous[key]), "%s preserves its foot pose while paused" % key)
	game.paused = false
	scene._process(0.01)
	expect(scene.actor_clock > clock_before, "Movement clock resumes with gameplay")

	game.visitors.clear()
	game.threats.clear()
	game.citizens[1].away = true
	scene._update_actor_gaits(0.1)
	expect(scene.actor_gaits.size() == 1 and scene.actor_gaits.has("citizen:500"), "Removed and newly unavailable actors release their gait state")
	var guard_texture: AtlasTexture = Actors.texture(502, 0, true)
	expect(guard_texture.region == Rect2(Actors.IDLE_BOUNDS[4]), "Stationary tower guard retains the original guard art")
	var portrait_texture: AtlasTexture = Actors.texture(2)
	expect(portrait_texture.region == Rect2(Actors.IDLE_BOUNDS[2]), "Civilian portrait retains the same unmodified original identity")

	scene.queue_free()
	await process_frame
	for path: String in [game.save_path, game.save_path + ".tmp", game.save_path + ".bak", preferences.settings_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	print("GAIT INTEGRATION: ", checks, " checks; ", failures, " failures")
	quit(0 if failures == 0 else 1)
