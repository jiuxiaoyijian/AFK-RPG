extends Control

const UI_STYLE = preload("res://scripts/ui/ui_style.gd")
const CubeSystem = preload("res://scripts/systems/cube_system.gd")

const PAGE_ORDER := ["extract", "upgrade_rare", "reforge", "convert_set", "refine_affix", "martial_codex"]
const PAGE_LABELS := {
	"extract": "萃取武学",
	"upgrade_rare": "精钢化真",
	"reforge": "回炉重铸",
	"convert_set": "传承互转",
	"refine_affix": "淬火精炼",
	"martial_codex": "武学秘录",
}
const PAGE_RECIPE_IDS := {
	"extract": "extract",
	"upgrade_rare": "upgrade_rare",
	"reforge": "reforge",
	"convert_set": "convert_set",
	"refine_affix": "refine_affix",
}
const SLOT_DISPLAY_NAMES := {
	"weapon": "兵器",
	"helmet": "头冠",
	"armor": "护甲",
	"gloves": "手套",
	"legs": "腿甲",
	"boots": "靴子",
	"accessory1": "佩饰1",
	"accessory2": "佩饰2",
	"belt": "腰带",
}
const CODEX_SLOT_LABELS := {
	"weapon": "兵器武学",
	"armor": "护甲武学",
	"accessory": "佩饰武学",
}

@onready var equipment_generator: Node = $"../../Systems/EquipmentGeneratorSystem"
@onready var title_label: Label = $Panel/TitleLabel
@onready var summary_label: Label = $Panel/SummaryLabel
@onready var tab_section_label: Label = $Panel/TabSectionLabel
@onready var list_section_label: Label = $Panel/ListSectionLabel
@onready var detail_section_label: Label = $Panel/DetailSectionLabel
@onready var action_section_label: Label = $Panel/ActionSectionLabel
@onready var extract_button: Button = $Panel/ExtractButton
@onready var upgrade_button: Button = $Panel/UpgradeButton
@onready var reforge_button: Button = $Panel/ReforgeButton
@onready var convert_button: Button = $Panel/ConvertButton
@onready var refine_button: Button = $Panel/RefineButton
@onready var martial_codex_button: Button = $Panel/MartialCodexButton
@onready var entry_list: ItemList = $Panel/EntryList
@onready var detail_label: Label = $Panel/DetailLabel
@onready var option_section_label: Label = $Panel/OptionSectionLabel
@onready var target_slot_label: Label = $Panel/TargetSlotLabel
@onready var target_slot_option: OptionButton = $Panel/TargetSlotOption
@onready var affix_label: Label = $Panel/AffixLabel
@onready var affix_option: OptionButton = $Panel/AffixOption
@onready var weapon_slot_label: Label = $Panel/WeaponSlotLabel
@onready var weapon_slot_option: OptionButton = $Panel/WeaponSlotOption
@onready var armor_slot_label: Label = $Panel/ArmorSlotLabel
@onready var armor_slot_option: OptionButton = $Panel/ArmorSlotOption
@onready var accessory_slot_label: Label = $Panel/AccessorySlotLabel
@onready var accessory_slot_option: OptionButton = $Panel/AccessorySlotOption
@onready var material_label: Label = $Panel/MaterialLabel
@onready var result_label: Label = $Panel/ResultLabel
@onready var status_label: Label = $Panel/StatusLabel
@onready var execute_button: Button = $Panel/ExecuteButton
@onready var close_button: Button = $Panel/CloseButton

var current_page: String = "extract"
var selected_entry_id: String = ""
var target_slot_ids: Array[String] = []
var affix_indices: Array[int] = []
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
	entry_list.item_selected.connect(_on_entry_selected)
	target_slot_option.item_selected.connect(_on_option_changed)
	affix_option.item_selected.connect(_on_option_changed)
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
	_refresh()


func _refresh(_payload: Variant = null) -> void:
	title_label.text = "百炼坊"
	tab_section_label.text = "百炼分支"
	list_section_label.text = "候选目标"
	detail_section_label.text = "目标详情"
	action_section_label.text = "材料与结果"
	option_section_label.text = "必要选项"
	summary_label.text = _build_summary_text()
	_update_tab_buttons()
	_refresh_entry_list()
	_refresh_options()
	_refresh_detail_and_actions()


func _refresh_entry_list() -> void:
	var previous_selection: String = selected_entry_id
	selected_entry_id = ""
	entry_list.clear()
	if current_page == "martial_codex":
		for effect_variant in GameManager.get_martial_codex_runtime_state().get("unlocked_effects", []):
			var effect: Dictionary = effect_variant
			var label: String = "[%s] %s" % [
				String(CODEX_SLOT_LABELS.get(String(effect.get("slot_id", "")), "武学")),
				String(effect.get("name", effect.get("effect_id", ""))),
			]
			entry_list.add_item(label)
			entry_list.set_item_metadata(entry_list.item_count - 1, String(effect.get("effect_id", "")))
			if String(effect.get("effect_id", "")) == previous_selection:
				selected_entry_id = previous_selection
				entry_list.select(entry_list.item_count - 1)
	else:
		for item_variant in _get_candidate_items():
			var item: Dictionary = item_variant
			var label: String = "[%s] %s (%.1f)" % [
				GameManager.get_rarity_display_name(String(item.get("rarity", "common"))),
				String(item.get("name", "装备")),
				float(item.get("score", 0.0)),
			]
			if not String(item.get("set_name", "")).is_empty():
				label += " · %s" % String(item.get("set_name", ""))
			entry_list.add_item(label)
			entry_list.set_item_metadata(entry_list.item_count - 1, String(item.get("id", "")))
			if String(item.get("id", "")) == previous_selection:
				selected_entry_id = previous_selection
				entry_list.select(entry_list.item_count - 1)

	if selected_entry_id.is_empty() and entry_list.item_count > 0:
		entry_list.select(0)
		selected_entry_id = String(entry_list.get_item_metadata(0))


func _refresh_options() -> void:
	_set_option_row_visible(target_slot_label, target_slot_option, false)
	_set_option_row_visible(affix_label, affix_option, false)
	_set_option_row_visible(weapon_slot_label, weapon_slot_option, false)
	_set_option_row_visible(armor_slot_label, armor_slot_option, false)
	_set_option_row_visible(accessory_slot_label, accessory_slot_option, false)
	target_slot_ids.clear()
	affix_indices.clear()

	if current_page == "convert_set":
		_set_option_row_visible(target_slot_label, target_slot_option, true)
		target_slot_label.text = "目标槽位"
		_populate_target_slot_option()
	elif current_page == "refine_affix":
		_set_option_row_visible(affix_label, affix_option, true)
		affix_label.text = "精炼词条"
		_populate_affix_option()
	elif current_page == "martial_codex":
		_set_option_row_visible(weapon_slot_label, weapon_slot_option, true)
		_set_option_row_visible(armor_slot_label, armor_slot_option, true)
		_set_option_row_visible(accessory_slot_label, accessory_slot_option, true)
		weapon_slot_label.text = CODEX_SLOT_LABELS["weapon"]
		armor_slot_label.text = CODEX_SLOT_LABELS["armor"]
		accessory_slot_label.text = CODEX_SLOT_LABELS["accessory"]
		_populate_codex_slot_option("weapon", weapon_slot_option)
		_populate_codex_slot_option("armor", armor_slot_option)
		_populate_codex_slot_option("accessory", accessory_slot_option)


func _refresh_detail_and_actions() -> void:
	var recipe_id: String = String(PAGE_RECIPE_IDS.get(current_page, ""))
	execute_button.visible = current_page != "martial_codex"
	if current_page == "martial_codex":
		execute_button.disabled = true
		detail_label.text = _build_codex_detail_text()
		material_label.text = _build_codex_material_text()
		result_label.text = _build_codex_result_text()
		status_label.text = _build_status_text()
		return

	var recipe: Dictionary = CubeSystem.get_recipe(recipe_id)
	var item: Dictionary = _get_selected_item()
	detail_label.text = GameManager.get_item_detail_text(item)
	material_label.text = _build_recipe_cost_text(recipe)
	result_label.text = _build_recipe_preview(recipe_id, item)
	status_label.text = _build_status_text()
	execute_button.disabled = item.is_empty() or not _has_valid_options_for_current_page(item)
	execute_button.text = String(recipe.get("name", "执行"))


func _on_page_pressed(page_id: String) -> void:
	current_page = page_id
	last_status_text = ""
	_refresh()


func _on_entry_selected(index: int) -> void:
	selected_entry_id = String(entry_list.get_item_metadata(index))
	_refresh_options()
	_refresh_detail_and_actions()


func _on_option_changed(_index: int) -> void:
	_refresh_detail_and_actions()


func _on_codex_slot_selected(slot_id: String, index: int) -> void:
	var effect_ids: Array = codex_slot_effect_ids.get(slot_id, [])
	if index < 0 or index >= effect_ids.size():
		return
	var effect_id: String = String(effect_ids[index])
	if slot_id == "accessory" and effect_id.is_empty() and weapon_slot_option.disabled and armor_slot_option.disabled:
		return
	var result: Dictionary = GameManager.activate_martial_codex_effect(slot_id, effect_id)
	last_status_text = "武学配置已更新" if bool(result.get("ok", false)) else String(result.get("reason", "武学配置失败"))
	_refresh()


func _on_execute_pressed() -> void:
	var recipe_id: String = String(PAGE_RECIPE_IDS.get(current_page, ""))
	if recipe_id.is_empty():
		return
	var options: Dictionary = {}
	if current_page == "convert_set":
		if target_slot_option.selected >= 0 and target_slot_option.selected < target_slot_ids.size():
			options["target_slot"] = String(target_slot_ids[target_slot_option.selected])
	elif current_page == "refine_affix":
		if affix_option.selected >= 0 and affix_option.selected < affix_indices.size():
			options["affix_index"] = int(affix_indices[affix_option.selected])
	var result: Dictionary = GameManager.execute_cube_recipe(recipe_id, selected_entry_id, options, equipment_generator)
	last_status_text = String(result.get("summary", "")) if bool(result.get("ok", false)) else String(result.get("reason", "百炼失败"))
	_refresh()


func _on_cube_operation_completed(operation_result: Dictionary) -> void:
	last_status_text = String(operation_result.get("summary", last_status_text))
	if visible:
		_refresh()


func _on_close_pressed() -> void:
	EventBus.ui_close_requested.emit()


func _get_candidate_items() -> Array:
	var items: Array = []
	for item_variant in GameManager.get_inventory_items():
		var item: Dictionary = item_variant
		match current_page:
			"extract":
				if GameManager.get_rarity_rank(String(item.get("rarity", "common"))) >= GameManager.get_rarity_rank("epic") and not item.get("legendary_affix", {}).is_empty():
					items.append(item)
			"upgrade_rare":
				if String(item.get("rarity", "")) == "rare":
					items.append(item)
			"reforge":
				if GameManager.get_rarity_rank(String(item.get("rarity", "common"))) >= GameManager.get_rarity_rank("epic"):
					items.append(item)
			"convert_set":
				if String(item.get("rarity", "")) == "set":
					items.append(item)
			"refine_affix":
				if GameManager.get_rarity_rank(String(item.get("rarity", "common"))) >= GameManager.get_rarity_rank("epic") and not item.get("affixes", []).is_empty():
					items.append(item)
	return items


func _get_selected_item() -> Dictionary:
	for item_variant in GameManager.get_inventory_items():
		var item: Dictionary = item_variant
		if String(item.get("id", "")) == selected_entry_id:
			return item
	return {}


func _populate_target_slot_option() -> void:
	target_slot_option.clear()
	target_slot_ids.clear()
	var item: Dictionary = _get_selected_item()
	if item.is_empty():
		target_slot_option.disabled = true
		target_slot_option.add_item("先选择传承装备")
		return
	for slot_id in _get_convert_target_slots(item):
		target_slot_option.add_item(SLOT_DISPLAY_NAMES.get(slot_id, slot_id))
		target_slot_ids.append(slot_id)
	target_slot_option.disabled = target_slot_ids.is_empty()
	if target_slot_ids.is_empty():
		target_slot_option.add_item("当前无可互转槽位")
	else:
		target_slot_option.select(0)


func _populate_affix_option() -> void:
	affix_option.clear()
	affix_indices.clear()
	var item: Dictionary = _get_selected_item()
	if item.is_empty():
		affix_option.disabled = true
		affix_option.add_item("先选择装备")
		return
	var affixes: Array = item.get("affixes", [])
	if item.has("refine_slot_index"):
		var locked_index: int = int(item.get("refine_slot_index", -1))
		if locked_index >= 0 and locked_index < affixes.size():
			var locked_affix: Dictionary = affixes[locked_index]
			affix_option.add_item("#%d %s" % [locked_index + 1, String(locked_affix.get("name", locked_affix.get("stat_key", "词条")))])
			affix_indices.append(locked_index)
			affix_option.select(0)
			affix_option.disabled = true
			return
	for index in range(affixes.size()):
		var affix: Dictionary = affixes[index]
		affix_option.add_item("#%d %s" % [index + 1, String(affix.get("name", affix.get("stat_key", "词条")))])
		affix_indices.append(index)
	affix_option.disabled = affix_indices.is_empty()
	if affix_indices.is_empty():
		affix_option.add_item("当前无可淬火词条")
	else:
		affix_option.select(0)


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
		codex_slot_effect_ids[slot_id] = [""]
		option_button.select(0)
		option_button.disabled = true
	else:
		option_button.disabled = false


func _get_convert_target_slots(item: Dictionary) -> Array[String]:
	var slots: Array[String] = []
	var set_data: Dictionary = ConfigDB.get_set(String(item.get("set_id", "")))
	if set_data.is_empty():
		return slots
	var current_slot: String = String(item.get("slot", ""))
	for allowed_slot_variant in set_data.get("piece_slots", []):
		var allowed_slot: String = String(allowed_slot_variant)
		if _normalize_slot(allowed_slot) == "accessory":
			for accessory_slot in ["accessory1", "accessory2"]:
				if accessory_slot != current_slot and not slots.has(accessory_slot):
					slots.append(accessory_slot)
			continue
		if allowed_slot != current_slot and not slots.has(allowed_slot):
			slots.append(allowed_slot)
	return slots


func _has_valid_options_for_current_page(item: Dictionary) -> bool:
	if item.is_empty():
		return false
	if current_page == "convert_set":
		return not target_slot_ids.is_empty()
	if current_page == "refine_affix":
		return not affix_indices.is_empty()
	return true


func _build_summary_text() -> String:
	var runtime_state: Dictionary = GameManager.get_martial_codex_runtime_state()
	return "当前分支: %s | 背包 %d 件 | 已解锁武学 %d 项 | 香火钱 %d | 祠灰 %d | 灵核 %d | 真意残片 %d" % [
		PAGE_LABELS.get(current_page, current_page),
		GameManager.get_inventory_count(),
		runtime_state.get("unlocked_effect_ids", []).size(),
		MetaProgressionSystem.gold,
		MetaProgressionSystem.scrap,
		MetaProgressionSystem.core,
		MetaProgressionSystem.legend_shard,
	]


func _build_recipe_cost_text(recipe: Dictionary) -> String:
	if recipe.is_empty():
		return "材料: --"
	var segments: Array[String] = []
	for cost_variant in recipe.get("costs", []):
		var cost: Dictionary = cost_variant
		var resource_id: String = String(cost.get("resource_id", ""))
		segments.append("%s x%d" % [
			MetaProgressionSystem.get_resource_display_name(resource_id),
			int(cost.get("amount", 0)),
		])
	return "材料: %s" % " | ".join(segments)


func _build_recipe_preview(recipe_id: String, item: Dictionary) -> String:
	if item.is_empty():
		return "结果预览: 先从左侧选择一件可处理的装备"
	match recipe_id:
		"extract":
			var legendary_affix: Dictionary = item.get("legendary_affix", {})
			return "结果预览: 解锁武学 %s" % String(legendary_affix.get("name", "未知武学"))
		"upgrade_rare":
			return "结果预览: 保留原 3 条词缀，并补 1 条新词缀 + 1 条武学"
		"reforge":
			return "结果预览: 保留底材/等级/传承信息，全部词缀与武学重随"
		"convert_set":
			var slot_name: String = "--"
			if target_slot_option.selected >= 0 and target_slot_option.selected < target_slot_ids.size():
				slot_name = SLOT_DISPLAY_NAMES.get(target_slot_ids[target_slot_option.selected], target_slot_ids[target_slot_option.selected])
			return "结果预览: 在同一传承内互转到 %s，并重随词缀与武学" % slot_name
		"refine_affix":
			var affix_name: String = "当前词条"
			if affix_option.selected >= 0 and affix_option.selected < affix_indices.size():
				var affix_data: Dictionary = item.get("affixes", [])[affix_indices[affix_option.selected]]
				affix_name = String(affix_data.get("name", affix_data.get("stat_key", "当前词条")))
			return "结果预览: 只重随 %s，其他词条与武学保持不变" % affix_name
		_:
			return "结果预览: --"


func _build_codex_detail_text() -> String:
	var runtime_state: Dictionary = GameManager.get_martial_codex_runtime_state()
	if selected_entry_id.is_empty():
		return "未选择武学秘录\n\n已解锁 %d 项，可在右侧三个槽位中配置激活。" % runtime_state.get("unlocked_effect_ids", []).size()
	for effect_variant in runtime_state.get("unlocked_effects", []):
		var effect: Dictionary = effect_variant
		if String(effect.get("effect_id", "")) != selected_entry_id:
			continue
		return "%s\n槽位: %s\n主词条: %s %+0.2f\n副词条: %s %+0.2f\n\n%s" % [
			String(effect.get("name", selected_entry_id)),
			String(CODEX_SLOT_LABELS.get(String(effect.get("slot_id", "")), "武学")),
			String(effect.get("stat_key", "--")),
			float(effect.get("value", 0.0)),
			String(effect.get("secondary_stat_key", "--")),
			float(effect.get("secondary_value", 0.0)),
			String(effect.get("description", "")),
		]
	return "未找到该武学详情"


func _build_codex_material_text() -> String:
	var runtime_state: Dictionary = GameManager.get_martial_codex_runtime_state()
	var active_effects: Array = runtime_state.get("active_effects", [])
	return "已解锁武学: %d 项\n当前激活: %d 项\n佩饰槽: 暂未开放可用武学" % [
		runtime_state.get("unlocked_effect_ids", []).size(),
		active_effects.size(),
	]


func _build_codex_result_text() -> String:
	var runtime_state: Dictionary = GameManager.get_martial_codex_runtime_state()
	var segments: Array[String] = []
	for slot_id in ["weapon", "armor", "accessory"]:
		var active_effect_id: String = String(runtime_state.get("active_slots", {}).get(slot_id, ""))
		var active_name: String = "未装配"
		for effect_variant in runtime_state.get("unlocked_effects", []):
			var effect: Dictionary = effect_variant
			if String(effect.get("effect_id", "")) == active_effect_id:
				active_name = String(effect.get("name", active_effect_id))
				break
		segments.append("%s: %s" % [CODEX_SLOT_LABELS.get(slot_id, slot_id), active_name])
	return "当前配置: %s" % " | ".join(segments)


func _build_status_text() -> String:
	return "当前状态: %s" % (last_status_text if not last_status_text.is_empty() else "等待操作")


func _normalize_slot(slot_id: String) -> String:
	return "accessory" if slot_id.begins_with("accessory") else slot_id


func _set_option_row_visible(label_node: Label, option_button: OptionButton, row_visible: bool) -> void:
	label_node.visible = row_visible
	option_button.visible = row_visible


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
		_update_button_style(page_button, _get_page_color(page_id))


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


func _apply_visual_style() -> void:
	UI_STYLE.style_label(title_label, "title")
	UI_STYLE.style_label(summary_label, "accent")
	UI_STYLE.style_label(tab_section_label, "heading")
	UI_STYLE.style_label(list_section_label, "heading")
	UI_STYLE.style_label(detail_section_label, "heading")
	UI_STYLE.style_label(action_section_label, "warning")
	UI_STYLE.style_label(option_section_label, "heading")
	UI_STYLE.style_item_list(entry_list)
	detail_label.add_theme_color_override("font_color", Color(0.84, 0.88, 0.94, 1.0))
	detail_label.add_theme_font_size_override("font_size", 12)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	material_label.add_theme_color_override("font_color", Color(0.94, 0.82, 0.54, 1.0))
	material_label.add_theme_font_size_override("font_size", 12)
	result_label.add_theme_color_override("font_color", Color(0.78, 0.90, 1.0, 1.0))
	result_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color(0.84, 0.92, 0.76, 1.0))
	status_label.add_theme_font_size_override("font_size", 12)
	_update_button_style(close_button, UI_STYLE.COLOR_TEXT_DIM)
	_update_button_style(execute_button, UI_STYLE.COLOR_GOLD)


func _update_button_style(button: Button, color: Color) -> void:
	UI_STYLE.style_button(button, color, button.disabled)
