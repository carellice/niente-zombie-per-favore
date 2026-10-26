extends SceneTree
## JNI doubles verify the real bridge's API branches; they cannot measure a panel.

var checks: int = 0
var failures: int = 0
var received: Dictionary = {}
const NATIVE = preload("res://scripts/android_frame_rate.gd")

class Version extends RefCounted:
	var SDK_INT: int = 35

class Java extends RefCounted:
	var version: Version = Version.new()
	var exception: Variant = null
	func wrap(_name: String) -> Object: return version
	func get_exception() -> Variant:
		var value: Variant = exception
		exception = null
		return value

class Mode extends RefCounted:
	var id: int
	var hz: float
	var size: Vector2i
	func _init(key: int, rate: float, dimensions: Vector2i=Vector2i(2400,1080)) -> void:
		id = key
		hz = rate
		size = dimensions
	func getModeId() -> int: return id
	func getRefreshRate() -> float: return hz
	func getPhysicalWidth() -> int: return size.x
	func getPhysicalHeight() -> int: return size.y

class Field extends RefCounted:
	var key: String
	func _init(name: String) -> void: key = name
	func setInt(attrs: Object, value: int) -> void: attrs.set(key,value)
	func setFloat(attrs: Object, value: float) -> void: attrs.set(key,value)

class Platform extends RefCounted:
	var valid: bool = true
	var missing: bool = false
	var reject: bool = false
	var java: Java
	var calls: Array = []
	var modes: Array = [Mode.new(1,60),Mode.new(2,90),Mode.new(3,119.88),Mode.new(4,144),Mode.new(5,120,Vector2i(3200,1440))]
	var preferredDisplayModeId: int = 0
	var preferredRefreshRate: float = 0
	var window_writes: int = 0
	func getGodot() -> Object: return self
	func getRenderView() -> Object: return null if missing else self
	func getView() -> Object: return self
	func getHolder() -> Object: return self
	func getSurface() -> Object: return self
	func isValid() -> bool: return valid
	func setFrameRate(rate: float, compatibility: int, strategy: int=-1) -> void:
		calls.append([rate,compatibility,strategy])
		if reject: java.exception = "IllegalArgumentException"
	func getWindow() -> Object: return self
	func getWindowManager() -> Object: return self
	func getDefaultDisplay() -> Object: return self
	func getMode() -> Object: return modes[0]
	func getSupportedModes() -> Array: return modes
	func getAttributes() -> Object: return self
	func getClass() -> Object: return self
	func getField(name: String) -> Object: return Field.new(name)
	func setAttributes(_attrs: Object) -> void: window_writes += 1

class Bridge extends RefCounted:
	var calls: Array[int] = []
	var callbacks: Array[Callable] = []
	func request(rate: int, callback: Callable) -> void:
		calls.append(rate)
		callbacks.append(callback)

func _initialize() -> void: run.call_deferred()
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("DISPLAY FAIL: ",message)
func settle() -> void:
	await process_frame
	await process_frame
func complete(result: Dictionary) -> void: received = result

func test_native_bridge() -> void:
	var native: RefCounted = NATIVE.new()
	var java: Java = Java.new()
	var platform: Platform = Platform.new()
	platform.java = java
	for sdk: int in [30,31,35]:
		java.version.SDK_INT = sdk
		for rate: int in [120,60]:
			platform.calls.clear()
			var result: Dictionary = native.apply_on_ui_thread(platform,java,rate)
			expect(result.ok and result.method=="surface","API %d accepts %d Hz request" % [sdk,rate])
			expect(platform.calls.size()==1,"One Surface request per application")
			expect(platform.calls[0]==[float(rate),0,0 if sdk>=31 else -1],"Correct compatibility, overload and seamless strategy")
			expect(platform.window_writes==0,"Modern Android does not change Window display modes")
	platform.valid = false
	platform.calls.clear()
	var pending: Dictionary = native.apply_on_ui_thread(platform,java,120)
	expect(not pending.ok and pending.retry,"Invalid startup Surface asks for a bounded retry")
	expect(platform.calls.is_empty(),"Never submits to an invalid Surface")
	platform.valid = true
	platform.missing = true
	pending = native.apply_on_ui_thread(platform,java,120)
	expect(not pending.ok and pending.retry,"Missing render view is safe at startup")
	platform.missing = false
	platform.reject = true
	var rejected: Dictionary = native.apply_on_ui_thread(platform,java,120)
	expect(not rejected.ok and not rejected.retry,"Java exception is consumed and not retried endlessly")
	platform.reject = false
	java.version.SDK_INT = 29
	platform.calls.clear()
	for rate: int in [120,60]:
		var result: Dictionary = native.apply_on_ui_thread(platform,java,rate)
		expect(result.ok and result.method=="window","Older Android uses public Window attributes")
		expect(platform.preferredDisplayModeId==(3 if rate==120 else 1),"Legacy request chooses best same-resolution mode within limit")
		expect(is_equal_approx(platform.preferredRefreshRate,119.88 if rate==120 else 60.0),"Legacy refresh rate is actually supported")
	expect(platform.calls.is_empty(),"API 29 never invokes the API 30 Surface method")
	var size: Vector2i = Vector2i(2400,1080)
	expect(NATIVE.best_legacy_mode([],size,120).is_empty(),"No mode list leaves the OS in control")
	expect(NATIVE.best_legacy_mode([{"id":1,"size":size,"hz":144}],size,120).is_empty(),"Never requests unsupported or over-limit legacy mode")
	expect(NATIVE.best_legacy_mode([{"id":1,"size":size,"hz":90}],size,120).id==1,"90 Hz panels retain 90 Hz support")
	expect(NATIVE.best_legacy_mode([{"id":1,"size":size,"hz":60}],size,120).id==1,"60 Hz panels retain 60 Hz support")
	native.request(120,complete)
	await settle()
	expect(not received.is_empty() and not received.ok and not received.retry,"Native entry point is a safe no-op on desktop")

func test_preferences() -> void:
	var prefs: Node = load("res://scripts/preferences.gd").new()
	prefs.settings_path = "user://display-test-preferences.cfg"
	expect(prefs.android_high_refresh,"New installations default to high refresh")
	var old: ConfigFile = ConfigFile.new()
	old.set_value("preferences","master_volume",0.42)
	expect(old.save(prefs.settings_path)==OK,"Old-format preferences fixture saves")
	expect(prefs.load_settings()==OK and prefs.android_high_refresh,"Existing preferences gain high refresh by default")
	expect(is_equal_approx(prefs.master_volume,0.42),"Migration retains existing audio preferences")
	prefs.apply_settings({"android_high_refresh":false})
	var copy: Node = load("res://scripts/preferences.gd").new()
	copy.settings_path = prefs.settings_path
	expect(copy.load_settings()==OK and not copy.android_high_refresh,"60 Hz choice survives restart")
	copy.apply_settings({"android_high_refresh":true})
	expect(prefs.load_settings()==OK and prefs.android_high_refresh,"120 Hz choice survives restart")
	prefs.free()
	copy.free()

func test_lifecycle() -> void:
	var prefs: Node = root.get_node("Preferences")
	var saved: Dictionary = prefs.snapshot()
	prefs.apply_settings({"android_high_refresh":true},false)
	var previous_limit: int = Engine.max_fps
	var physics_rate: int = Engine.physics_ticks_per_second
	var controller: Node = load("res://scripts/display_performance.gd").new()
	var bridge: Bridge = Bridge.new()
	controller.bridge = bridge
	root.add_child(controller)
	await settle()
	expect(bridge.calls.is_empty() and Engine.max_fps==previous_limit,"Desktop startup leaves render pacing untouched")
	controller.android = true
	controller._preferences_changed()
	expect(Engine.max_fps==120 and bridge.calls==[120],"Android sets render cap and requests 120 Hz together")
	controller._preferences_changed()
	expect(bridge.calls.size()==1,"Unrelated settings changes do not request a mode switch")
	var stale: Callable = bridge.callbacks[0]
	prefs.apply_settings({"android_high_refresh":false},false)
	controller._preferences_changed()
	expect(Engine.max_fps==60 and bridge.calls.back()==60,"60 Hz option updates native hint and cap immediately")
	bridge.callbacks.back().call({"ok":true,"retry":false,"method":"surface"})
	stale.call({"ok":false,"retry":true,"method":"stale"})
	expect(controller.last_result.method=="surface","Late result cannot overwrite the latest preference")
	controller._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var count: int = bridge.calls.size()
	controller._surface_changed()
	prefs.apply_settings({"android_high_refresh":true},false)
	controller._preferences_changed()
	expect(bridge.calls.size()==count,"Background layout/settings changes do not wake the display")
	controller._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await settle()
	expect(bridge.calls.size()==count+1 and bridge.calls.back()==120,"Resume reapplies the current preference")
	controller._surface_changed()
	expect(bridge.calls.size()==count+2,"Recreated/resized Surface receives a new hint")
	bridge.callbacks.back().call({"ok":false,"retry":true,"method":"pending"})
	await create_timer(0.3).timeout
	expect(bridge.calls.size()==count+3,"Surface not ready gets a delayed retry")
	controller._completed({"ok":false,"retry":true,"method":"pending"},controller._generation,controller.RETRY_DELAYS.size())
	await create_timer(0.3).timeout
	expect(bridge.calls.size()==count+3,"Retry budget is bounded")
	bridge.callbacks.back().call({"ok":false,"retry":true,"method":"pending"})
	controller._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await create_timer(0.6).timeout
	expect(bridge.calls.size()==count+3,"Pause cancels scheduled retries")
	controller._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await settle()
	expect(bridge.calls.back()==120 and bridge.calls.size()==count+4,"Lifecycle resume reapplies after a pause")
	expect(Engine.physics_ticks_per_second==physics_rate,"Physics tick rate remains unchanged")
	controller.android = false
	controller.queue_free()
	await settle()
	prefs.apply_settings(saved,false)
	Engine.max_fps = previous_limit

func test_game_time() -> void:
	var game: Node = root.get_node("Game")
	game.set_process(false)
	game.save_path = "user://display-test-colony.json"
	var reference: Dictionary = {}
	for fps: int in [60,90,120]:
		game._new_game()
		game.skip_tutorial()
		game.threats.clear()
		game.visitors.clear()
		game._visitor_timer = 10000.0
		game.wave_clock = 10000.0
		game._add_threat("walker",game.GATE_X-1000.0)
		game._spawn_visitor()
		game.visitors[0].x = game.GATE_X-900.0
		game.shot_cooldown = 20.0
		for frame: int in range(fps*2): game.advance(1.0/fps)
		var sample: Dictionary = {"zombie":float(game.threats[0].x),"visitor":float(game.visitors[0].x),"time":game.time_played,"cooldown":game.shot_cooldown}
		if reference.is_empty(): reference = sample
		for key: String in reference:
			expect(absf(float(reference[key])-float(sample[key]))<0.001,"Elapsed-time %s unchanged at %d fps" % [key,fps])

func run() -> void:
	root.get_node("Game").set_process(false)
	root.get_node("Preferences").settings_path = "user://display-global-test-preferences.cfg"
	await test_native_bridge()
	test_preferences()
	await test_lifecycle()
	test_game_time()
	print("ANDROID DISPLAY: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
