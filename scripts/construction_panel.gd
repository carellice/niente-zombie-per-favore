extends RefCounted
const Catalog = preload("res://scripts/build_panel.gd")

static func show_site(ui: CanvasLayer, col: VBoxContainer, building: Dictionary) -> void:
	var card: VBoxContainer = ui._card(col,ui.GOLD)
	var row: HBoxContainer = ui._hbox(18)
	row.add_child(ui._painted_icon(Catalog._art(str(building.type)),Vector2(128,112),"construction_"+str(building.type)))
	var info: VBoxContainer = ui._vbox(8)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(ui._copy("Cantiere in corso",27,ui.TEXT))
	var timer: Label = ui._bind_label(info,func(label: Label) -> void:
		label.text = "Pronto fra "+ui._time(float(building.construction_remaining))
	,24,ui.GOLD)
	timer.name = "ConstructionCountdown"
	row.add_child(info)
	card.add_child(row)
	var progress: ProgressBar = ui._progress(ui.SAGE,14)
	progress.name = "ConstructionProgress"
	progress.value = Game.construction_progress(building)*100.0
	card.add_child(progress)
	ui.bindings.append([progress,func(bar: ProgressBar) -> void: bar.value = Game.construction_progress(building)*100.0])
	ui._bind_label(card,func(label: Label) -> void: label.text = "%s · %d%% completato" % [Game.construction_stage(building),floori(Game.construction_progress(building)*100.0)],20,ui.SAGE)
	col.add_child(ui._copy("Quando i lavori finiscono l'edificio diventa operativo automaticamente. Puoi esplorare il rifugio: il cantiere continua anche a gioco chiuso.",20))
	col.add_child(ui._copy("I cinque nuovi letti saranno disponibili al termine dei lavori." if building.type=="residence" else "Potrai assegnare i lavoratori e rifornire il negozio quando il cantiere sarà terminato.",18,ui.GOLD))
	col.add_child(ui._copy("Costo già pagato. Non servono altre risorse per completare questi lavori.",18,ui.SAGE))
	ui._fixed_actions().add_child(ui._button("Torna al rifugio",ui._close_modal,true))
