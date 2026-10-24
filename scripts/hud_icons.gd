extends RefCounted
## Isolated, cached mip chains keep painted HUD symbols clean at small sizes.
## Cropping before generating mipmaps prevents neighbouring atlas icons bleeding.

const PATH: String = "res://assets/art/ui_icons.png"
const KEYS = {"coin":0,"crate":1,"bill":2,"home":3,"people":4,"person":4,"build":5,"compass":6,"gun":7,"shield":8,"check":8,"sun":9,"pause":10,"sound":11,"mute":11,"help":12,"cross":13,"heart":14,"coffee":15}
const REGIONS: Array[Rect2] = [
	Rect2(25,92,300,260),Rect2(338,90,298,259),Rect2(639,126,304,218),Rect2(943,80,282,278),
	Rect2(24,391,319,260),Rect2(340,387,304,265),Rect2(650,346,247,310),Rect2(916,367,313,291),
	Rect2(47,659,262,275),Rect2(345,655,284,283),Rect2(672,685,225,238),Rect2(945,684,279,239),
	Rect2(71,942,218,267),Rect2(363,951,249,240),Rect2(651,960,284,230),Rect2(986,940,236,260)
]
static var _icons: Array[Texture2D] = []
static var _crops: Dictionary = {}

static func texture(kind: String) -> Texture2D:
	if _icons.is_empty():
		# Build once, then release the CPU sheet rather than retaining a second
		# full-size atlas in memory or rebuilding textures during every draw.
		var source: Image = _source_image(PATH)
		for region: Rect2 in REGIONS:
			_icons.append(_filtered_texture(source.get_region(Rect2i(region))))
	return _icons[int(KEYS.get(kind,12))]

static func cropped_texture(path: String, region: Rect2i) -> Texture2D:
	var key: String = path+":"+str(region)
	if not _crops.has(key):
		_crops[key] = _filtered_texture(_source_image(path).get_region(region))
	return _crops[key]

static func _source_image(path: String) -> Image:
	var source: Image = (load(path) as Texture2D).get_image()
	if source.is_compressed():
		source.decompress()
	return source

static func _filtered_texture(source: Image) -> Texture2D:
	source.generate_mipmaps()
	return ImageTexture.create_from_image(source)
