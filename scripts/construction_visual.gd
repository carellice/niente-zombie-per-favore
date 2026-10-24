extends RefCounted
## Painted building art grows behind warm wooden scaffolding and drifting dust.
const Icons = preload("res://scripts/hud_icons.gd")

static func draw_site(canvas: CanvasItem, texture: Texture2D, rect: Rect2, progress: float, clock: float) -> void:
	var z: float = rect.size.x/310.0
	var wood: Color = Color("70513a")
	var light: Color = Color("ba9260")
	if texture!=null:
		canvas.draw_texture_rect(texture,rect,false,Color(0.78,0.82,0.72,0.20))
		var reveal: float = lerpf(0.10,0.98,progress)
		var source: Rect2 = Rect2(0,texture.get_height()*(1.0-reveal),texture.get_width(),texture.get_height()*reveal)
		var destination: Rect2 = Rect2(rect.position+Vector2(0,rect.size.y*(1.0-reveal)),Vector2(rect.size.x,rect.size.y*reveal))
		canvas.draw_texture_rect_region(texture,destination,source,Color(0.94,0.95,0.85))
	for side: float in [0.08,0.92]:
		var bottom: Vector2 = Vector2(rect.position.x+rect.size.x*side,rect.end.y)
		var top: Vector2 = Vector2(bottom.x,rect.position.y+rect.size.y*0.05)
		canvas.draw_line(bottom,top,wood,9.0*z,true)
		canvas.draw_line(bottom+Vector2(z,0),top+Vector2(z,0),light,3.0*z,true)
	for level: float in [0.22,0.53,0.82]:
		var left: Vector2 = rect.position+rect.size*Vector2(0.06,level)
		var right: Vector2 = rect.position+rect.size*Vector2(0.94,level)
		canvas.draw_line(left,right,wood,8.0*z,true)
		canvas.draw_line(left,right,light,3.0*z,true)
		canvas.draw_line(left,right-Vector2(0,rect.size.y*minf(0.25,level-0.05)),Color("947a54"),3.0*z,true)
		for joint: Vector2 in [left,right]: canvas.draw_circle(joint,4.0*z,Color("d7b983"),true,-1,true)
	var fence: Rect2 = Rect2(rect.position.x+8.0*z,rect.end.y-28.0*z,rect.size.x-16.0*z,27.0*z)
	canvas.draw_style_box(_fence_style(),fence)
	for i: int in range(9):
		var x: float = fence.position.x+(14.0+float(i)*31.0)*z
		canvas.draw_line(Vector2(x,fence.end.y-3*z),Vector2(x+13*z,fence.position.y+3*z),Color("edc16a"),7*z,true)
	# Small painted toolbox moves with the work rather than becoming a UI icon.
	var toolbox: Texture2D = Icons.texture("build")
	var origin: Vector2 = Vector2(rect.position.x+46*z,rect.end.y-20*z-maxf(0.0,sin(clock*5.0))*2.0*z)
	canvas.draw_set_transform(origin,sin(clock*4.0)*0.045)
	canvas.draw_texture_rect(toolbox,Rect2(Vector2(-22,-37)*z,Vector2(44,44)*z),false)
	canvas.draw_set_transform(Vector2.ZERO)
	for i: int in range(5):
		var age: float = fposmod(clock*0.55+float(i)*0.21,1.0)
		var x: float = rect.position.x+rect.size.x*(0.18+fposmod(float(i)*0.19+progress*0.13,0.65))
		var y: float = rect.end.y-30.0*z-age*25.0*z
		canvas.draw_circle(Vector2(x,y),(3.0+age*6.0)*z,Color(0.92,0.83,0.63,(1.0-age)*0.36),true,-1,true)
	var bar: Rect2 = Rect2(fence.position+Vector2(4,8)*z,Vector2(fence.size.x-8*z,5*z))
	canvas.draw_rect(bar,Color("4b4534"))
	canvas.draw_rect(Rect2(bar.position,Vector2(bar.size.x*progress,bar.size.y)),Color("b8cb8c"))

static func _fence_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("70513a")
	style.border_color = Color("ba9260")
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	return style
