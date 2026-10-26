extends SceneTree
## Read the actual APK bitmaps, including the native boot image, not loose assets.
var checks: int = 0
var failures: int = 0
func _initialize() -> void:
	run.call_deferred()
func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("LAUNCHER FAIL: ",message)
func run() -> void:
	root.get_node("Game").paused = true
	var path: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--apk="): path = argument.trim_prefix("--apk=")
	var apk: ZIPReader = ZIPReader.new()
	if apk.open(path)!=OK:
		printerr("APK cannot be read: ",path)
		quit(1)
		return
	for density: Array in [["mdpi-v4",108],["hdpi-v4",162],["xhdpi-v4",216],["xxhdpi-v4",324],["xxxhdpi-v4",432]]:
		var foreground: Image = Image.new()
		var name: String = "res/mipmap-%s/icon_foreground.png" % str(density[0])
		expect(foreground.load_png_from_buffer(apk.read_file(name))==OK,"Foreground shipped: "+name)
		expect(foreground.get_size()==Vector2i(int(density[1]),int(density[1])),"Foreground has correct density: "+name)
		var radius: float = 0.0
		var center: Vector2 = Vector2(foreground.get_size())*0.5
		for y: int in range(foreground.get_height()):
			for x: int in range(foreground.get_width()):
				if foreground.get_pixel(x,y).a>0.02:
					radius = maxf(radius,Vector2(x,y).distance_to(center)/foreground.get_width())
		expect(radius>0.15 and radius<=66.0/108.0*0.5,"Complete icon fits circular safe zone: "+name)
		expect(foreground.get_pixel(0,0).a<0.01,"Foreground padding is transparent: "+name)
		var background: Image = Image.new()
		name = "res/mipmap-%s/icon_background.png" % str(density[0])
		expect(background.load_png_from_buffer(apk.read_file(name))==OK,"Adaptive background shipped: "+name)
		expect(background.get_pixel(0,0).a>0.99 and background.get_pixel(0,0).is_equal_approx(Color("173735")),"Background is opaque game teal: "+name)
	var boot: Image = Image.new()
	expect(boot.load_png_from_buffer(apk.read_file("assets/assets/android/icon_foreground.png"))==OK,"Native boot splash PNG shipped unmodified")
	expect(apk.file_exists("assets/loading.tscn.remap") and apk.file_exists("assets/scripts/loading_screen.gdc"),"Real loading scene and script shipped")
	for script: String in ["armory_panel","build_panel","expedition_panel","phone_pages","citizen_roaming","construction_panel","construction_visual","expedition_gear","citizen_equipment_panel","building_signage","demolition_panel","cozy_rules","cozy_panel","world_touch","mobile_hud","ui_chrome"]:
		expect(apk.file_exists("assets/scripts/"+script+".gdc"),"New UI controller shipped: "+script)
	var journal_import: ConfigFile = ConfigFile.new()
	expect(apk.file_exists("assets/scripts/resource_ui.gdc"),"Illustrated costs and resource legend shipped")
	expect(apk.file_exists("assets/scripts/visitor_observation.gdc"),"Clear visitor observation and verdicts shipped")
	for script: String in ["display_performance","android_frame_rate"]:
		expect(apk.file_exists("assets/scripts/"+script+".gdc"),"Android display controller shipped: "+script)
	var journal_loaded: bool = journal_import.parse(apk.read_file("assets/assets/art/journal.png.import").get_string_from_utf8())==OK
	var journal_texture: String = str(journal_import.get_value("remap","path",""))
	expect(journal_loaded and not journal_texture.is_empty() and apk.file_exists("assets/"+journal_texture.trim_prefix("res://")),"Painted journal icon is shipped")
	var cherry_import: ConfigFile = ConfigFile.new()
	var radio_import: ConfigFile = ConfigFile.new()
	var radio_loaded: bool = radio_import.parse(apk.read_file("assets/assets/art/community-radio.png.import").get_string_from_utf8())==OK
	var radio_texture: String = str(radio_import.get_value("remap","path",""))
	expect(radio_loaded and not radio_texture.is_empty() and apk.file_exists("assets/"+radio_texture.trim_prefix("res://")),"Cozy community radio texture is shipped")
	var imported: bool = cherry_import.parse(apk.read_file("assets/assets/art/cherries.png.import").get_string_from_utf8())==OK
	var cherry_texture: String = str(cherry_import.get_value("remap","path",""))
	expect(imported and not cherry_texture.is_empty() and apk.file_exists("assets/"+cherry_texture.trim_prefix("res://")),"Chiara's painted cherries and their imported texture are shipped")
	expect(apk.file_exists("res/mipmap-anydpi-v26/icon.xml"),"Adaptive icon XML shipped")
	apk.close()
	print("ANDROID LAUNCHER: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
