class_name EquipmentViewModelService
extends RefCounted

const ItemPresentationService = preload("res://scripts/utils/item_presentation_service.gd")


static func build_screen_state(
	equipped_items: Dictionary,
	inventory_items: Array,
	set_summary: Dictionary,
	martial_codex_runtime: Dictionary,
	build_advice: Dictionary
) -> Dictionary:
	var slots: Array = []
	var equipped_count: int = 0
	for slot_id in GameManager.EQUIPMENT_SLOT_ORDER:
		var item: Dictionary = equipped_items.get(slot_id, {})
		if not item.is_empty():
			equipped_count += 1
		slots.append({
			"slot_id": slot_id,
			"display_name": ItemPresentationService.get_slot_display_name(slot_id),
			"item_id": String(item.get("id", "")),
			"title": ItemPresentationService.build_item_title(item) if not item.is_empty() else "未装备",
			"subtitle": ItemPresentationService.build_item_subtitle(item),
			"rarity": String(item.get("rarity", "common")),
			"is_empty": item.is_empty(),
			"badges": ItemPresentationService.build_item_badges(item),
		})

	return {
		"slots": slots,
		"equipped_count": equipped_count,
		"inventory_summary": ItemPresentationService.build_toolbar_summary(inventory_items, equipped_items),
		"set_summary_line": _build_set_summary_line(set_summary),
		"codex_summary_line": _build_codex_summary_line(martial_codex_runtime),
		"next_target_line": String(build_advice.get("next_target_line", "下一件: 继续补传承核心件")),
	}


static func _build_set_summary_line(set_summary: Dictionary) -> String:
	var primary_set: Dictionary = set_summary.get("primary_active_set", {})
	if primary_set.is_empty():
		return "传承: 当前未激活"
	return "传承: %s %d/6" % [
		String(primary_set.get("name", "传承")),
		int(primary_set.get("piece_count", 0)),
	]


static func _build_codex_summary_line(runtime_state: Dictionary) -> String:
	var active_effects: Array = runtime_state.get("active_effects", [])
	if active_effects.is_empty():
		return "武学秘录: 当前未装配"
	var segments: Array[String] = []
	for effect_variant in active_effects:
		var effect: Dictionary = effect_variant
		segments.append(String(effect.get("name", effect.get("effect_id", ""))))
	return "武学秘录: %s" % " / ".join(segments)
