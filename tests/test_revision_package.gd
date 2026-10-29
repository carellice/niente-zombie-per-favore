extends SceneTree
## Run against the exported executable to check the actual shipped resources.

var checks: int = 0
var failures: int = 0

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("PACKAGE FAIL: ", description)

func _initialize() -> void:
	expect(FileAccess.file_exists("res://project.binary") and not FileAccess.file_exists("res://tools/godot/Godot_v4.5.1-stable_win64_console.exe"), "Tests run against the exported resource pack")
	var voices = load("res://scripts/character_voices.gd")
	var sound_bank = load("res://scripts/sound_bank.gd")
	for kind: String in ["walker", "runner", "brute"]:
		for variant: int in range(3):
			var stream: AudioStream = voices.zombie(kind, variant)
			expect(stream != null and stream.get_length() > 0.15, "Recorded zombie sample shipped: %s %d" % [kind, variant])
	for key: String in ["shot_pistol", "shot_shotgun", "shot_sniper", "shot_smg", "reload_shotgun", "reload_sniper", "reload_smg"]:
		var stream: AudioStream = sound_bank.sound(key)
		expect(stream != null and stream.get_length() > 0.02, "Weapon audio shipped: " + key)
		expect(stream != null and stream.resource_path.begins_with("res://assets/audio/user/"), "Shipped weapon uses supplied recording: " + key)
	var zombie: AudioStreamOggVorbis = load("res://assets/audio/user/zombie.ogg") as AudioStreamOggVorbis
	expect(zombie != null and absf(zombie.get_length() - 92.725) < 0.02, "Complete supplied zombie recording shipped")
	expect(zombie != null and not zombie.loop, "Zombie recording uses crossfades instead of decoder hard loop")
	expect(ResourceLoader.exists("res://scripts/zombie_soundscape.gd"), "Two-stream zombie soundscape shipped")
	expect(ResourceLoader.exists("res://scripts/building_feedback.gd"), "Building silhouette and click feedback shipped")
	expect(sound_bank.sound("ui").resource_path == "res://assets/audio/ui_click.wav", "New soft interface click shipped and active")
	expect(FileAccess.file_exists("res://assets/audio/LICENSE-Kenney-UI.txt"), "Interface click source license shipped")
	expect(FileAccess.file_exists("res://assets/audio/user/manifest.json"), "User audio source manifest shipped")
	for original: String in ["pistola", "fucile a pompa", "fucile di precisione", "mitragliatore", "ricarica arma", "zombie"]:
		expect(not ResourceLoader.exists("res://suoni/" + original + ".mp3"), "Raw source is not duplicated inside resource pack: " + original)
	expect(voices.civilian(0, 0) == null and voices.civilian_count(0) == 0, "Survivor voices disabled in shipped bank")
	var directory = DirAccess.open("res://assets/audio/voices")
	var human_samples: Array[String] = []
	if directory:
		for filename: String in directory.get_files():
			if filename.begins_with("civilian_"):
				human_samples.append(filename)
	expect(directory != null and human_samples.is_empty(), "No legacy survivor voice files included in build")
	for path: String in ["res://assets/audio/voices/SOURCES.txt", "res://assets/audio/voices/LICENSE-CC0.txt", "res://assets/audio/LICENSE-CC0-Revision.txt", "res://assets/audio/revision-sources.json"]:
		expect(FileAccess.file_exists(path), "Source/license shipped: " + path)
	expect(ResourceLoader.exists("res://scripts/weapon_icon.gd"), "Weapon icons shipped")
	for icon: String in ["pistol", "shotgun", "sniper", "smg", "ammo"]:
		var artwork: Texture2D = load("res://assets/art/weapons/%s.png" % icon) as Texture2D
		expect(artwork != null and artwork.get_width() >= 512, "Painted imagegen artwork shipped: " + icon)
	expect(ResourceLoader.exists("res://assets/art/survivors-expanded.png"), "Expanded character art shipped")
	var new_art: Array[String] = ["res://assets/art/population.png","res://assets/art/community-radio.png"]
	for product: String in ["biscuit","breakfast","vegetables","tools","repair","cloth","bandage","medkit","medicine","water","bread"]:
		new_art.append("res://assets/art/products/%s.png" % product)
	for building: String in ["bakery","waterworks","tailor"]:
		new_art.append("res://assets/art/buildings/%s.png" % building)
	for path: String in new_art:
		var artwork: Texture2D = load(path) as Texture2D
		expect(artwork != null and artwork.get_width() >= 512, "Revision 0.4 painted artwork shipped: " + path)
		expect(artwork != null and artwork.get_image().has_mipmaps(), "Downscaled artwork has its mip chain: " + path)
	for source: String in ["characters","survivors-expanded"]:
		for condition: String in ["dirty","infected"]:
			var artwork: Texture2D = load("res://assets/art/%s-%s.png" % [source,condition]) as Texture2D
			expect(artwork != null and artwork.get_size() == Vector2(1536,1024), "Condition atlas preserves original UV dimensions: " + source + " " + condition)
	var catalog = load("res://scripts/content_catalog.gd")
	expect(catalog.BUILDING_NAMES.size()==8, "Eight building types shipped")
	expect(catalog.ZONES.size()==9, "Nine expedition destinations shipped")
	expect(catalog.make_quests().size()==32, "Thirty-two diary goals shipped")
	expect(ResourceLoader.exists("res://scripts/cozy_rules.gd") and ResourceLoader.exists("res://scripts/cozy_panel.gd"),"Cozy gameplay and redesigned panels shipped")
	var journal: Texture2D = load("res://scripts/hud_icons.gd").texture("journal")
	expect(journal!=null and journal.get_width()>200 and journal.get_image().has_mipmaps(),"Painted journal icon has isolated mipmaps")
	for module: String in ["world_touch","mobile_hud","ui_chrome","display_performance","android_frame_rate","resource_ui","visitor_observation","workforce_panel"]:
		expect(ResourceLoader.exists("res://scripts/"+module+".gd"),"Mobile presentation module shipped: "+module)
	print("REVISION PACKAGE: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
