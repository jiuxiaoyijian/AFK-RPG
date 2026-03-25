extends Control

const UI_STYLE = preload("res://scripts/ui/ui_style.gd")
const NAV_ICON_PATHS := {
	"inventory": "res://assets/generated/icons/nav_inventory.png",
	"research": "res://assets/generated/afk_rpg_formal/icons/system_wudao.png",
	"codex": "res://assets/generated/afk_rpg_formal/icons/system_yiwenlu.png",
	"drop_stats": "res://assets/generated/afk_rpg_formal/icons/system_jiyuantuiyan.png",
}

@onready var inventory_button: Button = $Panel/InventoryButton
@onready var cube_button: Button = $Panel/CubeButton
@onready var research_button: Button = $Panel/ResearchButton
@onready var codex_button: Button = $Panel/CodexButton
@onready var stats_button: Button = $Panel/StatsButton
@onready var gm_button: Button = $Panel/GMButton
@onready var hint_label: Label = $Panel/HintLabel
@onready var panel: Panel = $Panel

var active_panel_id: String = ""


func _ready() -> void:
	inventory_button.pressed.connect(_request_panel.bind("inventory"))
	cube_button.pressed.connect(_request_panel.bind("cube"))
	research_button.pressed.connect(_request_panel.bind("research"))
	codex_button.pressed.connect(_request_panel.bind("codex"))
	stats_button.pressed.connect(_request_panel.bind("drop_stats"))
	gm_button.pressed.connect(_request_panel.bind("gm"))

	EventBus.resources_changed.connect(_refresh)
	EventBus.research_changed.connect(_refresh)
	EventBus.codex_changed.connect(_refresh)
	EventBus.martial_codex_changed.connect(_refresh)
	EventBus.paragon_changed.connect(_refresh)
	EventBus.season_reborn.connect(_refresh)
	EventBus.node_changed.connect(_refresh)
	EventBus.rift_run_started.connect(_on_rift_or_gem_changed)
	EventBus.rift_run_finished.connect(_on_rift_or_gem_changed)
	EventBus.gem_upgraded.connect(_on_gem_upgraded)
	EventBus.ui_state_changed.connect(_on_ui_state_changed)

	_apply_button_icons()
	_apply_review_style()
	_refresh()


func _refresh(_payload: Variant = null) -> void:
	inventory_button.text = "背包  I\n%d 件可管理" % GameManager.get_inventory_count()
	cube_button.text = "百炼坊  B\n萃取 / 重铸"
	research_button.text = "成长中心  U\n%s" % _get_research_button_summary()
	codex_button.text = "异闻录  O\n%s" % _get_codex_button_summary()
	stats_button.text = "推演 / 秘境  P\n%s" % _get_stats_button_summary()
	gm_button.text = "GM  G\n调试入口"
	hint_label.text = "1/2/3 切道统  U 成长中心  B 百炼坊  P 推演与秘境  R 重开  T 切机缘  G GM  F5/F8 档1  Esc 关闭"
	_update_button_states()


func _on_ui_state_changed(panel_id: String, _blocking_input: bool) -> void:
	active_panel_id = panel_id
	_update_button_states()


func _on_rift_or_gem_changed(_payload: Dictionary) -> void:
	_refresh()


func _on_gem_upgraded(_gem_id: String, _new_level: int) -> void:
	_refresh()


func _request_panel(panel_id: String) -> void:
	EventBus.ui_panel_requested.emit(panel_id)


func _update_button_states() -> void:
	inventory_button.disabled = active_panel_id == "inventory"
	cube_button.disabled = active_panel_id == "cube"
	research_button.disabled = active_panel_id == "research"
	codex_button.disabled = active_panel_id == "codex"
	stats_button.disabled = active_panel_id == "drop_stats"
	gm_button.disabled = active_panel_id == "gm"
	_style_nav_buttons()


func _get_research_button_summary() -> String:
	var summary: Dictionary = GameManager.get_progression_hub_summary()
	return String(summary.get("research_summary", "武学参悟"))


func _get_codex_button_summary() -> String:
	var tracked_name: String = String(LootCodexSystem.tracked_legendary_affix_id)
	var tracked_affix: Dictionary = {}
	for entry_variant in ConfigDB.get_all_legendary_affixes():
		var entry: Dictionary = entry_variant
		if String(entry.get("id", "")) == tracked_name:
			tracked_affix = entry
			break
	var short_target: String = String(tracked_affix.get("name", "未设机缘"))
	return "机缘 %s" % short_target


func _get_stats_button_summary() -> String:
	var summary: Dictionary = GameManager.get_analysis_hub_summary()
	return String(summary.get("rift_summary", "试剑秘境"))


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


func _apply_review_style() -> void:
	UI_STYLE.style_panel(panel, "Panel")
	panel.add_theme_stylebox_override("panel", _build_nav_panel_style())
	hint_label.add_theme_font_size_override("font_size", 11)
	hint_label.add_theme_color_override("font_color", Color(0.40, 0.45, 0.52, 1.0))
	_apply_compact_typography()
	_style_nav_buttons()


func _style_nav_buttons() -> void:
	UI_STYLE.style_button(inventory_button, UI_STYLE.COLOR_BLUE, inventory_button.disabled)
	UI_STYLE.style_button(cube_button, UI_STYLE.COLOR_PEACH, cube_button.disabled)
	UI_STYLE.style_button(research_button, UI_STYLE.COLOR_GOLD, research_button.disabled)
	UI_STYLE.style_button(codex_button, UI_STYLE.COLOR_TEAL, codex_button.disabled)
	UI_STYLE.style_button(stats_button, UI_STYLE.COLOR_PEACH, stats_button.disabled)
	UI_STYLE.style_button(gm_button, UI_STYLE.COLOR_TEXT_DIM, gm_button.disabled)


func _build_nav_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.13, 0.98)
	style.border_color = Color(0.34, 0.42, 0.56, 0.72)
	style.border_width_top = 1
	style.border_width_bottom = 0
	style.border_width_left = 0
	style.border_width_right = 0
	return style
