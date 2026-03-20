extends Control

@onready var title_label: Label = $Panel/TitleLabel
@onready var summary_label: Label = $Panel/SummaryLabel
@onready var quick_section_label: Label = $Panel/QuickSectionLabel
@onready var list_section_label: Label = $Panel/ListSectionLabel
@onready var detail_section_label: Label = $Panel/DetailSectionLabel
@onready var rate_section_label: Label = $Panel/RateSectionLabel
@onready var recent_section_label: Label = $Panel/RecentSectionLabel
@onready var quick_hint_label: Label = $Panel/QuickHintLabel
@onready var current_button: Button = $Panel/CurrentButton
@onready var recommended_button: Button = $Panel/RecommendedButton
@onready var close_button: Button = $Panel/CloseButton
@onready var node_list: ItemList = $Panel/NodeList
@onready var detail_label: RichTextLabel = $Panel/DetailLabel
@onready var equipment_rate_label: RichTextLabel = $Panel/EquipmentRateLabel
@onready var equipment_rate_bar: ProgressBar = $Panel/EquipmentRateBar
@onready var legendary_rate_label: RichTextLabel = $Panel/LegendaryRateLabel
@onready var legendary_rate_bar: ProgressBar = $Panel/LegendaryRateBar
@onready var tracked_rate_label: RichTextLabel = $Panel/TrackedRateLabel
@onready var tracked_rate_bar: ProgressBar = $Panel/TrackedRateBar
@onready var recent_label: RichTextLabel = $Panel/RecentLabel

var selected_node_id: String = ""


func _ready() -> void:
	visible = false
	_apply_visual_style()
	current_button.pressed.connect(_on_current_pressed)
	recommended_button.pressed.connect(_on_recommended_pressed)
	close_button.pressed.connect(_on_close_pressed)
	node_list.item_selected.connect(_on_node_selected)

	EventBus.codex_changed.connect(_refresh)
	EventBus.node_changed.connect(_on_node_changed)
	EventBus.loot_target_changed.connect(_refresh)

	_refresh()


func _refresh() -> void:
	title_label.text = "掉落统计"
	summary_label.text = _build_summary_text()

	var previous_selection: String = selected_node_id
	selected_node_id = ""
	node_list.clear()

	for entry_variant in LootCodexSystem.get_drop_stat_entries():
		var entry: Dictionary = entry_variant
		var node_id: String = String(entry.get("node_id", ""))
		var label: String = "%s%s - %s | 刷 %d | 装备 %d | 传奇 %d" % [
			"[当前] " if bool(entry.get("is_current", false)) else "",
			String(entry.get("chapter_name", "")),
			node_id,
			int(entry.get("clears", 0)),
			int(entry.get("equipment_drops", 0)),
			int(entry.get("legendary_drops", 0)),
		]
		node_list.add_item(label)
		node_list.set_item_metadata(node_list.item_count - 1, node_id)
		if node_id == previous_selection:
			selected_node_id = node_id
			node_list.select(node_list.item_count - 1)

	if selected_node_id.is_empty() and node_list.item_count > 0:
		var preferred_node_id: String = GameManager.current_node_id
		var recommendation: Dictionary = LootCodexSystem.get_recommended_farm_node_for_legendary(LootCodexSystem.tracked_legendary_affix_id)
		if not recommendation.is_empty():
			preferred_node_id = String(recommendation.get("node_id", preferred_node_id))
		var preferred_index: int = _find_index_by_node_id(preferred_node_id)
		if preferred_index < 0:
			preferred_index = _find_index_by_node_id(GameManager.current_node_id)
		if preferred_index < 0:
			preferred_index = 0
		node_list.select(preferred_index)
		selected_node_id = String(node_list.get_item_metadata(preferred_index))

	_refresh_detail()
	_refresh_quick_hint()


func _refresh_detail() -> void:
	detail_label.text = LootCodexSystem.get_drop_stat_detail_text(selected_node_id)
	detail_label.scroll_to_line(0)
	detail_label.add_theme_color_override("default_color", Color(0.82, 0.90, 1.0, 1.0))
	_refresh_visual_rates()
	var recent_lines: Array[String] = []
	for record_variant in LootCodexSystem.get_recent_drop_records(4, selected_node_id):
		var record: Dictionary = record_variant
		recent_lines.append("%d. [%s] %s" % [
			int(record.get("clear_index", 0)),
			_get_node_type_label(String(record.get("node_type", "normal"))),
			String(record.get("summary", "无掉落")),
		])
	if recent_lines.is_empty():
		recent_label.text = "暂无记录\n继续刷图后会在这里累计最近样本。"
	else:
		recent_label.text = "\n".join(recent_lines)
	recent_label.scroll_to_line(0)


func _refresh_visual_rates() -> void:
	var visual_data: Dictionary = LootCodexSystem.get_drop_stat_visual_data(selected_node_id)
	_apply_rate_entry(
		equipment_rate_label,
		equipment_rate_bar,
		visual_data.get("equipment", {})
	)
	_apply_rate_entry(
		legendary_rate_label,
		legendary_rate_bar,
		visual_data.get("legendary", {})
	)
	_apply_rate_entry(
		tracked_rate_label,
		tracked_rate_bar,
		visual_data.get("tracked_target", {})
	)


func _on_node_selected(index: int) -> void:
	selected_node_id = String(node_list.get_item_metadata(index))
	_refresh_detail()


func _on_current_pressed() -> void:
	var index: int = _find_index_by_node_id(GameManager.current_node_id)
	if index >= 0:
		node_list.select(index)
		selected_node_id = String(node_list.get_item_metadata(index))
	_refresh_detail()
	_refresh_quick_hint()


func _on_recommended_pressed() -> void:
	var recommendation: Dictionary = LootCodexSystem.get_recommended_farm_node_for_legendary(LootCodexSystem.tracked_legendary_affix_id)
	var node_id: String = String(recommendation.get("node_id", ""))
	var index: int = _find_index_by_node_id(node_id)
	if index >= 0:
		node_list.select(index)
		selected_node_id = String(node_list.get_item_metadata(index))
	_refresh_detail()
	_refresh_quick_hint()


func _on_close_pressed() -> void:
	EventBus.ui_close_requested.emit()


func open_panel() -> void:
	visible = true
	_refresh()


func _on_node_changed(_node_id: String) -> void:
	_refresh()


func _find_index_by_node_id(node_id: String) -> int:
	for i in range(node_list.item_count):
		if String(node_list.get_item_metadata(i)) == node_id:
			return i
	return -1


func _apply_rate_entry(label_node: RichTextLabel, bar_node: ProgressBar, entry: Dictionary) -> void:
	if entry.is_empty():
		label_node.text = "暂无数据"
		label_node.scroll_to_line(0)
		bar_node.value = 0.0
		return
	var label: String = String(entry.get("label", "效率"))
	var expected_rate: float = float(entry.get("expected_rate", 0.0))
	var actual_rate: float = float(entry.get("actual_rate", 0.0))
	var state_label: String = String(entry.get("state_label", "暂无样本"))
	var delta_text: String = String(entry.get("delta_text", "0%"))
	var status_text: String = String(entry.get("status", ""))
	label_node.text = "%s | 理论 %.3f / 实测 %.3f | %s | %s" % [
		label,
		expected_rate,
		actual_rate,
		delta_text,
		state_label,
	]
	if not status_text.is_empty():
		label_node.text += "\n%s" % status_text
	label_node.scroll_to_line(0)
	label_node.add_theme_color_override("default_color", _get_rate_color(state_label))
	bar_node.value = float(entry.get("bar_value", 0.0))
	bar_node.self_modulate = _get_rate_color(state_label)


func _get_rate_color(state_label: String) -> Color:
	if state_label.contains("明显高于") or state_label.contains("超出"):
		return Color(0.46, 0.9, 0.54, 1.0)
	if state_label.contains("略高于"):
		return Color(0.76, 0.92, 0.48, 1.0)
	if state_label.contains("明显低于"):
		return Color(1.0, 0.42, 0.42, 1.0)
	if state_label.contains("略低于") or state_label.contains("不产出"):
		return Color(1.0, 0.68, 0.36, 1.0)
	return Color(0.76, 0.84, 0.96, 1.0)


func _build_summary_text() -> String:
	var summary_lines: Array[String] = LootCodexSystem.get_drop_stats_overview_lines()
	var top_line: String = " | ".join(summary_lines.slice(0, min(2, summary_lines.size())))
	var second_line_parts: Array[String] = []
	if summary_lines.size() > 2:
		for line_variant in summary_lines.slice(2, summary_lines.size()):
			second_line_parts.append(String(line_variant))
	second_line_parts.append(LootCodexSystem.get_tracked_target_summary_text())
	return "%s\n%s" % [top_line, " | ".join(second_line_parts)]


func _refresh_quick_hint() -> void:
	var recommendation: Dictionary = LootCodexSystem.get_recommended_farm_node_for_legendary(LootCodexSystem.tracked_legendary_affix_id)
	var recommendation_label: String = String(recommendation.get("short_label", "暂无推荐"))
	quick_hint_label.text = "当前节点: %s | 推荐节点: %s" % [
		GameManager.current_node_id,
		recommendation_label,
	]
	_update_button_style(current_button, Color(0.36, 0.64, 0.96, 1.0))
	_update_button_style(
		recommended_button,
		Color(0.98, 0.74, 0.32, 1.0) if not recommendation.is_empty() else Color(0.42, 0.42, 0.46, 1.0)
	)


func _get_node_type_label(node_type: String) -> String:
	match node_type:
		"elite":
			return "精英"
		"boss":
			return "首领"
		_:
			return "常规"


func _apply_visual_style() -> void:
	title_label.add_theme_color_override("font_color", Color(0.98, 0.92, 0.72, 1.0))
	summary_label.add_theme_color_override("font_color", Color(0.80, 0.86, 0.98, 1.0))
	quick_section_label.add_theme_color_override("font_color", Color(0.66, 0.82, 1.0, 1.0))
	list_section_label.add_theme_color_override("font_color", Color(0.66, 0.82, 1.0, 1.0))
	detail_section_label.add_theme_color_override("font_color", Color(0.74, 0.90, 1.0, 1.0))
	rate_section_label.add_theme_color_override("font_color", Color(0.82, 0.92, 0.66, 1.0))
	recent_section_label.add_theme_color_override("font_color", Color(0.98, 0.86, 0.54, 1.0))
	quick_hint_label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88, 1.0))
	recent_label.add_theme_color_override("default_color", Color(0.88, 0.90, 0.96, 1.0))
	_update_button_style(close_button, Color(0.50, 0.50, 0.56, 1.0))


func _update_button_style(button: Button, color: Color) -> void:
	button.self_modulate = color
