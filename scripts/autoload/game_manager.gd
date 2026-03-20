extends Node

const AVAILABLE_CORE_SKILLS := [
	"core_whirlwind",
	"core_deep_wound",
	"core_chain_lightning",
]

var current_chapter_id: String = "chapter_1"
var current_node_id: String = "ch1_n1"
var stable_node_id: String = "ch1_n1"
var selected_core_skill_id: String = "core_whirlwind"

var gold: int = 0
var scrap: int = 0
var core: int = 0
var legend_shard: int = 0
var current_run_kills: int = 0
var current_run_clears: int = 0
var inventory: Array = []
var equipped_items: Dictionary = {
	"weapon": {},
	"helmet": {},
	"armor": {},
	"gloves": {},
}
var research_levels: Dictionary = {}
var auto_salvage_below_rarity: String = "rare"
var last_loot_summary: String = "暂无掉落"
var last_loot_highlight: Dictionary = {}
const SALVAGE_THRESHOLDS := ["common", "uncommon", "rare", "epic", "legendary"]
const RESEARCH_META_KEYS := {
	"offline_efficiency_bonus": 0.0,
	"max_offline_seconds_bonus": 0.0,
	"gold_gain_percent": 0.0,
	"scrap_gain_percent": 0.0,
	"core_gain_percent": 0.0,
	"legend_shard_gain_percent": 0.0,
	"salvage_scrap_percent": 0.0,
}


func _ready() -> void:
	EventBus.config_loaded.connect(_on_config_loaded)
	if not ConfigDB.chapter_nodes.is_empty():
		_on_config_loaded()


func _on_config_loaded() -> void:
	if current_node_id.is_empty():
		current_node_id = ConfigDB.get_chapter_first_node(current_chapter_id)
	if stable_node_id.is_empty():
		stable_node_id = current_node_id
	EventBus.node_changed.emit(current_node_id)
	EventBus.core_skill_changed.emit(selected_core_skill_id)
	EventBus.resources_changed.emit()
	EventBus.equipment_changed.emit()
	EventBus.loot_summary_changed.emit(last_loot_summary)
	EventBus.inventory_changed.emit()
	EventBus.research_changed.emit()


func get_selected_core_skill() -> Dictionary:
	return ConfigDB.get_core_skill(selected_core_skill_id)


func get_selected_archetype_tags() -> Array:
	return get_selected_core_skill().get("archetype_tags", [])


func select_core_skill(skill_id: String) -> void:
	if not AVAILABLE_CORE_SKILLS.has(skill_id):
		return
	if ConfigDB.get_core_skill(skill_id).is_empty():
		return
	selected_core_skill_id = skill_id
	EventBus.core_skill_changed.emit(skill_id)


func grant_rewards(reward_entries: Array) -> Array:
	return MetaProgressionSystem.grant_rewards(reward_entries)


func get_rarity_rank(rarity: String) -> int:
	match rarity:
		"common":
			return 1
		"uncommon":
			return 2
		"rare":
			return 3
		"epic":
			return 4
		"legendary":
			return 5
		"ancient":
			return 6
		_:
			return 0


func get_total_combat_bonuses() -> Dictionary:
	var totals: Dictionary = {
		"attack_flat": 0.0,
		"hp_flat": 0.0,
		"defense_flat": 0.0,
		"attack_percent": 0.0,
		"attack_speed_percent": 0.0,
		"core_damage_percent": 0.0,
		"core_cooldown_reduction": 0.0,
		"whirlwind_radius_percent": 0.0,
		"bleed_dot_percent": 0.0,
		"execute_threshold": 0.0,
		"chain_count_bonus": 0.0,
		"chain_damage_percent": 0.0,
	}

	for item in equipped_items.values():
		if not item is Dictionary or item.is_empty():
			continue
		for stat_entry in item.get("base_stats", []):
			_add_stat_to_totals(totals, stat_entry)
		for affix_entry in item.get("affixes", []):
			_add_stat_to_totals(totals, affix_entry)
		if not item.get("legendary_affix", {}).is_empty():
			_add_stat_to_totals(totals, item.get("legendary_affix", {}))
			_add_secondary_stat_to_totals(totals, item.get("legendary_affix", {}))

	MetaProgressionSystem.apply_combat_bonuses_to_totals(totals)
	return totals


func get_meta_progression_bonuses() -> Dictionary:
	return MetaProgressionSystem.get_meta_progression_bonuses()


func get_adjusted_reward_count(item_id: String, base_count: int) -> int:
	return MetaProgressionSystem.get_adjusted_reward_count(item_id, base_count)


func get_adjusted_salvage_scrap(base_scrap: int) -> int:
	return MetaProgressionSystem.get_adjusted_salvage_scrap(base_scrap)


func get_research_level(node_id: String) -> int:
	return MetaProgressionSystem.get_research_level(node_id)


func can_upgrade_research(node_id: String) -> Dictionary:
	return MetaProgressionSystem.can_upgrade_research(node_id)


func upgrade_research(node_id: String) -> Dictionary:
	return MetaProgressionSystem.upgrade_research(node_id)


func get_research_items(tree_filter: String = "all") -> Array:
	return MetaProgressionSystem.get_research_items(tree_filter)


func get_research_overview_text(tree_filter: String = "all") -> String:
	return MetaProgressionSystem.get_research_overview_text(tree_filter)


func get_research_detail_text(node_id: String) -> String:
	return MetaProgressionSystem.get_research_detail_text(node_id)


func process_loot_item(item: Dictionary) -> Dictionary:
	LootCodexSystem.register_item(item)
	var result: Dictionary = {
		"action": "none",
		"item_name": _format_item_name(item),
	}
	var slot: String = String(item.get("slot", ""))
	var should_equip: bool = false

	if equipped_items.has(slot):
		var equipped_item: Dictionary = equipped_items[slot]
		if equipped_item.is_empty() or _get_item_score(item) > _get_item_score(equipped_item):
			should_equip = true

	if should_equip:
		var old_item: Dictionary = equipped_items.get(slot, {})
		equipped_items[slot] = item
		result["action"] = "equip"
		if not old_item.is_empty():
			_store_or_salvage_item(old_item, result)
		EventBus.equipment_changed.emit()
		EventBus.resources_changed.emit()
		EventBus.inventory_changed.emit()
		return result

	_store_or_salvage_item(item, result)
	EventBus.equipment_changed.emit()
	EventBus.resources_changed.emit()
	EventBus.inventory_changed.emit()
	return result


func get_equipment_summary() -> String:
	var lines: Array[String] = []
	for slot in ["weapon", "helmet", "armor", "gloves"]:
		var item: Dictionary = equipped_items.get(slot, {})
		if item.is_empty():
			lines.append("%s: --" % slot)
		else:
			lines.append("%s: %s" % [slot, _format_item_name(item)])
	return "\n".join(lines)


func get_equipped_item(slot: String) -> Dictionary:
	return equipped_items.get(slot, {})


func get_inventory_count() -> int:
	return inventory.size()


func get_inventory_items() -> Array:
	return inventory


func get_auto_salvage_label() -> String:
	return "自动分解低于: %s" % auto_salvage_below_rarity


func get_current_drop_focus() -> String:
	var node_data: Dictionary = ConfigDB.get_chapter_node(current_node_id)
	var profile_id: String = String(node_data.get("repeat_rewards_profile_id", ""))
	var profile: Dictionary = ConfigDB.get_drop_profile(profile_id)
	return String(profile.get("drop_focus", "常规掉落"))


func get_item_detail_text(item: Dictionary) -> String:
	if item.is_empty():
		return "未选择物品"

	var lines: Array[String] = []
	lines.append(_format_item_name(item))
	lines.append("部位: %s" % String(item.get("slot", "--")))
	lines.append("等级: %d" % int(item.get("item_level", 1)))
	lines.append("评分: %.1f" % float(item.get("score", 0.0)))
	lines.append("锁定: %s" % ("是" if bool(item.get("is_locked", false)) else "否"))
	lines.append("基础属性:")
	for stat_entry in item.get("base_stats", []):
		lines.append("- %s %+0.2f" % [String(stat_entry.get("stat_key", "")), float(stat_entry.get("value", 0.0))])
	lines.append("词条:")
	for affix_entry in item.get("affixes", []):
		var affix_name: String = String(affix_entry.get("name", String(affix_entry.get("stat_key", ""))))
		lines.append("- %s %+0.2f" % [affix_name, float(affix_entry.get("value", 0.0))])
	if not item.get("legendary_affix", {}).is_empty():
		var legendary_affix: Dictionary = item.get("legendary_affix", {})
		lines.append("传奇特效:")
		lines.append("- %s" % String(legendary_affix.get("name", "")))
		lines.append("- %s" % String(legendary_affix.get("description", "")))
		lines.append("- %s %+0.2f" % [String(legendary_affix.get("stat_key", "")), float(legendary_affix.get("value", 0.0))])
		if String(legendary_affix.get("secondary_stat_key", "")).length() > 0:
			lines.append("- %s %+0.2f" % [
				String(legendary_affix.get("secondary_stat_key", "")),
				float(legendary_affix.get("secondary_value", 0.0)),
			])
	return "\n".join(lines)


func get_loot_summary_lines(limit: int = 3) -> Array[String]:
	var lines: Array[String] = []
	for line_variant in String(last_loot_summary).split("\n", false):
		var line: String = String(line_variant).strip_edges()
		if line.is_empty():
			continue
		lines.append(line)
		if lines.size() >= limit:
			break
	return lines


func toggle_inventory_lock(item_id: String) -> void:
	for i in range(inventory.size()):
		var item: Dictionary = inventory[i]
		if String(item.get("id", "")) == item_id:
			item["is_locked"] = not bool(item.get("is_locked", false))
			inventory[i] = item
			EventBus.inventory_changed.emit()
			return


func equip_inventory_item(item_id: String) -> void:
	for i in range(inventory.size()):
		var item: Dictionary = inventory[i]
		if String(item.get("id", "")) != item_id:
			continue

		var slot: String = String(item.get("slot", ""))
		var old_item: Dictionary = equipped_items.get(slot, {})
		equipped_items[slot] = item
		inventory.remove_at(i)
		if not old_item.is_empty():
			inventory.append(old_item)
		EventBus.equipment_changed.emit()
		EventBus.inventory_changed.emit()
		EventBus.resources_changed.emit()
		return


func salvage_inventory_item(item_id: String) -> bool:
	for i in range(inventory.size()):
		var item: Dictionary = inventory[i]
		if String(item.get("id", "")) != item_id:
			continue
		if bool(item.get("is_locked", false)):
			return false
		var salvage_scrap_base: int = maxi(2, int(item.get("item_level", 1)) * get_rarity_rank(String(item.get("rarity", "common"))))
		var salvage_scrap: int = get_adjusted_salvage_scrap(salvage_scrap_base)
		MetaProgressionSystem.add_resource("scrap", salvage_scrap)
		inventory.remove_at(i)
		update_loot_summary(["手动分解: %s -> 铁屑 +%d" % [_format_item_name(item), salvage_scrap]])
		EventBus.inventory_changed.emit()
		return true
	return false


func cycle_auto_salvage_threshold() -> void:
	var current_index: int = SALVAGE_THRESHOLDS.find(auto_salvage_below_rarity)
	if current_index == -1:
		current_index = 0
	current_index = (current_index + 1) % SALVAGE_THRESHOLDS.size()
	auto_salvage_below_rarity = SALVAGE_THRESHOLDS[current_index]
	EventBus.inventory_changed.emit()


func update_loot_summary(lines: Array[String]) -> void:
	last_loot_summary = "\n".join(lines)
	EventBus.loot_summary_changed.emit(last_loot_summary)


func set_loot_highlight(highlight_data: Dictionary) -> void:
	last_loot_highlight = highlight_data.duplicate(true)


func get_loot_highlight() -> Dictionary:
	return last_loot_highlight


func gm_add_inventory_item(item: Dictionary) -> void:
	if item.is_empty():
		return
	var cloned_item: Dictionary = item.duplicate(true)
	cloned_item["is_locked"] = bool(cloned_item.get("is_locked", false))
	inventory.append(cloned_item)
	LootCodexSystem.register_item(cloned_item)
	EventBus.inventory_changed.emit()
	EventBus.codex_changed.emit()


func gm_jump_to_node(node_id: String) -> bool:
	var node_data: Dictionary = ConfigDB.get_chapter_node(node_id)
	if node_data.is_empty():
		return false
	current_chapter_id = String(node_data.get("chapter_id", current_chapter_id))
	current_node_id = node_id
	stable_node_id = node_id
	EventBus.node_changed.emit(current_node_id)
	return true


func gm_clear_inventory() -> void:
	inventory.clear()
	EventBus.inventory_changed.emit()


func _store_or_salvage_item(item: Dictionary, result: Dictionary) -> void:
	var rarity: String = String(item.get("rarity", "common"))
	if get_rarity_rank(rarity) < get_rarity_rank(auto_salvage_below_rarity):
		var salvage_scrap_base: int = maxi(2, int(item.get("item_level", 1)) * get_rarity_rank(rarity))
		var salvage_scrap: int = get_adjusted_salvage_scrap(salvage_scrap_base)
		MetaProgressionSystem.add_resource("scrap", salvage_scrap)
		result["action"] = "salvage"
		result["scrap"] = salvage_scrap
	else:
		item["is_locked"] = bool(item.get("is_locked", false))
		inventory.append(item)
		result["action"] = "store"


func _add_stat_to_totals(totals: Dictionary, entry: Dictionary) -> void:
	var stat_key: String = String(entry.get("stat_key", ""))
	var value: float = float(entry.get("value", 0.0))
	if totals.has(stat_key):
		totals[stat_key] += value


func _add_secondary_stat_to_totals(totals: Dictionary, entry: Dictionary) -> void:
	var stat_key: String = String(entry.get("secondary_stat_key", ""))
	var value: float = float(entry.get("secondary_value", 0.0))
	if totals.has(stat_key):
		totals[stat_key] += value


func _apply_research_bonuses_to_totals(totals: Dictionary) -> void:
	MetaProgressionSystem.apply_combat_bonuses_to_totals(totals)


func _get_research_upgrade_cost(research_node: Dictionary, target_level: int) -> Dictionary:
	var costs: Array = research_node.get("costs", [])
	for cost_entry_variant in costs:
		var cost_entry: Dictionary = cost_entry_variant
		if int(cost_entry.get("level", 0)) == target_level:
			return cost_entry
	if costs.is_empty():
		return {}
	return costs[-1]


func _get_resource_amount(resource_id: String) -> int:
	return MetaProgressionSystem.get_resource_amount(resource_id)


func _get_resource_bonus_key(_resource_id: String) -> String:
	return ""


func _consume_resource(resource_id: String, amount: int) -> void:
	MetaProgressionSystem.add_resource(resource_id, -amount)


func _sort_research_nodes(a: Dictionary, b: Dictionary) -> bool:
	return String(a.get("sort_id", "")) < String(b.get("sort_id", ""))


func _get_item_score(item: Dictionary) -> float:
	return float(item.get("score", 0.0))


func _format_item_name(item: Dictionary) -> String:
	return "[%s] %s" % [String(item.get("rarity", "common")), String(item.get("name", "未知装备"))]


func record_kill() -> void:
	current_run_kills += 1
	EventBus.resources_changed.emit()


func complete_node(node_id: String) -> void:
	current_run_clears += 1
	stable_node_id = node_id
	var node_data: Dictionary = ConfigDB.get_chapter_node(node_id)
	var next_node_id: String = String(node_data.get("next_node_id", ""))
	if next_node_id.is_empty():
		var current_chapter: Dictionary = ConfigDB.get_chapter(current_chapter_id)
		var next_chapter_id: String = String(current_chapter.get("next_chapter_id", ""))
		if not next_chapter_id.is_empty() and not ConfigDB.get_chapter(next_chapter_id).is_empty():
			current_chapter_id = next_chapter_id
			current_node_id = ConfigDB.get_chapter_first_node(current_chapter_id)
			stable_node_id = current_node_id
		else:
			current_node_id = ConfigDB.get_chapter_first_node(current_chapter_id)
	else:
		current_node_id = next_node_id
	EventBus.node_changed.emit(current_node_id)


func fallback_to_stable_node() -> void:
	current_node_id = stable_node_id
	EventBus.node_changed.emit(current_node_id)
