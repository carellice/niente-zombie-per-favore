extends SceneTree
## Version comparison decides whether the in-game update card offers an install.

const Updater = preload("res://scripts/updater.gd")

func _initialize() -> void:
	var cases: Array = [
		["0.4.1.48","0.4.1.47",true], ["v0.4.1.48","0.4.1.47",true], ["0.4.1.47","0.4.1.47",false],
		["0.4.1.9","0.4.1.10",false], ["0.5","0.4.1.99",true], ["0.4.1","0.4.1.0",false]
	]
	var failures: int = 0
	for c: Array in cases:
		if Updater.is_newer(c[0],c[1]) != c[2]:
			failures += 1
			printerr("FAIL: is_newer(%s,%s)" % [c[0],c[1]])
	print("UPDATER CHECKS %d FAILURES %d" % [cases.size(),failures])
	quit(1 if failures else 0)
