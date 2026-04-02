extends CanvasLayer

const UI_STYLE = preload("res://scripts/ui/ui_style.gd")

@onready var ui_dimmer: ColorRect = $UIDimmer
@onready var inventory_panel: Control = $InventoryPanel
@onready var cube_panel: Control = $CubePanel
@onready var research_panel: Control = $ResearchPanel
@onready var codex_panel: Control = $CodexPanel
@onready var drop_stats_panel: Control = $DropStatsPanel
@onready var settings_panel: Control = $SettingsPanel
@onready var gm_panel: Control = $GMPanel
@onready var offline_report_popup: Control = $OfflineReportPopup
@onready var main_nav_bar: Control = $MainNavBar
@onready var launch_menu: Control = $LaunchMenu
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
	if gm_panel != null and not DemoManager.is_debug_tools_enabled():
		gm_panel.visible = false
	_emit_ui_state()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_inventory"):
		_toggle_panel("inventory")
	elif event.is_action_pressed("ui_cube"):
		_toggle_panel("cube")
	elif event.is_action_pressed("ui_research"):
		_toggle_panel("research")
	elif event.is_action_pressed("ui_codex"):
		_toggle_panel("codex")
	elif event.is_action_pressed("ui_drop_stats"):
		_toggle_panel("drop_stats")
	elif event.is_action_pressed("ui_gm_panel"):
		if DemoManager.is_debug_tools_enabled():
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
		"cube":
			_show_panel(cube_panel)
		"research":
			_show_panel(research_panel)
		"codex":
			_show_panel(codex_panel)
		"drop_stats":
			_show_panel(drop_stats_panel)
		"settings":
			_show_panel(settings_panel)
		"gm":
			if not DemoManager.is_debug_tools_enabled():
				return
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
	for panel in [inventory_panel, cube_panel, research_panel, codex_panel, drop_stats_panel, settings_panel, gm_panel]:
		if panel != null:
			panel.visible = false


func _show_panel(panel: Control) -> void:
	panel.visible = true
	if panel.has_method("open_panel"):
		panel.open_panel()
	elif panel.has_method("_refresh"):
		panel._refresh()


func _apply_popup_panel_styles() -> void:
	for panel_root in [inventory_panel, cube_panel, research_panel, codex_panel, drop_stats_panel, settings_panel, gm_panel, offline_report_popup]:
		if panel_root != null:
			_apply_modal_theme_recursive(panel_root)


func _apply_modal_theme_recursive(node: Node) -> void:
	if node is Panel:
		var panel_node: Panel = node
		UI_STYLE.style_panel(panel_node, panel_node.name)
	elif node is OptionButton:
		var option_button: OptionButton = node
		UI_STYLE.style_option_button(option_button, UI_STYLE.COLOR_BLUE)
	elif node is CheckBox:
		var check_box: CheckBox = node
		UI_STYLE.style_check_box(check_box, UI_STYLE.COLOR_GOLD)
	elif node is Button:
		var button_node: Button = node
		UI_STYLE.style_button(button_node, _get_button_accent(button_node.name), button_node.disabled)
	elif node is ItemList:
		var item_list: ItemList = node
		UI_STYLE.style_item_list(item_list)
	elif node is ProgressBar:
		var progress_bar: ProgressBar = node
		UI_STYLE.style_progress_bar(progress_bar, UI_STYLE.COLOR_BLUE)
	elif node is RichTextLabel:
		var rich_text: RichTextLabel = node
		UI_STYLE.style_rich_text(rich_text)
	elif node is Label:
		var label_node: Label = node
		UI_STYLE.style_label(label_node, _get_label_role(label_node.name))
	for child in node.get_children():
		_apply_modal_theme_recursive(child)

func _get_button_accent(button_name: String) -> Color:
	if button_name.contains("Close"):
		return UI_STYLE.COLOR_TEXT_MUTED
	if button_name.contains("Salvage") or button_name.contains("Reset") or button_name.contains("Clear"):
		return UI_STYLE.COLOR_RED
	if button_name.contains("Track") or button_name.contains("Recommended") or button_name.contains("Upgrade"):
		return UI_STYLE.COLOR_GOLD
	if button_name.contains("Lock") or button_name.contains("Current") or button_name.contains("Save") or button_name.contains("Load"):
		return UI_STYLE.COLOR_BLUE
	if button_name.contains("Equip") or button_name.contains("Add") or button_name.contains("Unlock") or button_name.contains("Jump") or button_name.contains("Resource"):
		return UI_STYLE.COLOR_GREEN
	return UI_STYLE.COLOR_BLUE


func _get_label_role(label_name: String) -> String:
	if label_name.contains("Title"):
		return "title"
	if label_name.contains("Hint"):
		return "muted"
	if label_name.contains("Summary"):
		return "accent"
	return "body"


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
	var launch_menu_active: bool = launch_menu != null and launch_menu.visible
	main_nav_bar.visible = not EventBus.ui_blocking_input and not launch_menu_active
	collect_effects.visible = not EventBus.ui_blocking_input and not launch_menu_active
	EventBus.ui_state_changed.emit(active_panel_id, EventBus.ui_blocking_input)
