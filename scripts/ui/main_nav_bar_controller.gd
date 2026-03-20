extends Control

const NAV_ICON_PATHS := {
	"inventory": "res://assets/generated/icons/nav_inventory.png",
	"research": "res://assets/generated/icons/nav_research.png",
	"codex": "res://assets/generated/icons/nav_codex.png",
	"drop_stats": "res://assets/generated/icons/nav_stats.png",
}

@onready var inventory_button: Button = $Panel/InventoryButton
@onready var research_button: Button = $Panel/ResearchButton
@onready var codex_button: Button = $Panel/CodexButton
@onready var stats_button: Button = $Panel/StatsButton
@onready var gm_button: Button = $Panel/GMButton
@onready var hint_label: Label = $Panel/HintLabel

var active_panel_id: String = ""


func _ready() -> void:
	inventory_button.pressed.connect(_request_panel.bind("inventory"))
	research_button.pressed.connect(_request_panel.bind("research"))
	codex_button.pressed.connect(_request_panel.bind("codex"))
	stats_button.pressed.connect(_request_panel.bind("drop_stats"))
	gm_button.pressed.connect(_request_panel.bind("gm"))

	EventBus.resources_changed.connect(_refresh)
	EventBus.research_changed.connect(_refresh)
	EventBus.codex_changed.connect(_refresh)
	EventBus.ui_state_changed.connect(_on_ui_state_changed)

	_apply_button_icons()
	_apply_compact_typography()
	_refresh()


func _refresh() -> void:
	inventory_button.text = "背包  I\n%d 件可管理" % GameManager.get_inventory_count()
	research_button.text = "研究  U\n%s" % _get_research_button_summary()
	codex_button.text = "图鉴  O\n%s" % _get_codex_button_summary()
	stats_button.text = "统计  P\n%s" % _get_stats_button_summary()
	gm_button.text = "GM  G\n调试入口"
	hint_label.text = "1/2/3 切流派  R 重开  T 切目标  G GM  F5/F8 档1  Esc 关闭"
	_update_button_states()


func _on_ui_state_changed(panel_id: String, _blocking_input: bool) -> void:
	active_panel_id = panel_id
	_update_button_states()


func _request_panel(panel_id: String) -> void:
	EventBus.ui_panel_requested.emit(panel_id)


func _update_button_states() -> void:
	inventory_button.disabled = active_panel_id == "inventory"
	research_button.disabled = active_panel_id == "research"
	codex_button.disabled = active_panel_id == "codex"
	stats_button.disabled = active_panel_id == "drop_stats"
	gm_button.disabled = active_panel_id == "gm"


func _get_research_button_summary() -> String:
	var upgradable_count: int = 0
	for research_node_variant in MetaProgressionSystem.get_research_items("all"):
		var research_node: Dictionary = research_node_variant
		var state: Dictionary = MetaProgressionSystem.can_upgrade_research(String(research_node.get("id", "")))
		if bool(state.get("ok", false)):
			upgradable_count += 1
	return "可升级 %d 项" % upgradable_count


func _get_codex_button_summary() -> String:
	var tracked_name: String = String(LootCodexSystem.tracked_legendary_affix_id)
	var tracked_affix: Dictionary = {}
	for entry_variant in ConfigDB.get_all_legendary_affixes():
		var entry: Dictionary = entry_variant
		if String(entry.get("id", "")) == tracked_name:
			tracked_affix = entry
			break
	var short_target: String = String(tracked_affix.get("name", "未设目标"))
	return "目标 %s" % short_target


func _get_stats_button_summary() -> String:
	var recorded_nodes: int = LootCodexSystem.get_drop_stat_entries().size()
	var recent_count: int = LootCodexSystem.get_recent_drop_records(9999).size()
	return "节点 %d 个 | 最近 %d 条" % [recorded_nodes, recent_count]


func _apply_button_icons() -> void:
	_apply_button_icon(inventory_button, "inventory")
	_apply_button_icon(research_button, "research")
	_apply_button_icon(codex_button, "codex")
	_apply_button_icon(stats_button, "drop_stats")


func _apply_button_icon(button: Button, icon_id: String) -> void:
	var texture_path: String = String(NAV_ICON_PATHS.get(icon_id, ""))
	var icon_texture: Texture2D = _load_runtime_texture(texture_path)
	button.icon = icon_texture
	button.expand_icon = true


func _load_runtime_texture(resource_path: String) -> Texture2D:
	return RuntimeTextureLoader.load_texture(resource_path)


func get_inventory_collect_target() -> Vector2:
	return inventory_button.get_global_rect().get_center()


func _apply_compact_typography() -> void:
	_apply_font_size_recursive(self)


func _apply_font_size_recursive(node: Node) -> void:
	if node is Label:
		var label_node: Label = node
		label_node.add_theme_font_size_override("font_size", 13)
	elif node is Button:
		var button_node: Button = node
		button_node.add_theme_font_size_override("font_size", 13)
	for child in node.get_children():
		_apply_font_size_recursive(child)
