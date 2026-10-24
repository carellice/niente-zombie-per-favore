extends "res://scripts/main.gd"
## Measure the actual expansion drawing, including text that does not zoom.
var expansion_bounds: Rect2
var expansion_labels: int = 0
var measuring_expansion: bool = false

func _draw_expansion() -> void:
	expansion_bounds = _expansion_rect()
	expansion_labels = 0
	measuring_expansion = true
	super._draw_expansion()
	measuring_expansion = false

func _text(pos: Vector2, value: String, font_size: int, color: Color, font: Font, centered: bool=false) -> void:
	if measuring_expansion:
		var pixels: int = roundi(font_size*_world_text_scale())
		var dimensions: Vector2 = font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels)
		var origin: Vector2 = pos-Vector2(dimensions.x*0.5 if centered else 0.0,font.get_ascent(pixels))
		expansion_bounds = expansion_bounds.merge(Rect2(origin,dimensions).grow(2.0))
		expansion_labels += 1
	super._text(pos,value,font_size,color,font,centered)
