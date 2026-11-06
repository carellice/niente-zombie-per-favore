extends PanelContainer
## Main-menu card: installed version and, when a release is newer, a one-tap update.

var ui: CanvasLayer
var _title: Label
var _detail: Label
var _button: Button
var _bar: ProgressBar
var _clock: float = 0.0

func setup(owner_ui: CanvasLayer, phone: bool) -> void:
	ui = owner_ui
	name = "UpdateCard"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel",ui._style(Color(0.10,0.20,0.17,0.72),Color(0.85,0.74,0.51,0.55),18,12))
	var row: HBoxContainer = ui._hbox(12)
	add_child(row)
	var mark: TextureRect = ui._painted_icon(preload("res://assets/icon.png"),Vector2(40,40) if not phone else Vector2(48,48))
	row.add_child(mark)
	var text: VBoxContainer = ui._vbox(0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(text)
	_title = ui._label("",17 if not phone else 20,ui.LIGHT,true)
	text.add_child(_title)
	_detail = ui._copy("",13 if not phone else 16,Color("e3dcc3"))
	text.add_child(_detail)
	_bar = ui._progress(Color("ecc66e"),6)
	text.add_child(_bar)
	_button = ui._button("",_on_pressed,true,true)
	_button.custom_minimum_size.x = 150 if not phone else 190
	_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Honey stands out on the dark glass card, like the phone menu's primary action.
	_button.add_theme_stylebox_override("normal",ui._raised(ui.HONEY,Color("b88a3e"),16,false,10))
	_button.add_theme_stylebox_override("hover",ui._raised(Color("f3d488"),Color("b88a3e"),16,false,10))
	_button.add_theme_stylebox_override("pressed",ui._raised(Color("d9b25c"),Color("9c7533"),16,true,10))
	for key: String in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]:
		_button.add_theme_color_override(key,ui.INK)
	row.add_child(_button)
	Updater.changed.connect(_refresh)
	_refresh()

func _process(delta: float) -> void:
	_clock += delta
	if Updater.state==Updater.State.DOWNLOADING and _clock>=0.2:
		_clock = 0.0
		_refresh()

func _on_pressed() -> void:
	if Updater.state==Updater.State.AVAILABLE: Updater.install()
	else: Updater.check()

func _refresh() -> void:
	var version: String = Updater.current_version()
	_bar.visible = false
	_button.visible = true
	_button.disabled = false
	match Updater.state:
		Updater.State.AVAILABLE:
			_title.text = "Nuova versione %s" % Updater.latest_version
			_detail.text = "Installata: %s · i salvataggi restano al sicuro" % version
			_button.text = "Scarica" if OS.has_feature("android") else "Aggiorna"
			_title.add_theme_color_override("font_color",Color("f6d58a"))
		Updater.State.DOWNLOADING:
			var amount: float = Updater.progress()
			_title.text = "Download %d%%" % roundi(amount*100.0)
			_detail.text = "Il gioco si riavvierà aggiornato."
			_bar.visible = true
			_bar.value = amount*100.0
			_button.visible = false
		Updater.State.CHECKING:
			_title.text = "Versione %s" % version
			_detail.text = "Cerco aggiornamenti…"
			_button.visible = false
		Updater.State.CURRENT:
			_title.text = "Versione %s" % version
			_detail.text = "Il gioco è aggiornato."
			_button.visible = false
		Updater.State.FAILED:
			_title.text = "Versione %s" % version
			_detail.text = "Aggiornamenti non verificabili offline."
			_button.text = "Riprova"
		_:
			_title.text = "Versione %s" % version
			_detail.text = "Gioca anche senza connessione."
			_button.text = "Controlla"
	if Updater.state!=Updater.State.AVAILABLE: _title.add_theme_color_override("font_color",ui.LIGHT)
