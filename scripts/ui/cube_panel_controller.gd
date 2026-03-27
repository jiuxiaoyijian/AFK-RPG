extends Control

const ItemCardScene = preload("res://scenes/ui/item_card_button.tscn")
const UI_STYLE = preload("res://scripts/ui/ui_style.gd")
const CubeViewModelService = preload("res://scripts/utils/cube_view_model_service.gd")
const ItemPresentationService = preload("res://scripts/utils/item_presentation_service.gd")

const PAGE_ORDER := ["extract", "upgrade_rare", "reforge", "convert_set", "refine_affix", "martial_codex"]
const PAGE_LABELS := {
	"extract": "萃取武学",
	"upgrade_rare": "精钢化真",
	"reforge": "回炉重铸",
	"convert_set": "传承互转",
	"refine_affix": "淬火精炼",
	"martial_codex": "武学秘录",
}
const CODEX_SLOT_LABELS := {
	"weapon": "兵器武学",
	"armor": "护甲武学",
	"accessory": "佩饰武学",
}

@onready var equipment_generator: Node = $"../../Systems/EquipmentGeneratorSystem"
@onready var title_label: Label = $Panel/TitleLabel
@onready var summary_label: Label = $Panel/SummaryLabel
@onready var tab_section_label: Label = $Panel/TabSection/TabSectionLabel
@onready var extract_button: Button = $Panel/TabSection/ExtractButton
@onready var upgrade_button: Button = $Panel/TabSection/UpgradeButton
@onready var reforge_button: Button = $Panel/TabSection/ReforgeButton
@onready var convert_button: Button = $Panel/TabSection/ConvertButton
@onready var refine_button: Button = $Panel/TabSection/RefineButton
@onready var martial_codex_button: Button = $Panel/TabSection/MartialCodexButton
@onready var candidate_section_label: Label = $Panel/CandidateSection/CandidateSectionLabel
@onready var candidate_scroll: ScrollContainer = $Panel/CandidateSection/CandidateScroll
@onready var candidate_list: VBoxContainer = $Panel/CandidateSection/CandidateScroll/CandidateList
@onready var detail_section_label: Label = $Panel/DetailSection/DetailSectionLabel
@onready var detail_label: Label = $Panel/DetailSection/DetailLabel
@onready var option_section_label: Label = $Panel/DetailSection/OptionSectionLabel
@onready var target_slot_label: Label = $Panel/DetailSection/TargetSlotLabel
@onready var target_slot_option: OptionButton = $Panel/DetailSection/TargetSlotOption
@onready var affix_label: Label = $Panel/DetailSection/AffixLabel
@onready var affix_option: OptionButton = $Panel/DetailSection/AffixOption
@onready var weapon_slot_label: Label = $Panel/DetailSection/WeaponSlotLabel
@onready var weapon_slot_option: OptionButton = $Panel/DetailSection/WeaponSlotOption
@onready var armor_slot_label: Label = $Panel/DetailSection/ArmorSlotLabel
@onready var armor_slot_option: OptionButton = $Panel/DetailSection/ArmorSlotOption
@onready var accessory_slot_label: Label = $Panel/DetailSection/AccessorySlotLabel
@onready var accessory_slot_option: OptionButton = $Panel/DetailSection/AccessorySlotOption
@onready var action_section_label: Label = $Panel/ActionSection/ActionSectionLabel
@onready var material_label: Label = $Panel/ActionSection/MaterialLabel
@onready var result_label: Label = $Panel/ActionSection/ResultLabel
@onready var status_label: Label = $Panel/ActionSection/StatusLabel
@onready var execute_button: Button = $Panel/ActionSection/ExecuteButton
@onready var close_button: Button = $Panel/ActionSection/CloseButton

var current_page: String = "extract"
var selected_entry_id: String = ""
var selected_target_slot: String = ""
var selected_affix_index: int = -1
var codex_slot_effect_ids: Dictionary = {
	"weapon": [],
	"armor": [],
	"accessory": [],
}
var last_status_text: String = ""


func _ready() -> void:
	visible = false
	_apply_visual_style()
	extract_button.pressed.connect(_on_page_pressed.bind("extract"))
	upgrade_button.pressed.connect(_on_page_pressed.bind("upgrade_rare"))
	reforge_button.pressed.connect(_on_page_pressed.bind("reforge"))
	convert_button.pressed.connect(_on_page_pressed.bind("convert_set"))
	refine_button.pressed.connect(_on_page_pressed.bind("refine_affix"))
	martial_codex_button.pressed.connect(_on_page_pressed.bind("martial_codex"))
	target_slot_option.item_selected.connect(_on_target_slot_selected)
	affix_option.item_selected.connect(_on_affix_selected)
	weapon_slot_option.item_selected.connect(_on_codex_slot_selected.bind("weapon"))
	armor_slot_option.item_selected.connect(_on_codex_slot_selected.bind("armor"))
	accessory_slot_option.item_selected.connect(_on_codex_slot_selected.bind("accessory"))
	execute_button.pressed.connect(_on_execute_pressed)
	close_button.pressed.connect(_on_close_pressed)

	EventBus.inventory_changed.connect(_refresh)
	EventBus.resources_changed.connect(_refresh)
	EventBus.martial_codex_changed.connect(_refresh)
	EventBus.cube_operation_completed.connect(_on_cube_operation_completed)

	_refresh()


func open_panel() -> void:
	visible = true
	_apply_open_focus()
	_refresh()


func _refresh(_payload: Variant = null) -> void:
	title_label.text = "百炼坊"
	tab_section_label.text = "工坊分支"
	candidate_section_label.text = "候选目标"
	detail_section_label.text = "目标详情"
	option_section_label.text = "必要选项"
	action_section_label.text = "材料与结果"

	var screen_state: Dictionary = GameManager.get_cube_screen_state(
		current_page,
		selected_entry_id,
		selected_target_slot,
		selected_affix_index
	)
	if _should_select_first_entry(screen_state):
		selected_entry_id = String(screen_state.get("candidate_entries", [])[0].get("id", ""))
		screen_state = GameManager.get_cube_screen_state(
			current_page,
			selected_entry_id,
			selected_target_slot,
			selected_affix_index
		)

	summary_label.text = String(screen_state.get("summary_text", "百炼概览"))
	_update_tab_buttons()
	_refresh_candidate_list(screen_state)
	_refresh_option_controls(screen_state)
	_refresh_detail_and_actions(screen_state)


func _refresh_candidate_list(screen_state: Dictionary) -> void:
	for child in candidate_list.get_children():
		child.queue_free()

	for entry_variant in screen_state.get("candidate_entries", []):
		var entry: Dictionary = entry_variant
		var button = ItemCardScene.instantiate()
		button.name = "Candidate_%s" % String(entry.get("id", "entry"))
		button.pressed.connect(_on_candidate_pressed.bind(String(entry.get("id", ""))))
		var accent: Color = GameManager.get_rarity_color(String(entry.get("rarity", "common")))
		button.configure({
			"title": String(entry.get("title", "")),
			"subtitle": String(entry.get("subtitle", "")),
			"badges": entry.get("badges", []),
			"tooltip_text": "标签: %s" % (" | ".join(entry.get("badges", [])) if not entry.get("badges", []).is_empty() else "暂无"),
			"accent_color": accent,
			"slot_id": String(entry.get("slot", "")),
			"rarity": String(entry.get("rarity", "common")),
			"selected": selected_entry_id == String(entry.get("id", "")),
			"compact_mode": "candidate",
			"min_size": Vector2(0, 58),
		})
		candidate_list.add_child(button)

	if candidate_list.get_child_count() == 0:
		var empty_label := Label.new()
		empty_label.text = "当前分支暂无可处理目标"
		UI_STYLE.style_label(empty_label, "muted")
		candidate_list.add_child(empty_label)


func _refresh_option_controls(screen_state: Dictionary) -> void:
	var is_codex_mode: bool = String(screen_state.get("mode", "")) == "codex"
	_set_option_row_visible(target_slot_label, target_slot_option, false)
	_set_option_row_visible(affix_label, affix_option, false)
	_set_option_row_visible(weapon_slot_label, weapon_slot_option, false)
	_set_option_row_visible(armor_slot_label, armor_slot_option, false)
	_set_option_row_visible(accessory_slot_label, accessory_slot_option, false)

	if is_codex_mode:
		_set_option_row_visible(weapon_slot_label, weapon_slot_option, true)
		_set_option_row_visible(armor_slot_label, armor_slot_option, true)
		_set_option_row_visible(accessory_slot_label, accessory_slot_option, true)
		weapon_slot_label.text = CODEX_SLOT_LABELS["weapon"]
		armor_slot_label.text = CODEX_SLOT_LABELS["armor"]
		accessory_slot_label.text = CODEX_SLOT_LABELS["accessory"]
		_populate_codex_slot_option("weapon", weapon_slot_option)
		_populate_codex_slot_option("armor", armor_slot_option)
		_populate_codex_slot_option("accessory", accessory_slot_option)
		return

	if current_page == "convert_set":
		_set_option_row_visible(target_slot_label, target_slot_option, true)
		target_slot_label.text = "目标槽位"
		_populate_target_slot_option(screen_state.get("target_slots", []))
	elif current_page == "refine_affix":
		_set_option_row_visible(affix_label, affix_option, true)
		affix_label.text = "精炼词条"
		_populate_affix_option(screen_state.get("affix_entries", []))


func _refresh_detail_and_actions(screen_state: Dictionary) -> void:
	detail_label.text = String(screen_state.get("detail_text", "未选择目标"))
	material_label.text = String(screen_state.get("material_text", "材料: --"))
	result_label.text = String(screen_state.get("result_preview_text", "结果预览: --"))
	status_label.text = "当前状态: %s" % (last_status_text if not last_status_text.is_empty() else "等待操作")

	var is_codex_mode: bool = String(screen_state.get("mode", "")) == "codex"
	execute_button.visible = not is_codex_mode
	execute_button.disabled = is_codex_mode or not bool(screen_state.get("can_execute", false)) or not _has_required_options(screen_state)
	if not is_codex_mode:
		var recipe: Dictionary = screen_state.get("recipe", {})
		execute_button.text = String(recipe.get("name", "执行百炼"))


func _populate_target_slot_option(target_slots: Array) -> void:
	target_slot_option.clear()
	if target_slots.is_empty():
		target_slot_option.add_item("当前无可互转槽位")
		target_slot_option.disabled = true
		selected_target_slot = ""
		return
	var selected_index: int = 0
	for index in range(target_slots.size()):
		var slot_id: String = String(target_slots[index])
		target_slot_option.add_item(ItemPresentationService.get_slot_display_name(slot_id))
		if slot_id == selected_target_slot:
			selected_index = index
	target_slot_option.disabled = false
	target_slot_option.select(selected_index)
	selected_target_slot = String(target_slots[selected_index])


func _populate_affix_option(affix_entries: Array) -> void:
	affix_option.clear()
	if affix_entries.is_empty():
		affix_option.add_item("当前无可淬火词条")
		affix_option.disabled = true
		selected_affix_index = -1
		return
	var selected_index: int = 0
	for index in range(affix_entries.size()):
		var entry: Dictionary = affix_entries[index]
		affix_option.add_item(String(entry.get("label", "词条")))
		if int(entry.get("index", -1)) == selected_affix_index:
			selected_index = index
	affix_option.disabled = false
	affix_option.select(selected_index)
	selected_affix_index = int(affix_entries[selected_index].get("index", -1))
	affix_option.disabled = bool(affix_entries[selected_index].get("is_locked", false))


func _populate_codex_slot_option(slot_id: String, option_button: OptionButton) -> void:
	option_button.clear()
	var runtime_state: Dictionary = GameManager.get_martial_codex_runtime_state()
	var active_slots: Dictionary = runtime_state.get("active_slots", {})
	var available_effects: Array = runtime_state.get("available_by_slot", {}).get(slot_id, [])
	var effect_ids: Array = [""]
	option_button.add_item("未装配")
	for effect_variant in available_effects:
		var effect: Dictionary = effect_variant
		option_button.add_item(String(effect.get("name", effect.get("effect_id", ""))))
		effect_ids.append(String(effect.get("effect_id", "")))
	codex_slot_effect_ids[slot_id] = effect_ids
	var active_effect_id: String = String(active_slots.get(slot_id, ""))
	var active_index: int = effect_ids.find(active_effect_id)
	if active_index == -1:
		active_index = 0
	option_button.select(active_index)
	if slot_id == "accessory" and available_effects.is_empty():
		option_button.clear()
		option_button.add_item("暂未开放可用武学")
		option_button.select(0)
		option_button.disabled = true
		codex_slot_effect_ids[slot_id] = [""]
	else:
		option_button.disabled = false


func _has_required_options(screen_state: Dictionary) -> bool:
	match current_page:
		"convert_set":
			return not screen_state.get("target_slots", []).is_empty() and not selected_target_slot.is_empty()
		"refine_affix":
			return not screen_state.get("affix_entries", []).is_empty() and selected_affix_index >= 0
		_:
			return true


func _should_select_first_entry(screen_state: Dictionary) -> bool:
	var entries: Array = screen_state.get("candidate_entries", [])
	if entries.is_empty():
		return false
	if selected_entry_id.is_empty():
		return true
	for entry_variant in entries:
		var entry: Dictionary = entry_variant
		if String(entry.get("id", "")) == selected_entry_id:
			return false
	return true


func _on_page_pressed(page_id: String) -> void:
	current_page = page_id
	selected_entry_id = ""
	selected_target_slot = ""
	selected_affix_index = -1
	last_status_text = ""
	_refresh()


func _on_candidate_pressed(entry_id: String) -> void:
	selected_entry_id = entry_id
	last_status_text = ""
	_refresh()


func _on_target_slot_selected(index: int) -> void:
	var screen_state: Dictionary = GameManager.get_cube_screen_state(current_page, selected_entry_id, selected_target_slot, selected_affix_index)
	var target_slots: Array = screen_state.get("target_slots", [])
	if index < 0 or index >= target_slots.size():
		return
	selected_target_slot = String(target_slots[index])
	_refresh()


func _on_affix_selected(index: int) -> void:
	var screen_state: Dictionary = GameManager.get_cube_screen_state(current_page, selected_entry_id, selected_target_slot, selected_affix_index)
	var affix_entries: Array = screen_state.get("affix_entries", [])
	if index < 0 or index >= affix_entries.size():
		return
	selected_affix_index = int(affix_entries[index].get("index", -1))
	_refresh()


func _on_codex_slot_selected(slot_id: String, index: int) -> void:
	var effect_ids: Array = codex_slot_effect_ids.get(slot_id, [])
	if index < 0 or index >= effect_ids.size():
		return
	var effect_id: String = String(effect_ids[index])
	var result: Dictionary = GameManager.activate_martial_codex_effect(slot_id, effect_id)
	last_status_text = "武学配置已更新" if bool(result.get("ok", false)) else String(result.get("reason", "武学配置失败"))
	_refresh()


func _on_execute_pressed() -> void:
	var options: Dictionary = {}
	if current_page == "convert_set":
		options["target_slot"] = selected_target_slot
	elif current_page == "refine_affix":
		options["affix_index"] = selected_affix_index
	var result: Dictionary = GameManager.execute_cube_recipe(current_page, selected_entry_id, options, equipment_generator)
	last_status_text = String(result.get("summary", "")) if bool(result.get("ok", false)) else String(result.get("reason", "百炼失败"))
	selected_entry_id = ""
	_refresh()


func _on_cube_operation_completed(operation_result: Dictionary) -> void:
	last_status_text = String(operation_result.get("summary", last_status_text))
	if visible:
		_refresh()


func _on_close_pressed() -> void:
	EventBus.ui_close_requested.emit()


func _apply_open_focus() -> void:
	var focus_request: Dictionary = GameManager.consume_ui_focus_request("cube")
	if focus_request.is_empty():
		return
	current_page = String(focus_request.get("page_id", current_page))
	selected_entry_id = String(focus_request.get("selected_entry_id", selected_entry_id))
	selected_target_slot = String(focus_request.get("selected_target_slot", selected_target_slot))
	selected_affix_index = int(focus_request.get("selected_affix_index", selected_affix_index))
	last_status_text = String(focus_request.get("status_text", last_status_text))


func _update_tab_buttons() -> void:
	var button_map: Dictionary = {
		"extract": extract_button,
		"upgrade_rare": upgrade_button,
		"reforge": reforge_button,
		"convert_set": convert_button,
		"refine_affix": refine_button,
		"martial_codex": martial_codex_button,
	}
	for page_id in PAGE_ORDER:
		var page_button: Button = button_map[page_id]
		page_button.disabled = current_page == page_id
		UI_STYLE.style_button(page_button, _get_page_color(page_id), page_button.disabled)


func _get_page_color(page_id: String) -> Color:
	match page_id:
		"extract":
			return Color(0.86, 0.46, 0.34, 1.0)
		"upgrade_rare":
			return Color(0.86, 0.72, 0.32, 1.0)
		"reforge":
			return Color(0.48, 0.72, 0.96, 1.0)
		"convert_set":
			return Color(0.42, 0.82, 0.56, 1.0)
		"refine_affix":
			return Color(0.96, 0.60, 0.34, 1.0)
		_:
			return Color(0.76, 0.64, 0.96, 1.0)


func _set_option_row_visible(label_node: Label, option_button: OptionButton, row_visible: bool) -> void:
	label_node.visible = row_visible
	option_button.visible = row_visible


func _apply_visual_style() -> void:
	UI_STYLE.style_label(title_label, "title")
	UI_STYLE.style_label(summary_label, "accent")
	UI_STYLE.style_label(tab_section_label, "heading")
	UI_STYLE.style_label(candidate_section_label, "heading")
	UI_STYLE.style_label(detail_section_label, "heading")
	UI_STYLE.style_label(option_section_label, "heading")
	UI_STYLE.style_label(action_section_label, "warning")
	UI_STYLE.style_label(status_label, "muted")
	detail_label.add_theme_color_override("font_color", Color(0.84, 0.88, 0.94, 1.0))
	detail_label.add_theme_font_size_override("font_size", 12)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	material_label.add_theme_color_override("font_color", Color(0.94, 0.82, 0.54, 1.0))
	material_label.add_theme_font_size_override("font_size", 12)
	result_label.add_theme_color_override("font_color", Color(0.78, 0.90, 1.0, 1.0))
	result_label.add_theme_font_size_override("font_size", 12)
	UI_STYLE.style_option_button(target_slot_option, UI_STYLE.COLOR_BLUE)
	UI_STYLE.style_option_button(affix_option, UI_STYLE.COLOR_BLUE)
	UI_STYLE.style_option_button(weapon_slot_option, UI_STYLE.COLOR_BLUE)
	UI_STYLE.style_option_button(armor_slot_option, UI_STYLE.COLOR_BLUE)
	UI_STYLE.style_option_button(accessory_slot_option, UI_STYLE.COLOR_BLUE)
	UI_STYLE.style_button(execute_button, UI_STYLE.COLOR_GREEN, false)
	UI_STYLE.style_button(close_button, UI_STYLE.COLOR_TEXT_MUTED, false)
