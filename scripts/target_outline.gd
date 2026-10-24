extends Node
## One small offscreen mask follows the actual animated actor, including feet.
## Drawing this texture before the body leaves a luminous silhouette contour.

const WalkingRig = preload("res://scripts/walking_rig.gd")
const MASK_SHADER = preload("res://scripts/target_silhouette.gdshader")
const MASK_SIZE = Vector2i(192,224)
const MASK_ORIGIN = Vector2(96,208)
const MASK_HEIGHT = 160.0
const DIRECTIONS = 12

var viewport: SubViewport
var mask: MaskCanvas

class MaskCanvas extends Control:
	var look: int = 5
	var frame: int = 0
	var phase: float = 0.0
	var blend: float = 0.0
	var zombie: bool = true
	var facing_left: bool = false
	var appearance: String = "clean"
	var pose_texture: Texture2D

	func _draw() -> void:
		if frame==0:
			WalkingRig.draw_actor(self,look,phase,MASK_HEIGHT,MASK_ORIGIN,zombie,facing_left,blend,false,appearance)
		elif pose_texture:
			var width: float = MASK_HEIGHT*pose_texture.get_width()/maxf(pose_texture.get_height(),1)
			draw_set_transform(MASK_ORIGIN,0,Vector2(-1 if facing_left else 1,1))
			draw_texture_rect(pose_texture,Rect2(-width/2,-MASK_HEIGHT,width,MASK_HEIGHT),false)
			draw_set_transform(Vector2.ZERO)

func _ready() -> void:
	viewport = SubViewport.new()
	viewport.size = MASK_SIZE
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.gui_disable_input = true
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	add_child(viewport)
	mask = MaskCanvas.new()
	mask.size = Vector2(MASK_SIZE)
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var silhouette: ShaderMaterial = ShaderMaterial.new()
	silhouette.shader = MASK_SHADER
	mask.material = silhouette
	viewport.add_child(mask)

func configure(look: int, frame: int, phase: float, blend: float, zombie: bool, facing_left: bool, appearance: String, pose_texture: Texture2D) -> void:
	mask.look = look
	mask.frame = frame
	mask.phase = phase
	mask.blend = blend
	mask.zombie = zombie
	mask.facing_left = facing_left
	mask.appearance = appearance
	mask.pose_texture = pose_texture
	mask.queue_redraw()

func draw_halo(canvas: CanvasItem, origin: Vector2, height: float, intensity: float = 1.0) -> void:
	var scale_factor: float = height/MASK_HEIGHT
	var destination: Rect2 = Rect2(origin-MASK_ORIGIN*scale_factor,Vector2(MASK_SIZE)*scale_factor)
	var texture: Texture2D = viewport.get_texture()
	# Offset copies dilate the complete mask, so no outline appears at the
	# torso/leg joints and the light stays attached during every walking pose.
	for layer: int in range(3):
		var radius: float = [4.0,2.8,1.7][layer]
		var tint: Color = [Color(1.0,0.71,0.26,0.055),Color(1.0,0.83,0.40,0.095),Color(1.0,0.96,0.70,0.72)][layer]
		tint.a *= intensity
		for direction: int in range(DIRECTIONS):
			var offset: Vector2 = Vector2.from_angle(TAU*float(direction)/DIRECTIONS)*radius
			canvas.draw_texture_rect(texture,Rect2(destination.position+offset,destination.size),false,tint)
