extends CanvasLayer

@onready var ui_dimmer: ColorRect = $UIDimmer
@onready var inventory_panel: Control = $InventoryPanel
@onready var research_panel: Control = $ResearchPanel
@onready var codex_panel: Control = $CodexPanel
@onready var drop_stats_panel: Control = $DropStatsPanel
@onready var gm_panel: Control = $GMPanel
@onready var offline_report_popup: Control = $OfflineReportPopup
@onready var main_nav_bar: Control = $MainNavBar
@onready var collect_effects: Node2D = $CollectEffects

var active_panel_id: String = ""
var stage_event_queue: Array = []


func _ready() -> void:
	EventBus.ui_panel_requested.connect(_on_ui_panel_requested)
	EventBus.ui_close_requested.connect(_close_active_panel)
	EventBus.offline_report_ready.connect(_show_offline_report)
	EventBus.stage_event_ready.connect(_on_stage_event_ready)

	_close_regular_panels()
	_apply_popup_panel_styles()
	ui_dimmer.visible = false
	offline_report_popup.visible = false
	_emit_ui_state()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_inventory"):
		_toggle_panel("inventory")
	elif event.is_action_pressed("ui_research"):
		_toggle_panel("research")
	elif event.is_action_pressed("ui_codex"):
		_toggle_panel("codex")
	elif event.is_action_pressed("ui_drop_stats"):
		_toggle_panel("drop_stats")
	elif event.is_action_pressed("ui_gm_panel"):
		_toggle_panel("gm")
	elif event.is_action_pressed("ui_cancel"):
		if offline_report_popup.visible:
			_hide_offline_report()
		else:
			_close_active_panel()


func _on_ui_panel_requested(panel_id: String) -> void:
	_toggle_panel(panel_id)


func _toggle_panel(panel_id: String) -> void:
	if offline_report_popup.visible:
		return
	if active_panel_id == panel_id:
		_close_active_panel()
		return
	_open_panel(panel_id)


func _open_panel(panel_id: String) -> void:
	_close_regular_panels()
	match panel_id:
		"inventory":
			_show_panel(inventory_panel)
		"research":
			_show_panel(research_panel)
		"codex":
			_show_panel(codex_panel)
		"drop_stats":
			_show_panel(drop_stats_panel)
		"gm":
			_show_panel(gm_panel)
		_:
			return
	active_panel_id = panel_id
	_emit_ui_state()


func _close_active_panel() -> void:
	if active_panel_id == "offline_report" or offline_report_popup.visible:
		_hide_offline_report()
		return
	if active_panel_id == "stage_event":
		_hide_stage_event()
		return
	active_panel_id = ""
	_close_regular_panels()
	_emit_ui_state()
	_try_show_next_stage_event()


func _close_regular_panels() -> void:
	for panel in [inventory_panel, research_panel, codex_panel, drop_stats_panel, gm_panel]:
		if panel != null:
			panel.visible = false


func _show_panel(panel: Control) -> void:
	panel.visible = true
	if panel.has_method("open_panel"):
		panel.open_panel()
	elif panel.has_method("_refresh"):
		panel._refresh()


func _apply_popup_panel_styles() -> void:
	for panel_root in [inventory_panel, research_panel, codex_panel, drop_stats_panel, gm_panel, offline_report_popup]:
		if panel_root != null:
			_apply_panel_style_recursive(panel_root)
			_apply_compact_typography_recursive(panel_root)


func _apply_panel_style_recursive(node: Node) -> void:
	if node is Panel:
		var panel_node: Panel = node
		panel_node.add_theme_stylebox_override("panel", _build_panel_style(panel_node.name))
	for child in node.get_children():
		_apply_panel_style_recursive(child)


func _build_panel_style(panel_name: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.34, 0.42, 0.56, 1.0)
	match panel_name:
		"Panel":
			style.bg_color = Color(0.08, 0.10, 0.14, 1.0)
		"HeaderBar":
			style.bg_color = Color(0.12, 0.16, 0.22, 1.0)
		_:
			style.bg_color = Color(0.11, 0.13, 0.18, 1.0)
	return style


func _apply_compact_typography_recursive(node: Node) -> void:
	if node is Label:
		var label_node: Label = node
		label_node.add_theme_font_size_override("font_size", 14)
	elif node is RichTextLabel:
		var rich_text_node: RichTextLabel = node
		rich_text_node.add_theme_font_size_override("normal_font_size", 14)
	elif node is Button:
		var button_node: Button = node
		button_node.add_theme_font_size_override("font_size", 14)
	elif node is OptionButton:
		var option_button: OptionButton = node
		option_button.add_theme_font_size_override("font_size", 14)
	elif node is CheckBox:
		var check_box: CheckBox = node
		check_box.add_theme_font_size_override("font_size", 14)
	elif node is ItemList:
		var item_list: ItemList = node
		item_list.add_theme_font_size_override("font_size", 14)
	for child in node.get_children():
		_apply_compact_typography_recursive(child)


func _show_offline_report(report_text: String) -> void:
	_close_regular_panels()
	active_panel_id = "offline_report"
	ui_dimmer.visible = false
	if offline_report_popup.has_method("show_report"):
		offline_report_popup.show_report(report_text)
	else:
		offline_report_popup.visible = true
	_emit_ui_state()


func _hide_offline_report() -> void:
	if offline_report_popup.has_method("hide_popup"):
		offline_report_popup.hide_popup()
	else:
		offline_report_popup.visible = false
	active_panel_id = ""
	_emit_ui_state()
	_try_show_next_stage_event()


func _on_stage_event_ready(event_data: Dictionary) -> void:
	stage_event_queue.append(event_data.duplicate(true))
	_try_show_next_stage_event()


func _try_show_next_stage_event() -> void:
	if stage_event_queue.is_empty():
		return
	if active_panel_id != "" or offline_report_popup.visible:
		return
	var next_event: Dictionary = stage_event_queue.pop_front()
	active_panel_id = "stage_event"
	ui_dimmer.visible = false
	if offline_report_popup.has_method("show_stage_event"):
		offline_report_popup.show_stage_event(next_event)
	else:
		offline_report_popup.visible = true
	_emit_ui_state()


func _hide_stage_event() -> void:
	if offline_report_popup.has_method("hide_popup"):
		offline_report_popup.hide_popup()
	else:
		offline_report_popup.visible = false
	active_panel_id = ""
	EventBus.stage_event_closed.emit()
	_emit_ui_state()
	_try_show_next_stage_event()


func _emit_ui_state() -> void:
	EventBus.ui_blocking_input = active_panel_id != ""
	ui_dimmer.visible = EventBus.ui_blocking_input and active_panel_id != "offline_report" and active_panel_id != "stage_event"
	main_nav_bar.visible = not EventBus.ui_blocking_input
	collect_effects.visible = not EventBus.ui_blocking_input
	EventBus.ui_state_changed.emit(active_panel_id, EventBus.ui_blocking_input)
