extends SceneTree
## Native renderer capture, 10 seconds / 24 fps. Run without --headless.
## Each lane shows game-size motion plus the same rig at 3x with a tracking camera.
## The floor markers scroll under the close-up, making planted feet easy to inspect.
## --normalized-gait renders two synchronized cycles, 2 seconds each.
## --debug-gait adds actual L/R sole targets, bones and the shared pelvis projection.

const Rig = preload("res://scripts/walking_rig.gd")
const Gait = preload("res://scripts/gait_motion.gd")
const Typography = preload("res://scripts/typography.gd")
const FPS: int = 24
const FRAME_COUNT: int = 240
const OUTPUT: String = "res://.runtime/gait-frames"

class MotionStage extends Control:
	var motion_time: float = 0.0
	var normalized_gait: bool = false
	var debug_gait: bool = false
	var duration: float = FRAME_COUNT / float(FPS)
	const ROWS: Array[Dictionary] = [
		{"look": 0, "name": "CONTADINA", "speed": 19.0, "height": 70.0, "zombie": false},
		{"look": 1, "name": "BARISTA", "speed": 32.0, "height": 78.0, "zombie": false},
		{"look": 2, "name": "MECCANICA", "speed": 19.0, "height": 70.0, "zombie": false},
		{"look": 3, "name": "DOTTORESSA", "speed": 32.0, "height": 78.0, "zombie": false},
		{"look": 5, "name": "WALKER", "speed": 18.0, "height": 80.0, "zombie": true},
		{"look": 6, "name": "RUNNER", "speed": 43.0, "height": 80.0, "zombie": true},
		{"look": 7, "name": "BRUTO", "speed": 11.0, "height": 108.0, "zombie": true}
	]
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("eee8d6"))
		draw_string(Typography.heading(), Vector2(28, 45), "DUE GAMBE, UN PASSO CONTINUO", HORIZONTAL_ALIGNMENT_LEFT, -1, 33, Color("243d3c"))
		var subtitle: String = "Dimensioni reali e velocità del gioco   ·   Dettaglio ×3 con camera che segue il corpo"
		if normalized_gait:
			subtitle = "Due cicli sincronizzati, 2 secondi ciascuno   ·   Dimensioni reali e dettaglio ×3"
		if debug_gait:
			subtitle += "   ·   S = arancio, D = blu"
		draw_string(Typography.body(), Vector2(28, 77), subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("506b64"))
		draw_string(Typography.body(), Vector2(1575, 48), "%.2f s" % motion_time, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("446b60"))
		for index: int in range(ROWS.size()):
			var data: Dictionary = ROWS[index]
			var column: int = 0 if index < 4 else 1
			var row: int = index if index < 4 else index - 4
			_draw_lane(data, Vector2(24.0 + column * 872.0, 96.0 + row * 404.0))
		var notes: Vector2 = Vector2(926, 1376)
		draw_string(Typography.heading(), notes, "COSA OSSERVARE", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("284b43"))
		var observation_lines: Array[String] = [
			"Il sinistro supera il destro, poi il destro il sinistro.",
			"Entrambi i piedi passano davanti e dietro al bacino.",
			"La giunzione fra bacino e gambe resta continua.",
			"Il piede appoggiato segue lo stesso segno a terra."
		]
		for index: int in range(observation_lines.size()):
			var line: String = observation_lines[index]
			draw_string(Typography.body(), notes + Vector2(0, 45 + index * 35), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("506b64"))
		var progress: float = fposmod(motion_time, duration) / duration
		draw_rect(Rect2(24, 1725, 1712, 4), Color("cdd3bd"))
		draw_rect(Rect2(24, 1725, 1712 * progress, 4), Color("80a487"))

	func _draw_lane(data: Dictionary, at: Vector2) -> void:
		var h: float = float(data.height)
		var speed: float = float(data.speed)
		var zombie: bool = bool(data.zombie)
		var look: int = int(data.look)
		var stride: float = Gait.stride_length(look, zombie) * h
		if normalized_gait:
			speed = stride / 2.0
		var phase: float = motion_time * speed / stride + (0.0 if normalized_gait else look * 0.137)
		var baseline: float = at.y + 374.0
		draw_rect(Rect2(at, Vector2(848, 390)), Color("e2ddcc"))
		draw_string(Typography.heading(), at + Vector2(18, 33), str(data.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("284b43"))
		draw_string(Typography.body(), at + Vector2(18, 61), "%d px/s · falcata %.1f px · %.2f cicli/s" % [roundi(speed), stride, speed / stride], HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("65776a"))
		draw_string(Typography.body(), at + Vector2(18, 284), "NEL GIOCO", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("6d8472"))
		draw_string(Typography.body(), at + Vector2(587, 31), "DETTAGLIO ×3", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("6d8472"))
		draw_line(Vector2(at.x + 18, baseline), Vector2(at.x + 824, baseline), Color("92a27d"), 2.0)
		# World markers are static around the actual-size moving actor.
		for marker: int in range(18):
			var marker_x: float = at.x + 24 + marker * 28
			if marker_x < at.x + 510:
				draw_line(Vector2(marker_x, baseline + 2), Vector2(marker_x, baseline + 10), Color("9da98d"), 2.0)
		# The enlarged actor stays in frame; its ground moves with the camera.
		for marker: int in range(-8, 9):
			var marker_x: float = at.x + 644 + marker * 42 - fposmod(motion_time * speed * 3.0, 42.0)
			if marker_x >= at.x + 520 and marker_x <= at.x + 824:
				draw_line(Vector2(marker_x, baseline + 2), Vector2(marker_x, baseline + 10), Color("9da98d"), 2.0)
		var actual_origin: Vector2 = Vector2(at.x + 64 + motion_time * speed, baseline)
		var close_origin: Vector2 = Vector2(at.x + 665, baseline)
		Rig.draw_actor(self, look, phase, h, actual_origin, zombie)
		Rig.draw_actor(self, look, phase, h * 3.0, close_origin, zombie)
		if debug_gait:
			var pose: Dictionary = Gait.pose(look, phase, zombie)
			var render_offset: Vector2 = Rig.render_offset(look, zombie)
			_draw_anatomy(pose, actual_origin + render_offset * h, h, false)
			_draw_anatomy(pose, close_origin + render_offset * h * 3.0, h * 3.0, true)

	func _draw_anatomy(pose: Dictionary, origin: Vector2, height: float, labels: bool) -> void:
		var pelvis: Vector2 = (Vector2(pose.hip_left) + Vector2(pose.hip_right)) * 0.5
		var pelvis_at: Vector2 = origin + pelvis * height
		draw_line(pelvis_at - Vector2(0, 9), Vector2(pelvis_at.x, origin.y + 9), Color(0.2, 0.28, 0.23, 0.5), 1.0)
		for side: String in ["left", "right"]:
			var colour: Color = Color("d87522") if side == "left" else Color("236abb")
			var hip: Vector2 = origin + Vector2(pose["hip_" + side]) * height
			var knee: Vector2 = origin + Vector2(pose["knee_" + side]) * height
			var ankle: Vector2 = origin + Vector2(pose["ankle_" + side]) * height
			var foot: Vector2 = origin + Vector2(pose["foot_" + side]) * height
			if labels:
				draw_line(hip, knee, Color(colour, 0.6), 1.5)
				draw_line(knee, ankle, Color(colour, 0.6), 1.5)
				draw_circle(hip, 3.0, colour)
				draw_string(Typography.heading(), foot + Vector2(-5, -9), "S" if side == "left" else "D", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, colour)
				draw_line(Vector2(pelvis_at.x, origin.y + 9), Vector2(foot.x, origin.y + 9), colour, 2.0)
				draw_line(Vector2(foot.x, origin.y + 5), Vector2(foot.x, origin.y + 13), colour, 2.0)
			draw_arc(foot, 4.0 if labels else 2.0, 0.0, TAU, 20, colour, 1.8, true)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var frame_count: int = FRAME_COUNT
	var start_time: float = 0.0
	var normalized_gait: bool = false
	var debug_gait: bool = false
	var custom_frames: bool = false
	var output: String = OUTPUT
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--frames="):
			frame_count = clampi(argument.get_slice("=", 1).to_int(), 1, FRAME_COUNT)
			custom_frames = true
		if argument.begins_with("--time="):
			start_time = argument.get_slice("=", 1).to_float()
		if argument == "--normalized-gait":
			normalized_gait = true
		if argument == "--debug-gait":
			debug_gait = true
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if normalized_gait and not custom_frames:
		frame_count = 4 * FPS
	var path: String = ProjectSettings.globalize_path(output)
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(path)
	if directory_error != OK:
		push_error("Could not create preview frame directory: " + str(directory_error))
		quit(directory_error)
		return
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1760, 1740)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var stage: MotionStage = MotionStage.new()
	stage.size = Vector2(viewport.size)
	stage.normalized_gait = normalized_gait
	stage.debug_gait = debug_gait
	stage.duration = frame_count / float(FPS)
	viewport.add_child(stage)
	await process_frame
	await process_frame
	for frame: int in range(frame_count):
		stage.motion_time = start_time + frame / float(FPS)
		stage.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var screenshot: Image = viewport.get_texture().get_image()
		var result: Error = screenshot.save_png(path.path_join("frame-%04d.png" % frame))
		if result != OK:
			push_error("Preview capture failed: " + str(result))
			quit(result)
			return
		if frame % FPS == 0:
			print("Gait preview: %d / %d frames" % [frame, frame_count])
	print("Gait preview frames ready: ", path)
	quit(0)
