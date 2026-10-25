extends RefCounted
const Catalog = preload("res://scripts/build_panel.gd")

static func _summary(id: int) -> String:
	var preview: Dictionary = Game.demolition_preview(id)
	if not preview.valid: return str(preview.reason)
	var text: String = "Il cantiere verrà annullato e il tempo già trascorso andrà perso." if preview.pending else "L'edificio verrà rimosso definitivamente."
	if int(preview.beds_lost)>0:
		text += "\nAlloggi rimasti: %d posti per %d abitanti." % [int(preview.remaining_beds),Game.citizens.size()]
	if int(preview.workers)>0:
		text += "\nLavoratori liberati: %d. Restano nel rifugio, con armi e munizioni personali." % int(preview.workers)
	var losses: PackedStringArray = []
	if int(preview.stock)>0: losses.append("%d unità sugli scaffali" % int(preview.stock))
	if int(preview.ready_batches)>0: losses.append("produzioni pronte: %d" % int(preview.ready_batches))
	if int(preview.restocking)>0: losses.append("rifornimenti in corso: %d" % int(preview.restocking))
	if str(preview.get("service_loss","idle")) in ["working","ready"]: losses.append("contributo per il rifugio in corso o pronto")
	if not losses.is_empty(): text += "\nMerci perse: "+", ".join(losses)+"."
	return text

static func show_panel(ui: CanvasLayer, id: int) -> void:
	var preview: Dictionary = Game.demolition_preview(id)
	if not preview.valid: return
	var col: VBoxContainer = ui._open("demolition","Demolire questo edificio?",str(preview.name).to_upper(),id)
	var card: VBoxContainer = ui._card(col,ui.GOLD)
	var row: HBoxContainer = ui._hbox(18)
	row.add_child(ui._painted_icon(Catalog._art(str(preview.type)),Vector2(120,100),"demolition_"+str(preview.type)))
	row.add_child(ui._copy(str(preview.name),25,ui.TEXT))
	card.add_child(row)
	ui._bind_label(card,func(label: Label) -> void: label.text = _summary(id),19,ui.TEXT)
	col.add_child(ui._copy("Demolizione gratuita, senza rimborso. Merci e rifornimenti verranno persi. Gli altri edifici si avvicineranno.",19,ui.RED))
	var reason: Label = ui._bind_label(col,func(label: Label) -> void:
		var current: Dictionary = Game.demolition_preview(id)
		label.text = str(current.reason) if not current.can_demolish else "I progressi del diario restano acquisiti. Potrai costruire di nuovo dal lotto libero."
	,18,ui.GOLD)
	reason.name = "DemolitionReason"
	var actions: VBoxContainer = ui._fixed_actions()
	var cancel: Button = ui._button("Annulla, conserva l'edificio",ui._close_modal,true)
	cancel.name = "CancelDemolition"
	actions.add_child(cancel)
	var confirm: Button = ui._button("Demolisci definitivamente",ui._demolish_building.bind(id),false)
	confirm.name = "ConfirmDemolition"
	confirm.disabled = not preview.can_demolish
	confirm.add_theme_stylebox_override("normal",ui._raised(Color("efd4bf"),ui.RED,14,false,14))
	confirm.add_theme_stylebox_override("hover",ui._raised(Color("f9dfcf"),ui.RED,14,false,14))
	confirm.add_theme_stylebox_override("pressed",ui._raised(Color("dbb297"),ui.RED,14,true,14))
	confirm.add_theme_color_override("font_color",ui.RED)
	actions.add_child(confirm)
	ui.bindings.append([confirm,func(button: Button) -> void: button.disabled = not Game.demolition_preview(id).can_demolish])
