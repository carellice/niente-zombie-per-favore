extends SceneTree
## Portrait and runtime rig use the same painted identity, including new art.
## Motion is checked separately in test_gait_motion.gd, never inferred from masks.

const Actors = preload("res://scripts/actor_visuals.gd")
const Rig = preload("res://scripts/walking_rig.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("ACTOR FAIL: " + description)

func _run() -> void:
	for look: int in range(16):
		var column: int = Actors.civilian_column(look)
		check(column == (look if look >= 8 else look % 4), "stable civilian identity " + str(look))
		check(Actors.texture(look) == Actors.texture(column), "portrait shares original identity " + str(look))
		check(Actors.texture(look,3) == Actors.texture(column,3), "work pose preserves identity " + str(look))
		var portrait: AtlasTexture = Actors.texture(look)
		check(portrait.region == Rect2(Actors.source_bounds(look)), "portrait points at rig source body " + str(look))
		check(portrait.atlas == Actors.source_atlas(look), "portrait and rig share the atlas " + str(look))
	check(Actors.texture(1,0,true) == Actors.texture(7,0,true), "guard remains explicit role")
	for column: int in [0,1,2,3,5,6,7,8,9,10,11,12,13,14,15]:
		var zombie: bool = column >= 5 and column <= 7
		var part: Dictionary = Rig.source_parts(column,zombie)
		var bounds: Rect2i = Actors.source_bounds(column,zombie)
		check(part.left != part.right, "each leg has its own painted source " + str(column))
		check(part.boot_left != part.boot_right, "each shoe has its own source " + str(column))
		check(float(part.cut) < float(part.sole), "torso excludes original static feet " + str(column))
		check(Rect2(Vector2.ZERO,Actors.source_atlas(column,zombie).get_size()).encloses(Rect2(bounds)), "body within source atlas " + str(column))
	check(Actors.CIVILIAN_LOOKS.size() == 12, "twelve distinct civilian identities are available")
	for look: int in range(8,16):
		check(Actors.texture(look).region != Actors.texture(look-1).region, "new survivor never aliases a neighbouring identity " + str(look))
		check(Actors.texture(look,3).region == Actors.texture(look).region, "working new survivor keeps the same face and clothes " + str(look))
	print("Actor identity: %d checks, %d failures." % [checks,failures])
	quit(0 if failures == 0 else 1)
