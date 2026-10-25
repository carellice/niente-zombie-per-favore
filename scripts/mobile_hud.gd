extends RefCounted
const Chrome = preload("res://scripts/ui_chrome.gd")

static func header(ui: CanvasLayer) -> void:
	ui._header = PanelContainer.new()
	ui._header.name = "PhoneHeader"
	ui._header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	ui._header.add_theme_stylebox_override("panel",ui._floating_group(8))
	ui.hud.add_child(ui._header)
	var row: HBoxContainer = ui._hbox(9)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	ui._header_row = row
	ui._header.add_child(row)
	ui.coin_label = ui._resource_pill(row,"coin","MONETE",ui.GOLD,92)
	ui.supply_label = ui._resource_pill(row,"crate","PROVVISTE",ui.SAGE,80)
	ui.gem_label = ui._resource_pill(row,"bill","BANCONOTE",ui.SAGE,74)
	row.add_child(ui._spacer())
	ui.day_label = ui._resource_pill(row,"sun","GIORNO",ui.GOLD,70)
	ui.population_label = ui._resource_pill(row,"population","ABITANTI",ui.SAGE,102)
	row.add_child(ui._icon_button("journal",ui._show_quests,"Diario: storia, obiettivi e scoperte"))
	ui.pause_button = ui._icon_button("pause",ui._show_pause,"Prenditi una pausa")
	row.add_child(ui.pause_button)
	ui.objective_label = ui._label("")
	ui.objective_label.hide()
	ui._header.add_child(ui.objective_label)

static func footer(ui: CanvasLayer) -> void:
	ui._footer = PanelContainer.new()
	ui._footer.name = "PhoneDock"
	ui._footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	ui._footer.add_theme_stylebox_override("panel",ui._floating_group(8))
	ui.hud.add_child(ui._footer)
	var row: HBoxContainer = ui._hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	ui._footer.add_child(row)
	weapon(ui,row)
	row.add_child(ui._spacer())
	var nav: HBoxContainer = ui._hbox(10)
	nav.name = "VillageDock"
	row.add_child(nav)
	for entry: Array in [["rifugio","home","Rifugio"],["citizens","people","Persone"],["build","build","Costruisci"],["expeditions","compass","Esplora"],["armory","gun","Armeria"]]:
		var button: Button = ui._button("",ui._navigate.bind(entry[0]),false,true)
		button.custom_minimum_size = Vector2(104,72)
		button.name = "Dock_"+str(entry[0])
		var group: VBoxContainer = ui._button_stack(button,1,Vector2(6,6))
		var center: CenterContainer = CenterContainer.new()
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(ui._icon(entry[1],30))
		group.add_child(center)
		var caption: Label = ui._label(entry[2],15,ui.TEXT,true)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		group.add_child(caption)
		if entry[0] in ["rifugio","citizens","expeditions"]:
			var badge: PanelContainer = PanelContainer.new()
			badge.name = "ActivityBadge"
			badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
			badge.offset_left = -26
			badge.offset_right = -3
			badge.offset_top = 3
			badge.offset_bottom = 26
			badge.add_theme_stylebox_override("panel",ui._style(Chrome.HONEY,Chrome.HONEY,12,1))
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var count: Label = ui._label("",13,ui.INK,true)
			count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			badge.add_child(count)
			badge.hide()
			button.add_child(badge)
		nav.add_child(button)
		ui.nav_buttons[entry[0]] = button
	row.add_child(ui._spacer())
	ui.gate_button = ui._button("",ui._gate_focus,false,true)
	ui.gate_button.name = "GateDock"
	ui.gate_button.custom_minimum_size = Vector2(142,72)
	var gate: VBoxContainer = ui._button_stack(ui.gate_button,2,Vector2(12,7))
	var line: HBoxContainer = ui._hbox(6)
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(ui._icon("shield",25))
	ui.gate_label = ui._label("100%",18,ui.TEXT,true)
	line.add_child(ui.gate_label)
	gate.add_child(line)
	ui.gate_bar = ui._progress(ui.SAGE,5)
	gate.add_child(ui.gate_bar)
	var caption: Label = ui._label("Cancello",13,ui.TEXT,true)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gate.add_child(caption)
	row.add_child(ui.gate_button)
	ui.set_selected_tab("rifugio")

static func weapon(ui: CanvasLayer, parent: Node) -> void:
	ui._defense_context = ui._hbox(8)
	ui._defense_context.name = "PhoneWeaponDock"
	ui._defense_context.custom_minimum_size = Vector2(174,72)
	ui._defense_context.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(ui._defense_context)
	var choose: Button = ui._button("",ui._show_armory,false,true)
	choose.name = "ActiveWeapon"
	choose.custom_minimum_size = Vector2(66,72)
	ui._defense_weapon = ui._weapon_icon("pistol",Vector2(46,34))
	choose.add_child(ui._defense_weapon)
	ui._defense_weapon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	ui._defense_weapon.position = Vector2(-23,-17)
	ui._defense_context.add_child(choose)
	var info: VBoxContainer = ui._vbox(3)
	info.custom_minimum_size.x = 100
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	ui._defense_context.add_child(info)
	ui._defense_ammo = ui._label("Pistola · ∞",14,ui.CREAM,true)
	ui._floating_caption(ui._defense_ammo)
	info.add_child(ui._defense_ammo)
	ui._defense_status = ui._label("Pronto",13,ui.CREAM)
	ui._floating_caption(ui._defense_status)
	info.add_child(ui._defense_status)
	ui._defense_ready = ui._progress(ui.SAGE,4)
	info.add_child(ui._defense_ready)

static func fit(ui: CanvasLayer) -> void:
	var width: float = DeviceLayout.safe_rect().size.x
	var dock: HBoxContainer = ui._footer.find_child("VillageDock",true,false)
	if not is_instance_valid(dock): return
	var compact: bool = width<1080
	for button: Control in ui.nav_buttons.values(): button.custom_minimum_size.x = 94 if compact else 104
	dock.add_theme_constant_override("separation",7 if compact else 10)
	ui._defense_context.get_child(1).visible = width>=960
	ui._defense_context.custom_minimum_size.x = 78 if width<960 else 174
	ui.gate_button.custom_minimum_size.x = 118 if compact else 142

static func badges(ui: CanvasLayer, ready_count: int, expedition_status: String) -> void:
	var waiting: int = 0
	for visitor: Dictionary in Game.visitors:
		if Game.visitor_at_gate(visitor): waiting += 1
	var captions: Dictionary = {"rifugio":str(mini(9,ready_count)),"citizens":str(waiting),"expeditions":"!" if expedition_status=="ready" else "·"}
	for key: String in captions:
		var badge: PanelContainer = ui.nav_buttons[key].get_node_or_null("ActivityBadge")
		if not is_instance_valid(badge): continue
		badge.visible = ready_count>0 if key=="rifugio" else waiting>0 if key=="citizens" else expedition_status!="idle"
		badge.get_child(0).text = str(captions[key])
