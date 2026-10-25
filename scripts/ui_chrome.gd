extends RefCounted
## Shared visual language; animations never move a control's actual hit rectangle.
const FOREST = Color("264e43")
const MINT = Color("b6d6bd")
const PAPER = Color("f8f4e9")
const HONEY = Color("efc776")

class PageDecoration extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func _draw() -> void:
		var width: float = DeviceLayout.safe_rect().position.x+104
		draw_rect(Rect2(0,0,width,size.y),FOREST)
		draw_rect(Rect2(width,0,2,size.y),Color("d8bd82"))
		# A restrained stitched edge links the modern page to the painted village.
		for y: int in range(24,int(size.y)-20,18):
			draw_line(Vector2(width-7,y),Vector2(width-7,y+5),Color(0.75,0.86,0.75,0.24),1,true)

class ButtonInk extends Control:
	var amount: float = 0.0:
		set(value): amount = value; queue_redraw()
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		if amount<=0.001: return
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = Color(1.0,0.93,0.71,amount*0.18)
		box.set_corner_radius_all(18)
		draw_style_box(box,Rect2(Vector2(2,2),size-Vector2(4,4)))

static func decorate_button(button: Button) -> void:
	var ink: ButtonInk = ButtonInk.new()
	ink.name = "TouchInk"
	ink.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(ink)
	button.button_down.connect(func() -> void:
		if not is_instance_valid(ink) or Preferences.reduced_motion: return
		if ink.has_meta("motion"):
			var previous: Tween = ink.get_meta("motion")
			if previous.is_valid(): previous.kill()
		var tween: Tween = ink.create_tween()
		ink.set_meta("motion",tween)
		tween.tween_property(ink,"amount",1.0,0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	button.button_up.connect(func() -> void:
		if not is_instance_valid(ink): return
		if Preferences.reduced_motion:
			ink.amount = 0
			return
		if ink.has_meta("motion"):
			var previous: Tween = ink.get_meta("motion")
			if previous.is_valid(): previous.kill()
		var tween: Tween = ink.create_tween()
		ink.set_meta("motion",tween)
		tween.tween_property(ink,"amount",0.0,0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)

static func reveal(parent: Control) -> void:
	if Preferences.reduced_motion: return
	var index: int = 0
	for child: Node in parent.get_children():
		if not child is Control or not child.visible: continue
		var control: Control = child
		control.modulate.a = 0
		var tween: Tween = control.create_tween()
		tween.tween_interval(minf(0.12,index*0.025))
		tween.tween_property(control,"modulate:a",1.0,0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		index += 1

static func select_nav(ui: CanvasLayer, key: String) -> void:
	for name: String in ui.nav_buttons:
		var button: Button = ui.nav_buttons[name]
		var selected: bool = key==name
		button.add_theme_stylebox_override("normal",ui._raised(FOREST if selected else Color("faf5e7"),Color("d8bd82") if selected else Color("c8d1bc"),22,false,8))
		button.add_theme_stylebox_override("hover",ui._raised(Color("456f58") if selected else Color("fff9eb"),Color("b6c8b0"),22,false,8))
		var group: VBoxContainer = button.get_node("ButtonContent")
		var caption: Label = group.get_child(1)
		caption.add_theme_color_override("font_color",Color("fff4d9") if selected else FOREST)
		if selected and not button.get_meta("selected",false) and not Preferences.reduced_motion:
			# Animate the icon, not its parent button: taps keep a stable target.
			var icon: Control = group.get_child(0)
			icon.pivot_offset = icon.size*0.5
			icon.scale = Vector2.ONE*0.84
			var tween: Tween = icon.create_tween()
			tween.tween_property(icon,"scale",Vector2.ONE,0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		button.set_meta("selected",selected)

static func retire(control: Control) -> void:
	if Preferences.reduced_motion:
		control.hide()
		control.queue_free()
		return
	# Public modal references are cleared immediately; the departing view is inert.
	for node: Node in control.find_children("*","Control",true,false): node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween: Tween = control.create_tween()
	tween_out(tween,control)

static func tween_out(tween: Tween, control: Control) -> void:
	tween.tween_property(control,"modulate:a",0.0,0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(control.queue_free)
