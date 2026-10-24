extends RefCounted
## One type scale for the HUD, dossiers and world-space labels.
## Rounded Fredoka headings and a fixed bold Nunito Sans body keep small text clear.

static var _heading: Font
static var _body: Font

static func heading() -> Font:
	if _heading == null:
		var font: FontVariation = FontVariation.new()
		font.base_font = load("res://assets/fonts/fredoka.ttf")
		# Numeric OpenType axis tags: strings such as "wght" are silently ignored.
		font.variation_opentype = {0x77676874: 700.0, 0x77647468: 100.0}
		_heading = font
	return _heading

static func body() -> Font:
	if _body == null:
		var font: FontVariation = FontVariation.new()
		font.base_font = load("res://assets/fonts/body.ttf")
		font.variation_opentype = {0x77676874: 700.0, 0x77647468: 100.0, 0x6f70737a: 12.0}
		_body = font
	return _body
