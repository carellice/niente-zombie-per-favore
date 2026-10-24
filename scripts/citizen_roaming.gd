extends RefCounted
## Local presentation paths: no wrapping, no gameplay RNG and no offline motion.
var states: Dictionary = {}

func reset() -> void:
	states.clear()

func _ensure(id: int, width: float) -> Dictionary:
	if not states.has(id):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = id*73856093+19349663
		var x: float = rng.randf_range(30.0,maxf(31.0,width-30.0))
		states[id] = {"x":x,"target":x,"wait":rng.randf_range(0.2,2.0),"left":false,"rng":rng}
	return states[id]

func position(id: int, width: float) -> float:
	return float(_ensure(id,width).x)

func facing_left(id: int) -> bool:
	return bool(states.get(id,{}).get("left",false))

func advance(citizens: Array, width: float, speed: float, delta: float) -> void:
	var present: Dictionary = {}
	var low: float = 30.0
	var high: float = maxf(low+1.0,width-30.0)
	for citizen: Dictionary in citizens:
		var id: int = int(citizen.id)
		present[id] = true
		if citizen.get("away",false) or int(citizen.get("job",-1))>=0: continue
		var state: Dictionary = _ensure(id,width)
		state.x = clampf(float(state.x),low,high)
		state.target = clampf(float(state.target),low,high)
		if float(state.wait)>0.0:
			state.wait = maxf(0.0,float(state.wait)-delta)
			if state.wait>0.0: continue
			var rng: RandomNumberGenerator = state.rng
			var target: float = rng.randf_range(low,high)
			var stride: float = minf(80.0,(high-low)*0.35)
			if absf(target-float(state.x))<stride:
				target = minf(high,float(state.x)+stride) if state.x<(low+high)*0.5 else maxf(low,float(state.x)-stride)
			state.target = target
			state.left = target<float(state.x)
		state.x = move_toward(float(state.x),float(state.target),speed*delta)
		if is_equal_approx(float(state.x),float(state.target)):
			state.wait = (state.rng as RandomNumberGenerator).randf_range(1.2,4.8)
	for id: Variant in states.keys():
		if not present.has(id): states.erase(id)
