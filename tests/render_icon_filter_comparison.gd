extends SceneTree
## Native GPU evidence of icon minification. Run without --headless and with an
## isolated APPDATA directory; this script never writes the player's save.
## The baseline reproduces the old linear sampler on the painted atlas; the new
## side instantiates the actual HUD Glyph and its isolated mipmapped icon.

const Type = preload("res://scripts/typography.gd")
const BACKGROUND = Color("f2e7ce")
const INK = Color("493d2d")
const SIZES: Array[int] = [18, 24, 30, 34, 44, 58]
const KINDS: Array[String] = ["coin", "crate", "bill", "home", "people", "build", "compass", "gun", "shield", "sun", "pause", "sound", "help", "cross", "heart", "coffee"]
const OUTPUT = "res://.runtime/icon-filter-comparison"
const PANEL_SIZE = Vector2i(1180, 1050)
const SAMPLE_SIDE = 80
const REFERENCE_SCALE = 8

var checks: int = 0
var failures: int = 0
var ui_script: GDScript

class BaselineGlyph extends Control:
	var kind: String = "coin"
	var atlas: Texture2D = load("res://assets/art/ui_icons.png")
	const KEYS = {"coin":0,"crate":1,"bill":2,"home":3,"people":4,"build":5,"compass":6,"gun":7,"shield":8,"sun":9,"pause":10,"sound":11,"help":12,"cross":13,"heart":14,"coffee":15}
	const REGIONS: Array[Rect2] = [
		Rect2(25,92,300,260),Rect2(338,90,298,259),Rect2(639,126,304,218),Rect2(943,80,282,278),
		Rect2(24,391,319,260),Rect2(340,387,304,265),Rect2(650,346,247,310),Rect2(916,367,313,291),
		Rect2(47,659,262,275),Rect2(345,655,284,283),Rect2(672,685,225,238),Rect2(945,684,279,239),
		Rect2(71,942,218,267),Rect2(363,951,249,240),Rect2(651,960,284,230),Rect2(986,940,236,260)
	]
	func _draw() -> void:
		var region: Rect2 = REGIONS[int(KEYS.get(kind, 12))]
		var factor = minf(size.x / region.size.x, size.y / region.size.y)
		draw_texture_rect_region(atlas, Rect2((size - region.size * factor) / 2.0, region.size * factor), region)

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("ICON MINIFICATION FAIL: " + description)

func _viewport(dimensions: Vector2i) -> SubViewport:
	var viewport = SubViewport.new()
	viewport.size = dimensions
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)
	var background = ColorRect.new()
	background.size = Vector2(dimensions)
	background.color = BACKGROUND
	viewport.add_child(background)
	return viewport

func _label(parent: Node, text: String, position: Vector2, font_size: int = 17, color: Color = INK) -> Label:
	var label = Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_override("font", Type.body())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _glyph(parent: Node, kind: String, dimensions: float, position: Vector2, filter: CanvasItem.TextureFilter) -> Control:
	var glyph = BaselineGlyph.new() if filter == CanvasItem.TEXTURE_FILTER_LINEAR else ui_script.Glyph.new()
	glyph.kind = kind
	glyph.texture_filter = filter
	glyph.size = Vector2.ONE * dimensions
	glyph.position = position
	parent.add_child(glyph)
	return glyph

func _capture(viewport: SubViewport) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Run render_icon_filter_comparison.gd with the native GPU renderer.")
		quit(1)
		return
	ui_script = load("res://scripts/game_ui.gd")
	var directory = ProjectSettings.globalize_path(OUTPUT)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-folder="):
			directory = argument.trim_prefix("--evidence-folder=")
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "isolated output folder is writable")
	var icons = load("res://scripts/hud_icons.gd")
	var seen: Dictionary = {}
	for index: int in range(KINDS.size()):
		var kind = KINDS[index]
		var texture: Texture2D = icons.texture(kind)
		check(texture.get_image().has_mipmaps(), "%s: isolated texture includes its mip chain" % kind)
		check(texture.get_size() == BaselineGlyph.REGIONS[index].size, "%s: isolated texture uses exactly the original symbol bounds" % kind)
		check(not seen.has(texture.get_instance_id()), "%s: texture is separate from the other symbols" % kind)
		seen[texture.get_instance_id()] = true
		check(texture == icons.texture(kind), "%s: repeated draws reuse the cached texture" % kind)
	for pair: Array in [["person", "people"], ["check", "shield"], ["mute", "sound"]]:
		check(icons.texture(pair[0]) == icons.texture(pair[1]), "%s/%s: aliases share a cached texture" % pair)
	var app_icon: Texture2D = load("res://assets/icon.png")
	check(app_icon.get_image().has_mipmaps(), "the standalone app icon includes imported mipmaps")
	var face: Texture2D = icons.cropped_texture("res://assets/art/characters.png", Rect2i(1002, 58, 87, 93))
	check(face.get_size() == Vector2(87, 93), "zombie alert uses only the isolated face bounds")
	check(face.get_image().has_mipmaps(), "zombie alert face includes its own mip chain")
	check(face == icons.cropped_texture("res://assets/art/characters.png", Rect2i(1002, 58, 87, 93)), "zombie alert face reuses its cached texture")
	var actual_glyph = ui_script.Glyph.new()
	check(actual_glyph.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "a real HUD Glyph defaults to the minification sampler")
	actual_glyph.free()

	var sheet = _viewport(PANEL_SIZE)
	_label(sheet, "Icone HUD · campioni a dimensione nativa", Vector2(22, 12), 28)
	_label(sheet, "Ogni coppia confronta il filtro precedente (prima riga) con il filtro nuovo (seconda riga).", Vector2(22, 48), 17)
	for column: int in range(KINDS.size()):
		_label(sheet, KINDS[column], Vector2(143 + column * 64, 82), 11)
	for index: int in range(SIZES.size()):
		var dimensions = SIZES[index]
		var row_y: float = 112 + index * 149
		_label(sheet, "%d px · prima" % dimensions, Vector2(20, row_y + 21), 15)
		_label(sheet, "%d px · ora" % dimensions, Vector2(20, row_y + 88), 15, Color("526d42"))
		for column: int in range(KINDS.size()):
			var x: float = 140 + column * 64 + (64 - dimensions) * 0.5
			_glyph(sheet, KINDS[column], dimensions, Vector2(x, row_y + (64 - dimensions) * 0.5), CanvasItem.TEXTURE_FILTER_LINEAR)
			_glyph(sheet, KINDS[column], dimensions, Vector2(x, row_y + 67 + (64 - dimensions) * 0.5), CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)
	var native_picture = await _capture(sheet)
	check(native_picture.save_png(directory.path_join("icone-confronto-native.png")) == OK, "all 16 icons captured at 18–58 native pixels")

	# Enlarge the actual native render using nearest sampling. This exposes its
	# pixels without adding another smoothing pass or modifying source artwork.
	var detail = _viewport(Vector2i(1040, 580))
	_label(detail, "Monete e provviste · ingrandimento 5× dei pixel del render", Vector2(22, 12), 24)
	var native_detail = _viewport(Vector2i(200, 100))
	_label(native_detail, "prima", Vector2(2, 1), 10)
	_label(native_detail, "ora", Vector2(2, 51), 10)
	for column: int in range(4):
		var kind = "coin" if column < 2 else "crate"
		var dimensions: int = 18 if column % 2 == 0 else 30
		_glyph(native_detail, kind, dimensions, Vector2(31 + column * 42, 18), CanvasItem.TEXTURE_FILTER_LINEAR)
		_glyph(native_detail, kind, dimensions, Vector2(31 + column * 42, 68), CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)
	await _capture(native_detail)
	var enlarged = TextureRect.new()
	enlarged.texture = native_detail.get_texture()
	enlarged.position = Vector2(20, 63)
	enlarged.size = Vector2(1000, 500)
	enlarged.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	detail.add_child(enlarged)
	var enlarged_picture = await _capture(detail)
	check(enlarged_picture.save_png(directory.path_join("monete-confronto-pixel.png")) == OK, "native coin/crate pixels captured at 5× for inspection")

	# Compare the two native samplers against an 8× supersampled, area-averaged
	# reference. Fractional placements exercise the small subpixel changes caused
	# by viewport stretch, rather than a single favourable alignment.
	var sample = _viewport(Vector2i(SAMPLE_SIDE * 2, SAMPLE_SIDE))
	var reference = _viewport(Vector2i(SAMPLE_SIDE * REFERENCE_SCALE, SAMPLE_SIDE * REFERENCE_SCALE))
	var old_icon = _glyph(sample, "coin", 24, Vector2(11, 11), CanvasItem.TEXTURE_FILTER_LINEAR)
	var new_icon = _glyph(sample, "coin", 24, Vector2(SAMPLE_SIDE + 11, 11), CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)
	var reference_icon = _glyph(reference, "coin", 24 * REFERENCE_SCALE, Vector2(11, 11) * REFERENCE_SCALE, CanvasItem.TEXTURE_FILTER_LINEAR)
	var previous_error: float = 0.0
	var filtered_error: float = 0.0
	var count: int = 0
	for kind: String in ["coin", "crate"]:
		old_icon.kind = kind
		new_icon.kind = kind
		reference_icon.kind = kind
		for dimensions: int in SIZES:
			for offset: float in [0.0, 0.25, 0.5]:
				old_icon.size = Vector2.ONE * dimensions
				new_icon.size = Vector2.ONE * dimensions
				reference_icon.size = Vector2.ONE * dimensions * REFERENCE_SCALE
				old_icon.position = Vector2(11 + offset, 11 + offset)
				new_icon.position = Vector2(SAMPLE_SIDE + 11 + offset, 11 + offset)
				reference_icon.position = old_icon.position * REFERENCE_SCALE
				old_icon.queue_redraw()
				new_icon.queue_redraw()
				reference_icon.queue_redraw()
				var sample_picture = await _capture(sample)
				var reference_picture = reference.get_texture().get_image()
				var errors: Vector2 = _reference_errors(sample_picture, reference_picture)
				previous_error += errors.x
				filtered_error += errors.y
				count += 1
				print("Icon reference %s %d px offset %.2f: linear %.6f, mipmaps %.6f" % [kind, dimensions, offset, errors.x, errors.y])
	var reduction = 1.0 - filtered_error / maxf(previous_error, 0.000001)
	check(reduction > 0.25, "painted resource icons reduce error against the 8× reference by at least 25%% (actual %.1f%%)" % (100 * reduction))
	var file = FileAccess.open(directory.path_join("metrics.txt"), FileAccess.WRITE)
	check(file != null, "GPU error report can be saved")
	var report = "Icon minification GPU QA\n%d checks, %d failures\n%d subpixel cases\nBaseline mean RGB pixel distance: %.8f\nFiltered mean RGB pixel distance: %.8f\nReduction: %.2f%%\n" % [checks, failures, count, previous_error / count, filtered_error / count, reduction * 100]
	if file:
		file.store_string(report)
	print(report)
	for viewport: SubViewport in [sheet, detail, native_detail, sample, reference]:
		viewport.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _reference_errors(sample: Image, reference: Image) -> Vector2:
	var errors = Vector2.ZERO
	var count: int = 0
	# Box integration is deliberate: it measures area coverage, the missing
	# information when the old sampler chooses just four high-resolution texels.
	for y: int in range(SAMPLE_SIDE):
		for x: int in range(SAMPLE_SIDE):
			var expected = Vector3.ZERO
			for dy: int in range(REFERENCE_SCALE):
				for dx: int in range(REFERENCE_SCALE):
					var pixel = reference.get_pixel(x * REFERENCE_SCALE + dx, y * REFERENCE_SCALE + dy)
					expected += Vector3(pixel.r, pixel.g, pixel.b)
			expected /= REFERENCE_SCALE * REFERENCE_SCALE
			if (expected - Vector3(BACKGROUND.r, BACKGROUND.g, BACKGROUND.b)).length() < 0.025:
				continue
			var old = sample.get_pixel(x, y)
			var current = sample.get_pixel(x + SAMPLE_SIDE, y)
			errors.x += (Vector3(old.r, old.g, old.b) - expected).abs().length()
			errors.y += (Vector3(current.r, current.g, current.b) - expected).abs().length()
			count += 1
	return errors / maxf(count, 1)
