extends RefCounted
## Explain the decision at the gate without revealing infection before the result.
const Rules = preload("res://scripts/cozy_rules.gd")

static func preview(game: Node, visitor: Dictionary) -> Dictionary:
	var status: String = str(visitor.get("observation",""))
	var remaining: float = float(visitor.get("observation_remaining",0.0))
	var duration: float = maxf(remaining,float(visitor.get("observation_duration",Rules.observation_duration(game)))) if status=="waiting" else Rules.observation_duration(game)
	var view: Dictionary = {"state":"idle","title":"Contagio da verificare","body":"Scopri se è sano. Un infiltrato danneggia il cancello.","icon":"shield","tone":"pending","duration":duration,"remaining":remaining,"progress":0.0,"can_start":false,"action":"Verifica il contagio"}
	if status=="done":
		view.state = "infected" if visitor.suspicious else "healthy"
		view.title = "Contagio confermato" if visitor.suspicious else "Nessun contagio rilevato"
		view.body = "Ingresso bloccato. Accompagna la persona verso l'uscita." if visitor.suspicious else "Puoi accoglierlo: il controllo è concluso." if game.citizens.size()<game.capacity() else "Il controllo è concluso. Serve un letto libero per accoglierlo."
		view.tone = "danger" if visitor.suspicious else "safe"
		view.icon = "cross" if visitor.suspicious else "shield"
		view.progress = 100.0
		return view
	if status=="waiting":
		view.state = "waiting"
		view.title = "Controllo in corso"
		view.body = "Attendi l'esito prima di accoglierlo. Puoi continuare a giocare."
		view.icon = "compass"
		view.tone = "pending"
		view.action = "In osservazione"
		view.progress = clampf(100.0*(1.0-remaining/maxf(duration,1.0)),0.0,100.0)
		return view
	if not game.visitor_at_gate(visitor):
		view.state = "arriving"
		view.body = "Il controllo sarà disponibile all'arrivo al cancello."
		return view
	for other: Dictionary in game.visitors:
		if other.get("observation","")=="waiting":
			view.state = "busy"
			view.body = "Puoi controllare una persona alla volta. Attendi l'altro esito."
			view.action = "Posto occupato"
			return view
	view.can_start = true
	return view

static func show_card(ui: CanvasLayer, parent: Node, visitor: Dictionary) -> void:
	var game: Node = ui.get_node("/root/Game")
	var card: VBoxContainer = ui._card(parent,ui.SAGE)
	card.get_parent().name = "ObservationCard"
	var header: HBoxContainer = ui._hbox(12)
	card.add_child(header)
	var icon: Control = ui._icon("shield",36)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(icon)
	var title: Label = ui._copy("",24,ui.TEXT)
	title.name = "ObservationTitle"
	title.add_theme_font_override("font",ui.heading)
	header.add_child(title)
	var details: VBoxContainer = ui._vbox(8)
	details.name = "ObservationExplanation"
	details.add_child(ui._copy("Sporco e graffi possono esserci anche sulle persone sane. Il controllo dà un esito certo.",17))
	details.add_child(ui._copy("È gratuito, per una persona alla volta. Non occupa letti e puoi continuare a giocare durante l'attesa.",17))
	var help: Button = ui._icon_button("help",func() -> void: details.visible = not details.visible,"A cosa serve l'osservazione?")
	help.name = "ObservationHelp"
	header.add_child(help)
	var body: Label = ui._copy("",19,ui.TEXT)
	body.name = "ObservationPurpose"
	card.add_child(body)
	var timing: HBoxContainer = ui._hbox(12)
	var clock: HFlowContainer = ui._amounts([["compass","60 s"]])
	clock.name = "ObservationTiming"
	timing.add_child(clock)
	var free: Label = ui._label("Gratis · nessun letto occupato",16,ui.SAGE)
	free.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	free.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timing.add_child(free)
	card.add_child(timing)
	var progress: ProgressBar = ui._progress(ui.SAGE,10)
	progress.name = "ObservationProgress"
	card.add_child(progress)
	var observe: Button = ui._button("Verifica il contagio",ui._cozy_action.bind("observe",int(visitor.id)),true)
	observe.name = "ObserveVisitor"
	card.add_child(observe)
	card.add_child(details)
	details.hide()
	var update: Callable = func(_control: Control) -> void:
		var view: Dictionary = preview(game,visitor)
		var tint: Color = ui.RED if view.tone=="danger" else ui.GOLD if view.tone=="pending" else ui.SAGE
		title.text = view.title
		title.add_theme_color_override("font_color",tint)
		body.text = view.body
		icon.kind = view.icon
		icon.visible = view.state in ["waiting","healthy","infected"]
		icon.queue_redraw()
		var style: StyleBoxFlat = card.get_parent().get_theme_stylebox("panel")
		if style.border_color!=tint: style.border_color = tint
		var finished: bool = view.state in ["healthy","infected"]
		timing.visible = not finished
		clock.get_child(0).get_node("Quantity").text = "%d s" % ceili(float(view.remaining) if view.state=="waiting" else float(view.duration))
		clock.tooltip_text = clock.get_child(0).get_node("Quantity").text+" · controllo gratuito"
		progress.visible = view.state=="waiting"
		progress.value = float(view.progress)
		observe.visible = not finished
		observe.text = view.action
		observe.disabled = not bool(view.can_start)
	update.call(card)
	ui.bindings.append([card,update])
