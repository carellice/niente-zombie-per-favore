extends SceneTree
## Native visual evidence: the portrait, actual game scale and walking rig.

const Actors = preload("res://scripts/actor_visuals.gd")
const Rig = preload("res://scripts/walking_rig.gd")
const Typography = preload("res://scripts/typography.gd")
const Names = preload("res://scripts/survivor_appearances.gd")

class Gallery extends Control:
	var phase: float = 0.0
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size),Color("efe6cf"))
		draw_string(Typography.heading(),Vector2(24,44),"12 VOLTI PER UNA NUOVA VITA",HORIZONTAL_ALIGNMENT_LEFT,-1,34,Color("355143"))
		draw_string(Typography.body(),Vector2(24,76),"Stessa identità nel ritratto e nel mondo · camminata con due piedi alternati",HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("687457"))
		for i: int in range(12):
			var look: int = Actors.CIVILIAN_LOOKS[i]
			var at: Vector2 = Vector2(16+(i%4)*316,94+floori(float(i)/4.0)*272)
			var label: String = ["Contadina","Barista","Meccanica","Dottoressa"][i] if i<4 else Names.LABELS[i-4]
			draw_rect(Rect2(at,Vector2(302,258)),Color("dedfc2"))
			draw_string(Typography.heading(),at+Vector2(14,29),label,HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("355143"))
			var source: Texture2D = Actors.texture(look)
			var h: float = 170.0
			var w: float = h*source.get_width()/source.get_height()
			draw_texture_rect(source,Rect2(at+Vector2(70-w*.5,64),Vector2(w,h)),false)
			draw_line(at+Vector2(137,234),at+Vector2(292,234),Color("9ba77d"),2.0)
			Rig.draw_actor(self,look,phase,170,at+Vector2(220,234))
			Rig.draw_actor(self,look,phase,78,at+Vector2(155,234))
			draw_string(Typography.body(),at+Vector2(15,250),"RITRATTO",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("687457"))
			draw_string(Typography.body(),at+Vector2(143,250),"78px",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("687457"))
			draw_string(Typography.body(),at+Vector2(209,250),"CAMMINATA",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("687457"))

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size=Vector2i(1280,920)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var stage: Gallery=Gallery.new()
	stage.size=Vector2(viewport.size)
	viewport.add_child(stage)
	await process_frame
	for phase: float in [0.0,0.25,0.5,0.75]:
		stage.phase=phase
		stage.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var path: String="res://docs/SOPRAVVISSUTI-VARIANTI-%02d.png"%roundi(phase*100)
		var err: Error=viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
		if err!=OK:
			push_error("Survivor gallery capture failed: "+str(err))
			quit(1)
			return
	print("Saved four native survivor variant galleries.")
	viewport.queue_free()
	await process_frame
	quit(0)
