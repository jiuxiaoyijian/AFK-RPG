extends Control

const UI_STYLE = preload("res://scripts/ui/ui_style.gd")
const NAV_ICON_PATHS := {
	"inventory": "res://assets/generated/icons/nav_inventory.png",
	"skills": "res://assets/generated/afk_rpg_formal/icons/system_wudao.png",
	"cube": "res://assets/generated/afk_rpg_formal/icons/drop_rare.png",
	"research": "res://assets/generated/afk_rpg_formal/icons/system_wudao.png",
	"codex": "res://assets/generated/afk_rpg_formal/icons/system_yiwenlu.png",
	"drop_stats": "res://assets/generated/afk_rpg_formal/icons/system_jiyuantuiyan.png",
	"settings": "res://assets/generated/afk_rpg_formal/icons/icon_orb_common.png",
}

@onready var inventory_button: Button = $Panel/InventoryButton
@onready var skills_button: Button = $Panel/SkillsButton
@onready var cube_button: Button = $Panel/CubeButton
@onready var research_button: Button = $Panel/ResearchButton
@onready var codex_button: Button = $Panel/CodexButton
@onready var stats_button: Button = $Panel/StatsButton
@onready var settings_button: Button = $Panel/SettingsButton
@onready var hint_label: Label = $Panel/HintLabel
@onready var panel: Panel = $Panel

var active_panel_id: String = ""


func _ready() -> void:
	inventory_button.pressed.connect(_request_panel.bind("inventory"))
	skills_button.pressed.connect(_request_panel.bind("skills"))
	cube_button.pressed.connect(_request_panel.bind("cube"))
	research_button.pressed.connect(_request_panel.bind("research"))
	codex_button.pressed.connect(_request_panel.bind("codex"))
	stats_button.pressed.connect(_request_panel.bind("drop_stats"))
	settings_button.pressed.connect(_request_panel.bind("settings"))

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
	inventory_button.text = "背包  I"
	skills_button.text = "技能  K"
	cube_button.text = "百炼坊  B"
	research_button.text = "成长中心  U"
	codex_button.text = "异闻录  O"
	stats_button.text = "推演 / 秘境  P"
	settings_button.text = "设置"
	inventory_button.tooltip_text = "%d 件可管理装备" % GameManager.get_inventory_count()
	skills_button.tooltip_text = _get_skills_button_summary()
	cube_button.tooltip_text = "萃取、重铸与武学秘录"
	research_button.tooltip_text = _get_research_button_summary()
	codex_button.tooltip_text = _get_codex_button_summary()
	stats_button.tooltip_text = _get_stats_button_summary()
	settings_button.tooltip_text = "音量、存档、反馈与版本信息"
	hint_label.text = "I 背包   K 技能   B 百炼坊   U 成长中心   O 异闻录   P 推演/秘境   Esc 关闭"
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
	skills_button.disabled = active_panel_id == "skills"
	cube_button.disabled = active_panel_id == "cube"
	research_button.disabled = active_panel_id == "research"
	codex_button.disabled = active_panel_id == "codex"
	stats_button.disabled = active_panel_id == "drop_stats"
	settings_button.disabled = active_panel_id == "settings"
	_style_nav_buttons()


func _get_research_button_summary() -> String:
	var summary: Dictionary = GameManager.get_progression_hub_summary()
	return String(summary.get("research_summary", "武学参悟"))


func _get_skills_button_summary() -> String:
	var state: Dictionary = GameManager.get_skill_screen_state()
	var hero_summary: Dictionary = state.get("hero_summary", {})
	return "Lv.%d | 四技能位 %d | 被动位 %d" % [
		int(hero_summary.get("level", 1)),
		int(hero_summary.get("unlocked_skill_slots", 2)),
		int(hero_summary.get("unlocked_passive_slots", 0)),
	]


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
	_apply_button_icon(skills_button, "skills")
	_apply_button_icon(cube_button, "cube")
	_apply_button_icon(research_button, "research")
	_apply_button_icon(codex_button, "codex")
	_apply_button_icon(stats_button, "drop_stats")
	_apply_button_icon(settings_button, "settings")


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
		label_node.add_theme_font_size_override("font_size", 11)
	elif node is Button:
		var button_node: Button = node
		button_node.add_theme_font_size_override("font_size", 11)
	for child in node.get_children():
		_apply_font_size_recursive(child)


func _apply_review_style() -> void:
	UI_STYLE.style_panel(panel, "Panel")
	panel.add_theme_stylebox_override("panel", _build_nav_panel_style())
	hint_label.add_theme_font_size_override("font_size", 10)
	hint_label.add_theme_color_override("font_color", Color(0.40, 0.45, 0.52, 1.0))
	_apply_compact_typography()
	_style_nav_buttons()


func _style_nav_buttons() -> void:
	UI_STYLE.style_button(inventory_button, UI_STYLE.COLOR_BLUE, inventory_button.disabled)
	UI_STYLE.style_button(skills_button, UI_STYLE.COLOR_GREEN, skills_button.disabled)
	UI_STYLE.style_button(cube_button, UI_STYLE.COLOR_PEACH, cube_button.disabled)
	UI_STYLE.style_button(research_button, UI_STYLE.COLOR_GOLD, research_button.disabled)
	UI_STYLE.style_button(codex_button, UI_STYLE.COLOR_TEAL, codex_button.disabled)
	UI_STYLE.style_button(stats_button, UI_STYLE.COLOR_PEACH, stats_button.disabled)
	UI_STYLE.style_button(settings_button, UI_STYLE.COLOR_TEXT_DIM, settings_button.disabled)
	for button in [inventory_button, skills_button, cube_button, research_button, codex_button, stats_button, settings_button]:
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.expand_icon = true
		button.custom_minimum_size = Vector2(0, 48)
	settings_button.custom_minimum_size = Vector2(0, 32)


func _build_nav_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.13, 0.90)
	style.border_color = Color(0.34, 0.42, 0.56, 0.72)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	return style
