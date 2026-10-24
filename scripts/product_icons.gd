extends RefCounted
## Painted product illustrations share a small visual vocabulary across shops.

const HUDIcons = preload("res://scripts/hud_icons.gd")
const PRODUCTS = {
	"cafe": ["coffee","biscuit","breakfast"],
	"garden": ["vegetables","vegetables","crate"],
	"workshop": ["crate","tools","repair"],
	"clinic": ["bandage","medkit","medicine"],
	"bakery": ["bread","bread","biscuit"],
	"waterworks": ["water","water","water"],
	"tailor": ["cloth","cloth","cloth"]
}
static var _textures: Dictionary = {}

static func texture(building: String, tier: int) -> Texture2D:
	var products: Array = PRODUCTS.get(building,["crate","crate","crate"])
	var key: String = str(products[clampi(tier-1,0,products.size()-1)])
	if key in ["coffee","crate"]: return HUDIcons.texture(key)
	return _load_painted("res://assets/art/products/%s.png" % key,"crate")

static func population() -> Texture2D:
	return _load_painted("res://assets/art/population.png","people")

static func _load_painted(path: String, fallback: String) -> Texture2D:
	if _textures.has(path): return _textures[path]
	# Assets can be imported after the editor first parses this script.
	if not ResourceLoader.exists(path): return HUDIcons.texture(fallback)
	var texture: Texture2D = load(path) as Texture2D
	_textures[path] = texture
	return texture
