extends Control

const UI_STYLE = preload("res://scripts/ui/ui_style.gd")
const ParagonSystem = preload("res://scripts/systems/paragon_system.gd")
const SeasonSystem = preload("res://scripts/systems/season_system.gd")

@onready var title_label: Label = $Panel/TitleLabel
@onready var summary_label: Label = $Panel/SummaryLabel
@onready var tab_section_label: Label = $Panel/TabSectionLabel
@onready var filter_section_label: Label = $Panel/FilterSectionLabel
@onready var list_section_label: Label = $Panel/ListSectionLabel
@onready var detail_section_label: Label = $Panel/DetailSectionLabel
@onready var action_section_label: Label = $Panel/ActionSectionLabel
@onready var comprehension_tab_button: Button = $Panel/ComprehensionTabButton
@onready var paragon_tab_button: Button = $Panel/ParagonTabButton
@onready var rebirth_tab_button: Button = $Panel/RebirthTabButton
@onready var all_button: Button = $Panel/AllButton
@onready var combat_button: Button = $Panel/CombatButton
@onready var idle_button: Button = $Panel/IdleButton
@onready var economy_button: Button = $Panel/EconomyButton
@onready var node_list: ItemList = $Panel/ResearchList
@onready var page_status_label: Label = $Panel/PageStatusLabel
@onready var detail_label: Label = $Panel/DetailLabel
@onready var action_hint_label: Label = $Panel/ActionHintLabel
@onready var reset_button: Button = $Panel/ResetButton
@onready var upgrade_button: Button = $Panel/UpgradeButton
@onready var close_button: Button = $Panel/CloseButton

var selected_research_id: String = ""
var selected_paragon_stat_id: String = ""
var current_filter: String = "all"
var active_tab: String = "comprehension"
var rebirth_confirm_armed: bool = false


func _ready() -> void:
	visible = false
	_apply_visual_style()
	comprehension_tab_button.pressed.connect(_on_tab_pressed.bind("comprehension"))
	paragon_tab_button.pressed.connect(_on_tab_pressed.bind("paragon"))
	rebirth_tab_button.pressed.connect(_on_tab_pressed.bind("season"))
	all_button.pressed.connect(_on_filter_pressed.bind("all"))
	combat_button.pressed.connect(_on_filter_pressed.bind("combat"))
	idle_button.pressed.connect(_on_filter_pressed.bind("idle"))
	economy_button.pressed.connect(_on_filter_pressed.bind("economy"))
	node_list.item_selected.connect(_on_research_selected)
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	close_button.pressed.connect(_on_close_pressed)

	EventBus.research_changed.connect(_refresh)
	EventBus.resources_changed.connect(_refresh)
	EventBus.node_changed.connect(_on_progress_context_changed)
	EventBus.paragon_changed.connect(_on_runtime_summary_changed)
	EventBus.season_reborn.connect(_on_runtime_summary_changed)
	EventBus.rift_run_started.connect(_on_progress_context_changed)
	EventBus.rift_run_finished.connect(_on_progress_context_changed)

	_refresh()


func _refresh() -> void:
	var hub_summary: Dictionary = GameManager.get_progression_hub_summary()
	title_label.text = "成长中心"
	tab_section_label.text = "成长页签"
	summary_label.text = String(hub_summary.get("summary_text", "成长概览"))
	_update_tab_buttons()

	match active_tab:
		"paragon":
			_refresh_paragon_page(hub_summary.get("paragon", {}))
		"season":
			_refresh_season_page(hub_summary.get("season", {}))
		_:
			_refresh_comprehension_page()


func _refresh_comprehension_page() -> void:
	filter_section_label.text = "参悟分支"
	list_section_label.text = "参悟节点"
	detail_section_label.text = "参悟详情"
	action_section_label.text = "参悟操作"
	all_button.text = "全部"
	combat_button.text = "战法"
	idle_button.text = "闭关"
	economy_button.text = "机缘"

	_set_page_layout(true, true, false, true)
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

	_refresh_research_detail()


func _refresh_placeholder_page(page_name: String, action_name: String, list_name: String, summary: Dictionary) -> void:
	filter_section_label.text = "阶段说明"
	list_section_label.text = list_name
	detail_section_label.text = page_name
	action_section_label.text = action_name
	_set_page_layout(false, false, true, false)
	page_status_label.text = "%s\n\n%s" % [
		String(summary.get("status", "后续阶段开放")),
		String(summary.get("summary_text", "当前仍处于占位态。")),
	]
	detail_label.text = String(summary.get("summary_text", "当前仍处于占位态。"))
	page_status_label.add_theme_color_override("font_color", Color(0.84, 0.86, 0.92, 1.0))
	detail_label.add_theme_color_override("font_color", Color(0.84, 0.86, 0.92, 1.0))
	action_hint_label.text = "当前阶段: %s" % String(summary.get("status", "后续阶段开放"))
	action_hint_label.add_theme_color_override("font_color", Color(0.96, 0.80, 0.42, 1.0))


func _refresh_paragon_page(summary: Dictionary) -> void:
	if not bool(summary.get("is_unlocked", false)):
		_refresh_placeholder_page(
			"宗师修为",
			"宗师状态",
			"宗师摘要",
			summary
		)
		return

	filter_section_label.text = "修为进度"
	list_section_label.text = "可分配项"
	detail_section_label.text = "宗师详情"
	action_section_label.text = "修为操作"
	_set_page_layout(false, true, false, true)

	var previous_selection: String = selected_paragon_stat_id
	selected_paragon_stat_id = ""
	node_list.clear()
	for entry_variant in summary.get("entries", []):
		var entry: Dictionary = entry_variant
		var stat_id: String = String(entry.get("id", ""))
		var cap: int = int(entry.get("cap", -1))
		var cap_text: String = "%d/∞" % int(entry.get("points", 0)) if cap < 0 else "%d/%d" % [int(entry.get("points", 0)), cap]
		var line: String = "[%s] %s | %s | %s" % [
			String(entry.get("category", "宗师")),
			String(entry.get("name", stat_id)),
			cap_text,
			String(entry.get("effect_text", "")),
		]
		node_list.add_item(line)
		node_list.set_item_metadata(node_list.item_count - 1, stat_id)
		if stat_id == previous_selection:
			selected_paragon_stat_id = stat_id
			node_list.select(node_list.item_count - 1)

	if selected_paragon_stat_id.is_empty() and node_list.item_count > 0:
		node_list.select(0)
		selected_paragon_stat_id = String(node_list.get_item_metadata(0))

	_refresh_paragon_detail(summary)


func _refresh_paragon_detail(summary: Dictionary) -> void:
	detail_label.add_theme_color_override("font_color", Color(0.92, 0.86, 0.66, 1.0))
	detail_label.text = "%s\n\n%s" % [
		String(summary.get("summary_text", "宗师修为已开启")),
		ParagonSystem.build_stat_detail_text(GameManager.paragon_state, selected_paragon_stat_id),
	]
	var available_points: int = int(summary.get("available_points", 0))
	var stat_definition: Dictionary = ParagonSystem.get_stat_definition(selected_paragon_stat_id)
	var entry_points: int = int(GameManager.paragon_state.get("allocated", {}).get(selected_paragon_stat_id, 0))
	var cap: int = int(stat_definition.get("cap", -1))
	var is_capped: bool = cap >= 0 and entry_points >= cap
	upgrade_button.disabled = selected_paragon_stat_id.is_empty() or available_points <= 0 or is_capped
	upgrade_button.text = "投入 1 点宗师修为" if not upgrade_button.disabled else (
		"该项已达上限" if is_capped else ("暂无可分配宗师点" if available_points <= 0 else "未选择修为项")
	)
	action_hint_label.text = "宗师等级: %d | 当前修为: %d/%d | 可用点数: %d" % [
		int(summary.get("level", 0)),
		int(round(float(summary.get("experience", 0.0)))),
		int(summary.get("next_level_experience", 0)),
		available_points,
	]
	action_hint_label.add_theme_color_override("font_color", Color(0.96, 0.80, 0.42, 1.0))
	_update_button_style(
		upgrade_button,
		Color(0.84, 0.66, 0.26, 1.0) if not upgrade_button.disabled else Color(0.42, 0.42, 0.46, 1.0)
	)
	reset_button.visible = true
	reset_button.disabled = int(summary.get("allocated_points", 0)) <= 0
	reset_button.text = "重置分点"
	_update_button_style(
		reset_button,
		Color(0.42, 0.78, 0.96, 1.0) if not reset_button.disabled else Color(0.42, 0.42, 0.46, 1.0)
	)


func _refresh_season_page(summary: Dictionary) -> void:
	var preview: Dictionary = GameManager.get_season_rebirth_preview()
	filter_section_label.text = "轮回条件"
	list_section_label.text = "轮回摘要"
	detail_section_label.text = "轮回预览"
	action_section_label.text = "轮回操作"
	_set_page_layout(false, false, true, true)

	var blocked_reason: String = String(summary.get("blocked_reason", ""))
	page_status_label.text = "%s\n\n%s%s" % [
		String(summary.get("status", "未满足条件")),
		String(summary.get("summary_text", "后续阶段开放")),
		"\n开启条件: %s" % blocked_reason if not blocked_reason.is_empty() else "",
	]
	page_status_label.add_theme_color_override("font_color", Color(0.84, 0.86, 0.92, 1.0))

	var detail_lines: Array[String] = []
	detail_lines.append("本次重入后将保留:")
	for line_variant in preview.get("keep_lines", []):
		detail_lines.append("- %s" % String(line_variant))
	detail_lines.append("")
	detail_lines.append("本次重入后将重置:")
	for line_variant in preview.get("reset_lines", []):
		detail_lines.append("- %s" % String(line_variant))
	detail_lines.append("")
	detail_lines.append("下一次江湖阅历:")
	detail_lines.append("- 当前: %s" % String(preview.get("current_bonus_text", "暂未获得永久加成")))
	detail_lines.append("- 下次: %s" % String(preview.get("next_bonus_text", "暂未获得永久加成")))
	detail_label.text = "\n".join(detail_lines)
	detail_label.add_theme_color_override("font_color", Color(0.82, 0.90, 1.0, 1.0))

	upgrade_button.disabled = not bool(preview.get("ok", false))
	upgrade_button.text = "再次点击确认重入江湖" if rebirth_confirm_armed and not upgrade_button.disabled else "重入江湖"
	_update_button_style(
		upgrade_button,
		Color(0.86, 0.34, 0.30, 1.0) if not upgrade_button.disabled else Color(0.42, 0.42, 0.46, 1.0)
	)
	if not bool(preview.get("ok", false)):
		rebirth_confirm_armed = false
		action_hint_label.text = "当前不可执行: %s" % String(preview.get("reason", "未满足条件"))
	elif rebirth_confirm_armed:
		action_hint_label.text = "再次点击将执行重入江湖，并重置当前轮装备、材料与章节进度。"
	else:
		action_hint_label.text = "条件已满足。点击一次进入确认态，再次点击才会真正执行。"
	action_hint_label.add_theme_color_override("font_color", Color(0.96, 0.80, 0.42, 1.0))
	reset_button.visible = false


func _refresh_research_detail() -> void:
	detail_label.text = MetaProgressionSystem.get_research_detail_text(selected_research_id)
	if selected_research_id.is_empty():
		upgrade_button.disabled = true
		upgrade_button.text = "提升参悟"
		action_hint_label.text = "未选择参悟节点 | 左侧选择节点后可查看提升条件"
		action_hint_label.add_theme_color_override("font_color", Color(0.74, 0.78, 0.86, 1.0))
		detail_label.add_theme_color_override("font_color", Color(0.82, 0.84, 0.90, 1.0))
		_update_button_style(upgrade_button, Color(0.42, 0.42, 0.46, 1.0))
		return

	var upgrade_state: Dictionary = MetaProgressionSystem.can_upgrade_research(selected_research_id)
	upgrade_button.disabled = not bool(upgrade_state.get("ok", false))
	detail_label.add_theme_color_override("font_color", _get_tree_type_color(_get_selected_tree_type()))
	if bool(upgrade_state.get("ok", false)):
		var cost_entry: Dictionary = upgrade_state.get("cost", {})
		upgrade_button.text = "提升参悟 (%s x%d)" % [
			MetaProgressionSystem.get_resource_display_name(String(cost_entry.get("resource_id", ""))),
			int(cost_entry.get("amount", 0)),
		]
		action_hint_label.text = "当前参悟可提升 | 下一跳消耗 %s x%d" % [
			MetaProgressionSystem.get_resource_display_name(String(cost_entry.get("resource_id", ""))),
			int(cost_entry.get("amount", 0)),
		]
		action_hint_label.add_theme_color_override("font_color", Color(0.56, 0.88, 0.62, 1.0))
	else:
		upgrade_button.text = String(upgrade_state.get("reason", "不可升级"))
		action_hint_label.text = "当前参悟状态 | %s" % String(upgrade_state.get("reason", "不可升级"))
		action_hint_label.add_theme_color_override("font_color", Color(0.96, 0.80, 0.42, 1.0))
	_update_button_style(
		upgrade_button,
		Color(0.38, 0.72, 0.48, 1.0) if not upgrade_button.disabled else Color(0.42, 0.42, 0.46, 1.0)
	)


func _on_tab_pressed(tab_id: String) -> void:
	active_tab = tab_id
	rebirth_confirm_armed = false
	_refresh()


func _on_research_selected(index: int) -> void:
	if active_tab == "paragon":
		selected_paragon_stat_id = String(node_list.get_item_metadata(index))
		_refresh_paragon_detail(GameManager.get_progression_hub_summary().get("paragon", {}))
		return
	selected_research_id = String(node_list.get_item_metadata(index))
	_refresh_research_detail()


func _on_upgrade_pressed() -> void:
	match active_tab:
		"paragon":
			if selected_paragon_stat_id.is_empty():
				return
			GameManager.allocate_paragon_point(selected_paragon_stat_id)
		"season":
			if not rebirth_confirm_armed:
				rebirth_confirm_armed = true
			else:
				var result: Dictionary = GameManager.perform_season_rebirth()
				if bool(result.get("ok", false)):
					rebirth_confirm_armed = false
		_:
			if selected_research_id.is_empty():
				return
			MetaProgressionSystem.upgrade_research(selected_research_id)
	_refresh()


func _on_reset_pressed() -> void:
	if active_tab != "paragon":
		return
	GameManager.reset_paragon_allocations()
	_refresh()


func _on_filter_pressed(tree_filter: String) -> void:
	current_filter = tree_filter
	_refresh()


func _on_close_pressed() -> void:
	rebirth_confirm_armed = false
	EventBus.ui_close_requested.emit()


func _on_runtime_summary_changed(_summary: Dictionary) -> void:
	_refresh()


func _on_progress_context_changed(_payload: Variant = null) -> void:
	_refresh()


func open_panel() -> void:
	visible = true
	_refresh()


func _update_tab_buttons() -> void:
	comprehension_tab_button.disabled = active_tab == "comprehension"
	paragon_tab_button.disabled = active_tab == "paragon"
	rebirth_tab_button.disabled = active_tab == "season"
	_update_button_style(
		comprehension_tab_button,
		Color(0.36, 0.52, 0.88, 1.0) if not comprehension_tab_button.disabled else Color(0.24, 0.34, 0.60, 1.0)
	)
	_update_button_style(
		paragon_tab_button,
		Color(0.98, 0.74, 0.32, 1.0) if not paragon_tab_button.disabled else Color(0.56, 0.42, 0.22, 1.0)
	)
	_update_button_style(
		rebirth_tab_button,
		Color(0.42, 0.78, 0.96, 1.0) if not rebirth_tab_button.disabled else Color(0.24, 0.46, 0.58, 1.0)
	)


func _update_filter_buttons() -> void:
	all_button.disabled = current_filter == "all"
	combat_button.disabled = current_filter == "combat"
	idle_button.disabled = current_filter == "idle"
	economy_button.disabled = current_filter == "economy"
	_update_button_style(all_button, Color(0.36, 0.52, 0.88, 1.0) if not all_button.disabled else Color(0.24, 0.34, 0.60, 1.0))
	_update_button_style(combat_button, Color(0.88, 0.42, 0.42, 1.0) if not combat_button.disabled else Color(0.56, 0.28, 0.28, 1.0))
	_update_button_style(idle_button, Color(0.42, 0.78, 0.96, 1.0) if not idle_button.disabled else Color(0.24, 0.46, 0.58, 1.0))
	_update_button_style(economy_button, Color(0.84, 0.70, 0.34, 1.0) if not economy_button.disabled else Color(0.54, 0.42, 0.22, 1.0))


func _set_page_layout(show_filters: bool, show_list: bool, show_status: bool, show_upgrade: bool) -> void:
	all_button.visible = show_filters
	combat_button.visible = show_filters
	idle_button.visible = show_filters
	economy_button.visible = show_filters
	node_list.visible = show_list
	page_status_label.visible = show_status
	upgrade_button.visible = show_upgrade
	reset_button.visible = false


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
	UI_STYLE.style_label(title_label, "title")
	UI_STYLE.style_label(summary_label, "accent")
	UI_STYLE.style_label(tab_section_label, "heading")
	UI_STYLE.style_label(filter_section_label, "heading")
	UI_STYLE.style_label(list_section_label, "heading")
	UI_STYLE.style_label(detail_section_label, "heading")
	UI_STYLE.style_label(action_section_label, "warning")
	UI_STYLE.style_label(action_hint_label, "muted")
	UI_STYLE.style_label(page_status_label, "muted")
	UI_STYLE.style_item_list(node_list)
	_update_button_style(reset_button, UI_STYLE.COLOR_TEXT_DIM)
	_update_button_style(close_button, UI_STYLE.COLOR_TEXT_DIM)


func _update_button_style(button: Button, color: Color) -> void:
	UI_STYLE.style_button(button, color, button.disabled)
