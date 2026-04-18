extends Control

const ItemCardScene = preload("res://scenes/ui/item_card_button.tscn")
const UI_STYLE = preload("res://scripts/ui/ui_style.gd")
const InventoryViewModelService = preload("res://scripts/utils/inventory_view_model_service.gd")
const RuntimeTextureLoader = preload("res://scripts/utils/runtime_texture_loader.gd")

const MAIN_PANEL_TEXTURE_PATH := "res://assets/generated/afk_rpg_formal/ui/inventory/inventory_main_frame_9patch.png"
const HEADER_BAR_TEXTURE_PATH := "res://assets/generated/afk_rpg_formal/ui/inventory/inventory_header_bar_9patch.png"
const PAPER_DOLL_PANEL_TEXTURE_PATH := "res://assets/generated/afk_rpg_formal/ui/inventory/paper_doll_panel_9patch.png"
const INVENTORY_GRID_PANEL_TEXTURE_PATH := "res://assets/generated/afk_rpg_formal/ui/inventory/inventory_grid_panel_9patch.png"
const DETAIL_PANEL_TEXTURE_PATH := "res://assets/generated/afk_rpg_formal/ui/inventory/detail_panel_9patch.png"
const TOOLBAR_PANEL_TEXTURE_PATH := "res://assets/generated/afk_rpg_formal/ui/inventory/toolbar_panel_9patch.png"
const GRID_CELL_FRAME_TEXTURE_PATH := "res://assets/generated/afk_rpg_formal/ui/inventory/inventory_cell_frame.png"
const EQUIPMENT_SLOT_FRAME_TEXTURE_PATH := "res://assets/generated/afk_rpg_formal/ui/equipment_slot_base.png"
const OPTION_DROPDOWN_TEXTURE_PATH := "res://assets/generated/afk_rpg_formal/ui/controls/option_dropdown_base.png"
const PAGE_ARROW_LEFT_TEXTURE_PATH := "res://assets/generated/afk_rpg_formal/ui/controls/page_arrow_left.png"
const PAGE_ARROW_RIGHT_TEXTURE_PATH := "res://assets/generated/afk_rpg_formal/ui/controls/page_arrow_right.png"
const BUTTON_PRIMARY_TEXTURE_PATH := "res://assets/generated/afk_rpg_formal/ui/controls/button_primary_base.png"
const BUTTON_SECONDARY_TEXTURE_PATH := "res://assets/generated/afk_rpg_formal/ui/controls/button_secondary_base.png"
const BUTTON_DANGER_TEXTURE_PATH := "res://assets/generated/afk_rpg_formal/ui/controls/button_danger_base.png"

@onready var panel: Panel = $Panel
@onready var header_bar: Panel = $Panel/HeaderBar
@onready var title_label: Label = $Panel/TitleLabel
@onready var summary_label: Label = $Panel/SummaryLabel
@onready var paper_doll_section: Panel = $Panel/PaperDollSection
@onready var paper_doll_section_label: Label = $Panel/PaperDollSection/PaperDollSectionLabel
@onready var paper_doll_summary_label: Label = $Panel/PaperDollSection/PaperDollSummaryLabel
@onready var paper_doll_grid: GridContainer = $Panel/PaperDollSection/PaperDollGrid
@onready var inventory_section: Panel = $Panel/InventorySection
@onready var inventory_section_label: Label = $Panel/InventorySection/InventorySectionLabel
@onready var filter_label: Label = $Panel/InventorySection/FilterLabel
@onready var filter_option: OptionButton = $Panel/InventorySection/FilterOption
@onready var sort_label: Label = $Panel/InventorySection/SortLabel
@onready var sort_option: OptionButton = $Panel/InventorySection/SortOption
@onready var prev_page_button: Button = $Panel/InventorySection/PrevPageButton
@onready var page_label: Label = $Panel/InventorySection/PageLabel
@onready var next_page_button: Button = $Panel/InventorySection/NextPageButton
@onready var inventory_grid: GridContainer = $Panel/InventorySection/InventoryGrid
@onready var detail_section: Panel = $Panel/DetailSection
@onready var detail_section_label: Label = $Panel/DetailSection/DetailSectionLabel
@onready var badge_label: Label = $Panel/DetailSection/BadgeLabel
@onready var detail_label: Label = $Panel/DetailSection/DetailLabel
@onready var compare_label: Label = $Panel/DetailSection/CompareLabel
@onready var toolbar_section: Panel = $Panel/ToolbarSection
@onready var toolbar_section_label: Label = $Panel/ToolbarSection/ToolbarSectionLabel
@onready var action_hint_label: Label = $Panel/ToolbarSection/ActionHintLabel
@onready var threshold_button: Button = $Panel/ToolbarSection/ThresholdButton
@onready var equip_button: Button = $Panel/ToolbarSection/EquipButton
@onready var unequip_button: Button = $Panel/ToolbarSection/UnequipButton
@onready var lock_button: Button = $Panel/ToolbarSection/LockButton
@onready var salvage_button: Button = $Panel/ToolbarSection/SalvageButton
@onready var close_button: Button = $Panel/ToolbarSection/CloseButton

var selected_item_id: String = ""
var selected_slot_id: String = ""
var current_page: int = 0
var current_filter_id: String = InventoryViewModelService.FILTER_ALL
var current_sort_id: String = InventoryViewModelService.SORT_SCORE_DESC

var grid_buttons: Array = []
var equipment_buttons: Dictionary = {}
var filter_option_ids: Array[String] = []
var sort_option_ids: Array[String] = []


func _ready() -> void:
	visible = false
	_apply_visual_style()
	_build_equipment_buttons()
	_build_inventory_grid()
	_populate_filter_option()
	_populate_sort_option()

	filter_option.item_selected.connect(_on_filter_changed)
	sort_option.item_selected.connect(_on_sort_changed)
	prev_page_button.pressed.connect(_on_prev_page_pressed)
	next_page_button.pressed.connect(_on_next_page_pressed)
	threshold_button.pressed.connect(_on_threshold_pressed)
	equip_button.pressed.connect(_on_equip_pressed)
	unequip_button.pressed.connect(_on_unequip_pressed)
	lock_button.pressed.connect(_on_lock_pressed)
	salvage_button.pressed.connect(_on_salvage_pressed)
	close_button.pressed.connect(_on_close_pressed)

	EventBus.inventory_changed.connect(_refresh)
	EventBus.equipment_changed.connect(_refresh)
	EventBus.resources_changed.connect(_refresh)
	EventBus.set_bonus_changed.connect(_refresh)
	EventBus.martial_codex_changed.connect(_refresh)

	_refresh()


func open_panel() -> void:
	visible = true
	_apply_open_focus()
	_refresh()


func _refresh(_payload: Variant = null) -> void:
	title_label.text = "角色与背包"
	inventory_section_label.text = "格子背包"
	paper_doll_section_label.text = "角色纸娃娃"
	detail_section_label.text = "详情与对比"
	toolbar_section_label.text = "快捷操作"
	threshold_button.text = GameManager.get_auto_salvage_label()

	var screen_state: Dictionary = GameManager.get_inventory_screen_state(
		current_page,
		current_filter_id,
		current_sort_id,
		selected_item_id,
		selected_slot_id
	)
	if screen_state.get("selected_item", {}).is_empty() and screen_state.get("selected_equipped_item", {}).is_empty():
		var fallback_id: String = _get_first_visible_item_id(screen_state)
		if not fallback_id.is_empty():
			selected_item_id = fallback_id
			selected_slot_id = ""
			screen_state = GameManager.get_inventory_screen_state(
				current_page,
				current_filter_id,
				current_sort_id,
				selected_item_id,
				selected_slot_id
			)

	var equipment_state: Dictionary = GameManager.get_equipment_screen_state()
	summary_label.text = "%s | 格子 %d/%d" % [
		String(screen_state.get("summary_text", "")),
		int(screen_state.get("used_count", 0)),
		int(screen_state.get("capacity", 40)),
	]
	paper_doll_summary_label.text = "%s | %s | %s" % [
		String(equipment_state.get("inventory_summary", "")),
		String(equipment_state.get("set_summary_line", "")),
		String(equipment_state.get("codex_summary_line", "")),
	]
	page_label.text = "第 %d / %d 页" % [
		int(screen_state.get("page", 0)) + 1,
		int(screen_state.get("page_count", 1)),
	]
	prev_page_button.disabled = int(screen_state.get("page", 0)) <= 0
	next_page_button.disabled = int(screen_state.get("page", 0)) >= int(screen_state.get("page_count", 1)) - 1
	UI_STYLE.style_button(prev_page_button, UI_STYLE.COLOR_BLUE, prev_page_button.disabled)
	UI_STYLE.style_button(next_page_button, UI_STYLE.COLOR_BLUE, next_page_button.disabled)
	current_page = int(screen_state.get("page", 0))

	_refresh_equipment_buttons(equipment_state)
	_refresh_grid_buttons(screen_state)
	_refresh_detail(screen_state)


func _refresh_equipment_buttons(equipment_state: Dictionary) -> void:
	for slot_entry_variant in equipment_state.get("slots", []):
		var slot_entry: Dictionary = slot_entry_variant
		var slot_id: String = String(slot_entry.get("slot_id", ""))
		var button = equipment_buttons.get(slot_id, null)
		if button == null:
			continue
		var is_empty: bool = bool(slot_entry.get("is_empty", true))
		var accent: Color = Color(0.36, 0.42, 0.50, 1.0) if is_empty else GameManager.get_rarity_color(String(slot_entry.get("rarity", "common")))
		button.configure({
			"title": String(slot_entry.get("display_name", slot_id)),
			"subtitle": String(slot_entry.get("title", "未装备")),
			"badges": slot_entry.get("badges", []),
			"tooltip_text": String(slot_entry.get("subtitle", "未装备")),
			"accent_color": accent,
			"slot_id": slot_id,
			"rarity": String(slot_entry.get("rarity", "common")),
			"selected": selected_slot_id == slot_id and selected_item_id.is_empty(),
			"compact_mode": "equipment",
			"min_size": Vector2(70, 72),
			"is_placeholder": is_empty,
			"frame_texture_path": EQUIPMENT_SLOT_FRAME_TEXTURE_PATH,
			"frame_modulate": Color(1, 1, 1, 0.45) if is_empty else Color(1, 1, 1, 0.92),
		})


func _refresh_grid_buttons(screen_state: Dictionary) -> void:
	var entries: Array = screen_state.get("grid_entries", [])
	for index in range(grid_buttons.size()):
		var button = grid_buttons[index]
		var entry: Dictionary = entries[index]
		var has_item: bool = String(entry.get("kind", "")) == "item"
		var accent: Color = Color(0.26, 0.30, 0.36, 1.0)
		if has_item:
			accent = GameManager.get_rarity_color(String(entry.get("rarity", "common")))
			if bool(entry.get("is_high_value", false)):
				accent = accent.lightened(0.08)
		button.configure({
			"title": String(entry.get("title", "")) if has_item else "空格",
			"subtitle": String(entry.get("subtitle", "")) if has_item else "可存放 1 件",
			"badges": entry.get("badges", []),
			"tooltip_text": "%s\n%s" % [
				String(entry.get("title", "")),
				String(entry.get("subtitle", "")),
			] if has_item else "空格位",
			"accent_color": accent,
			"slot_id": String(entry.get("slot", "")),
			"rarity": String(entry.get("rarity", "common")),
			"disabled": not has_item,
			"selected": has_item and selected_item_id == String(entry.get("item_id", "")),
			"compact_mode": "grid",
			"min_size": Vector2(44, 56),
			"is_placeholder": not has_item,
			"frame_texture_path": GRID_CELL_FRAME_TEXTURE_PATH,
			"frame_modulate": Color(1, 1, 1, 0.56) if not has_item else Color(1, 1, 1, 0.96),
		})


func _refresh_detail(screen_state: Dictionary) -> void:
	var selected_item: Dictionary = screen_state.get("selected_item", {})
	var compare_summary: Dictionary = screen_state.get("compare_summary", {})
	var badges: Array = screen_state.get("detail_badges", [])

	detail_label.text = String(screen_state.get("detail_text", "未选择物品"))
	compare_label.text = "%s\n%s" % [
		String(compare_summary.get("title", "装备对比")),
		"\n".join(compare_summary.get("lines", [])),
	]
	badge_label.text = "标签: %s" % (" | ".join(badges) if not badges.is_empty() else "暂无")
	detail_label.add_theme_color_override("font_color", _get_selected_color(selected_item))
	compare_label.add_theme_color_override(
		"font_color",
		Color(0.72, 0.90, 0.76, 1.0) if bool(compare_summary.get("is_upgrade", false)) else Color(0.82, 0.86, 0.92, 1.0)
	)

	var action_state: Dictionary = screen_state.get("action_state", {})
	equip_button.disabled = not bool(action_state.get("can_equip", false))
	unequip_button.disabled = not bool(action_state.get("can_unequip", false))
	lock_button.disabled = not bool(action_state.get("can_lock", false))
	salvage_button.disabled = not bool(action_state.get("can_salvage", false))
	lock_button.text = "解锁" if bool(selected_item.get("is_locked", false)) else "锁定"
	action_hint_label.text = _build_action_hint(screen_state)

	UI_STYLE.style_button(threshold_button, UI_STYLE.COLOR_BLUE, false)
	UI_STYLE.style_button(equip_button, UI_STYLE.COLOR_GREEN, equip_button.disabled)
	UI_STYLE.style_button(unequip_button, UI_STYLE.COLOR_BLUE, unequip_button.disabled)
	UI_STYLE.style_button(lock_button, UI_STYLE.COLOR_GOLD, lock_button.disabled)
	UI_STYLE.style_button(salvage_button, UI_STYLE.COLOR_RED, salvage_button.disabled)
	UI_STYLE.style_button(close_button, UI_STYLE.COLOR_TEXT_MUTED, false)
	_apply_inventory_control_textures()


func _build_equipment_buttons() -> void:
	for child in paper_doll_grid.get_children():
		child.queue_free()
	equipment_buttons.clear()
	for slot_id in GameManager.EQUIPMENT_SLOT_ORDER:
		var button = ItemCardScene.instantiate()
		button.name = "Equipment_%s" % slot_id
		button.pressed.connect(_on_equipped_slot_pressed.bind(slot_id))
		paper_doll_grid.add_child(button)
		equipment_buttons[slot_id] = button


func _build_inventory_grid() -> void:
	for child in inventory_grid.get_children():
		child.queue_free()
	grid_buttons.clear()
	for index in range(InventoryViewModelService.PAGE_SIZE):
		var button = ItemCardScene.instantiate()
		button.name = "InventoryCell_%d" % index
		button.pressed.connect(_on_grid_button_pressed.bind(index))
		inventory_grid.add_child(button)
		grid_buttons.append(button)


func _populate_filter_option() -> void:
	filter_option.clear()
	filter_option_ids.clear()
	for entry_variant in InventoryViewModelService.get_filter_options():
		var entry: Dictionary = entry_variant
		filter_option.add_item(String(entry.get("label", "全部")))
		filter_option_ids.append(String(entry.get("id", InventoryViewModelService.FILTER_ALL)))
	filter_option.select(filter_option_ids.find(current_filter_id))


func _populate_sort_option() -> void:
	sort_option.clear()
	sort_option_ids.clear()
	for entry_variant in InventoryViewModelService.get_sort_options():
		var entry: Dictionary = entry_variant
		sort_option.add_item(String(entry.get("label", "按评分")))
		sort_option_ids.append(String(entry.get("id", InventoryViewModelService.SORT_SCORE_DESC)))
	sort_option.select(sort_option_ids.find(current_sort_id))


func _on_grid_button_pressed(index: int) -> void:
	var screen_state: Dictionary = GameManager.get_inventory_screen_state(
		current_page,
		current_filter_id,
		current_sort_id,
		selected_item_id,
		selected_slot_id
	)
	var entries: Array = screen_state.get("grid_entries", [])
	if index < 0 or index >= entries.size():
		return
	var entry: Dictionary = entries[index]
	if String(entry.get("kind", "")) != "item":
		return
	selected_item_id = String(entry.get("item_id", ""))
	selected_slot_id = ""
	_refresh()


func _on_equipped_slot_pressed(slot_id: String) -> void:
	selected_slot_id = slot_id
	selected_item_id = ""
	_refresh()


func _on_filter_changed(index: int) -> void:
	if index < 0 or index >= filter_option_ids.size():
		return
	current_filter_id = filter_option_ids[index]
	current_page = 0
	selected_item_id = ""
	selected_slot_id = ""
	_refresh()


func _on_sort_changed(index: int) -> void:
	if index < 0 or index >= sort_option_ids.size():
		return
	current_sort_id = sort_option_ids[index]
	current_page = 0
	selected_item_id = ""
	selected_slot_id = ""
	_refresh()


func _on_prev_page_pressed() -> void:
	current_page = maxi(0, current_page - 1)
	selected_item_id = ""
	selected_slot_id = ""
	_refresh()


func _on_next_page_pressed() -> void:
	current_page += 1
	selected_item_id = ""
	selected_slot_id = ""
	_refresh()


func _on_equip_pressed() -> void:
	if selected_item_id.is_empty():
		return
	GameManager.equip_inventory_item(selected_item_id)
	selected_item_id = ""
	selected_slot_id = ""
	_refresh()


func _on_unequip_pressed() -> void:
	if selected_slot_id.is_empty():
		return
	GameManager.unequip_slot(selected_slot_id)
	selected_item_id = ""
	selected_slot_id = ""
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
	selected_item_id = ""
	_refresh()


func _on_threshold_pressed() -> void:
	GameManager.cycle_auto_salvage_threshold()
	_refresh()


func _on_close_pressed() -> void:
	EventBus.ui_close_requested.emit()


func _apply_open_focus() -> void:
	var focus_request: Dictionary = GameManager.consume_ui_focus_request("inventory")
	if focus_request.is_empty():
		return
	selected_item_id = String(focus_request.get("selected_item_id", selected_item_id))
	selected_slot_id = String(focus_request.get("selected_slot_id", selected_slot_id))
	current_filter_id = String(focus_request.get("filter_id", current_filter_id))
	current_sort_id = String(focus_request.get("sort_id", current_sort_id))
	current_page = int(focus_request.get("page", current_page))
	if not selected_item_id.is_empty():
		selected_slot_id = ""
	elif not selected_slot_id.is_empty():
		selected_item_id = ""
	var filter_index: int = filter_option_ids.find(current_filter_id)
	if filter_index != -1:
		filter_option.select(filter_index)
	var sort_index: int = sort_option_ids.find(current_sort_id)
	if sort_index != -1:
		sort_option.select(sort_index)


func _build_action_hint(screen_state: Dictionary) -> String:
	var selected_item: Dictionary = screen_state.get("selected_inventory_item", {})
	var selected_equipped_item: Dictionary = screen_state.get("selected_equipped_item", {})
	if not selected_item.is_empty():
		return "当前选择: %s | 先看右侧对比，再决定穿戴、锁定或送去百炼坊。" % String(selected_item.get("name", "装备"))
	if not selected_equipped_item.is_empty():
		return "当前选择: 已穿戴 %s | 可直接卸下回到格子背包。" % String(selected_equipped_item.get("name", "装备"))
	return "先从纸娃娃或格子背包里选一件物品。"


func _get_selected_color(item: Dictionary) -> Color:
	if item.is_empty():
		return Color(0.82, 0.84, 0.90, 1.0)
	return GameManager.get_rarity_color(String(item.get("rarity", "common")))


func _get_first_visible_item_id(screen_state: Dictionary) -> String:
	for entry_variant in screen_state.get("grid_entries", []):
		var entry: Dictionary = entry_variant
		if String(entry.get("kind", "")) == "item":
			return String(entry.get("item_id", ""))
	return ""


func _apply_visual_style() -> void:
	_apply_inventory_panel_styles()
	UI_STYLE.style_label(title_label, "title")
	UI_STYLE.style_label(summary_label, "accent")
	UI_STYLE.style_label(paper_doll_section_label, "heading")
	UI_STYLE.style_label(paper_doll_summary_label, "muted")
	UI_STYLE.style_label(inventory_section_label, "heading")
	UI_STYLE.style_label(filter_label, "tiny")
	UI_STYLE.style_label(sort_label, "tiny")
	UI_STYLE.style_label(page_label, "muted")
	UI_STYLE.style_label(detail_section_label, "heading")
	UI_STYLE.style_label(badge_label, "warning")
	UI_STYLE.style_label(toolbar_section_label, "heading")
	UI_STYLE.style_label(action_hint_label, "muted")
	detail_label.add_theme_font_size_override("font_size", 12)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	compare_label.add_theme_font_size_override("font_size", 12)
	compare_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI_STYLE.style_option_button(filter_option, UI_STYLE.COLOR_BLUE)
	UI_STYLE.style_option_button(sort_option, UI_STYLE.COLOR_BLUE)
	UI_STYLE.style_button(prev_page_button, UI_STYLE.COLOR_BLUE, false)
	UI_STYLE.style_button(next_page_button, UI_STYLE.COLOR_BLUE, false)
	_apply_inventory_control_textures()


func _apply_inventory_panel_styles() -> void:
	_apply_warm_panel_style(panel, Color(0.17, 0.13, 0.09, 0.94), Color(0.62, 0.50, 0.34, 0.82), 20, Vector2(18, 14))
	_apply_warm_panel_style(header_bar, Color(0.24, 0.18, 0.12, 0.90), Color(0.72, 0.58, 0.38, 0.88), 16, Vector2(12, 10))
	_apply_warm_panel_style(paper_doll_section, Color(0.15, 0.13, 0.10, 0.86), Color(0.64, 0.54, 0.38, 0.74), 16, Vector2(14, 12))
	_apply_warm_panel_style(inventory_section, Color(0.13, 0.11, 0.09, 0.90), Color(0.60, 0.50, 0.34, 0.74), 16, Vector2(14, 12))
	_apply_warm_panel_style(detail_section, Color(0.18, 0.15, 0.12, 0.88), Color(0.72, 0.60, 0.40, 0.82), 16, Vector2(14, 12))
	_apply_warm_panel_style(toolbar_section, Color(0.18, 0.15, 0.12, 0.90), Color(0.68, 0.56, 0.38, 0.78), 16, Vector2(14, 10))

	_apply_panel_texture_overlay(panel, MAIN_PANEL_TEXTURE_PATH, Color(1, 1, 1, 0.92), "MainTextureFrame")
	_apply_panel_texture_overlay(header_bar, HEADER_BAR_TEXTURE_PATH, Color(1, 1, 1, 0.96), "HeaderTextureFrame")
	_apply_panel_texture_overlay(paper_doll_section, PAPER_DOLL_PANEL_TEXTURE_PATH, Color(1, 1, 1, 0.92), "SectionTextureFrame")
	_apply_panel_texture_overlay(inventory_section, INVENTORY_GRID_PANEL_TEXTURE_PATH, Color(1, 1, 1, 0.92), "SectionTextureFrame")
	_apply_panel_texture_overlay(detail_section, DETAIL_PANEL_TEXTURE_PATH, Color(1, 1, 1, 0.94), "SectionTextureFrame")
	_apply_panel_texture_overlay(toolbar_section, TOOLBAR_PANEL_TEXTURE_PATH, Color(1, 1, 1, 0.92), "SectionTextureFrame")


func _apply_warm_panel_style(
	target_panel: Panel,
	bg_color: Color,
	border_color: Color,
	corner_radius: int,
	content_margin: Vector2
) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	style.shadow_size = 8
	style.shadow_color = Color(0, 0, 0, 0.14)
	style.content_margin_left = content_margin.x
	style.content_margin_top = content_margin.y
	style.content_margin_right = content_margin.x
	style.content_margin_bottom = content_margin.y
	target_panel.add_theme_stylebox_override("panel", style)


func _apply_panel_texture_overlay(target_panel: Control, texture_path: String, tint: Color, overlay_name: String) -> void:
	var overlay := target_panel.get_node_or_null(overlay_name) as TextureRect
	if overlay == null:
		overlay = TextureRect.new()
		overlay.name = overlay_name
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.z_index = 0
		overlay.show_behind_parent = false
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		target_panel.add_child(overlay)
		target_panel.move_child(overlay, 0)
	overlay.texture = RuntimeTextureLoader.load_texture(texture_path)
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	overlay.modulate = tint


func _apply_inventory_control_textures() -> void:
	_apply_panel_texture_overlay(filter_option, OPTION_DROPDOWN_TEXTURE_PATH, Color(1, 1, 1, 0.98), "OptionTextureFrame")
	_apply_panel_texture_overlay(sort_option, OPTION_DROPDOWN_TEXTURE_PATH, Color(1, 1, 1, 0.98), "OptionTextureFrame")
	_apply_panel_texture_overlay(threshold_button, BUTTON_PRIMARY_TEXTURE_PATH, Color(1, 1, 1, 0.98), "ButtonTextureFrame")
	_apply_panel_texture_overlay(equip_button, BUTTON_PRIMARY_TEXTURE_PATH, Color(1, 1, 1, 0.98), "ButtonTextureFrame")
	_apply_panel_texture_overlay(unequip_button, BUTTON_SECONDARY_TEXTURE_PATH, Color(1, 1, 1, 0.98), "ButtonTextureFrame")
	_apply_panel_texture_overlay(lock_button, BUTTON_SECONDARY_TEXTURE_PATH, Color(1, 1, 1, 0.98), "ButtonTextureFrame")
	_apply_panel_texture_overlay(close_button, BUTTON_SECONDARY_TEXTURE_PATH, Color(1, 1, 1, 0.98), "ButtonTextureFrame")
	_apply_panel_texture_overlay(salvage_button, BUTTON_DANGER_TEXTURE_PATH, Color(1, 1, 1, 0.98), "ButtonTextureFrame")
	_apply_icon_button_texture(prev_page_button, PAGE_ARROW_LEFT_TEXTURE_PATH, "ArrowTextureFrame")
	_apply_icon_button_texture(next_page_button, PAGE_ARROW_RIGHT_TEXTURE_PATH, "ArrowTextureFrame")


func _apply_icon_button_texture(target_button: Button, texture_path: String, overlay_name: String) -> void:
	target_button.text = ""
	_apply_panel_texture_overlay(target_button, texture_path, Color(1, 1, 1, 0.98), overlay_name)
