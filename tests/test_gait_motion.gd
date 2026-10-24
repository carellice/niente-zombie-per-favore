extends SceneTree
## Physical gait checks: support, independent legs, planted soles and continuous joints.
## These deliberately test motion over time rather than counting different drawings.

const Gait = preload("res://scripts/gait_motion.gd")
const SAMPLES: int = 240
const JOINTS: Array[String] = [
	"hip_left", "hip_right", "knee_left", "knee_right",
	"ankle_left", "ankle_right", "foot_left", "foot_right"
]
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error("GAIT FAIL: " + description)

func _run() -> void:
	for look: int in range(4):
		_check_cycle(look, false)
		_check_idle(look, false)
	for look: int in range(8,16):
		_check_cycle(look, false)
		_check_idle(look, false)
	for look: int in range(5, 8):
		_check_cycle(look, true)
		_check_idle(look, true)
	print("Gait motion: %d checks, %d failures." % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _check_cycle(look: int, zombie: bool) -> void:
	var label: String = ("zombie " if zombie else "civilian ") + str(look)
	var poses: Array[Dictionary] = []
	# A small phase offset keeps exact support boundaries out of the sampled flags.
	for sample: int in range(SAMPLES):
		poses.append(Gait.pose(look, (sample + 0.137) / SAMPLES, zombie))
	var first: Dictionary = poses[0]
	var complete: bool = true
	for key: String in JOINTS + ["stance_left", "stance_right", "body_offset", "stride"]:
		complete = complete and first.has(key)
	check(complete, label + ": complete public pose")
	if not complete:
		return
	var stride: float = float(first.stride)
	check(stride > 0.1 and stride < 1.0, label + ": useful stride in actor-height units")
	var finite: bool = true
	var unsupported: int = 0
	var largest_jump: float = 0.0
	var largest_body_bob: float = 0.0
	var largest_ground_error: float = 0.0
	var largest_slip: float = 0.0
	var largest_length_error: float = 0.0
	var largest_reach_excess: float = -INF
	var settings: Dictionary = Gait.config(look, zombie)
	var available_reach: float = float(settings.upper) + float(settings.lower)
	var front_order_samples: int = 0
	var opposite_front_order: int = 0
	var smallest_raw_order: float = INF
	var largest_raw_order: float = -INF
	var largest_half_cycle_exchange_error: float = 0.0
	for sample: int in range(SAMPLES):
		var p: Dictionary = poses[sample]
		var next: Dictionary = poses[(sample + 1) % SAMPLES]
		var half: Dictionary = poses[(sample + SAMPLES / 2) % SAMPLES]
		if not bool(p.stance_left) and not bool(p.stance_right):
			unsupported += 1
		var body: Vector2 = p.body_offset
		finite = finite and body.is_finite() and is_finite(float(p.stride))
		largest_body_bob = maxf(largest_body_bob, absf(body.y))
		for joint: String in JOINTS:
			var point: Vector2 = p[joint]
			var next_point: Vector2 = next[joint]
			finite = finite and point.is_finite()
			largest_jump = maxf(largest_jump, point.distance_to(next_point))
		for side: String in ["left", "right"]:
			var foot: Vector2 = p["foot_" + side]
			var next_foot: Vector2 = next["foot_" + side]
			if bool(p["stance_" + side]):
				largest_ground_error = maxf(largest_ground_error, absf(foot.y))
				if bool(next["stance_" + side]):
					# The actor advances by stride / SAMPLES. A supporting sole
					# must move backwards by exactly that amount in actor space.
					var world_delta: Vector2 = next_foot - foot + Vector2(stride / SAMPLES, 0.0)
					largest_slip = maxf(largest_slip, world_delta.length())
			var reference: Vector2 = _segment_lengths(first, side)
			var lengths: Vector2 = _segment_lengths(p, side)
			var hip: Vector2 = p["hip_" + side]
			var ankle: Vector2 = p["ankle_" + side]
			largest_reach_excess = maxf(largest_reach_excess, hip.distance_to(ankle) - available_reach)
			largest_length_error = maxf(largest_length_error, absf(lengths.x - reference.x))
			largest_length_error = maxf(largest_length_error, absf(lengths.y - reference.y))
		# These are the ACTUAL projected feet. Subtracting separate per-leg
		# centres hides a permanently leading leg and can validate a limp.
		var order: float = _forward_order(p)
		smallest_raw_order = minf(smallest_raw_order, order)
		largest_raw_order = maxf(largest_raw_order, order)
		largest_half_cycle_exchange_error = maxf(largest_half_cycle_exchange_error,
			absf(order + _forward_order(half)))
		if absf(order) > 0.025:
			front_order_samples += 1
			if order * _forward_order(half) < 0.0:
				opposite_front_order += 1
	check(finite, label + ": finite joint coordinates throughout the cycle")
	check(unsupported == 0, label + ": at least one planted foot, without hopping")
	check(largest_ground_error < 0.001, label + ": supporting soles stay on the ground")
	check(largest_slip < 0.001, label + ": planted feet remain stationary in world space")
	check(largest_length_error < 0.00001, label + ": neither thigh nor shin changes length")
	check(largest_reach_excess <= 0.000001, label + ": every sole target is reachable without stretching either bone")
	check(largest_body_bob <= 0.005, label + ": torso does not jump with the steps")
	check(largest_jump < 0.035, label + ": no per-frame joint jumps, including loop wrap")
	check(front_order_samples > SAMPLES / 3 and opposite_front_order == front_order_samples,
		label + ": actual left and right feet exchange their forward order each half-cycle")
	check(smallest_raw_order < -0.045 and largest_raw_order > 0.045,
		label + ": each actual foot visibly passes in front of the other")
	check(largest_half_cycle_exchange_error < 0.001,
		label + ": half-cycle exchange is symmetric about a common pelvis projection")
	for side: String in ["left", "right"]:
		_check_leg(poses, side, label)
	_check_boundaries(look, zombie, label)
	print("Gait %s: actual L-R foot order [%.5fh, %.5fh]; exchange error %.5fh; world slip %.7fh; length error %.7fh; body bob %.7fh; max joint step %.5fh" % [
		label, smallest_raw_order, largest_raw_order, largest_half_cycle_exchange_error,
		largest_slip, largest_length_error, largest_body_bob, largest_jump])

func _check_leg(poses: Array[Dictionary], side: String, label: String) -> void:
	var transitions: int = 0
	var planted: int = 0
	var lift: float = 0.0
	var min_x: float = INF
	var max_x: float = -INF
	var penetrates_ground: bool = false
	var half_cycle_support_matches: bool = true
	var largest_half_cycle_position_error: float = 0.0
	var centre_crossings: int = 0
	var other: String = "right" if side == "left" else "left"
	for sample: int in range(SAMPLES):
		var p: Dictionary = poses[sample]
		var next: Dictionary = poses[(sample + 1) % SAMPLES]
		var half: Dictionary = poses[(sample + SAMPLES / 2) % SAMPLES]
		var stance: bool = bool(p["stance_" + side])
		if stance != bool(next["stance_" + side]):
			transitions += 1
		if stance:
			planted += 1
		half_cycle_support_matches = half_cycle_support_matches and stance == bool(half["stance_" + other])
		var foot: Vector2 = p["foot_" + side]
		var next_foot: Vector2 = next["foot_" + side]
		var pelvis_x: float = (Vector2(p.hip_left).x + Vector2(p.hip_right).x) * 0.5
		var other_half_foot: Vector2 = half["foot_" + other]
		largest_half_cycle_position_error = maxf(largest_half_cycle_position_error,
			foot.distance_to(other_half_foot))
		if (foot.x - pelvis_x) * (next_foot.x - pelvis_x) < 0.0:
			centre_crossings += 1
		lift = maxf(lift, -foot.y)
		min_x = minf(min_x, foot.x - pelvis_x)
		max_x = maxf(max_x, foot.x - pelvis_x)
		penetrates_ground = penetrates_ground or foot.y > 0.001
	var prefix: String = "%s %s leg: " % [label, side]
	check(transitions == 2, prefix + "one support and one swing per cycle")
	check(planted >= SAMPLES / 2 and planted < SAMPLES * 0.8, prefix + "both support and swing have meaningful duration")
	check(lift > 0.012, prefix + "the foot independently clears the ground")
	check(max_x - min_x > 0.08, prefix + "the foot independently moves forward and back")
	check(min_x < -0.025 and max_x > 0.025,
		prefix + "the actual foot travels both ahead of and behind the common pelvis")
	check(centre_crossings == 2, prefix + "the actual foot crosses the common pelvis twice per cycle")
	check(largest_half_cycle_position_error < 0.001,
		prefix + "the two actual feet share the same excursion and exchange positions")
	check(not penetrates_ground, prefix + "the sole never goes through the ground")
	check(half_cycle_support_matches, prefix + "support timing alternates with the other leg")

func _check_boundaries(look: int, zombie: bool, label: String) -> void:
	var support: float = float(Gait.config(look, zombie).stance)
	var worst: float = 0.0
	# Probe both touchdown and liftoff of each leg, not only the cycle seam.
	for boundary: float in [0.0, 0.5, support, fposmod(support - 0.5, 1.0)]:
		var before: Dictionary = Gait.pose(look, boundary - 0.00001, zombie)
		var after: Dictionary = Gait.pose(look, boundary + 0.00001, zombie)
		for joint: String in JOINTS:
			var a: Vector2 = before[joint]
			var b: Vector2 = after[joint]
			worst = maxf(worst, a.distance_to(b))
	check(worst < 0.0002, label + ": continuous touchdown, liftoff and cycle seam")

func _segment_lengths(p: Dictionary, side: String) -> Vector2:
	var hip: Vector2 = p["hip_" + side]
	var knee: Vector2 = p["knee_" + side]
	var ankle: Vector2 = p["ankle_" + side]
	return Vector2(hip.distance_to(knee), knee.distance_to(ankle))

func _check_idle(look: int, zombie: bool) -> void:
	var label: String = ("zombie " if zombie else "civilian ") + str(look)
	var reference: Dictionary = Gait.pose(look, 0.0, zombie, 0.0)
	var joint_drift: float = 0.0
	var grounded: bool = true
	for phase: float in [0.13, 0.28, 0.49, 0.63, 0.82, 0.99]:
		var pose: Dictionary = Gait.pose(look, phase, zombie, 0.0)
		for joint: String in JOINTS:
			var a: Vector2 = reference[joint]
			var b: Vector2 = pose[joint]
			joint_drift = maxf(joint_drift, a.distance_to(b))
		var left: Vector2 = pose.foot_left
		var right: Vector2 = pose.foot_right
		grounded = grounded and absf(left.y) < 0.001 and absf(right.y) < 0.001
		grounded = grounded and bool(pose.stance_left) and bool(pose.stance_right)
	check(joint_drift < 0.00001, label + ": stationary pose does not march in place")
	check(grounded, label + ": both idle soles are supported")

func _forward_order(p: Dictionary) -> float:
	# A side-view walk must show the left foot ahead, then the right foot ahead.
	# The rendered x coordinates matter, not excursions about unrelated tracks.
	var left: Vector2 = p.foot_left
	var right: Vector2 = p.foot_right
	return left.x - right.x
