extends Control
## Painted equipment icons share a cached mip chain at every UI size.

const PATHS: Dictionary = {
	"pistol":"res://assets/art/weapons/pistol.png",
	"shotgun":"res://assets/art/weapons/shotgun.png",
	"sniper":"res://assets/art/weapons/sniper.png",
	"smg":"res://assets/art/weapons/smg.png",
	"ammo":"res://assets/art/weapons/ammo.png"
}
static var _textures: Dictionary = {}

var kind: String = "pistol":
	set(value):
		kind = value
		queue_redraw()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	resized.connect(queue_redraw)

static func _painted_texture(icon_kind: String) -> Texture2D:
	if _textures.has(icon_kind):
		return _textures[icon_kind]
	var path: String = str(PATHS.get(icon_kind,""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var original: Texture2D = load(path) as Texture2D
	if original == null:
		return null
	var source: Image = original.get_image()
	if source.is_compressed():
		source.decompress()
	# Ignore transparent canvas padding without changing the original PNG or
	# its painted edges. Every silhouette then uses the same available space.
	var bounds: Rect2i = source.get_used_rect()
	if not bounds.has_area():
		return null
	var artwork: Image = source.get_region(bounds)
	artwork.generate_mipmaps()
	var texture: ImageTexture = ImageTexture.create_from_image(artwork)
	_textures[icon_kind] = texture
	return texture

func _draw() -> void:
	var texture: Texture2D = _painted_texture(kind)
	if texture == null or size.x <= 4.0 or size.y <= 4.0:
		return
	var available: Vector2 = size-Vector2(4,4)
	var original_size: Vector2 = texture.get_size()
	var scale_factor: float = minf(available.x/original_size.x,available.y/original_size.y)
	var artwork_size: Vector2 = original_size*scale_factor
	draw_texture_rect(texture,Rect2((size-artwork_size)*0.5,artwork_size),false)
