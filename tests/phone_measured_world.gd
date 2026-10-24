extends "res://scripts/main.gd"
## Loaded after autoload initialization to measure the real actor draw sizes.

var observed: Dictionary = {}

func _draw_person(column: int, frame: int, world_x: float, base_y: float, height: float, facing_left: bool=false, ground_shadow: bool=true, walk_phase: float=-1.0, zombie: bool=false, gait_blend: float=1.0, appearance: String="clean") -> void:
	observed[str(world_x)] = height
	super._draw_person(column,frame,world_x,base_y,height,facing_left,ground_shadow,walk_phase,zombie,gait_blend,appearance)
