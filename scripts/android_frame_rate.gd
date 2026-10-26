extends RefCounted
## Android's display request is separate from Godot's render-frame limit.
## AndroidRuntime is built into the standard 4.5 export templates; no permissions.

func request(rate: int, completed: Callable) -> void:
	if not OS.has_feature("android") or not Engine.has_singleton("AndroidRuntime") or not Engine.has_singleton("JavaClassWrapper"):
		completed.call_deferred({"ok":false,"retry":false,"method":"unavailable"})
		return
	var runtime: Object = Engine.get_singleton("AndroidRuntime")
	var java: Object = Engine.get_singleton("JavaClassWrapper")
	var activity: Object = runtime.getActivity()
	if activity==null:
		completed.call_deferred({"ok":false,"retry":true,"method":"activity_pending"})
		return
	# Java calls that touch a Window/Surface belong on Android's UI thread.
	# Only the deferred completion below returns to the Godot main thread.
	var work: Callable = func() -> void:
		completed.call_deferred(apply_on_ui_thread(activity,java,rate))
	activity.runOnUiThread(runtime.createRunnableFromGodotCallable(work))

func _invoke(java: Object, target: Object, method: String, args: Array=[]) -> Variant:
	if target==null: return null
	var result: Variant = target.callv(method,args)
	return result if java.get_exception()==null else null

func apply_on_ui_thread(activity: Object, java: Object, rate: int) -> Dictionary:
	var version: Object = java.wrap("android.os.Build$VERSION")
	if java.get_exception()!=null or version==null:
		return {"ok":false,"retry":false,"method":"version_unavailable"}
	var sdk: int = int(version.SDK_INT)
	if sdk>=30:
		var engine: Object = _invoke(java,activity,"getGodot")
		var render_view: Object = _invoke(java,engine,"getRenderView")
		var view: Object = _invoke(java,render_view,"getView")
		var holder: Object = _invoke(java,view,"getHolder")
		var surface: Object = _invoke(java,holder,"getSurface")
		if surface==null or not bool(_invoke(java,surface,"isValid")):
			return {"ok":false,"retry":true,"method":"surface_pending"}
		# DEFAULT compatibility suits an interactive game. Only seamless changes:
		# never change the screen resolution or blank the panel to reach 120 Hz.
		if sdk>=31: surface.setFrameRate(float(rate),0,0)
		else: surface.setFrameRate(float(rate),0)
		if java.get_exception()==null:
			return {"ok":true,"retry":false,"method":"surface"}
		return {"ok":false,"retry":false,"method":"surface_rejected"}
	return _legacy_window_request(activity,java,rate)

static func best_legacy_mode(modes: Array, current: Vector2i, target: int) -> Dictionary:
	var best: Dictionary = {}
	for mode: Dictionary in modes:
		var hz: float = float(mode.get("hz",0.0))
		if Vector2i(mode.get("size",Vector2i.ZERO))!=current or hz<=0.0 or hz>target+0.1: continue
		if hz>float(best.get("hz",0.0)): best = mode
	return best

func _legacy_window_request(activity: Object, java: Object, rate: int) -> Dictionary:
	var window: Object = _invoke(java,activity,"getWindow")
	var display: Object = _invoke(java,activity,"getWindowManager")
	display = _invoke(java,display,"getDefaultDisplay")
	var current: Object = _invoke(java,display,"getMode")
	var native_modes: Variant = _invoke(java,display,"getSupportedModes")
	if window==null or current==null or native_modes==null:
		return {"ok":false,"retry":true,"method":"window_pending"}
	var dimensions: Vector2i = Vector2i(int(current.getPhysicalWidth()),int(current.getPhysicalHeight()))
	var modes: Array = []
	for mode: Object in native_modes:
		modes.append({"id":int(mode.getModeId()),"hz":float(mode.getRefreshRate()),"size":Vector2i(int(mode.getPhysicalWidth()),int(mode.getPhysicalHeight()))})
	if java.get_exception()!=null: return {"ok":false,"retry":false,"method":"modes_unavailable"}
	var choice: Dictionary = best_legacy_mode(modes,dimensions,rate)
	var attrs: Object = _invoke(java,window,"getAttributes")
	var attrs_class: Object = _invoke(java,attrs,"getClass")
	# JavaObject exposes methods and constants, not mutable Java fields.
	# Public reflection writes LayoutParams without relying on hidden APIs.
	var mode_field: Object = _invoke(java,attrs_class,"getField",["preferredDisplayModeId"])
	var rate_field: Object = _invoke(java,attrs_class,"getField",["preferredRefreshRate"])
	if mode_field==null or rate_field==null:
		return {"ok":false,"retry":false,"method":"attributes_unavailable"}
	mode_field.setInt(attrs,int(choice.get("id",0)))
	if java.get_exception()!=null: return {"ok":false,"retry":false,"method":"mode_rejected"}
	rate_field.setFloat(attrs,float(choice.get("hz",0.0)))
	if java.get_exception()!=null: return {"ok":false,"retry":false,"method":"rate_rejected"}
	window.setAttributes(attrs)
	return {"ok":java.get_exception()==null,"retry":false,"method":"window"}
