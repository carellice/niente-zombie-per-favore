extends RefCounted
## Continuous two-leg cutout rig. Portraits and moving bodies share the exact
## painted source; the limbs are UV meshes, not a second set of drawn figures.

const Motion = preload("res://scripts/gait_motion.gd")
const Actors = preload("res://scripts/actor_visuals.gd")
const NewSurvivors = preload("res://scripts/survivor_appearances.gd")
const ATLAS: Texture2D = preload("res://assets/art/characters.png")
const ATLAS_SIZE: Vector2 = Vector2(1536.0, 1024.0)

## Global atlas coordinates. Each leg has its own painted trouser/shoe pixels.
## ring = (centre x, centre y, left edge x, right edge x).
## Boot rectangles exclude the other shoe and retain their natural alpha edge.
const PARTS: Array[Dictionary] = [
	{"cut":230.0, "sole":285.0,
	 "left":[Vector4(91,216,75,106),Vector4(87,241,70,103),Vector4(81,258,66,97)],
	 "right":[Vector4(117,216,102,135),Vector4(119,241,104,134),Vector4(122,258,108,136)],
	 "boot_left":Rect2(60,254,40,31), "boot_right":Rect2(106,254,43,31)},
	{"cut":245.0, "sole":285.0,
	 "left":[Vector4(261,226,245,278),Vector4(257,249,241,274),Vector4(253,264,236,270)],
	 "right":[Vector4(293,226,278,310),Vector4(294,249,279,310),Vector4(295,264,280,310)],
	 "boot_left":Rect2(233,259,42,26), "boot_right":Rect2(279,259,43,26)},
	{"cut":228.0, "sole":285.0,
	 "left":[Vector4(454,213,434,474),Vector4(450,239,431,473),Vector4(444,259,425,465)],
	 "right":[Vector4(487,213,470,507),Vector4(490,239,472,512),Vector4(492,259,476,509)],
	 "boot_left":Rect2(422,255,46,30), "boot_right":Rect2(476,255,44,30)},
	{"cut":245.0, "sole":286.0,
	 "left":[Vector4(642,225,627,658),Vector4(640,249,625,658),Vector4(636,263,620,654)],
	 "right":[Vector4(678,225,660,696),Vector4(678,249,662,695),Vector4(678,263,664,694)],
	 "boot_left":Rect2(616,259,43,27), "boot_right":Rect2(663,259,40,27)},
	{},
	{"cut":220.0, "sole":286.0,
	 "left":[Vector4(990,213,974,1008),Vector4(982,241,965,1000),Vector4(973,267,950,992)],
	 "right":[Vector4(1018,213,1003,1036),Vector4(1024,241,1009,1042),Vector4(1025,267,1009,1042)],
	 "boot_left":Rect2(949,263,47,23), "boot_right":Rect2(1007,263,55,23)},
	{"cut":210.0, "sole":286.0,
	 "left":[Vector4(1190,205,1171,1209),Vector4(1184,239,1155,1213),Vector4(1149,269,1132,1166)],
	 "left_uv":[Vector4(1177,205,1170,1183),Vector4(1170,239,1155,1184),Vector4(1149,269,1132,1166)],
	 "right":[Vector4(1215,205,1200,1232),Vector4(1225,239,1214,1237),Vector4(1222,269,1210,1235)],
	 "boot_left":Rect2(1130,266,47,20), "boot_right":Rect2(1209,266,47,20)},
	{"cut":255.0, "sole":288.0, "brown_legs":true,
	 "left":[Vector4(1380,248,1351,1410),Vector4(1377,259,1345,1409),Vector4(1373,270,1340,1405)],
	 "right":[Vector4(1465,248,1436,1497),Vector4(1464,259,1439,1492),Vector4(1467,270,1439,1497)],
	 "boot_left":Rect2(1340,270,72,18), "boot_right":Rect2(1438,268,64,20)}
]

static func source_parts(look: int, zombie: bool=false) -> Dictionary:
	var column: int = clampi(look,5,7) if zombie else Actors.civilian_column(look)
	return PARTS[column] if column < 8 else NewSurvivors.PARTS[column-8]

static func render_offset(look: int, zombie: bool=false) -> Vector2:
	var parts: Dictionary = source_parts(look,zombie)
	var bounds: Rect2i = Actors.source_bounds(look,zombie)
	var left: Array = parts.left
	var right: Array = parts.right
	var hip_mid_x: float = (float(left[0].x)+float(right[0].x))*0.5
	return Vector2((hip_mid_x-float(bounds.position.x)-float(bounds.size.x)*0.5)/float(bounds.size.y),0.0)

static func draw_actor(canvas: CanvasItem, look: int, phase: float, height: float, origin: Vector2, zombie: bool=false, facing_left: bool=false, blend: float=1.0, debug_feet: bool=false, appearance: String="clean") -> void:
	var column: int = clampi(look,5,7) if zombie else Actors.civilian_column(look)
	var parts: Dictionary = source_parts(look,zombie)
	var bounds: Rect2i = Actors.source_bounds(look,zombie)
	var source_texture: Texture2D = Actors.source_atlas(look,zombie,appearance)
	# Dirt and early illness are painted on the face and upper clothes. Keep
	# the established trouser/shoe pixels and UV contours for both alternating
	# feet; a new illustration must never change the tested walking geometry.
	var leg_texture: Texture2D = Actors.source_atlas(look,zombie)
	var texture_size: Vector2 = source_texture.get_size()
	var source_height: float = float(bounds.size.y)
	var source_scale: float = height/source_height
	var pose: Dictionary = Motion.pose(look,phase,zombie,blend)
	var config: Dictionary = Motion.config(look,zombie)
	var left: Array = parts.left
	var right: Array = parts.right
	# Atlas bounds include hands and bags. Anchor the articulated pelvis under
	# the painted pelvis rather than under the centre of that wider rectangle.
	var rig_offset: Vector2 = render_offset(look,zombie)
	var mirror: Vector2 = Vector2(-1.0 if facing_left else 1.0,1.0)
	canvas.draw_set_transform(origin,0.0,mirror)
	_draw_leg(canvas,left,parts.boot_left,float(parts.sole),pose,"left",rig_offset,height,source_scale,float(config.boot_height),Color(0.88,0.91,0.89,1.0),parts,bounds,parts.get("left_uv",[]),Color(1,0,0) if debug_feet else Color.WHITE,leg_texture,texture_size)
	_draw_leg(canvas,right,parts.boot_right,float(parts.sole),pose,"right",rig_offset,height,source_scale,float(config.boot_height),Color.WHITE,parts,bounds,[],Color(0,0,1) if debug_feet else Color.WHITE,leg_texture,texture_size)
	# The torso and first leg row have EXACTLY the same source and destination
	# coordinates. This is a shared edge, not a fixed shirt laid over a moving
	# thigh. Deformation starts gradually below it, so the pelvis cannot split.
	var crop: Rect2 = Rect2(Vector2(bounds.position),Vector2(bounds.size.x,float(parts.cut)-bounds.position.y))
	var body_rect: Rect2 = Rect2(Vector2(-float(bounds.size.x)*0.5*source_scale,-height),crop.size*source_scale)
	canvas.draw_texture_rect_region(source_texture,body_rect,crop,Color.WHITE,false,true)
	if column == 7:
		# The obese brute's green lower silhouette reads as a heavy hanging
		# belly, with only short brown legs below it. Preserve its actual ragged
		# contour instead of cutting the entire wide body on a horizontal row.
		# No original brown leg or boot is retained in this stationary patch.
		var belly: PackedVector2Array = PackedVector2Array([
			Vector2(1348,250),Vector2(1492,250),Vector2(1491,250),
			Vector2(1488,258),Vector2(1482,261),Vector2(1473,261),
			Vector2(1466,263),Vector2(1460,260),Vector2(1451,261),
			Vector2(1440,257),Vector2(1423,255),Vector2(1414,255),
			Vector2(1408,258),Vector2(1402,262),Vector2(1394,262),
			Vector2(1387,265),Vector2(1382,262),Vector2(1378,260),
			Vector2(1368,260),Vector2(1362,257),Vector2(1354,258),Vector2(1348,255)
		])
		_draw_static_patch(canvas,belly,bounds,source_scale,height)
	if column == 6:
		# The runner's forward hand hangs lower than his waist. Keep these
		# original stationary arm pixels without retaining the static legs.
		var arm: Rect2 = Rect2(1237,198,40,40)
		var arm_position: Vector2 = Vector2((arm.position.x-float(bounds.position.x)-float(bounds.size.x)*0.5)*source_scale,(arm.position.y-float(bounds.position.y))*source_scale-height)
		canvas.draw_texture_rect_region(ATLAS,Rect2(arm_position,arm.size*source_scale),arm,Color.WHITE,false,true)
		# His back arm crosses in front of the shorts in the original painting.
		# Keep that hand fixed, and use clean pants/calf UVs for the moving leg.
		var hand: PackedVector2Array = PackedVector2Array([Vector2(1182,193),Vector2(1198,193),Vector2(1202,214),Vector2(1208,219),Vector2(1216,229),Vector2(1211,242),Vector2(1205,249),Vector2(1190,249),Vector2(1185,238),Vector2(1187,222)])
		_draw_static_patch(canvas,hand,bounds,source_scale,height)
	canvas.draw_set_transform(Vector2.ZERO)

static func _draw_leg(canvas: CanvasItem, rings: Array, boot: Rect2, source_sole: float, pose: Dictionary, side: String, rig_offset: Vector2, height: float, source_scale: float, boot_height: float, tint: Color, parts: Dictionary, bounds: Rect2i, uv_rings: Array=[], boot_tint: Color=Color.WHITE, source_texture: Texture2D=ATLAS, texture_size: Vector2=ATLAS_SIZE) -> void:
	# Newly painted shoes end on slightly different source rows. Give each its
	# own sole anchor so both feet really touch the same ground during stance.
	source_sole = float(parts.get("sole_"+side,source_sole))
	var hip: Vector2 = (Vector2(pose["hip_"+side])+rig_offset)*height
	var knee: Vector2 = (Vector2(pose["knee_"+side])+rig_offset)*height
	var ankle: Vector2 = (Vector2(pose["ankle_"+side])+rig_offset)*height
	var foot: Vector2 = (Vector2(pose["foot_"+side])+rig_offset)*height
	# The old boot rectangles were offset differently around their respective
	# ankles. Centre both painted soles on the actual alternating foot goals;
	# otherwise the sprite itself can undo the crossing measured by the gait.
	var source_boot_center: float = boot.get_center().x
	ankle.x += (float(rings[2].x)-source_boot_center)*source_scale
	var cut: float = float(parts.cut)
	var last: Vector4 = rings[2]
	var boot_y_scale: float = boot_height*height/maxf(source_sole-last.y,1.0)
	var cloth_end: float = boot.position.y
	var source_origin: Vector2 = Vector2(float(bounds.position.x)+float(bounds.size.x)*0.5,float(bounds.end.y))
	var rows: Array[Dictionary] = []
	# Closely spaced rows form a single smooth cloth surface. At the waist the
	# painted silhouette stays anchored; by the knee it follows the full gait.
	# The old three independently positioned rings jumped at the body crop.
	const ROW_COUNT: int = 12
	for i: int in range(ROW_COUNT+1):
		var y: float = lerpf(cut,cloth_end,float(i)/ROW_COUNT)
		var ring: Vector4 = _source_ring(rings,y)
		var texture_y: float = y
		if bool(parts.get("brown_legs",false)):
			# Clean brown trouser paint is below the brute's irregular green hem.
			# Sampling the green belly into the bending limb made thin stretched
			# threads. Only the brown lower legs move beneath that heavy body.
			texture_y = lerpf(267.0,cloth_end,inverse_lerp(cut,cloth_end,y))
		var source_ring: Vector4 = _source_ring(rings,texture_y) if uv_rings.is_empty() else _source_ring(uv_rings,texture_y)
		var fixed_center: Vector2 = (Vector2(ring.x,y)-source_origin)*source_scale
		var desired: Vector2
		var middle: Vector4 = rings[1]
		if y <= middle.y:
			desired = hip.lerp(knee,inverse_lerp(float(rings[0].y),middle.y,y))
		else:
			desired = knee.lerp(ankle,inverse_lerp(middle.y,last.y,y))
		# Both displacement and its derivative are zero on the common waist
		# edge. There is no tinted crop line: depth shade also fades in below it.
		var weight: float = smoothstep(cut,minf(cut+9.0,cloth_end),y)
		var center: Vector2 = fixed_center.lerp(desired,weight)
		# The calf and shoe also share one source/destination edge. Mapping a
		# separate boot rectangle over a differently placed shin made a second
		# visible cut at the cuffs when a foot was raised.
		var shoe_center: Vector2 = foot+Vector2((ring.x-source_boot_center)*source_scale,(y-source_sole)*boot_y_scale)
		center = center.lerp(shoe_center,smoothstep(maxf(cut,cloth_end-6.0),cloth_end,y))
		rows.append({"left":center+Vector2((ring.z-ring.x)*source_scale,0),"right":center+Vector2((ring.w-ring.x)*source_scale,0),"uv_left":Vector2(source_ring.z,texture_y)/texture_size,"uv_right":Vector2(source_ring.w,texture_y)/texture_size,"color":Color.WHITE.lerp(tint,weight)})
	for i: int in range(ROW_COUNT):
		var a: Dictionary = rows[i]
		var b: Dictionary = rows[i+1]
		var vertices: PackedVector2Array = PackedVector2Array([a.left,a.right,b.right,b.left])
		var uv: PackedVector2Array = PackedVector2Array([a.uv_left,a.uv_right,b.uv_right,b.uv_left])
		_draw_band(canvas,vertices,uv,Color.WHITE,PackedColorArray([a.color,a.color,b.color,b.color]),source_texture)
	# Shoes are rigid horizontally and keep the same sole plane during stance.
	# Their source vertical size is fitted to the ankle height used by the IK.
	var y_scale: float = boot_y_scale
	var boot_points: PackedVector2Array = PackedVector2Array()
	var boot_uv: PackedVector2Array = PackedVector2Array()
	for source: Vector2 in [boot.position,Vector2(boot.end.x,boot.position.y),boot.end,Vector2(boot.position.x,boot.end.y)]:
		boot_points.append(foot+Vector2((source.x-source_boot_center)*source_scale,(source.y-source_sole)*y_scale))
		boot_uv.append(source/texture_size)
	canvas.draw_polygon(boot_points,PackedColorArray([tint*boot_tint]),boot_uv,source_texture)

static func _source_ring(rings: Array, y: float) -> Vector4:
	var segment: int = 0 if y <= float(rings[1].y) else 1
	var a: Vector4 = rings[segment]
	var b: Vector4 = rings[segment+1]
	return a.lerp(b,clampf(inverse_lerp(a.y,b.y,y),0.0,1.0))

static func _draw_band(canvas: CanvasItem, vertices: PackedVector2Array, uv: PackedVector2Array, tint: Color, colors: PackedColorArray=PackedColorArray(), source_texture: Texture2D=ATLAS) -> void:
	# Explicit triangles also cover an almost collapsed band at a contact
	# boundary; CanvasItem's polygon ear clipping need not infer its diagonal.
	for indices: Vector3i in [Vector3i(0,1,2),Vector3i(0,2,3)]:
		var triangle: PackedVector2Array = PackedVector2Array([vertices[indices.x],vertices[indices.y],vertices[indices.z]])
		if absf((triangle[1]-triangle[0]).cross(triangle[2]-triangle[0]))<0.000001:
			continue
		var triangle_colors: PackedColorArray = PackedColorArray([tint]) if colors.is_empty() else PackedColorArray([colors[indices.x],colors[indices.y],colors[indices.z]])
		canvas.draw_polygon(triangle,triangle_colors,PackedVector2Array([uv[indices.x],uv[indices.y],uv[indices.z]]),source_texture)

static func _draw_static_patch(canvas: CanvasItem, source_points: PackedVector2Array, bounds: Rect2i, source_scale: float, height: float) -> void:
	var vertices: PackedVector2Array = PackedVector2Array()
	var uv: PackedVector2Array = PackedVector2Array()
	for source: Vector2 in source_points:
		vertices.append(Vector2((source.x-float(bounds.position.x)-float(bounds.size.x)*0.5)*source_scale,(source.y-float(bounds.position.y))*source_scale-height))
		uv.append(source/ATLAS_SIZE)
	canvas.draw_polygon(vertices,PackedColorArray([Color.WHITE]),uv,ATLAS)
