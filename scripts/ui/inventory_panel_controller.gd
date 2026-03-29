extends Control

const PANEL_FRAME_PATH := "res://assets/generated/afk_rpg_formal/ui/sliced/panel_9patch_frame.png"
const SLOT_DISPLAY_NAMES := {
	"weapon": "兵器", "helmet": "头冠", "armor": "护甲",
	"gloves": "手套", "legs": "腿甲", "boots": "靴子",
	"accessory1": "佩饰1", "accessory2": "佩饰2", "belt": "腰带",
}
const ITEMS_PER_PAGE := 40

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/TitleLabel
@onready var summary_label: Label = $Panel/SummaryLabel
@onready var paper_doll_summary_label: Label = $Panel/PaperDollSection/PaperDollSummaryLabel
@onready var paper_doll_grid: GridContainer = $Panel/PaperDollSection/PaperDollGrid
@onready var inventory_grid: GridContainer = $Panel/InventorySection/InventoryGrid
@onready var page_label: Label = $Panel/InventorySection/PageLabel
@onready var prev_page_button: Button = $Panel/InventorySection/PrevPageButton
@onready var next_page_button: Button = $Panel/InventorySection/NextPageButton
@onready var detail_label: Label = $Panel/DetailSection/DetailLabel
@onready var badge_label: Label = $Panel/DetailSection/BadgeLabel
@onready var compare_label: Label = $Panel/DetailSection/CompareLabel
@onready var action_hint_label: Label = $Panel/ToolbarSection/ActionHintLabel
@onready var threshold_button: Button = $Panel/ToolbarSection/ThresholdButton
@onready var equip_button: Button = $Panel/ToolbarSection/EquipButton
@onready var unequip_button: Button = $Panel/ToolbarSection/UnequipButton
@onready var lock_button: Button = $Panel/ToolbarSection/LockButton
@onready var salvage_button: Button = $Panel/ToolbarSection/SalvageButton
@onready var close_button: Button = $Panel/ToolbarSection/CloseButton

var selected_item_id: String = ""
var current_page: int = 0
var total_pages: int = 1


func _ready() -> void:
	visible = false
	_apply_visual_style()
	equip_button.pressed.connect(_on_equip_pressed)
	unequip_button.pressed.connect(_on_unequip_pressed)
	lock_button.pressed.connect(_on_lock_pressed)
	salvage_button.pressed.connect(_on_salvage_pressed)
	threshold_button.pressed.connect(_on_threshold_pressed)
	close_button.pressed.connect(_on_close_pressed)
	prev_page_button.pressed.connect(_on_prev_page)
	next_page_button.pressed.connect(_on_next_page)

	EventBus.inventory_changed.connect(_refresh)
	EventBus.equipment_changed.connect(_refresh)
	EventBus.resources_changed.connect(_refresh)

	_refresh()


func _refresh() -> void:
	title_label.text = "角色与背包"
	threshold_button.text = GameManager.get_auto_salvage_label()
	summary_label.text = _build_inventory_summary()
	_refresh_paper_doll()
	_refresh_inventory_grid()
	_refresh_detail()


func _refresh_paper_doll() -> void:
	for child in paper_doll_grid.get_children():
		child.queue_free()
	var equipped_lines: Array[String] = []
	for slot_id in GameManager.EQUIPMENT_SLOT_ORDER:
		var item: Dictionary = GameManager.get_equipped_item(slot_id)
		var display_name: String = SLOT_DISPLAY_NAMES.get(slot_id, slot_id)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(72, 28)
		btn.clip_text = true
		if item.is_empty():
			btn.text = "%s: --" % display_name
			btn.add_theme_font_size_override("font_size", 10)
			btn.add_theme_color_override("font_color", Color(0.52, 0.54, 0.58))
		else:
			var rarity: String = String(item.get("rarity", "common"))
			btn.text = "%s: %s" % [display_name, String(item.get("name", "--"))]
			btn.add_theme_font_size_override("font_size", 10)
			btn.add_theme_color_override("font_color", GameManager.get_rarity_color(rarity))
			equipped_lines.append("[%s] %s" % [display_name, String(item.get("name", "--"))])
		paper_doll_grid.add_child(btn)
	paper_doll_summary_label.text = "已装备 %d/9 槽位" % equipped_lines.size()


func _refresh_inventory_grid() -> void:
	for child in inventory_grid.get_children():
		child.queue_free()

	var all_items: Array = GameManager.get_inventory_items()
	total_pages = maxi(1, ceili(float(all_items.size()) / float(ITEMS_PER_PAGE)))
	current_page = mini(current_page, total_pages - 1)
	page_label.text = "第 %d / %d 页" % [current_page + 1, total_pages]
	prev_page_button.disabled = current_page <= 0
	next_page_button.disabled = current_page >= total_pages - 1

	var start_idx: int = current_page * ITEMS_PER_PAGE
	var end_idx: int = mini(start_idx + ITEMS_PER_PAGE, all_items.size())

	var previous_selection: String = selected_item_id
	var found_previous: bool = false

	for i in range(start_idx, end_idx):
		var item_data: Dictionary = all_items[i]
		var item_id: String = String(item_data.get("id", ""))
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(46, 46)
		btn.clip_text = true
		var rarity: String = String(item_data.get("rarity", "common"))
		var locked_prefix: String = "🔒" if bool(item_data.get("is_locked", false)) else ""
		btn.text = "%s%s" % [locked_prefix, String(item_data.get("name", "?")).left(4)]
		btn.add_theme_font_size_override("font_size", 9)
		btn.add_theme_color_override("font_color", GameManager.get_rarity_color(rarity))
		btn.tooltip_text = _format_item_short(item_data)
		btn.pressed.connect(_on_grid_item_selected.bind(item_id))
		inventory_grid.add_child(btn)
		if item_id == previous_selection:
			found_previous = true

	if not found_previous and all_items.size() > 0:
		selected_item_id = String(all_items[mini(start_idx, all_items.size() - 1)].get("id", ""))
	elif all_items.is_empty():
		selected_item_id = ""


func _on_grid_item_selected(item_id: String) -> void:
	selected_item_id = item_id
	_refresh_detail()


func _refresh_detail() -> void:
	var item: Dictionary = _find_selected_item()
	detail_label.text = GameManager.get_item_detail_text(item)
	var has_item: bool = not item.is_empty()
	equip_button.disabled = not has_item
	unequip_button.disabled = not has_item
	lock_button.disabled = not has_item
	salvage_button.disabled = not has_item or bool(item.get("is_locked", false))
	lock_button.text = "解锁" if bool(item.get("is_locked", false)) else "锁定"
	equip_button.text = "装备" if has_item else "装备"
	salvage_button.text = "已锁定" if bool(item.get("is_locked", false)) else "分解"
	detail_label.add_theme_color_override("font_color", _get_item_detail_color(item))
	action_hint_label.text = _build_action_hint(item)
	action_hint_label.add_theme_color_override("font_color", _get_action_hint_color(item))

	if has_item:
		var rarity: String = String(item.get("rarity", "common"))
		badge_label.text = "品质: %s  评分: %.1f" % [
			GameManager.get_rarity_display_name(rarity),
			float(item.get("score", 0.0)),
		]
		badge_label.add_theme_color_override("font_color", GameManager.get_rarity_color(rarity))
		var slot_id: String = String(item.get("slot", ""))
		var equipped_item: Dictionary = GameManager.get_equipped_item(slot_id) if not slot_id.is_empty() else {}
		if equipped_item.is_empty():
			compare_label.text = "当前槽位无装备"
		else:
			compare_label.text = "当前装备: %s\n评分: %.1f" % [
				String(equipped_item.get("name", "--")),
				float(equipped_item.get("score", 0.0)),
			]
	else:
		badge_label.text = "标签: --"
		compare_label.text = "装备对比"


func _on_equip_pressed() -> void:
	if selected_item_id.is_empty():
		return
	GameManager.equip_inventory_item(selected_item_id)
	_refresh()


func _on_unequip_pressed() -> void:
	pass


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


func _on_prev_page() -> void:
	if current_page > 0:
		current_page -= 1
		_refresh_inventory_grid()
		_refresh_detail()


func _on_next_page() -> void:
	if current_page < total_pages - 1:
		current_page += 1
		_refresh_inventory_grid()
		_refresh_detail()


func open_panel() -> void:
	visible = true
	current_page = 0
	_refresh()


func _find_selected_item() -> Dictionary:
	for item in GameManager.get_inventory_items():
		var item_data: Dictionary = item
		if String(item_data.get("id", "")) == selected_item_id:
			return item_data
	return {}


func _format_item_short(item: Dictionary) -> String:
	var rarity_display: String = GameManager.get_rarity_display_name(String(item.get("rarity", "common")))
	return "[%s] %s (%.1f)" % [
		rarity_display,
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
	for slot in GameManager.EQUIPMENT_SLOT_ORDER:
		if not GameManager.get_equipped_item(slot).is_empty():
			equipped_count += 1
	return "库存 %d 件 | 锁定 %d 件 | 已装备 %d/9 | 刷图关注: %s" % [
		inventory_items.size(), locked_count, equipped_count,
		GameManager.get_current_drop_focus(),
	]


func _build_action_hint(item: Dictionary) -> String:
	if item.is_empty():
		return "未选择物品 | 先从背包格子中选一件查看"
	var status_label: String = "已锁定" if bool(item.get("is_locked", false)) else "可装备或分解"
	return "选中: %s | %s | 评分 %.1f" % [
		String(item.get("name", "未知装备")), status_label, float(item.get("score", 0.0)),
	]


func _get_item_detail_color(item: Dictionary) -> Color:
	if item.is_empty():
		return Color(0.82, 0.84, 0.90, 1.0)
	return GameManager.get_rarity_color(String(item.get("rarity", "common")))


func _get_action_hint_color(item: Dictionary) -> Color:
	if item.is_empty():
		return Color(0.74, 0.78, 0.86, 1.0)
	if bool(item.get("is_locked", false)):
		return Color(0.95, 0.82, 0.40, 1.0)
	return Color(0.52, 0.86, 0.60, 1.0)


func _apply_visual_style() -> void:
	title_label.add_theme_color_override("font_color", Color(0.98, 0.92, 0.72, 1.0))
	summary_label.add_theme_color_override("font_color", Color(0.78, 0.84, 0.96, 1.0))
	action_hint_label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88, 1.0))
	_apply_panel_frame()


func _apply_panel_frame() -> void:
	var frame_texture: Texture2D = RuntimeTextureLoader.load_texture(PANEL_FRAME_PATH)
	if frame_texture == null:
		return
	var frame_rect := TextureRect.new()
	frame_rect.name = "PanelFrame"
	frame_rect.texture = frame_texture
	frame_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame_rect.stretch_mode = TextureRect.STRETCH_SCALE
	frame_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame_rect.anchors_preset = Control.PRESET_FULL_RECT
	frame_rect.anchor_right = 1.0
	frame_rect.anchor_bottom = 1.0
	frame_rect.z_index = 10
	panel.add_child(frame_rect)
