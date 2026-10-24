extends RefCounted
## Cached silhouette light and a small, bottom-anchored response for city art.
## Preparation reads images once; drawing only uses the cached GPU textures.

const MAX_MASK_SIZE: int = 512
const CLICK_DURATION: float = 0.30
const HOVER_RATE: float = 22.0
const DIRECTIONS: int = 8

var _masks: Dictionary = {}
var _hover_amounts: Dictionary = {}
var _click_ages: Dictionary = {}

func prepare(textures: Array[Texture2D]) -> void:
	for texture: Texture2D in textures:
		if texture == null:
			continue
		var key: int = texture.get_instance_id()
		if _masks.has(key):
			continue
		# AtlasTexture.get_image() supplies its cropped region, so neighbouring
		# illustrations in settlement.png never become part of the outline.
		var source: Image = texture.get_image()
		if source == null or source.is_empty():
			continue
		var image: Image = source.duplicate()
		if image.is_compressed() and image.decompress() != OK:
			continue
		image.clear_mipmaps()
		image.convert(Image.FORMAT_RGBA8)
		var longest_side: int = maxi(image.get_width(), image.get_height())
		if longest_side > MAX_MASK_SIZE:
			var factor: float = float(MAX_MASK_SIZE) / float(longest_side)
			image.resize(maxi(1, roundi(image.get_width() * factor)), maxi(1, roundi(image.get_height() * factor)), Image.INTERPOLATE_LANCZOS)
		var pixels: PackedByteArray = image.get_data()
		for index: int in range(0, pixels.size(), 4):
			pixels[index] = 255
			pixels[index + 1] = 255
			pixels[index + 2] = 255
		var mask_image: Image = Image.create_from_data(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8, pixels)
		mask_image.generate_mipmaps()
		_masks[key] = ImageTexture.create_from_image(mask_image)

func update(delta: float, hovered_id: int = -1) -> void:
	var step: float = maxf(delta, 0.0)
	if hovered_id >= 0 and not _hover_amounts.has(hovered_id):
		_hover_amounts[hovered_id] = 0.0
	var weight: float = 1.0 - exp(-step * HOVER_RATE)
	for id: Variant in _hover_amounts.keys():
		var target: float = 1.0 if int(id) == hovered_id else 0.0
		var value: float = lerpf(float(_hover_amounts[id]), target, weight)
		if target == 0.0 and value < 0.001:
			_hover_amounts.erase(id)
		else:
			_hover_amounts[id] = value
	for id: Variant in _click_ages.keys():
		var age: float = float(_click_ages[id]) + step
		if age >= CLICK_DURATION:
			_click_ages.erase(id)
		else:
			_click_ages[id] = age

func click(id: int) -> void:
	if id >= 0:
		_click_ages[id] = 0.0

func reset() -> void:
	_hover_amounts.clear()
	_click_ages.clear()

func amount(id: int) -> float:
	return maxf(float(_hover_amounts.get(id, 0.0)), _click_amount(id))

func draw(canvas: CanvasItem, texture: Texture2D, box: Rect2, tint: Color, id: int) -> void:
	if texture == null:
		return
	# This is the same bottom-centred fit used by main._draw_fitted.
	var factor: float = minf(box.size.x / maxf(texture.get_width(), 1), box.size.y / maxf(texture.get_height(), 1))
	var dimensions: Vector2 = texture.get_size() * factor
	var origin: Vector2 = Vector2(box.get_center().x, box.end.y)
	var hover: float = float(_hover_amounts.get(id, 0.0))
	var compression: float = _click_deformation(id)
	var scale_factor: Vector2 = Vector2(
		clampf(1.0 + hover * 0.005 - compression * 0.45, 0.984, 1.016),
		clampf(1.0 + hover * 0.005 + compression, 0.984, 1.016)
	)
	dimensions *= scale_factor
	var destination: Rect2 = Rect2(origin - Vector2(dimensions.x * 0.5, dimensions.y), dimensions)
	var intensity: float = amount(id)
	var mask: Texture2D = _masks.get(texture.get_instance_id(), null)
	if intensity > 0.001 and mask != null:
		# Offsets are in screen-space, keeping the fine edge readable at every
		# camera zoom. The wider, faint layer is only a soft ambient halo.
		for layer: int in range(2):
			var radius: float = 3.6 if layer == 0 else 1.8
			var color: Color = Color(1.0, 0.77, 0.34, 0.024) if layer == 0 else Color(1.0, 0.89, 0.58, 0.44)
			color.a *= intensity * tint.a
			for direction: int in range(DIRECTIONS):
				var offset: Vector2 = Vector2.from_angle(TAU * float(direction) / DIRECTIONS) * radius
				canvas.draw_texture_rect(mask, Rect2(destination.position + offset, destination.size), false, color)
	var brightness: float = 1.0 + hover * 0.035 + _click_amount(id) * 0.025
	var body_tint: Color = Color(tint.r * brightness, tint.g * brightness, tint.b * brightness, tint.a)
	canvas.draw_texture_rect(texture, destination, false, body_tint)

func _click_amount(id: int) -> float:
	if not _click_ages.has(id):
		return 0.0
	return 1.0 - smoothstep(0.0, CLICK_DURATION, float(_click_ages[id]))

func _click_deformation(id: int) -> float:
	if not _click_ages.has(id):
		return 0.0
	var age: float = float(_click_ages[id])
	if age < 0.09:
		return -0.016 * sin(PI * age / 0.09)
	return 0.008 * sin(PI * (age - 0.09) / (CLICK_DURATION - 0.09))
