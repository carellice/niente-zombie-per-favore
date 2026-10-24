extends RefCounted
## Continuous two-leg gait, in actor-height units. The root travels one stride
## per cycle, so a supporting foot exactly cancels that forward displacement.

const NewSurvivors = preload("res://scripts/survivor_appearances.gd")

static func config(look: int, zombie: bool = false) -> Dictionary:
	if not zombie and look >= 8 and look <= 15:
		var hip: float = NewSurvivors.HIP_HEIGHTS[look-8]
		var limb: float = sqrt(pow(hip-0.07,2.0)+pow(0.115,2.0))*0.52
		return {"stride":0.34,"stance":0.60,"hip_y":-hip,"upper":limb,"lower":limb,"boot_height":0.07,"lift":0.045}
	if zombie and look == 6:
		return {"stride": 0.46, "stance": 0.58, "hip_y": -0.31, "upper": 0.142, "lower": 0.142, "boot_height": 0.07, "lift": 0.065}
	if zombie and look == 7:
		return {"stride": 0.30, "stance": 0.62, "hip_y": -0.16, "upper": 0.075, "lower": 0.075, "boot_height": 0.06, "lift": 0.028}
	if zombie:
		return {"stride": 0.36, "stance": 0.62, "hip_y": -0.30, "upper": 0.127, "lower": 0.127, "boot_height": 0.08, "lift": 0.04}
	return {"stride": 0.34, "stance": 0.60, "hip_y": -0.28, "upper": 0.121, "lower": 0.121, "boot_height": 0.07, "lift": 0.045}

static func stride_length(look: int, zombie: bool = false) -> float:
	return float(config(look, zombie).stride)

static func pose(look: int, phase: float, zombie: bool = false, blend: float = 1.0) -> Dictionary:
	var settings: Dictionary = config(look, zombie)
	var amount: float = clampf(blend, 0.0, 1.0)
	# This is a side view: depth separates the two legs, not a permanent
	# fore/aft offset. Both shoes must cross the same pelvis line each cycle.
	var hip_spread: float = 0.012
	var result: Dictionary = {"body_offset": Vector2.ZERO, "stride": settings.stride}
	for side: String in ["left", "right"]:
		var offset: float = 0.0 if side == "left" else 0.5
		var p: float = fposmod(phase + offset, 1.0)
		var stance: float = float(settings.stance)
		var stride: float = float(settings.stride)
		var front: float = stride * stance * 0.5
		var foot: Vector2
		if p < stance:
			foot = Vector2(front - stride * p, 0.0)
		else:
			var t: float = (p - stance) / (1.0 - stance)
			# Hermite tangents match the backward velocity of the supporting
			# foot at liftoff and touchdown, avoiding a jerk at either boundary.
			var tangent: float = -stride * (1.0 - stance)
			var t2: float = t * t
			var t3: float = t2 * t
			var x: float = (2.0*t3-3.0*t2+1.0)*(-front) + (t3-2.0*t2+t)*tangent + (-2.0*t3+3.0*t2)*front + (t3-t2)*tangent
			foot = Vector2(x, -float(settings.lift) * pow(sin(PI * t), 2.0))
		var hip_x: float = -hip_spread if side == "left" else hip_spread
		var neutral: Vector2 = Vector2(-0.035 if side == "left" else 0.035, 0.0)
		foot = neutral.lerp(foot, amount)
		var hip: Vector2 = Vector2(hip_x, float(settings.hip_y))
		var ankle: Vector2 = foot + Vector2(0.0, -float(settings.boot_height))
		var knee: Vector2 = _knee(hip, ankle, float(settings.upper), float(settings.lower))
		result["hip_" + side] = hip
		result["knee_" + side] = knee
		result["ankle_" + side] = ankle
		result["foot_" + side] = foot
		result["stance_" + side] = p < stance or amount < 0.0001
	return result

static func _knee(hip: Vector2, ankle: Vector2, upper: float, lower: float) -> Vector2:
	var delta: Vector2 = ankle - hip
	var distance: float = delta.length()
	var direction: Vector2 = delta / maxf(distance, 0.000001)
	var along: float = (upper*upper - lower*lower + distance*distance) / (2.0 * maxf(distance, 0.000001))
	var bend: float = sqrt(maxf(0.0, upper*upper - along*along))
	return hip + direction * along + Vector2(direction.y, -direction.x) * bend
