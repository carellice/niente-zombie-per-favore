extends "res://scripts/main.gd"
## Observe the arguments actually consumed by the production world renderer.
var rendered_actors: Array[Dictionary] = []
var rendered_labels: Array[String] = []
var drawing_order: Array[String] = []

func _draw() -> void:
	rendered_actors.clear()
	rendered_labels.clear()
	drawing_order.clear()
	super._draw()

func _draw_person(column: int, frame: int, world_x: float, base_y: float, height: float, facing_left: bool=false, ground_shadow: bool=true, walk_phase: float=-1.0, zombie: bool=false, gait_blend: float=1.0, appearance: String="clean") -> void:
	# The permanent tower guard uses the separate static rendering path.
	if walk_phase>=0.0:
		rendered_actors.append({"look":column,"frame":frame,"x":world_x,"y":base_y,"height":height,"left":facing_left,"zombie":zombie,"phase":walk_phase,"blend":gait_blend,"appearance":appearance})
	super._draw_person(column,frame,world_x,base_y,height,facing_left,ground_shadow,walk_phase,zombie,gait_blend,appearance)

func _draw_gate() -> void:
	drawing_order.append("tower")
	super._draw_gate()

func _draw_guards() -> void:
	drawing_order.append("soldier")
	super._draw_guards()

func _text(pos: Vector2, value: String, font_size: int, color: Color, font: Font, centered: bool=false) -> void:
	rendered_labels.append(value)
	super._text(pos,value,font_size,color,font,centered)
