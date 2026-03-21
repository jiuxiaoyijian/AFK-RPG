extends Control

@onready var title_label: Label = $Panel/TitleLabel
@onready var summary_label: Label = $Panel/SummaryLabel
@onready var filter_section_label: Label = $Panel/FilterSectionLabel
@onready var list_section_label: Label = $Panel/ListSectionLabel
@onready var detail_section_label: Label = $Panel/DetailSectionLabel
@onready var action_section_label: Label = $Panel/ActionSectionLabel
@onready var all_button: Button = $Panel/AllButton
@onready var combat_button: Button = $Panel/CombatButton
@onready var idle_button: Button = $Panel/IdleButton
@onready var economy_button: Button = $Panel/EconomyButton
@onready var node_list: ItemList = $Panel/ResearchList
@onready var detail_label: Label = $Panel/DetailLabel
@onready var action_hint_label: Label = $Panel/ActionHintLabel
@onready var upgrade_button: Button = $Panel/UpgradeButton
@onready var close_button: Button = $Panel/CloseButton

var selected_research_id: String = ""
var current_filter: String = "all"


func _ready() -> void:
	visible = false
	_apply_visual_style()
	all_button.pressed.connect(_on_filter_pressed.bind("all"))
	combat_button.pressed.connect(_on_filter_pressed.bind("combat"))
	idle_button.pressed.connect(_on_filter_pressed.bind("idle"))
	economy_button.pressed.connect(_on_filter_pressed.bind("economy"))
	node_list.item_selected.connect(_on_research_selected)
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	close_button.pressed.connect(_on_close_pressed)

	EventBus.research_changed.connect(_refresh)
	EventBus.resources_changed.connect(_refresh)

	_refresh()


func _refresh() -> void:
	title_label.text = "悟道与长期成长"
	filter_section_label.text = "悟道分支"
	list_section_label.text = "悟道节点"
	detail_section_label.text = "悟道详情"
	action_section_label.text = "悟道操作"
	combat_button.text = "战法"
	idle_button.text = "闭关"
	economy_button.text = "机缘"
	summary_label.text = _build_research_summary()
	_update_filter_buttons()

	var previous_selection: String = selected_research_id
	selected_research_id = ""
	node_list.clear()

	for research_node_variant in MetaProgressionSystem.get_research_items(current_filter):
		var research_node: Dictionary = research_node_variant
		var research_id: String = String(research_node.get("id", ""))
		var current_level: int = MetaProgressionSystem.get_research_level(research_id)
		var max_level: int = int(research_node.get("max_level", 1))
		var tree_type: String = String(research_node.get("tree_type", "combat"))
		var state_prefix: String = "[满]" if current_level >= max_level else ("[已解锁]" if current_level > 0 else "[未解锁]")
		var label: String = "%s[%s] %s Lv.%d/%d" % [
			state_prefix,
			_get_tree_type_label(tree_type),
			String(research_node.get("name", research_id)),
			current_level,
			max_level,
		]
		node_list.add_item(label)
		node_list.set_item_metadata(node_list.item_count - 1, research_id)
		if research_id == previous_selection:
			selected_research_id = previous_selection
			node_list.select(node_list.item_count - 1)

	if selected_research_id.is_empty() and node_list.item_count > 0:
		node_list.select(0)
		selected_research_id = String(node_list.get_item_metadata(0))

	_refresh_detail()


func _refresh_detail() -> void:
	detail_label.text = MetaProgressionSystem.get_research_detail_text(selected_research_id)
	if selected_research_id.is_empty():
		upgrade_button.disabled = true
		upgrade_button.text = "提升悟道"
		action_hint_label.text = "未选择悟道 | 左侧选择节点后可查看提升条件"
		action_hint_label.add_theme_color_override("font_color", Color(0.74, 0.78, 0.86, 1.0))
		detail_label.add_theme_color_override("font_color", Color(0.82, 0.84, 0.90, 1.0))
		_update_button_style(upgrade_button, Color(0.42, 0.42, 0.46, 1.0))
		return

	var upgrade_state: Dictionary = MetaProgressionSystem.can_upgrade_research(selected_research_id)
	upgrade_button.disabled = not bool(upgrade_state.get("ok", false))
	detail_label.add_theme_color_override("font_color", _get_tree_type_color(_get_selected_tree_type()))
	if bool(upgrade_state.get("ok", false)):
		var cost_entry: Dictionary = upgrade_state.get("cost", {})
		upgrade_button.text = "提升悟道 (%s x%d)" % [
			MetaProgressionSystem.get_resource_display_name(String(cost_entry.get("resource_id", ""))),
			int(cost_entry.get("amount", 0)),
		]
		action_hint_label.text = "当前悟道可提升 | 下一跳消耗 %s x%d" % [
			MetaProgressionSystem.get_resource_display_name(String(cost_entry.get("resource_id", ""))),
			int(cost_entry.get("amount", 0)),
		]
		action_hint_label.add_theme_color_override("font_color", Color(0.56, 0.88, 0.62, 1.0))
	else:
		upgrade_button.text = String(upgrade_state.get("reason", "不可升级"))
		action_hint_label.text = "当前悟道状态 | %s" % String(upgrade_state.get("reason", "不可升级"))
		action_hint_label.add_theme_color_override("font_color", Color(0.96, 0.80, 0.42, 1.0))
	_update_button_style(
		upgrade_button,
		Color(0.38, 0.72, 0.48, 1.0) if not upgrade_button.disabled else Color(0.42, 0.42, 0.46, 1.0)
	)


func _on_research_selected(index: int) -> void:
	selected_research_id = String(node_list.get_item_metadata(index))
	_refresh_detail()


func _on_upgrade_pressed() -> void:
	if selected_research_id.is_empty():
		return
	MetaProgressionSystem.upgrade_research(selected_research_id)
	_refresh()


func _on_filter_pressed(tree_filter: String) -> void:
	current_filter = tree_filter
	_refresh()


func _on_close_pressed() -> void:
	EventBus.ui_close_requested.emit()


func open_panel() -> void:
	visible = true
	_refresh()


func _update_filter_buttons() -> void:
	all_button.disabled = current_filter == "all"
	combat_button.disabled = current_filter == "combat"
	idle_button.disabled = current_filter == "idle"
	economy_button.disabled = current_filter == "economy"
	_update_button_style(all_button, Color(0.36, 0.52, 0.88, 1.0) if not all_button.disabled else Color(0.24, 0.34, 0.60, 1.0))
	_update_button_style(combat_button, Color(0.88, 0.42, 0.42, 1.0) if not combat_button.disabled else Color(0.56, 0.28, 0.28, 1.0))
	_update_button_style(idle_button, Color(0.42, 0.78, 0.96, 1.0) if not idle_button.disabled else Color(0.24, 0.46, 0.58, 1.0))
	_update_button_style(economy_button, Color(0.84, 0.70, 0.34, 1.0) if not economy_button.disabled else Color(0.54, 0.42, 0.22, 1.0))


func _get_tree_type_label(tree_type: String) -> String:
	match tree_type:
		"combat":
			return "战法"
		"idle":
			return "闭关"
		"economy":
			return "机缘"
		_:
			return tree_type


func _build_research_summary() -> String:
	var branch_stats: Dictionary = {
		"combat": {"current": 0, "max": 0},
		"idle": {"current": 0, "max": 0},
		"economy": {"current": 0, "max": 0},
	}
	for node_variant in MetaProgressionSystem.get_research_items("all"):
		var node: Dictionary = node_variant
		var tree_type: String = String(node.get("tree_type", "combat"))
		if not branch_stats.has(tree_type):
			branch_stats[tree_type] = {"current": 0, "max": 0}
		branch_stats[tree_type]["current"] += MetaProgressionSystem.get_research_level(String(node.get("id", "")))
		branch_stats[tree_type]["max"] += int(node.get("max_level", 1))

	var bonus: Dictionary = MetaProgressionSystem.get_meta_progression_bonuses()
	return "当前筛选: %s | 战法 %d/%d | 闭关 %d/%d | 机缘 %d/%d\n资源加成: 香火钱 %+d%% | 祠灰 %+d%% | 灵核 %+d%%" % [
		_get_tree_type_label(current_filter) if current_filter != "all" else "全部",
		int(branch_stats["combat"]["current"]),
		int(branch_stats["combat"]["max"]),
		int(branch_stats["idle"]["current"]),
		int(branch_stats["idle"]["max"]),
		int(branch_stats["economy"]["current"]),
		int(branch_stats["economy"]["max"]),
		int(round(float(bonus.get("gold_gain_percent", 0.0)) * 100.0)),
		int(round(float(bonus.get("scrap_gain_percent", 0.0)) * 100.0)),
		int(round(float(bonus.get("core_gain_percent", 0.0)) * 100.0)),
	]


func _get_selected_tree_type() -> String:
	if selected_research_id.is_empty():
		return current_filter if current_filter != "all" else "combat"
	var node: Dictionary = ConfigDB.get_research_node(selected_research_id)
	return String(node.get("tree_type", "combat"))


func _get_tree_type_color(tree_type: String) -> Color:
	match tree_type:
		"combat":
			return Color(1.0, 0.72, 0.72, 1.0)
		"idle":
			return Color(0.70, 0.92, 1.0, 1.0)
		"economy":
			return Color(1.0, 0.86, 0.58, 1.0)
		_:
			return Color(0.84, 0.86, 0.92, 1.0)


func _apply_visual_style() -> void:
	title_label.add_theme_color_override("font_color", Color(0.98, 0.92, 0.72, 1.0))
	summary_label.add_theme_color_override("font_color", Color(0.80, 0.86, 0.98, 1.0))
	filter_section_label.add_theme_color_override("font_color", Color(0.66, 0.82, 1.0, 1.0))
	list_section_label.add_theme_color_override("font_color", Color(0.66, 0.82, 1.0, 1.0))
	detail_section_label.add_theme_color_override("font_color", Color(0.74, 0.90, 1.0, 1.0))
	action_section_label.add_theme_color_override("font_color", Color(0.98, 0.86, 0.54, 1.0))
	action_hint_label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88, 1.0))
	_update_button_style(close_button, Color(0.50, 0.50, 0.56, 1.0))


func _update_button_style(button: Button, color: Color) -> void:
	button.self_modulate = color
