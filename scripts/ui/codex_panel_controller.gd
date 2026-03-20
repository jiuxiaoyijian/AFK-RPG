extends Control

@onready var title_label: Label = $Panel/TitleLabel
@onready var summary_label: Label = $Panel/SummaryLabel
@onready var filter_section_label: Label = $Panel/FilterSectionLabel
@onready var list_section_label: Label = $Panel/ListSectionLabel
@onready var detail_section_label: Label = $Panel/DetailSectionLabel
@onready var action_section_label: Label = $Panel/ActionSectionLabel
@onready var all_button: Button = $Panel/AllButton
@onready var base_button: Button = $Panel/BaseButton
@onready var affix_button: Button = $Panel/AffixButton
@onready var legendary_button: Button = $Panel/LegendaryButton
@onready var entry_list: ItemList = $Panel/EntryList
@onready var detail_label: RichTextLabel = $Panel/DetailLabel
@onready var action_hint_label: Label = $Panel/ActionHintLabel
@onready var track_button: Button = $Panel/TrackButton
@onready var cycle_button: Button = $Panel/CycleButton
@onready var close_button: Button = $Panel/CloseButton

var selected_entry_id: String = ""
var current_category: String = "all"


func _ready() -> void:
	visible = false
	_apply_visual_style()
	all_button.pressed.connect(_on_filter_pressed.bind("all"))
	base_button.pressed.connect(_on_filter_pressed.bind("base"))
	affix_button.pressed.connect(_on_filter_pressed.bind("affix"))
	legendary_button.pressed.connect(_on_filter_pressed.bind("legendary"))
	entry_list.item_selected.connect(_on_entry_selected)
	track_button.pressed.connect(_on_track_pressed)
	cycle_button.pressed.connect(_on_cycle_pressed)
	close_button.pressed.connect(_on_close_pressed)

	EventBus.codex_changed.connect(_refresh)
	EventBus.loot_target_changed.connect(_refresh)
	EventBus.core_skill_changed.connect(_on_core_skill_changed)

	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cycle_target"):
		LootCodexSystem.cycle_target_for_current_build()
		if visible:
			_refresh()


func _refresh() -> void:
	title_label.text = "图鉴与目标追踪"
	summary_label.text = _build_summary_text()
	_update_filter_buttons()

	var previous_selection: String = selected_entry_id
	selected_entry_id = ""
	entry_list.clear()

	for entry_variant in _get_current_entries():
		var entry: Dictionary = entry_variant
		var entry_id: String = String(entry.get("id", ""))
		var category: String = String(entry.get("category", "legendary"))
		var label: String = "%s%s%s" % [
			"[发现] " if bool(entry.get("discovered", false)) else "[未发现] ",
			String(entry.get("name", entry_id)),
			" [追踪]" if category == "legendary" and LootCodexSystem.tracked_legendary_affix_id == entry_id else "",
		]
		entry_list.add_item(label)
		entry_list.set_item_metadata(entry_list.item_count - 1, {"id": entry_id, "category": category})
		if entry_id == previous_selection:
			selected_entry_id = previous_selection
			entry_list.select(entry_list.item_count - 1)

	if selected_entry_id.is_empty() and entry_list.item_count > 0:
		var tracked_index: int = _find_list_index_by_id(LootCodexSystem.tracked_legendary_affix_id)
		if tracked_index >= 0:
			entry_list.select(tracked_index)
			var tracked_meta: Dictionary = entry_list.get_item_metadata(tracked_index)
			selected_entry_id = String(tracked_meta.get("id", ""))
		else:
			entry_list.select(0)
			var first_meta: Dictionary = entry_list.get_item_metadata(0)
			selected_entry_id = String(first_meta.get("id", ""))

	_refresh_detail()


func _refresh_detail() -> void:
	var selected_category: String = _get_selected_category()
	detail_label.text = LootCodexSystem.get_codex_detail_text(selected_entry_id, selected_category)
	detail_label.scroll_to_line(0)
	var can_track: bool = not selected_entry_id.is_empty() and selected_category == "legendary"
	track_button.disabled = not can_track
	detail_label.add_theme_color_override("default_color", _get_detail_color())
	if not can_track:
		track_button.text = "仅传奇可追踪"
		action_hint_label.text = _build_action_hint(selected_category, false)
		action_hint_label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88, 1.0))
	else:
		track_button.text = "设为追踪目标" if selected_entry_id != LootCodexSystem.tracked_legendary_affix_id else "当前追踪目标"
		action_hint_label.text = _build_action_hint(selected_category, true)
		action_hint_label.add_theme_color_override(
			"font_color",
			Color(0.98, 0.84, 0.44, 1.0) if selected_entry_id == LootCodexSystem.tracked_legendary_affix_id else Color(0.56, 0.88, 0.62, 1.0)
		)
	_update_button_style(cycle_button, Color(0.54, 0.54, 0.92, 1.0))
	_update_button_style(
		track_button,
		Color(0.98, 0.72, 0.30, 1.0) if can_track and selected_entry_id == LootCodexSystem.tracked_legendary_affix_id
		else (Color(0.34, 0.72, 0.96, 1.0) if can_track else Color(0.42, 0.42, 0.46, 1.0))
	)


func _on_entry_selected(index: int) -> void:
	var metadata: Dictionary = entry_list.get_item_metadata(index)
	selected_entry_id = String(metadata.get("id", ""))
	_refresh_detail()


func _on_track_pressed() -> void:
	if selected_entry_id.is_empty() or _get_selected_category() != "legendary":
		return
	LootCodexSystem.set_tracked_legendary_affix(selected_entry_id)
	_refresh()


func _on_cycle_pressed() -> void:
	LootCodexSystem.cycle_target_for_current_build()
	_refresh()


func _on_close_pressed() -> void:
	EventBus.ui_close_requested.emit()


func open_panel() -> void:
	visible = true
	_refresh()


func _on_core_skill_changed(_skill_id: String) -> void:
	_refresh()


func _on_filter_pressed(category: String) -> void:
	current_category = category
	_refresh()


func _update_filter_buttons() -> void:
	all_button.disabled = current_category == "all"
	base_button.disabled = current_category == "base"
	affix_button.disabled = current_category == "affix"
	legendary_button.disabled = current_category == "legendary"
	_update_button_style(all_button, Color(0.36, 0.52, 0.88, 1.0) if not all_button.disabled else Color(0.24, 0.34, 0.60, 1.0))
	_update_button_style(base_button, Color(0.56, 0.74, 0.86, 1.0) if not base_button.disabled else Color(0.32, 0.42, 0.50, 1.0))
	_update_button_style(affix_button, Color(0.62, 0.84, 0.54, 1.0) if not affix_button.disabled else Color(0.34, 0.46, 0.28, 1.0))
	_update_button_style(legendary_button, Color(0.98, 0.72, 0.30, 1.0) if not legendary_button.disabled else Color(0.56, 0.38, 0.18, 1.0))


func _get_current_entries() -> Array:
	var entries: Array = []
	if current_category == "all":
		entries.append_array(LootCodexSystem.get_codex_entries("base"))
		entries.append_array(LootCodexSystem.get_codex_entries("affix"))
		entries.append_array(LootCodexSystem.get_codex_entries("legendary"))
		return entries
	return LootCodexSystem.get_codex_entries(current_category)


func _get_selected_category() -> String:
	if selected_entry_id.is_empty():
		return current_category if current_category != "all" else "legendary"
	for i in range(entry_list.item_count):
		var metadata: Dictionary = entry_list.get_item_metadata(i)
		if String(metadata.get("id", "")) == selected_entry_id:
			return String(metadata.get("category", "legendary"))
	return current_category


func _find_list_index_by_id(legendary_id: String) -> int:
	for i in range(entry_list.item_count):
		var metadata: Dictionary = entry_list.get_item_metadata(i)
		if String(metadata.get("id", "")) == legendary_id:
			return i
	return -1


func _build_summary_text() -> String:
	var filter_label: String = "全部"
	match current_category:
		"base":
			filter_label = "底材"
		"affix":
			filter_label = "词条"
		"legendary":
			filter_label = "传奇"
	return "当前分类: %s | %s\n%s" % [
		filter_label,
		LootCodexSystem.get_codex_summary_text(),
		LootCodexSystem.get_tracked_target_summary_text(),
	]


func _build_action_hint(_selected_category: String, can_track: bool) -> String:
	if selected_entry_id.is_empty():
		return "未选择条目 | 先从左侧列表中选择一个图鉴条目"

	var selected_entry: Dictionary = _get_selected_entry()
	var discovered: bool = bool(selected_entry.get("discovered", false))
	if not can_track:
		return "当前条目: %s | %s | 仅传奇条目可设为追踪" % [
			String(selected_entry.get("name", selected_entry_id)),
			"已发现" if discovered else "未发现",
		]
	return "当前条目: %s | %s | %s" % [
		String(selected_entry.get("name", selected_entry_id)),
		"已发现" if discovered else "未发现",
		"当前正在追踪" if selected_entry_id == LootCodexSystem.tracked_legendary_affix_id else "可设为追踪目标",
	]


func _get_selected_entry() -> Dictionary:
	for entry_variant in _get_current_entries():
		var entry: Dictionary = entry_variant
		if String(entry.get("id", "")) == selected_entry_id:
			return entry
	return {}


func _get_detail_color() -> Color:
	var selected_category: String = _get_selected_category()
	match selected_category:
		"legendary":
			return Color(1.0, 0.78, 0.40, 1.0)
		"affix":
			return Color(0.70, 0.92, 0.60, 1.0)
		"base":
			return Color(0.66, 0.84, 1.0, 1.0)
		_:
			return Color(0.86, 0.88, 0.94, 1.0)


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
