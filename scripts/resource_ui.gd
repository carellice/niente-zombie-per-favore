extends RefCounted
## Painted amounts replace repeated unit names, while actions remain readable.
const NAMES = {"coin":"monete","crate":"provviste","bill":"banconote","build":"materiali","ammo":"colpi","compass":"tempo","people":"persone","home":"letti liberi","coffee":"cibo","goods":"beni","heart":"servizi","sun":"giorno","stock":"pezzi","discoveries":"scoperte","health":"salute"}
const SYMBOLS = {"stock":"crate","discoveries":"compass","health":"heart"}

static func amount(ui: CanvasLayer, key: String, value: Variant, tint: Color, pixels: int=28) -> HBoxContainer:
	var row: HBoxContainer = ui._hbox(6)
	row.name = "Amount_"+key
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_meta("resource",key)
	row.set_meta("amount",str(value))
	var icon: Control = ui._weapon_icon("ammo",Vector2(pixels+6,pixels)) if key=="ammo" else ui._icon("crate" if key=="goods" else str(SYMBOLS.get(key,key)),pixels)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var label: Label = ui._label(str(value),19,tint,true)
	label.name = "Quantity"
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	row.tooltip_text = str(value)+" "+str(NAMES.get(key,key))
	return row

static func row(ui: CanvasLayer, entries: Array, tint: Color, centered: bool=false) -> HFlowContainer:
	var flow: HFlowContainer = HFlowContainer.new()
	flow.name = "ResourceAmounts"
	flow.add_theme_constant_override("h_separation",16)
	flow.add_theme_constant_override("v_separation",6)
	flow.alignment = FlowContainer.ALIGNMENT_CENTER if centered else FlowContainer.ALIGNMENT_BEGIN
	flow.mouse_filter = Control.MOUSE_FILTER_PASS
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hints: PackedStringArray = []
	for entry: Array in entries:
		flow.add_child(amount(ui,str(entry[0]),entry[1],tint))
		hints.append(str(entry[1])+" "+str(NAMES.get(str(entry[0]),entry[0])))
	flow.tooltip_text = " · ".join(hints)
	return flow

static func costs(coins: int=0, supplies: int=0, parts: int=0, gems: int=0) -> Array:
	var entries: Array = []
	for entry: Array in [["coin",coins],["crate",supplies],["build",parts],["bill",gems]]:
		if int(entry[1])>0: entries.append(entry)
	return entries

static func set_button(ui: CanvasLayer, button: Button, caption: String, entries: Array, primary: bool=false) -> void:
	button.text = caption # Keep a meaningful native label for accessibility/input.
	button.clip_text = true
	var content: VBoxContainer = button.get_node_or_null("CostButtonContent")
	if content==null:
		button.set_meta("cost_button",true)
		button.set_meta("base_height",button.custom_minimum_size.y)
		content = ui._button_stack(button,4,Vector2(12,10))
		content.name = "CostButtonContent"
		var title: Label = ui._copy(caption,18,ui.CREAM if primary else ui.TEXT)
		title.name = "ActionCaption"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_override("font",ui.heading)
		content.add_child(title)
		# The real Button still handles every gesture; decorative children ignore it.
		for state: String in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color","font_disabled_color"]:
			button.add_theme_color_override(state,Color.TRANSPARENT)
		content.minimum_size_changed.connect(func() -> void:
			button.custom_minimum_size.y = maxf(float(button.get_meta("base_height")),content.get_combined_minimum_size().y+20)
		)
		button.draw.connect(func() -> void: content.modulate.a = 0.48 if button.disabled else 1.0)
	content.get_node("ActionCaption").text = caption
	var signature: String = str(entries.map(func(entry: Array) -> String: return str(entry[0])))
	var amounts: HFlowContainer = content.get_node_or_null("ButtonCosts")
	if amounts==null or button.get_meta("cost_keys","")!=signature:
		if amounts!=null:
			content.remove_child(amounts)
			amounts.queue_free()
		amounts = row(ui,entries,ui.CREAM if primary else ui.TEXT,true)
		amounts.name = "ButtonCosts"
		amounts.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(amounts)
		button.set_meta("cost_keys",signature)
	else:
		for index: int in range(entries.size()):
			var item: Control = amounts.get_child(index)
			item.set_meta("amount",str(entries[index][1]))
			item.get_node("Quantity").text = str(entries[index][1])
	amounts.visible = not entries.is_empty()
	var hints: PackedStringArray = [caption]
	for entry: Array in entries: hints.append(str(entry[1])+" "+str(NAMES.get(str(entry[0]),entry[0])))
	button.tooltip_text = " · ".join(hints)
	button.set_meta("displayed_amounts",entries.duplicate(true))
	button.queue_redraw()
