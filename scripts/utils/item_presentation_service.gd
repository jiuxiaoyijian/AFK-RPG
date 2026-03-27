class_name ItemPresentationService
extends RefCounted

const LootRuleService = preload("res://scripts/utils/loot_rule_service.gd")

const SLOT_DISPLAY_NAMES := {
	"weapon": "兵器",
	"helmet": "头冠",
	"armor": "护甲",
	"gloves": "护手",
	"legs": "腿甲",
	"boots": "轻靴",
	"accessory1": "佩饰·左",
	"accessory2": "佩饰·右",
	"accessory": "佩饰",
	"belt": "腰封",
}


static func get_slot_display_name(slot_id: String) -> String:
	return SLOT_DISPLAY_NAMES.get(slot_id, slot_id)


static func build_item_title(item: Dictionary) -> String:
	if item.is_empty():
		return "空槽位"
	return String(item.get("name", "未知装备"))


static func build_item_subtitle(item: Dictionary) -> String:
	if item.is_empty():
		return "未装备"
	var segments: Array[String] = [
		GameManager.get_rarity_display_name(String(item.get("rarity", "common"))),
		get_slot_display_name(String(item.get("slot", "--"))),
		"%.1f" % float(item.get("score", 0.0)),
	]
	if not String(item.get("set_name", "")).is_empty():
		segments.append(String(item.get("set_name", "")))
	return " · ".join(segments)


static func build_grid_label(item: Dictionary) -> String:
	if item.is_empty():
		return ""
	var lines: Array[String] = []
	lines.append(String(item.get("name", "未知装备")))
	lines.append("%s · %.0f" % [
		GameManager.get_rarity_display_name(String(item.get("rarity", "common"))),
		float(item.get("score", 0.0)),
	])
	return "\n".join(lines)


static func build_item_badges(item: Dictionary) -> Array[String]:
	var badges: Array[String] = []
	if item.is_empty():
		return badges
	if bool(item.get("is_locked", false)):
		badges.append("已锁定")
	if is_high_value_item(item):
		badges.append("高价值")
	if not String(item.get("set_name", "")).is_empty():
		badges.append("传承")
	if not item.get("legendary_affix", {}).is_empty():
		badges.append("武学")
	if item.has("refine_slot_index"):
		badges.append("已精炼")
	return badges


static func is_high_value_item(item: Dictionary) -> bool:
	if item.is_empty():
		return false
	return LootRuleService.is_manual_decision_item(item)


static func is_equip_upgrade(candidate_item: Dictionary, equipped_item: Dictionary) -> bool:
	if candidate_item.is_empty():
		return false
	if equipped_item.is_empty():
		return true
	return float(candidate_item.get("score", 0.0)) > float(equipped_item.get("score", 0.0))


static func build_compare_summary(candidate_item: Dictionary, equipped_item: Dictionary) -> Dictionary:
	if candidate_item.is_empty():
		return {
			"title": "当前未选择物品",
			"lines": ["先从格子背包或纸娃娃槽位中选择一件物品。"],
			"is_upgrade": false,
		}

	if equipped_item.is_empty():
		return {
			"title": "当前槽位未装备",
			"lines": [
				"穿上后可直接补全该槽位。",
				"评分 %.1f，可立即纳入 Build。" % float(candidate_item.get("score", 0.0)),
			],
			"is_upgrade": true,
		}

	var candidate_score: float = float(candidate_item.get("score", 0.0))
	var equipped_score: float = float(equipped_item.get("score", 0.0))
	var score_delta: float = candidate_score - equipped_score
	var is_upgrade: bool = score_delta >= 0.0
	var lines: Array[String] = []
	lines.append("当前穿戴：%s" % build_item_title(equipped_item))
	lines.append("评分对比：%.1f → %.1f (%+.1f)" % [equipped_score, candidate_score, score_delta])
	if not String(candidate_item.get("set_name", "")).is_empty():
		lines.append("传承归属：%s" % String(candidate_item.get("set_name", "")))
	if not candidate_item.get("legendary_affix", {}).is_empty():
		lines.append("武学：%s" % String(candidate_item.get("legendary_affix", {}).get("name", "未知武学")))
	lines.append("建议：%s" % ("可直接替换" if is_upgrade else "更适合保留观察或送往百炼坊"))
	return {
		"title": "装备对比",
		"lines": lines,
		"is_upgrade": is_upgrade,
	}


static func build_toolbar_summary(inventory_items: Array, equipped_items: Dictionary) -> String:
	var locked_count: int = 0
	var high_value_count: int = 0
	for item_variant in inventory_items:
		var item: Dictionary = item_variant
		if bool(item.get("is_locked", false)):
			locked_count += 1
		if is_high_value_item(item):
			high_value_count += 1

	var equipped_count: int = 0
	for slot_id in GameManager.EQUIPMENT_SLOT_ORDER:
		if not equipped_items.get(slot_id, {}).is_empty():
			equipped_count += 1

	return "库存 %d 件 | 锁定 %d 件 | 高价值 %d 件 | 已装备 %d/9" % [
		inventory_items.size(),
		locked_count,
		high_value_count,
		equipped_count,
	]
