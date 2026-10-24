extends SceneTree
## Range feedback must agree with the firing rules without blinking on reload.
## Native rendering additionally compares a frozen scene with/without its halos.

var game: Node
var scene: Control
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("TARGET OUTLINE FAIL: ",description)

func add_enemy(kind: String, world_x: float) -> Dictionary:
	game._add_threat(kind,world_x)
	return game.threats.back()

func draw_frame() -> void:
	scene.queue_redraw()
	await process_frame
	await process_frame
	await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw

func changed_pixels(first: Image, second: Image, region: Rect2i) -> int:
	var area: Rect2i = region.intersection(Rect2i(Vector2i.ZERO,first.get_size()))
	var count: int = 0
	for y: int in range(area.position.y,area.end.y):
		for x: int in range(area.position.x,area.end.x):
			var a: Color = first.get_pixel(x,y)
			var b: Color = second.get_pixel(x,y)
			if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))>0.025:
				count += 1
	return count

func actor_region(enemy: Dictionary) -> Rect2i:
	var height: float = (108.0 if str(enemy.kind)=="brute" else 80.0)*scene.zoom
	return Rect2i(Vector2i(floori(scene._sx(float(enemy.x))-height*0.75-10.0),floori(scene._ground()-height-12.0)),Vector2i(ceili(height*1.5+20.0),ceili(height+32.0)))

func capture_feedback() -> void:
	if DisplayServer.get_name()=="headless" or not OS.get_cmdline_user_args().has("--capture-outline"):
		return
	game.threats.clear()
	game.visitors.clear()
	game.departing_visitors.clear()
	game.citizens.clear()
	scene.hit_flashes.clear()
	scene.actor_gaits.clear()
	scene.camera_x = -1000.0
	scene.target_camera = scene.camera_x
	scene.zoom = 0.98
	scene.target_zoom = scene.zoom
	scene.shake = 0.0
	scene.particles.clear()
	scene.shots.clear()
	game.weapon = "pistol"
	game.ammo = 24
	game.paused = false
	var far: Dictionary = add_enemy("walker",-800.0)
	var near: Dictionary = add_enemy("walker",-300.0)
	var runner: Dictionary = add_enemy("runner",-90.0)
	var brute: Dictionary = add_enemy("brute",100.0)
	for enemy: Dictionary in game.threats:
		scene.actor_gaits["enemy:%d" % int(enemy.id)] = {"phase":0.25,"blend":1.0,"x":float(enemy.x)}
	scene.ui._update_hud()
	scene.ui.toast_stack.visible = false
	scene._sync_target_outlines()
	await draw_frame()
	var with_outline: Image = root.get_texture().get_image()
	expect(with_outline.save_png("C:/Users/flavi/Desktop/CODEX_niente_zombie_per_favore/docs/CONTORNO-PORTATA.png")==OK,"native screenshot saved")
	# Keep every actor, pose, UI control and light frozen; only omit the draw
	# cache. This proves the actual renderer produced a local silhouette glow.
	var original_outlines: Dictionary = scene.target_outlines.duplicate()
	scene.target_outlines.clear()
	await draw_frame()
	var without_outline: Image = root.get_texture().get_image()
	expect(with_outline.get_size()==without_outline.get_size(),"render comparison has matching viewports")
	if with_outline.get_size()==without_outline.get_size():
		expect(changed_pixels(with_outline,without_outline,actor_region(far))==0,"distant walker has no rendered halo")
		for enemy: Dictionary in [near,runner,brute]:
			var changed: int = changed_pixels(with_outline,without_outline,actor_region(enemy))
			expect(changed>35,"visible silhouette glow renders around "+str(enemy.kind))
	scene.target_outlines = original_outlines
	await draw_frame()

func run() -> void:
	game = root.get_node("Game")
	game.save_path = "user://target-outline-test-save.json"
	game.set_process(false)
	game._new_game()
	game.skip_tutorial()
	var preferences: Node = root.get_node("Preferences")
	preferences.settings_path = "user://target-outline-test-settings.cfg"
	preferences.apply_settings({"sound_enabled":false,"screen_shake":false,"fullscreen":false},false)
	root.size = Vector2i(1440,900)
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.set_process(false)
	scene.ui._start_game()
	scene.ui._close_modal()
	game.paused = false
	scene.camera_x = -850.0
	scene.target_camera = scene.camera_x
	scene.zoom = 0.82
	scene.target_zoom = scene.zoom
	game.owned_weapons = ["pistol","shotgun","sniper","smg"]
	var enemy: Dictionary = add_enemy("walker",100.0)
	for key: String in ["pistol","shotgun","sniper","smg"]:
		game.weapon = key
		game.ammo = 24
		var reach: float = float(game.WEAPONS[key]["range"])
		enemy.x = game.GATE_X-reach-0.1
		expect(not scene._enemy_in_weapon_range(enemy),key+" excludes targets just beyond reach")
		enemy.x = game.GATE_X-reach
		expect(scene._enemy_in_weapon_range(enemy),key+" includes its exact range boundary")
		enemy.x = game.GATE_X-reach+0.1
		expect(scene._enemy_in_weapon_range(enemy),key+" includes targets inside reach")
	game.weapon = "sniper"
	game.ammo = 0
	enemy.x = game.GATE_X-1000.0
	expect(not scene._enemy_in_weapon_range(enemy),"empty sniper uses pistol fallback range immediately")
	enemy.x = game.GATE_X-float(game.WEAPONS.pistol.range)
	expect(scene._enemy_in_weapon_range(enemy),"empty nonpistol includes the fallback pistol boundary")
	game.ammo = 24
	game.weapon = "pistol"
	enemy.x = 100.0
	game.shot_cooldown = 5.0
	expect(scene._enemy_in_weapon_range(enemy),"reload cooldown does not blink away range feedback")
	game.paused = true
	expect(scene._enemy_in_weapon_range(enemy),"pause preserves the visible distance cue")
	game.paused = false
	scene.in_main_menu = true
	expect(not scene._enemy_in_weapon_range(enemy),"main menu suppresses the combat cue")
	scene.in_main_menu = false
	var unknown: Dictionary = enemy.duplicate()
	unknown.id = -999
	expect(not scene._enemy_in_weapon_range(unknown),"unregistered target cannot gain a halo")
	var original_hp: float = float(enemy.hp)
	enemy.hp = 0.0
	expect(not scene._enemy_in_weapon_range(enemy),"defeated target cannot gain a halo")
	enemy.hp = original_hp
	scene._sync_target_outlines()
	expect(scene.target_outlines.has(int(enemy.id)),"visible in-range threat gets a cached silhouette")
	var first: Node = scene.target_outlines.get(int(enemy.id))
	scene._sync_target_outlines()
	expect(scene.target_outlines.get(int(enemy.id))==first,"unchanged enemy reuses its viewport")
	# Visitors may share the same civilian illustration as a revealed
	# infiltrator; membership in threats is what enables combat feedback.
	game._spawn_visitor()
	var visitor: Dictionary = game.visitors.back()
	visitor.x = 100.0
	scene._sync_target_outlines()
	expect(scene.target_outlines.size()==1,"visitor creates no combat silhouette")
	var infiltrator: Dictionary = add_enemy("infiltrator",150.0)
	infiltrator.look = 10
	infiltrator.appearance = "infected"
	infiltrator.facing_left = true
	scene.actor_gaits["enemy:%d" % int(infiltrator.id)] = {"phase":0.37,"blend":0.8,"x":150.0}
	scene._sync_target_outlines()
	expect(scene.target_outlines.has(int(infiltrator.id)),"revealed infiltrator is highlighted as a real threat")
	var infiltrator_outline: Node = scene.target_outlines.get(int(infiltrator.id))
	check_pose(infiltrator_outline,infiltrator,0)
	scene.hit_flashes[int(infiltrator.id)] = 0.1
	scene._sync_target_outlines()
	check_pose(infiltrator_outline,infiltrator,3)
	# Exercise the real presentation loop: the flash expires before the mask
	# is synchronized, so both silhouette and body return to walking together.
	scene.hit_flashes[int(infiltrator.id)] = 0.01
	scene._process(0.02)
	expect(not scene.hit_flashes.has(int(infiltrator.id)) and int(infiltrator_outline.mask.frame)==0,"expired hit flash returns body and contour to walking in the same frame")
	scene.set_process(false)
	scene.hit_flashes.clear()
	game.threats.erase(infiltrator)
	scene._sync_target_outlines()
	expect(not scene.target_outlines.has(int(infiltrator.id)),"defeated/removed infiltrator drops its viewport cache")
	enemy.x = -800.0
	scene._sync_target_outlines()
	expect(not scene.target_outlines.has(int(enemy.id)),"moving out of range releases its viewport")
	game.weapon = "sniper"
	scene._sync_target_outlines()
	expect(scene.target_outlines.has(int(enemy.id)),"switching to long rifle updates the cue immediately")
	scene.camera_x = 1500.0
	scene.target_camera = scene.camera_x
	scene._sync_target_outlines()
	expect(scene._enemy_in_weapon_range(enemy),"panning camera never changes physical weapon reach")
	expect(scene.target_outlines.is_empty(),"offscreen threat releases its unnecessary viewport")
	scene.camera_x = -850.0
	scene.target_camera = scene.camera_x
	game.weapon = "pistol"
	enemy.x = 100.0
	scene._sync_target_outlines()
	expect(scene.target_outlines.has(int(enemy.id)),"returning to view restores the appropriate cue")
	scene.in_main_menu = true
	scene._sync_target_outlines()
	expect(scene.target_outlines.is_empty(),"opening main menu releases combat viewports")
	scene.in_main_menu = false
	await capture_feedback()
	scene.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	for path: String in [game.save_path,game.save_path+".tmp",game.save_path+".bak",preferences.settings_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	print("Target outline: %d checks, %d failures." % [checks,failures])
	quit(0 if failures==0 else 1)

func check_pose(outline: Node, enemy: Dictionary, frame: int) -> void:
	if outline==null:
		expect(false,"pose mask exists")
		return
	# These are renderer inputs, not a second animation. Matching them to the
	# source actor prevents lagging feet, alternate portraits and seam flashes.
	var mask: Node = outline.get("mask")
	expect(mask!=null,"outline exposes the composed actor mask")
	if mask==null:
		return
	expect(int(mask.get("look"))==10 and not bool(mask.get("zombie")),"mask uses infiltrator's exact civilian identity")
	expect(is_equal_approx(float(mask.get("phase")),0.37) and is_equal_approx(float(mask.get("blend")),0.8),"mask follows the existing alternating-foot gait")
	expect(bool(mask.get("facing_left")) and str(mask.get("appearance"))=="infected","mask matches facing direction and appearance")
	expect(int(mask.get("frame"))==frame,"mask matches the actor's hit/idle frame")
	var viewport: SubViewport = outline.get("viewport")
	expect(viewport!=null and viewport.transparent_bg,"silhouette composition uses transparent viewport")
