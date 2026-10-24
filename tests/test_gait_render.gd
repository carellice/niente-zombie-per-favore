extends SceneTree
## GPU regression of the painted soles, including source alpha and occlusion.
## Run without --headless. Debug tint changes only boot colour, never geometry.

const Rig = preload("res://scripts/walking_rig.gd")
const HEIGHT: float = 256.0
const ORIGIN: Vector2 = Vector2(320.0, 340.0)
const OUTPUT: String = "res://.runtime/gait-render-test"
const LOOKS: Array[int] = [0, 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]

class SoleStage extends Control:
	var look: int = 0
	var phase: float = 0.0
	func _draw() -> void:
		Rig.draw_actor(self, look, phase, HEIGHT, ORIGIN, look >= 5 and look <= 7, false, 1.0, true)

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("RENDERED GAIT FAIL: " + description)

func _run() -> void:
	var output: String = ProjectSettings.globalize_path(OUTPUT)
	var directory_result: Error = DirAccess.make_dir_recursive_absolute(output)
	check(directory_result == OK, "can create isolated GPU capture directory")
	if directory_result != OK:
		quit(1)
		return
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(640, 384)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var stage: SoleStage = SoleStage.new()
	stage.size = Vector2(viewport.size)
	viewport.add_child(stage)
	await process_frame
	await process_frame
	for look: int in LOOKS:
		var samples: Array[Dictionary] = []
		for phase: float in [0.0, 0.5]:
			stage.look = look
			stage.phase = phase
			stage.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var picture: Image = viewport.get_texture().get_image()
			var path: String = output.path_join("look-%d-phase-%02d.png" % [look, roundi(phase * 100.0)])
			check(picture.save_png(path) == OK, "look %d phase %.1f: native capture saved" % [look, phase])
			var soles: Dictionary = _painted_sole_centres(picture)
			samples.append(soles)
			check(int(soles.left_count) >= 20, "look %d phase %.1f: left painted sole remains visible" % [look, phase])
			check(int(soles.right_count) >= 20, "look %d phase %.1f: right painted sole remains visible" % [look, phase])
		var first: Dictionary = samples[0]
		var second: Dictionary = samples[1]
		var pelvis_x: float = ORIGIN.x + Rig.render_offset(look, look >= 5 and look <= 7).x * HEIGHT
		var first_order: float = (float(first.left_x) - float(first.right_x)) / HEIGHT
		var second_order: float = (float(second.left_x) - float(second.right_x)) / HEIGHT
		check(first_order > 0.08 and second_order < -0.08,
			"look %d: actual painted left/right soles exchange forward order by a visible margin" % look)
		for side: String in ["left", "right"]:
			var a: float = (float(first[side + "_x"]) - pelvis_x) / HEIGHT
			var b: float = (float(second[side + "_x"]) - pelvis_x) / HEIGHT
			check(minf(a, b) < -0.025 and maxf(a, b) > 0.025,
				"look %d %s: actual painted sole passes both ahead of and behind the shared pelvis" % [look, side])
		print("Painted soles look %d: L-R order %.5fh -> %.5fh; visible pixels L %d/%d, R %d/%d" % [
			look, first_order, second_order, first.left_count, second.left_count, first.right_count, second.right_count])
	print("Rendered gait: %d checks, %d failures." % [checks, failures])
	quit(0 if failures == 0 else 1)

func _painted_sole_centres(picture: Image) -> Dictionary:
	var left_count: int = 0
	var right_count: int = 0
	var left_sum: float = 0.0
	var right_sum: float = 0.0
	# Only the boot area can contribute. Red/blue tint is multiplied by the
	# original painted texture, retaining its alpha, shading and occlusion.
	# At the two contact poses, both sole planes coincide with ORIGIN.y.
	for y: int in range(floori(ORIGIN.y - HEIGHT * 0.15), ceili(ORIGIN.y + 1.0)):
		for x: int in range(picture.get_width()):
			var pixel: Color = picture.get_pixel(x, y)
			if pixel.a < 0.3:
				continue
			if pixel.r > 0.02 and pixel.g < 0.005 and pixel.b < 0.005:
				left_count += 1
				left_sum += x
			elif pixel.b > 0.02 and pixel.r < 0.005 and pixel.g < 0.005:
				right_count += 1
				right_sum += x
	return {
		"left_count": left_count, "right_count": right_count,
		"left_x": left_sum / maxf(left_count, 1),
		"right_x": right_sum / maxf(right_count, 1)
	}
