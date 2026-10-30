extends RefCounted
## In-world preparation markers. Each arc follows an actual gameplay timer.
const Observation = preload("res://scripts/visitor_observation.gd")
const START = -PI*0.5
const SAGE = Color("608552")
const GOLD = Color("bb8439")

static func product_progress(product: Dictionary) -> float:
	var remaining: float = maxf(0.0,float(product.get("remaining",0.0)))
	# Older saves have no batch duration; retain their original base-duration bar.
	var duration: float = maxf(remaining,float(product.get("restock_duration",product.get("duration",1.0))))
	return clampf(1.0-remaining/maxf(duration,0.001),0.0,1.0)

static func preparations(game: Node, building: Dictionary) -> Array[Dictionary]:
	var tasks: Array[Dictionary] = []
	if game.is_under_construction(building): return tasks
	var workers: int = game._available_workers(building)
	for product: Dictionary in building.get("products",[]):
		if product.get("status","")!="restocking": continue
		tasks.append({"progress":product_progress(product),"paused":workers<int(product.tier)})
	var service: Dictionary = building.get("service",{})
	if service.get("status","")=="working":
		var duration: float = 120.0 if building.type=="garden" else 150.0
		tasks.append({"progress":clampf(1.0-float(service.remaining)/duration,0.0,1.0),"paused":workers==0})
	return tasks

static func visitor_bounds(scene: Control, visitor: Dictionary) -> Rect2:
	var diameter: float = clampf(54.0*scene._actor_zoom(),46.0,88.0)
	var head: Vector2 = Vector2(scene._sx(float(visitor.x)),scene._ground()-71.0*scene._actor_zoom())
	return Rect2(head-Vector2(diameter*0.5,diameter+14.0),Vector2.ONE*diameter)

static func visitor_visible(visitor: Dictionary, departing: bool=false) -> bool:
	return not departing and visitor.get("observation","")=="waiting"

static func draw_visitor(scene: Control, game: Node, visitor: Dictionary, art: Texture2D) -> void:
	if not visitor_visible(visitor): return
	var rect: Rect2 = visitor_bounds(scene,visitor)
	if rect.end.x<0.0 or rect.position.x>scene.size.x: return
	var view: Dictionary = Observation.preview(game,visitor)
	var center: Vector2 = rect.get_center()
	var radius: float = rect.size.x*0.5
	scene.draw_circle(center+Vector2(0,3),radius,Color(0.1,0.15,0.12,0.35),true,-1,true)
	scene.draw_circle(center,radius,Color("f5ebd3"),true,-1,true)
	scene.draw_arc(center,radius-1.5,0,TAU,64,Color("826741"),2.0,true)
	var size: Vector2 = art.get_size()*(rect.size.x*0.54/maxf(art.get_width(),art.get_height()))
	scene.draw_texture_rect(art,Rect2(center-size*0.5,size),false)
	draw_ring(scene,rect,[{"progress":float(view.progress)/100.0,"paused":false}])

static func draw_ring(canvas: CanvasItem, rect: Rect2, tasks: Array[Dictionary]) -> void:
	if tasks.is_empty(): return
	var center: Vector2 = rect.get_center()
	var width: float = clampf(rect.size.x*0.065,3.5,6.0)
	var radius: float = rect.size.x*0.5-width*0.5-4.0
	var gap: float = 0.16 if tasks.size()>1 else 0.0
	var sweep: float = TAU/tasks.size()-gap
	for i: int in range(tasks.size()):
		var task: Dictionary = tasks[i]
		var start: float = START+float(i)*TAU/tasks.size()+gap*0.5
		_arc(canvas,center,radius,start,start+sweep,Color("d4c8a6"),width)
		var progress: float = clampf(float(task.progress),0.0,1.0)
		var tint: Color = GOLD if task.paused else SAGE
		# A small starting bead makes even a newly started batch recognisable.
		_arc(canvas,center,radius,start,start+sweep*progress,tint,width)

static func draw_preparation_badge(canvas: CanvasItem, rect: Rect2, tasks: Array[Dictionary]) -> void:
	if tasks.is_empty(): return
	var radius: float = clampf(rect.size.x*0.15,9.0,14.0)
	var center: Vector2 = rect.get_center()+Vector2.ONE*rect.size.x*0.32
	var paused: bool = false
	for task: Dictionary in tasks:
		if task.paused: paused = true
	canvas.draw_circle(center,radius+1.5,Color("826741"),true,-1,true)
	canvas.draw_circle(center,radius,Color("f5ebd3"),true,-1,true)
	var tint: Color = GOLD if paused else SAGE
	if paused:
		for side: float in [-0.23,0.23]:
			canvas.draw_line(center+Vector2(side,-0.4)*radius,center+Vector2(side,0.4)*radius,tint,2.5,true)
	else:
		canvas.draw_arc(center,radius*0.62,0,TAU,32,tint,1.7,true)
		canvas.draw_polyline(PackedVector2Array([center+Vector2(0,-0.4)*radius,center,center+Vector2(0.34,0.18)*radius]),tint,2.0,true)

static func _arc(canvas: CanvasItem, center: Vector2, radius: float, start: float, end: float, tint: Color, width: float) -> void:
	if end>start: canvas.draw_arc(center,radius,start,end,maxi(2,ceili((end-start)*16)),tint,width,true)
	for angle: float in [start,end]:
		canvas.draw_circle(center+Vector2.from_angle(angle)*radius,width*0.5,tint,true,-1,true)
