extends RefCounted
## One identity map for world actors, admission cards and citizen portraits.

const ORIGINAL_PATH: String = "res://assets/art/characters.png"
const NewSurvivors = preload("res://scripts/survivor_appearances.gd")
const CIVILIAN_LOOKS: Array[int] = [0,1,2,3,8,9,10,11,12,13,14,15]
const IDLE_BOUNDS: Array[Rect2i] = [
	Rect2i(26,58,142,227), Rect2i(228,51,118,234), Rect2i(394,46,155,239), Rect2i(588,52,130,234),
	Rect2i(761,49,176,238), Rect2i(949,60,168,226), Rect2i(1131,56,147,230), Rect2i(1299,35,225,253)
]
const ACTION_BOUNDS: Array[Rect2i] = [
	Rect2i(19,813,181,194), Rect2i(218,808,165,198), Rect2i(396,801,192,206), Rect2i(589,813,144,194),
	Rect2i(762,806,195,202), Rect2i(961,817,171,191), Rect2i(1150,825,157,180), Rect2i(1310,799,221,207)
]
static var _textures: Dictionary = {}
static var _atlases: Dictionary = {}

static func appearance_key(appearance: String) -> String:
	return appearance if appearance in ["dirty","infected"] else "clean"

static func atlas_path(look: int, zombie: bool = false, appearance: String = "clean") -> String:
	var base_path: String = ORIGINAL_PATH if zombie or civilian_column(look) < 8 else NewSurvivors.PATH
	var variant: String = "clean" if zombie else appearance_key(appearance)
	if variant == "clean":
		return base_path
	var path: String = base_path.trim_suffix(".png")+"-"+variant+".png"
	return path if ResourceLoader.exists(path) else base_path

static func civilian_column(look: int) -> int:
	return look if look >= 8 and look <= 15 else posmod(look, 4)

static func source_bounds(look: int, zombie: bool = false) -> Rect2i:
	var column: int = clampi(look,5,7) if zombie else civilian_column(look)
	return IDLE_BOUNDS[column] if column < 8 else NewSurvivors.BOUNDS[column-8]

static func source_atlas(look: int, zombie: bool = false, appearance: String = "clean") -> Texture2D:
	var path: String = atlas_path(look,zombie,appearance)
	if not _atlases.has(path):
		_atlases[path] = load(path)
	return _atlases[path]

static func texture(look: int, frame: int = 0, guard: bool = false, appearance: String = "clean") -> Texture2D:
	var column: int = 4 if guard else civilian_column(look)
	var variant: String = "clean" if guard else appearance_key(appearance)
	var key: String = "idle-%d-%d-%s" % [column, frame, variant]
	if _textures.has(key):
		return _textures[key]
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = load(ORIGINAL_PATH) if guard else source_atlas(look,false,variant)
	if column >= 8:
		atlas.region = Rect2(NewSurvivors.BOUNDS[column-8])
	else:
		atlas.region = Rect2(ACTION_BOUNDS[column] if frame == 3 else IDLE_BOUNDS[column])
	atlas.filter_clip = true
	_textures[key] = atlas
	return atlas

