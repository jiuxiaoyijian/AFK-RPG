class_name InventoryViewModelService
extends RefCounted

const ItemPresentationService = preload("res://scripts/utils/item_presentation_service.gd")

const GRID_COLUMNS := 10
const GRID_ROWS := 4
const PAGE_SIZE := GRID_COLUMNS * GRID_ROWS
const FILTER_ALL := "all"
const FILTER_HIGH_VALUE := "high_value"
const FILTER_LOCKED := "locked"
const FILTER_UPGRADES := "upgrades"
const SORT_SCORE_DESC := "score_desc"
const SORT_RARITY_DESC := "rarity_desc"
const SORT_SLOT := "slot"


static func build_screen_state(
	inventory_items: Array,
	equipped_items: Dictionary,
	page: int = 0,
	filter_id: String = FILTER_ALL,
	sort_id: String = SORT_SCORE_DESC,
	selected_item_id: String = "",
	selected_slot_id: String = ""
) -> Dictionary:
	var filtered_items: Array = _filter_items(inventory_items, equipped_items, filter_id)
	_sort_items(filtered_items, sort_id)

	var page_count: int = maxi(1, int(ceili(float(filtered_items.size()) / float(PAGE_SIZE))))
	var normalized_page: int = clampi(page, 0, page_count - 1)
	var start_index: int = normalized_page * PAGE_SIZE
	var end_index: int = mini(start_index + PAGE_SIZE, filtered_items.size())
	var page_items: Array = filtered_items.slice(start_index, end_index)

	var grid_entries: Array = []
	for index in range(PAGE_SIZE):
		if index < page_items.size():
			var item: Dictionary = page_items[index]
			grid_entries.append({
				"kind": "item",
				"item_id": String(item.get("id", "")),
				"title": ItemPresentationService.build_item_title(item),
				"subtitle": ItemPresentationService.build_item_subtitle(item),
				"grid_label": ItemPresentationService.build_grid_label(item),
				"rarity": String(item.get("rarity", "common")),
				"badges": ItemPresentationService.build_item_badges(item),
				"is_locked": bool(item.get("is_locked", false)),
				"is_high_value": ItemPresentationService.is_high_value_item(item),
				"slot_id": String(item.get("slot", "")),
			})
		else:
			grid_entries.append({
				"kind": "empty",
				"title": "",
				"subtitle": "",
				"grid_label": "",
			})

	var selected_item: Dictionary = _find_item_by_id(inventory_items, selected_item_id)
	var selected_equipped_item: Dictionary = {}
	if selected_item.is_empty() and not selected_slot_id.is_empty():
		selected_equipped_item = equipped_items.get(selected_slot_id, {})

	var detail_item: Dictionary = selected_item if not selected_item.is_empty() else selected_equipped_item
	var compare_item: Dictionary = {}
	var compare_summary: Dictionary = {}
	if not selected_item.is_empty():
		compare_item = equipped_items.get(_resolve_compare_slot(String(selected_item.get("slot", ""))), {})
		compare_summary = ItemPresentationService.build_compare_summary(selected_item, compare_item)
	elif not selected_equipped_item.is_empty():
		compare_summary = {
			"title": "已穿戴装备",
			"lines": [
				"当前位于 %s。" % ItemPresentationService.get_slot_display_name(String(selected_slot_id)),
				"评分 %.1f，可卸下后回到格子背包。" % float(selected_equipped_item.get("score", 0.0)),
			],
			"is_upgrade": false,
		}
	else:
		compare_summary = ItemPresentationService.build_compare_summary({}, {})

	return {
		"grid_columns": GRID_COLUMNS,
		"grid_rows": GRID_ROWS,
		"page_size": PAGE_SIZE,
		"page": normalized_page,
		"page_count": page_count,
		"filter_id": filter_id,
		"sort_id": sort_id,
		"used_count": inventory_items.size(),
		"visible_count": filtered_items.size(),
		"capacity": PAGE_SIZE,
		"overflow_count": maxi(0, inventory_items.size() - PAGE_SIZE),
		"summary_text": ItemPresentationService.build_toolbar_summary(inventory_items, equipped_items),
		"grid_entries": grid_entries,
		"selected_item": detail_item,
		"selected_inventory_item": selected_item,
		"selected_equipped_item": selected_equipped_item,
		"detail_badges": ItemPresentationService.build_item_badges(detail_item),
		"compare_item": compare_item,
		"compare_summary": compare_summary,
		"detail_text": GameManager.get_item_detail_text(detail_item),
		"action_state": {
			"can_equip": not selected_item.is_empty(),
			"can_unequip": selected_item.is_empty() and not selected_equipped_item.is_empty(),
			"can_lock": not selected_item.is_empty(),
			"can_salvage": not selected_item.is_empty() and not bool(selected_item.get("is_locked", false)),
		},
	}


static func get_filter_options() -> Array:
	return [
		{"id": FILTER_ALL, "label": "全部"},
		{"id": FILTER_HIGH_VALUE, "label": "高价值"},
		{"id": FILTER_UPGRADES, "label": "可替换"},
		{"id": FILTER_LOCKED, "label": "已锁定"},
	]


static func get_sort_options() -> Array:
	return [
		{"id": SORT_SCORE_DESC, "label": "按评分"},
		{"id": SORT_RARITY_DESC, "label": "按品质"},
		{"id": SORT_SLOT, "label": "按槽位"},
	]


static func _filter_items(inventory_items: Array, equipped_items: Dictionary, filter_id: String) -> Array:
	var result: Array = []
	for item_variant in inventory_items:
		var item: Dictionary = item_variant
		match filter_id:
			FILTER_HIGH_VALUE:
				if ItemPresentationService.is_high_value_item(item):
					result.append(item)
			FILTER_LOCKED:
				if bool(item.get("is_locked", false)):
					result.append(item)
			FILTER_UPGRADES:
				var slot_id: String = _resolve_compare_slot(String(item.get("slot", "")))
				if ItemPresentationService.is_equip_upgrade(item, equipped_items.get(slot_id, {})):
					result.append(item)
			_:
				result.append(item)
	return result


static func _sort_items(items: Array, sort_id: String) -> void:
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		match sort_id:
			SORT_RARITY_DESC:
				var rarity_delta: int = GameManager.get_rarity_rank(String(b.get("rarity", "common"))) - GameManager.get_rarity_rank(String(a.get("rarity", "common")))
				if rarity_delta == 0:
					return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
				return rarity_delta < 0
			SORT_SLOT:
				var slot_a: String = String(a.get("slot", ""))
				var slot_b: String = String(b.get("slot", ""))
				if slot_a == slot_b:
					return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
				return slot_a < slot_b
			_:
				return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)


static func _find_item_by_id(items: Array, item_id: String) -> Dictionary:
	for item_variant in items:
		var item: Dictionary = item_variant
		if String(item.get("id", "")) == item_id:
			return item
	return {}


static func _resolve_compare_slot(slot_id: String) -> String:
	if slot_id == "accessory":
		return "accessory1"
	return slot_id
