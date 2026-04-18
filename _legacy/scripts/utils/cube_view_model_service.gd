class_name CubeViewModelService
extends RefCounted

const CubeSystem = preload("res://scripts/systems/cube_system.gd")
const ItemPresentationService = preload("res://scripts/utils/item_presentation_service.gd")

const PAGE_RECIPE_IDS := {
	"extract": "extract",
	"upgrade_rare": "upgrade_rare",
	"reforge": "reforge",
	"convert_set": "convert_set",
	"refine_affix": "refine_affix",
}
const CODEX_SLOT_LABELS := {
	"weapon": "兵器武学",
	"armor": "护甲武学",
	"accessory": "佩饰武学",
}


static func build_screen_state(
	page_id: String,
	inventory_items: Array,
	codex_runtime_state: Dictionary,
	selected_entry_id: String = "",
	selected_target_slot: String = "",
	selected_affix_index: int = -1
) -> Dictionary:
	if page_id == "martial_codex":
		return _build_codex_state(codex_runtime_state, selected_entry_id)

	var recipe_id: String = String(PAGE_RECIPE_IDS.get(page_id, ""))
	var recipe: Dictionary = CubeSystem.get_recipe(recipe_id)
	var candidates: Array = _get_candidate_items(page_id, inventory_items)
	var selected_item: Dictionary = _find_item_by_id(candidates, selected_entry_id)
	if selected_item.is_empty() and not candidates.is_empty():
		selected_item = candidates[0]

	var target_slots: Array = []
	if page_id == "convert_set":
		target_slots = _get_convert_target_slots(selected_item)
	var affix_entries: Array = []
	if page_id == "refine_affix":
		affix_entries = _get_affix_entries(selected_item)

	return {
		"mode": "recipe",
		"page_id": page_id,
		"recipe_id": recipe_id,
		"recipe": recipe,
		"summary_text": _build_summary_text(page_id, codex_runtime_state, inventory_items),
		"candidate_entries": _build_candidate_entries(candidates),
		"selected_item": selected_item,
		"detail_text": GameManager.get_item_detail_text(selected_item),
		"material_text": _build_recipe_cost_text(recipe),
		"result_preview_text": _build_recipe_preview(page_id, selected_item, selected_target_slot, selected_affix_index, affix_entries),
		"target_slots": target_slots,
		"affix_entries": affix_entries,
		"can_execute": not selected_item.is_empty(),
	}


static func _build_codex_state(runtime_state: Dictionary, selected_effect_id: String) -> Dictionary:
	var unlocked_effects: Array = runtime_state.get("unlocked_effects", [])
	var selected_effect: Dictionary = {}
	for effect_variant in unlocked_effects:
		var effect: Dictionary = effect_variant
		if String(effect.get("effect_id", "")) == selected_effect_id:
			selected_effect = effect
			break
	if selected_effect.is_empty() and not unlocked_effects.is_empty():
		selected_effect = unlocked_effects[0]
	return {
		"mode": "codex",
		"summary_text": "已解锁武学 %d 项 | 当前激活 %d 项" % [
			runtime_state.get("unlocked_effect_ids", []).size(),
			runtime_state.get("active_effects", []).size(),
		],
		"candidate_entries": _build_codex_entries(unlocked_effects),
		"selected_item": selected_effect,
		"detail_text": _build_codex_detail_text(selected_effect),
		"material_text": _build_codex_material_text(runtime_state),
		"result_preview_text": _build_codex_result_text(runtime_state),
		"can_execute": false,
	}


static func _build_summary_text(page_id: String, codex_runtime_state: Dictionary, inventory_items: Array) -> String:
	return "当前分支: %s | 背包 %d 件 | 已解锁武学 %d 项" % [
		page_id,
		inventory_items.size(),
		codex_runtime_state.get("unlocked_effect_ids", []).size(),
	]


static func _build_candidate_entries(items: Array) -> Array:
	var entries: Array = []
	for item_variant in items:
		var item: Dictionary = item_variant
		entries.append({
			"id": String(item.get("id", "")),
			"title": ItemPresentationService.build_item_title(item),
			"subtitle": ItemPresentationService.build_item_subtitle(item),
			"rarity": String(item.get("rarity", "common")),
			"badges": ItemPresentationService.build_item_badges(item),
		})
	return entries


static func _build_codex_entries(effects: Array) -> Array:
	var entries: Array = []
	for effect_variant in effects:
		var effect: Dictionary = effect_variant
		entries.append({
			"id": String(effect.get("effect_id", "")),
			"title": String(effect.get("name", effect.get("effect_id", ""))),
			"subtitle": String(CODEX_SLOT_LABELS.get(String(effect.get("slot_id", "")), "武学")),
			"rarity": "epic",
			"badges": [],
		})
	return entries


static func _get_candidate_items(page_id: String, inventory_items: Array) -> Array:
	var items: Array = []
	for item_variant in inventory_items:
		var item: Dictionary = item_variant
		match page_id:
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


static func _build_recipe_cost_text(recipe: Dictionary) -> String:
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


static func _build_recipe_preview(page_id: String, item: Dictionary, selected_target_slot: String, selected_affix_index: int, affix_entries: Array) -> String:
	if item.is_empty():
		return "结果预览: 先从左侧选择一件可处理的装备"
	match page_id:
		"extract":
			var legendary_affix: Dictionary = item.get("legendary_affix", {})
			return "结果预览: 解锁武学 %s" % String(legendary_affix.get("name", "未知武学"))
		"upgrade_rare":
			return "结果预览: 保留原 3 条词缀，并补 1 条新词缀 + 1 条武学"
		"reforge":
			return "结果预览: 保留底材/等级/传承信息，全部词缀与武学重随"
		"convert_set":
			var slot_name: String = ItemPresentationService.get_slot_display_name(selected_target_slot)
			return "结果预览: 在同一传承内互转到 %s，并重随词缀与武学" % slot_name
		"refine_affix":
			var label: String = "当前词条"
			for entry_variant in affix_entries:
				var entry: Dictionary = entry_variant
				if int(entry.get("index", -1)) == selected_affix_index:
					label = String(entry.get("label", label))
			return "结果预览: 只重随 %s，其他词条与武学保持不变" % label
		_:
			return "结果预览: --"


static func _build_codex_detail_text(effect: Dictionary) -> String:
	if effect.is_empty():
		return "未选择武学秘录\n\n已解锁的武学会在这里显示，并可装入兵器 / 护甲 / 佩饰三个槽位。"
	return "%s\n槽位: %s\n主词条: %s %+0.2f\n副词条: %s %+0.2f\n\n%s" % [
		String(effect.get("name", effect.get("effect_id", ""))),
		String(CODEX_SLOT_LABELS.get(String(effect.get("slot_id", "")), "武学")),
		String(effect.get("stat_key", "--")),
		float(effect.get("value", 0.0)),
		String(effect.get("secondary_stat_key", "--")),
		float(effect.get("secondary_value", 0.0)),
		String(effect.get("description", "")),
	]


static func _build_codex_material_text(runtime_state: Dictionary) -> String:
	return "已解锁武学: %d 项\n当前激活: %d 项\n佩饰槽: %s" % [
		runtime_state.get("unlocked_effect_ids", []).size(),
		runtime_state.get("active_effects", []).size(),
		"暂未开放可用武学" if runtime_state.get("available_by_slot", {}).get("accessory", []).is_empty() else "可正常切换",
	]


static func _build_codex_result_text(runtime_state: Dictionary) -> String:
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


static func _find_item_by_id(items: Array, item_id: String) -> Dictionary:
	for item_variant in items:
		var item: Dictionary = item_variant
		if String(item.get("id", "")) == item_id:
			return item
	return {}


static func _get_convert_target_slots(item: Dictionary) -> Array:
	var slots: Array = []
	if item.is_empty():
		return slots
	var set_data: Dictionary = ConfigDB.get_set(String(item.get("set_id", "")))
	if set_data.is_empty():
		return slots
	var current_slot: String = String(item.get("slot", ""))
	for allowed_slot_variant in set_data.get("piece_slots", []):
		var allowed_slot: String = String(allowed_slot_variant)
		if allowed_slot == "accessory":
			for accessory_slot in ["accessory1", "accessory2"]:
				if accessory_slot != current_slot and not slots.has(accessory_slot):
					slots.append(accessory_slot)
			continue
		if allowed_slot != current_slot and not slots.has(allowed_slot):
			slots.append(allowed_slot)
	return slots


static func _get_affix_entries(item: Dictionary) -> Array:
	var entries: Array = []
	if item.is_empty():
		return entries
	var affixes: Array = item.get("affixes", [])
	if item.has("refine_slot_index"):
		var locked_index: int = int(item.get("refine_slot_index", -1))
		if locked_index >= 0 and locked_index < affixes.size():
			var locked_affix: Dictionary = affixes[locked_index]
			entries.append({
				"index": locked_index,
				"label": "#%d %s" % [locked_index + 1, String(locked_affix.get("name", locked_affix.get("stat_key", "词条")))],
				"is_locked": true,
			})
			return entries
	for index in range(affixes.size()):
		var affix: Dictionary = affixes[index]
		entries.append({
			"index": index,
			"label": "#%d %s" % [index + 1, String(affix.get("name", affix.get("stat_key", "词条")))],
			"is_locked": false,
		})
	return entries
