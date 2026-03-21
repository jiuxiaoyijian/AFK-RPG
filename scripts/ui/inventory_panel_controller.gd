extends Control

@onready var title_label: Label = $Panel/TitleLabel
@onready var threshold_button: Button = $Panel/ThresholdButton
@onready var summary_label: Label = $Panel/SummaryLabel
@onready var inventory_list: ItemList = $Panel/InventoryList
@onready var detail_label: Label = $Panel/DetailLabel
@onready var list_section_label: Label = $Panel/ListSectionLabel
@onready var detail_section_label: Label = $Panel/DetailSectionLabel
@onready var action_section_label: Label = $Panel/ActionSectionLabel
@onready var action_hint_label: Label = $Panel/ActionHintLabel
@onready var equip_button: Button = $Panel/EquipButton
@onready var lock_button: Button = $Panel/LockButton
@onready var salvage_button: Button = $Panel/SalvageButton
@onready var close_button: Button = $Panel/CloseButton

var selected_item_id: String = ""


func _ready() -> void:
	visible = false
	_apply_visual_style()
	inventory_list.item_selected.connect(_on_item_selected)
	equip_button.pressed.connect(_on_equip_pressed)
	lock_button.pressed.connect(_on_lock_pressed)
	salvage_button.pressed.connect(_on_salvage_pressed)
	threshold_button.pressed.connect(_on_threshold_pressed)
	close_button.pressed.connect(_on_close_pressed)

	EventBus.inventory_changed.connect(_refresh)
	EventBus.equipment_changed.connect(_refresh)
	EventBus.resources_changed.connect(_refresh)

	_refresh()


func _refresh() -> void:
	title_label.text = "背包与装备管理"
	threshold_button.text = GameManager.get_auto_salvage_label()
	summary_label.text = _build_inventory_summary()

	var previous_selection: String = selected_item_id
	selected_item_id = ""
	inventory_list.clear()

	for item in GameManager.get_inventory_items():
		var item_data: Dictionary = item
		var label := "%s %s" % [
			"[锁]" if bool(item_data.get("is_locked", false)) else "",
			_format_item_short(item_data),
		]
		inventory_list.add_item(label.strip_edges())
		inventory_list.set_item_metadata(inventory_list.item_count - 1, String(item_data.get("id", "")))
		if String(item_data.get("id", "")) == previous_selection:
			selected_item_id = previous_selection
			inventory_list.select(inventory_list.item_count - 1)

	if selected_item_id.is_empty() and inventory_list.item_count > 0:
		inventory_list.select(0)
		selected_item_id = String(inventory_list.get_item_metadata(0))

	_refresh_detail()


func _refresh_detail() -> void:
	var item: Dictionary = _find_selected_item()
	detail_label.text = GameManager.get_item_detail_text(item)
	var has_item: bool = not item.is_empty()
	equip_button.disabled = not has_item
	lock_button.disabled = not has_item
	salvage_button.disabled = not has_item or bool(item.get("is_locked", false))
	lock_button.text = "解锁" if bool(item.get("is_locked", false)) else "锁定"
	equip_button.text = "装备到对应槽位" if has_item else "装备"
	salvage_button.text = "已锁定，无法分解" if bool(item.get("is_locked", false)) else "分解为祠灰"
	detail_label.add_theme_color_override("font_color", _get_item_detail_color(item))
	action_hint_label.text = _build_action_hint(item)
	action_hint_label.add_theme_color_override("font_color", _get_action_hint_color(item))
	_update_button_style(threshold_button, Color(0.34, 0.52, 0.88, 1.0))
	_update_button_style(equip_button, Color(0.32, 0.74, 0.48, 1.0) if has_item else Color(0.42, 0.42, 0.46, 1.0))
	_update_button_style(
		lock_button,
		Color(0.84, 0.72, 0.30, 1.0) if has_item else Color(0.42, 0.42, 0.46, 1.0)
	)
	_update_button_style(
		salvage_button,
		Color(0.86, 0.40, 0.38, 1.0) if not salvage_button.disabled else Color(0.42, 0.42, 0.46, 1.0)
	)


func _on_item_selected(index: int) -> void:
	selected_item_id = String(inventory_list.get_item_metadata(index))
	_refresh_detail()


func _on_equip_pressed() -> void:
	if selected_item_id.is_empty():
		return
	GameManager.equip_inventory_item(selected_item_id)
	_refresh()


func _on_lock_pressed() -> void:
	if selected_item_id.is_empty():
		return
	GameManager.toggle_inventory_lock(selected_item_id)
	_refresh()


func _on_salvage_pressed() -> void:
	if selected_item_id.is_empty():
		return
	GameManager.salvage_inventory_item(selected_item_id)
	_refresh()


func _on_threshold_pressed() -> void:
	GameManager.cycle_auto_salvage_threshold()
	_refresh()


func _on_close_pressed() -> void:
	EventBus.ui_close_requested.emit()


func open_panel() -> void:
	visible = true
	_refresh()


func _find_selected_item() -> Dictionary:
	for item in GameManager.get_inventory_items():
		var item_data: Dictionary = item
		if String(item_data.get("id", "")) == selected_item_id:
			return item_data
	return {}


func _format_item_short(item: Dictionary) -> String:
	return "[%s] %s (%.1f)" % [
		String(item.get("rarity", "common")),
		String(item.get("name", "未知装备")),
		float(item.get("score", 0.0)),
	]


func _build_inventory_summary() -> String:
	var inventory_items: Array = GameManager.get_inventory_items()
	var locked_count: int = 0
	for item_variant in inventory_items:
		var item: Dictionary = item_variant
		if bool(item.get("is_locked", false)):
			locked_count += 1

	var equipped_count: int = 0
	for slot in ["weapon", "helmet", "armor", "gloves"]:
		if not GameManager.get_equipped_item(slot).is_empty():
			equipped_count += 1

	return "库存 %d 件 | 锁定 %d 件 | 已装备 %d/4\n当前刷图关注: %s" % [
		inventory_items.size(),
		locked_count,
		equipped_count,
		GameManager.get_current_drop_focus(),
	]


func _build_action_hint(item: Dictionary) -> String:
	if item.is_empty():
		return "未选择物品 | 先从左侧列表挑一件准备查看或操作"

	var status_label: String = "已锁定，适合留作备选" if bool(item.get("is_locked", false)) else "可装备或分解"
	return "当前选择: %s | %s | 评分 %.1f" % [
		String(item.get("name", "未知装备")),
		status_label,
		float(item.get("score", 0.0)),
	]


func _get_item_detail_color(item: Dictionary) -> Color:
	if item.is_empty():
		return Color(0.82, 0.84, 0.90, 1.0)
	return _get_rarity_color(String(item.get("rarity", "common")))


func _get_action_hint_color(item: Dictionary) -> Color:
	if item.is_empty():
		return Color(0.74, 0.78, 0.86, 1.0)
	if bool(item.get("is_locked", false)):
		return Color(0.95, 0.82, 0.40, 1.0)
	return Color(0.52, 0.86, 0.60, 1.0)


func _get_rarity_color(rarity: String) -> Color:
	match rarity:
		"legendary":
			return Color(1.0, 0.72, 0.28, 1.0)
		"epic":
			return Color(0.84, 0.52, 1.0, 1.0)
		"rare":
			return Color(0.46, 0.74, 1.0, 1.0)
		_:
			return Color(0.88, 0.90, 0.94, 1.0)


func _apply_visual_style() -> void:
	title_label.add_theme_color_override("font_color", Color(0.98, 0.92, 0.72, 1.0))
	summary_label.add_theme_color_override("font_color", Color(0.78, 0.84, 0.96, 1.0))
	list_section_label.add_theme_color_override("font_color", Color(0.66, 0.82, 1.0, 1.0))
	detail_section_label.add_theme_color_override("font_color", Color(0.72, 0.90, 1.0, 1.0))
	action_section_label.add_theme_color_override("font_color", Color(0.98, 0.86, 0.54, 1.0))
	action_hint_label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88, 1.0))
	_update_button_style(close_button, Color(0.50, 0.50, 0.56, 1.0))


func _update_button_style(button: Button, color: Color) -> void:
	button.self_modulate = color
