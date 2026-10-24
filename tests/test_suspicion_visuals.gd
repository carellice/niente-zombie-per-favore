extends SceneTree
## The same identity and painted condition must survive portrait, world and gait.

const Actors = preload("res://scripts/actor_visuals.gd")
const Rig = preload("res://scripts/walking_rig.gd")
const Typography = preload("res://scripts/typography.gd")
var checks: int = 0
var failures: int = 0

class ContactSheet extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size),Color("263e37"))
		draw_string(Typography.heading(),Vector2(24,38),"POLVERE, STANCHEZZA O CONTAGIO?",HORIZONTAL_ALIGNMENT_LEFT,-1,27,Color("fff1d6"))
		for index: int in range(Actors.CIVILIAN_LOOKS.size()):
			var look: int = Actors.CIVILIAN_LOOKS[index]
			var corner: Vector2 = Vector2(22+(index%4)*354,65+(index/4)*270)
			draw_rect(Rect2(corner,Vector2(335,250)),Color("f4e7ca"))
			draw_string(Typography.heading(),corner+Vector2(12,26),"IDENTITÀ %d" % look,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("594c37"))
			var conditions: Array[String] = ["clean","dirty","infected"]
			var labels: Array[String] = ["Pulito","Polvere","Indizi"]
			for condition: int in range(3):
				var origin: Vector2 = corner+Vector2(57+condition*108,210)
				var appearance: String = conditions[condition]
				var portrait: Texture2D = Actors.texture(look,0,false,appearance)
				var dimensions: Vector2 = portrait.get_size()*94.0/portrait.get_height()
				draw_texture_rect(portrait,Rect2(origin+Vector2(-dimensions.x*0.5,-169),dimensions),false)
				Rig.draw_actor(self,look,0.14+index*0.03,70,origin,false,false,1.0,false,appearance)
				draw_string(Typography.body(),corner+Vector2(18+condition*108,235),labels[condition],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("594c37"))

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("SUSPICION VISUAL FAIL: "+description)

func run() -> void:
	for look: int in Actors.CIVILIAN_LOOKS:
		var base: Texture2D = Actors.source_atlas(look)
		var body: Rect2i = Actors.source_bounds(look)
		var base_pixels: PackedByteArray = base.get_image().get_region(body).get_data()
		for appearance: String in ["dirty","infected"]:
			var source: Texture2D = Actors.source_atlas(look,false,appearance)
			var portrait: AtlasTexture = Actors.texture(look,0,false,appearance)
			expect(source!=base, "%d %s has painted artwork" % [look,appearance])
			expect(source.get_size()==base.get_size(), "%d %s preserves atlas coordinates" % [look,appearance])
			expect(portrait.atlas==source and portrait.region==Rect2(body), "%d %s world and portrait share identity and condition" % [look,appearance])
			expect(source.get_image().get_region(body).get_data()!=base_pixels, "%d %s has visible new painted details" % [look,appearance])
			expect(Actors.texture(look,3,false,appearance).atlas==source, "%d %s working pose keeps its condition" % [look,appearance])
		expect(Actors.texture(look,0,false,"invalid")==Actors.texture(look),"unknown condition safely uses clean identity %d" % look)
	for look: int in [5,6,7]:
		expect(Actors.source_atlas(look,true,"infected")==Actors.source_atlas(look,true),"zombie source is unaffected by civilian variants %d" % look)
	expect(Actors.texture(0,0,true,"infected")==Actors.texture(0,0,true),"permanent soldier keeps original uniform")
	var game: Node = root.get_node("Game")
	game.save_path = "user://suspicion-visual-test.json"
	game.set_process(false)
	game._new_game()
	game.skip_tutorial()
	game.paused = false
	root.get_node("Preferences").apply_settings({"sound_enabled":false,"screen_shake":false,"fullscreen":false},false)
	var scene: Control = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	for look: int in Actors.CIVILIAN_LOOKS:
		var infiltrator: Dictionary = {"kind":"infiltrator","look":look,"appearance":"infected"}
		expect(scene._enemy_column(infiltrator)==look and not scene._is_zombie(infiltrator),"revealed infiltrator preserves human appearance %d" % look)
	for kind: String in ["bakery","waterworks","tailor"]:
		expect(scene.extra_building_art.has(kind),"new building has its own painted facade "+kind)
	if DisplayServer.get_name()!="headless" and OS.get_cmdline_user_args().has("--capture-suspicion"):
		root.size = Vector2i(1440,900)
		game.coins = 100000
		for kind: String in ["bakery","waterworks","tailor"]:
			expect(ready_build(game,kind),"new facade can be placed in the refuge "+kind)
		scene.ui._start_game()
		scene.ui.toast_stack.visible = false
		scene.camera_x = 520.0
		scene.target_camera = 520.0
		scene.zoom = 1.2
		scene.target_zoom = 1.2
		scene.queue_redraw()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		expect(root.get_texture().get_image().save_png("C:/Users/flavi/Desktop/CODEX_niente_zombie_per_favore/docs/NUOVI-EDIFICI-v04.png")==OK,"native painted facades exported")
	scene.queue_free()
	await process_frame
	if DisplayServer.get_name()!="headless" and OS.get_cmdline_user_args().has("--capture-suspicion"):
		root.size = Vector2i(1440,900)
		var sheet: Control = ContactSheet.new()
		sheet.size = Vector2(1440,900)
		root.add_child(sheet)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		expect(root.get_texture().get_image().save_png("C:/Users/flavi/Desktop/CODEX_niente_zombie_per_favore/docs/SOPRAVVISSUTI-INDIZI-v04.png")==OK,"native contact sheet exported")
		sheet.queue_free()
		await process_frame
	print("Suspicion visuals: %d checks, %d failures." % [checks,failures])
	quit(0 if failures==0 else 1)

func ready_build(model: Node, kind: String) -> bool:
	var fixture: Script = load(get_script().resource_path.get_base_dir().path_join("construction_fixture.gd"))
	return fixture.build_ready(model,kind)
