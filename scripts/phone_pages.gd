extends RefCounted
## Landscape phone pages: one scroll surface, a narrow control rail and real gutters.

const TITLES = {"armory":"Armeria","weapon_details":"Caratteristiche arma","visitor":"Accoglienza","citizens":"Cittadini","citizen_equipment":"Equipaggiamento","assignment":"Lavoratori","job_select":"Assegna un lavoro","build":"Costruisci","expeditions":"Spedizioni","demolition":"Demolizione","gate":"Difese del cancello","quests":"Diario del rifugio","help":"Come si gioca","pause":"Pausa","settings":"Impostazioni","credits":"Crediti","reset":"Nuova partita","tutorial_intro":"Benvenuto al rifugio"}
const ICONS = {"armory":"gun","weapon_details":"gun","visitor":"person","citizens":"people","citizen_equipment":"gun","assignment":"people","job_select":"people","build":"build","expeditions":"compass","demolition":"build","gate":"shield","quests":"bill","help":"help","pause":"pause","settings":"sound","credits":"heart"}

static func open_page(ui: CanvasLayer, kind: String, title: String, id: int, saved_scroll: int, continuing: bool) -> VBoxContainer:
	ui.modal = Control.new()
	ui.modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.root.add_child(ui.modal)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.10,0.16,0.13,0.7)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.modal.add_child(shade)
	ui._modal_shade = shade
	var box: PanelContainer = PanelContainer.new()
	box.name = "PhonePage"
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.add_theme_stylebox_override("panel",ui._cabinet_style())
	ui.modal.add_child(box)
	ui._modal_box = box
	var safe: MarginContainer = MarginContainer.new()
	safe.name = "PhoneSafeContents"
	box.add_child(safe)
	ui._phone_safe = safe
	var columns: HBoxContainer = ui._hbox(12)
	safe.add_child(columns)
	var rail: VBoxContainer = ui._vbox(12)
	rail.name = "PhoneControls"
	rail.custom_minimum_size.x = 72
	columns.add_child(rail)
	var close: Button
	if ui._phone_pause_return:
		close = ui._button("←",ui._dismiss_phone_page,false,true)
		close.custom_minimum_size = Vector2(72,72)
		close.add_theme_font_size_override("font_size",32)
		close.tooltip_text = "Torna alla pausa"
	else:
		close = ui._icon_button("cross",ui._dismiss_phone_page,"Riprendi la partita" if kind=="pause" else "Chiudi")
	close.name = "PhoneClose"
	close.add_theme_stylebox_override("normal",ui._style(Color("e9dabc"),Color("d3b98a"),18,8))
	rail.add_child(close)
	if kind=="building": rail.add_child(ui._icon_button("help",ui._show_building_help.bind(id),"A cosa serve questo edificio?"))
	var space: Control = Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.add_child(space)
	var section: Control = ui._icon(str(ICONS.get(kind,"home")),40,ui.SAGE)
	section.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rail.add_child(section)
	var page_column: VBoxContainer = ui._vbox(8)
	page_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(page_column)
	var balance_inset: MarginContainer = MarginContainer.new()
	for edge: String in ["left","right"]: balance_inset.add_theme_constant_override("margin_"+edge,24)
	page_column.add_child(balance_inset)
	ui._add_purchase_balances(balance_inset,kind)
	balance_inset.visible = ui.PURCHASE_PANELS.has(kind)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "PhonePageScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_theme_stylebox_override("panel",ui._floating_group())
	page_column.add_child(scroll)
	ui.modal_scroll = scroll
	var inset: MarginContainer = MarginContainer.new()
	inset.name = "PhonePagePadding"
	inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for edge: String in ["left","right"]: inset.add_theme_constant_override("margin_"+edge,24)
	for edge: String in ["top","bottom"]: inset.add_theme_constant_override("margin_"+edge,16)
	scroll.add_child(inset)
	var page: VBoxContainer = ui._vbox(18)
	page.name = "PhonePageBody"
	inset.add_child(page)
	ui._phone_page = page
	var heading: Label = ui._copy(str(TITLES.get(kind,title)),32,ui.TEXT)
	heading.name = "PhonePageTitle"
	heading.add_theme_font_override("font",ui.heading)
	page.add_child(heading)
	ui.modal_navigation = ui._hbox(16)
	ui.modal_navigation.name = "DialogNavigation"
	page.add_child(ui.modal_navigation)
	ui.modal_navigation.hide()
	ui.modal_content = ui._vbox(16)
	ui.modal_content.name = "PhonePageContent"
	page.add_child(ui.modal_content)
	ui.modal_actions = ui._vbox(12)
	ui.modal_actions.name = "DialogActions"
	page.add_child(ui.modal_actions)
	ui.modal_actions.hide()
	ui._fit_modal_to_screen()
	layout(ui)
	ui.panel_changed.emit(true)
	ui._update_zombie_alert()
	ui._restore_modal_scroll.call_deferred(scroll.get_instance_id(),saved_scroll)
	ui._begin_modal_motion(not continuing)
	ui._update_context_visibility()
	ui._finish_phone_page.call_deferred(box.get_instance_id())
	return ui.modal_content

static func pause_menu(ui: CanvasLayer) -> void:
	var col: VBoxContainer = ui._open("pause","Partita in pausa","PAUSA")
	var title: Label = ui._phone_page.get_node("PhonePageTitle")
	title.text = "Partita in pausa"
	col.add_child(ui._copy("Giorno %d · %d abitanti · Il tempo di gioco è fermo." % [Game.day,Game.citizens.size()],22,ui.MUTED))
	var resume: Button = ui._button("Riprendi la partita",ui._resume_from_pause,true)
	resume.name = "PauseResume"
	resume.custom_minimum_size.y = 84
	col.add_child(resume)
	var options: GridContainer = GridContainer.new()
	options.columns = 2
	options.add_theme_constant_override("h_separation",16)
	options.add_theme_constant_override("v_separation",16)
	col.add_child(options)
	for entry: Array in [["sound","Impostazioni","Audio, interfaccia e schermo","settings"],["help","Come si gioca","Comandi e regole del rifugio","help"]]:
		var button: Button = ui._button("",ui._pause_options.bind(entry[3]))
		button.name = "PauseSettings" if entry[3]=="settings" else "PauseHelp"
		button.custom_minimum_size.y = 104
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		options.add_child(button)
		var contents: HBoxContainer = ui._hbox(14)
		contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		contents.offset_left = 16
		contents.offset_right = -16
		contents.offset_top = 12
		contents.offset_bottom = -12
		contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(contents)
		var icon: Control = ui._icon(entry[0],44)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		contents.add_child(icon)
		var info: VBoxContainer = ui._vbox(4)
		info.alignment = BoxContainer.ALIGNMENT_CENTER
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		contents.add_child(info)
		var heading: Label = ui._copy(entry[1],24,ui.TEXT)
		heading.add_theme_font_override("font",ui.heading)
		info.add_child(heading)
		info.add_child(ui._copy(entry[2],22,ui.MUTED))
	var saving: VBoxContainer = ui._card(col)
	var save_row: HBoxContainer = ui._hbox(16)
	saving.add_child(save_row)
	var status: Label = ui._copy("Salvataggio automatico attivo.",22,ui.SAGE)
	status.name = "PauseSaveStatus"
	save_row.add_child(status)
	var save: Button = ui._button("Salva adesso",ui._save_from_pause)
	save.name = "PauseSave"
	save_row.add_child(save)
	var menu: Button = ui._button("Salva e torna al menu principale",ui._return_to_main_menu,false,true)
	menu.name = "PauseMainMenu"
	col.add_child(menu)
	col.add_child(ui._copy("Potrai continuare da qui quando vuoi.",22,ui.MUTED))

static func layout(ui: CanvasLayer) -> void:
	if not is_instance_valid(ui._phone_safe): return
	var safe: Rect2 = DeviceLayout.safe_rect()
	var dimensions: Vector2 = DeviceLayout.ui_size()
	ui._phone_safe.add_theme_constant_override("margin_left",ceili(safe.position.x)+16)
	ui._phone_safe.add_theme_constant_override("margin_right",ceili(dimensions.x-safe.end.x)+16)
	ui._phone_safe.add_theme_constant_override("margin_top",ceili(safe.position.y)+12)
	ui._phone_safe.add_theme_constant_override("margin_bottom",ceili(dimensions.y-safe.end.y)+12)

static func polish(ui: CanvasLayer) -> void:
	if not is_instance_valid(ui._phone_page): return
	# Text must wrap before a minimum width can push the page past its right gutter.
	for label: Node in ui._phone_page.find_children("*","Label",true,false):
		label.add_theme_font_size_override("font_size",maxi(22,label.get_theme_font_size("font_size")))
		if label.text.length()>24:
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var available: float = DeviceLayout.safe_rect().size.x-32-72-12-48-16
	adapt_rows(ui._phone_page,available)
	ui._apply_mobile_controls()

static func adapt_rows(node: Node, available: float) -> void:
	if node is GridContainer:
		if node.has_meta("phone_grid"):
			node.columns = 2 if available>=760 else 1
		available = (available-node.get_theme_constant("h_separation")*(node.columns-1))/node.columns
	if node is PanelContainer:
		var style: StyleBox = node.get_theme_stylebox("panel")
		available -= style.get_content_margin(SIDE_LEFT)+style.get_content_margin(SIDE_RIGHT)
	if node is HBoxContainer:
		# Keep the original row and its bindings alive when switching to a stack.
		var wrapped: VBoxContainer = node.get_meta("phone_stack") if node.has_meta("phone_stack") else null
		if is_instance_valid(wrapped):
			for child: Node in wrapped.get_children(): child.reparent(node)
			node.remove_child(wrapped)
			wrapped.queue_free()
			node.remove_meta("phone_stack")
		if node.get_combined_minimum_size().x>available+1:
			var children: Array[Node] = node.get_children()
			var stack: VBoxContainer = VBoxContainer.new()
			stack.add_theme_constant_override("separation",12)
			stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			node.add_child(stack)
			for child: Node in children: child.reparent(stack)
			node.set_meta("phone_stack",stack)
	for child: Node in node.get_children():
		# Manually placed icon/text groups inside buttons retain their composition.
		if not child is Button and not child is HSlider: adapt_rows(child,available)

static func main_menu(ui: CanvasLayer) -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.menu_layer.add_child(margin)
	ui._menu_margin = margin
	var columns: HBoxContainer = ui._hbox(36)
	margin.add_child(columns)
	var hero: VBoxContainer = ui._vbox(16)
	hero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ui._menu_hero = hero
	columns.add_child(hero)
	var mark: TextureRect = ui._painted_icon(load("res://assets/icon.png"),Vector2(132,132))
	mark.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	hero.add_child(mark)
	var logo: Label = ui._copy("Niente Zombie\nPer Favore!",48,ui.LIGHT)
	logo.add_theme_font_override("font",ui.heading)
	logo.add_theme_color_override("font_outline_color",ui.WOOD)
	logo.add_theme_constant_override("outline_size",4)
	hero.add_child(logo)
	hero.add_child(ui._copy("Costruisci. Accogli. Difendi.",22,ui.CREAM))
	var cabinet: PanelContainer = PanelContainer.new()
	ui._menu_cabinet = cabinet
	cabinet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabinet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cabinet.add_theme_stylebox_override("panel",ui._floating_group())
	columns.add_child(cabinet)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cabinet.add_child(scroll)
	var choices: VBoxContainer = ui._vbox(16)
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(choices)
	var play: Button = ui._button("Continua la partita  →" if ui._menu_had_save else "Gioca  →",ui._start_game,true)
	play.name = "PlayButton"
	play.custom_minimum_size.y = 94
	choices.add_child(play)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation",14)
	grid.add_theme_constant_override("v_separation",14)
	choices.add_child(grid)
	for entry: Array in [["home","Nuova partita",ui._confirm_reset],["sound","Impostazioni",ui._show_settings],["heart","Crediti",ui._show_credits],["cross","Esci",ui._quit_game]]:
		var button: Button = ui._button("",entry[2])
		button.custom_minimum_size = Vector2(190,108)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var group: VBoxContainer = ui._button_stack(button,6)
		var center: CenterContainer = CenterContainer.new()
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(ui._icon(entry[0],40))
		group.add_child(center)
		var label: Label = ui._label(entry[1],22,ui.TEXT,true)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		group.add_child(label)
		grid.add_child(button)
	ui._layout_menu()
	ui._apply_mobile_controls.call_deferred()
	ui.panel_changed.emit(true)
	ui.main_menu_opened.emit()
	play.grab_focus()
