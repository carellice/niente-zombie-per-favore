extends RefCounted
## Existing unrelated suites arrange operational buildings without advancing combat.
## Construction itself is exercised through build()/advance()/save/load in its suite.
static func build_ready(model: Node, kind: String) -> bool:
	if not model.build(kind): return false
	var site: Dictionary = model.buildings.back()
	model._tick_construction(float(site.construction_remaining),true)
	model._commit()
	return true
