extends Node

var gold: int = 0
var scrap: int = 0
var core: int = 0
var legend_shard: int = 0
var research_levels: Dictionary = {}

const RESEARCH_META_KEYS := {
	"offline_efficiency_bonus": 0.0,
	"max_offline_seconds_bonus": 0.0,
	"gold_gain_percent": 0.0,
	"scrap_gain_percent": 0.0,
	"core_gain_percent": 0.0,
	"legend_shard_gain_percent": 0.0,
	"salvage_scrap_percent": 0.0,
}


func build_save_data() -> Dictionary:
	return {
		"gold": gold,
		"scrap": scrap,
		"core": core,
		"legend_shard": legend_shard,
		"research_levels": research_levels,
	}


func load_save_data(payload: Dictionary) -> void:
	gold = int(payload.get("gold", gold))
	scrap = int(payload.get("scrap", scrap))
	core = int(payload.get("core", core))
	legend_shard = int(payload.get("legend_shard", legend_shard))
	var loaded_research_levels: Variant = payload.get("research_levels", research_levels)
	if loaded_research_levels is Dictionary:
		research_levels = loaded_research_levels
	emit_state_changed()


func emit_state_changed() -> void:
	EventBus.resources_changed.emit()
	EventBus.research_changed.emit()


func grant_rewards(reward_entries: Array) -> Array:
	var applied_entries: Array[Dictionary] = []
	for entry in reward_entries:
		var item_id: String = String(entry.get("item_id", ""))
		var base_count: int = int(entry.get("count", 0))
		var count: int = get_adjusted_reward_count(item_id, base_count)
		if count <= 0:
			continue
		_apply_resource_delta(item_id, count)
		applied_entries.append({
			"item_id": item_id,
			"count": count,
			"base_count": base_count,
		})
	EventBus.resources_changed.emit()
	return applied_entries


func add_resource(resource_id: String, amount: int) -> void:
	if amount == 0:
		return
	_apply_resource_delta(resource_id, amount)
	EventBus.resources_changed.emit()


func gm_set_resource(resource_id: String, amount: int) -> void:
	match resource_id:
		"gold", "scrap", "core", "legend_shard":
			_apply_resource_delta(resource_id, -get_resource_amount(resource_id))
			_apply_resource_delta(resource_id, maxi(0, amount))
			EventBus.resources_changed.emit()
		_:
			pass


func gm_unlock_all_research() -> void:
	for research_node_variant in ConfigDB.get_all_research_nodes():
		var research_node: Dictionary = research_node_variant
		research_levels[String(research_node.get("id", ""))] = int(research_node.get("max_level", 1))
	EventBus.resources_changed.emit()
	EventBus.research_changed.emit()
	EventBus.equipment_changed.emit()


func gm_reset_all_resources() -> void:
	for resource_id in ["gold", "scrap", "core", "legend_shard"]:
		gm_set_resource(resource_id, 0)


func get_resource_amount(resource_id: String) -> int:
	match resource_id:
		"gold":
			return gold
		"scrap":
			return scrap
		"core":
			return core
		"legend_shard":
			return legend_shard
		_:
			return 0


func get_resource_display_name(resource_id: String) -> String:
	match resource_id:
		"gold":
			return "香火钱"
		"scrap":
			return "祠灰"
		"core":
			return "灵核"
		"legend_shard":
			return "真意残片"
		_:
			return resource_id


func get_meta_progression_bonuses() -> Dictionary:
	var totals: Dictionary = RESEARCH_META_KEYS.duplicate(true)
	for research_id in research_levels.keys():
		var level: int = int(research_levels.get(research_id, 0))
		if level <= 0:
			continue
		var research_node: Dictionary = ConfigDB.get_research_node(String(research_id))
		for bonus_entry in research_node.get("stat_bonuses", []):
			var stat_key: String = String(bonus_entry.get("stat_key", ""))
			var value_per_level: float = float(bonus_entry.get("value_per_level", 0.0))
			if totals.has(stat_key):
				totals[stat_key] += value_per_level * float(level)
	return totals


func get_adjusted_reward_count(item_id: String, base_count: int) -> int:
	var meta_bonuses: Dictionary = get_meta_progression_bonuses()
	var bonus_key: String = _get_resource_bonus_key(item_id)
	var multiplier: float = 1.0
	if meta_bonuses.has(bonus_key):
		multiplier += float(meta_bonuses.get(bonus_key, 0.0))
	return maxi(0, int(round(float(base_count) * multiplier)))


func get_adjusted_salvage_scrap(base_scrap: int) -> int:
	var meta_bonuses: Dictionary = get_meta_progression_bonuses()
	var multiplier: float = 1.0 + float(meta_bonuses.get("salvage_scrap_percent", 0.0))
	return maxi(0, int(round(float(base_scrap) * multiplier)))


func get_research_level(node_id: String) -> int:
	return int(research_levels.get(node_id, 0))


func can_upgrade_research(node_id: String) -> Dictionary:
	var research_node: Dictionary = ConfigDB.get_research_node(node_id)
	if research_node.is_empty():
		return {"ok": false, "reason": "悟道节点不存在"}

	var current_level: int = get_research_level(node_id)
	var max_level: int = int(research_node.get("max_level", 1))
	if current_level >= max_level:
		return {"ok": false, "reason": "已满级"}

	for prerequisite_id_variant in research_node.get("prerequisite_ids", []):
		var prerequisite_id: String = String(prerequisite_id_variant)
		if get_research_level(prerequisite_id) <= 0:
			var prerequisite_node: Dictionary = ConfigDB.get_research_node(prerequisite_id)
			return {
				"ok": false,
				"reason": "需要先解锁 %s" % String(prerequisite_node.get("name", prerequisite_id)),
			}

	var cost_entry: Dictionary = _get_research_upgrade_cost(research_node, current_level + 1)
	var resource_id: String = String(cost_entry.get("resource_id", ""))
	var cost_amount: int = int(cost_entry.get("amount", 0))
	if get_resource_amount(resource_id) < cost_amount:
		return {"ok": false, "reason": "%s 不足" % get_resource_display_name(resource_id)}

	return {"ok": true, "reason": "", "cost": cost_entry, "next_level": current_level + 1}


func upgrade_research(node_id: String) -> Dictionary:
	var check_result: Dictionary = can_upgrade_research(node_id)
	if not bool(check_result.get("ok", false)):
		return check_result

	var cost_entry: Dictionary = check_result.get("cost", {})
	_consume_resource(String(cost_entry.get("resource_id", "")), int(cost_entry.get("amount", 0)))
	research_levels[node_id] = int(check_result.get("next_level", 1))
	var research_node: Dictionary = ConfigDB.get_research_node(node_id)
	GameManager.update_loot_summary([
		"悟道有成: %s Lv.%d" % [String(research_node.get("name", node_id)), get_research_level(node_id)],
		"消耗: %s x%d" % [get_resource_display_name(String(cost_entry.get("resource_id", ""))), int(cost_entry.get("amount", 0))],
		"效果: %s" % String(research_node.get("description", "")),
	])
	EventBus.resources_changed.emit()
	EventBus.equipment_changed.emit()
	EventBus.research_changed.emit()
	EventBus.research_upgraded.emit(node_id, get_research_level(node_id))
	return {"ok": true, "reason": "", "new_level": get_research_level(node_id)}


func get_research_items(tree_filter: String = "all") -> Array:
	var nodes: Array = ConfigDB.get_all_research_nodes()
	if tree_filter != "all":
		var filtered_nodes: Array = []
		for node_variant in nodes:
			var node: Dictionary = node_variant
			if String(node.get("tree_type", "")) == tree_filter:
				filtered_nodes.append(node)
		nodes = filtered_nodes
	nodes.sort_custom(_sort_research_nodes)
	return nodes


func get_research_overview_text(tree_filter: String = "all") -> String:
	var branch_stats: Dictionary = {}
	for tree_type in ["combat", "idle", "economy"]:
		branch_stats[tree_type] = {"current": 0, "max": 0}

	for node_variant in ConfigDB.get_all_research_nodes():
		var node: Dictionary = node_variant
		var tree_type: String = String(node.get("tree_type", "combat"))
		if not branch_stats.has(tree_type):
			branch_stats[tree_type] = {"current": 0, "max": 0}
		branch_stats[tree_type]["current"] += get_research_level(String(node.get("id", "")))
		branch_stats[tree_type]["max"] += int(node.get("max_level", 1))

	var lines: Array[String] = []
	var filter_label: String = "全部"
	match tree_filter:
		"combat":
			filter_label = "战斗"
		"idle":
			filter_label = "挂机"
		"economy":
			filter_label = "经济"
	lines.append("当前筛选: %s | 战斗 %d/%d | 挂机 %d/%d | 经济 %d/%d" % [
		filter_label,
		int(branch_stats["combat"]["current"]),
		int(branch_stats["combat"]["max"]),
		int(branch_stats["idle"]["current"]),
		int(branch_stats["idle"]["max"]),
		int(branch_stats["economy"]["current"]),
		int(branch_stats["economy"]["max"]),
	])

	var meta_bonuses: Dictionary = get_meta_progression_bonuses()
	lines.append("机缘加成: 香火钱 %+d%% | 祠灰 %+d%% | 灵核 %+d%% | 真意残片 %+d%% | 分解 %+d%%" % [
		int(round(float(meta_bonuses.get("gold_gain_percent", 0.0)) * 100.0)),
		int(round(float(meta_bonuses.get("scrap_gain_percent", 0.0)) * 100.0)),
		int(round(float(meta_bonuses.get("core_gain_percent", 0.0)) * 100.0)),
		int(round(float(meta_bonuses.get("legend_shard_gain_percent", 0.0)) * 100.0)),
		int(round(float(meta_bonuses.get("salvage_scrap_percent", 0.0)) * 100.0)),
	])
	return "\n".join(lines)


func get_research_detail_text(node_id: String) -> String:
	var research_node: Dictionary = ConfigDB.get_research_node(node_id)
	if research_node.is_empty():
		return "未选择悟道节点"

	var current_level: int = get_research_level(node_id)
	var max_level: int = int(research_node.get("max_level", 1))
	var lines: Array[String] = []
	lines.append("%s" % String(research_node.get("name", node_id)))
	lines.append("类型: %s" % String(research_node.get("tree_type", "combat")))
	lines.append("等级: %d/%d" % [current_level, max_level])
	lines.append("说明: %s" % String(research_node.get("description", "")))
	lines.append("当前效果:")
	for bonus_entry in research_node.get("stat_bonuses", []):
		var stat_key: String = String(bonus_entry.get("stat_key", ""))
		var value_per_level: float = float(bonus_entry.get("value_per_level", 0.0))
		lines.append("- %s %+0.3f / 级, 当前 %+0.3f" % [stat_key, value_per_level, value_per_level * float(current_level)])
	var upgrade_state: Dictionary = can_upgrade_research(node_id)
	if bool(upgrade_state.get("ok", false)):
		var cost_entry: Dictionary = upgrade_state.get("cost", {})
		lines.append("下一级消耗: %s x%d" % [String(cost_entry.get("resource_id", "")), int(cost_entry.get("amount", 0))])
	else:
		lines.append("升级状态: %s" % String(upgrade_state.get("reason", "")))
	if research_node.get("prerequisite_ids", []).size() > 0:
		lines.append("前置需求:")
		for prerequisite_id_variant in research_node.get("prerequisite_ids", []):
			var prerequisite_id: String = String(prerequisite_id_variant)
			var prerequisite_node: Dictionary = ConfigDB.get_research_node(prerequisite_id)
			lines.append("- %s" % String(prerequisite_node.get("name", prerequisite_id)))
	return "\n".join(lines)


func apply_combat_bonuses_to_totals(totals: Dictionary) -> void:
	for research_id in research_levels.keys():
		var level: int = int(research_levels.get(research_id, 0))
		if level <= 0:
			continue
		var research_node: Dictionary = ConfigDB.get_research_node(String(research_id))
		for bonus_entry in research_node.get("stat_bonuses", []):
			var stat_key: String = String(bonus_entry.get("stat_key", ""))
			var value_per_level: float = float(bonus_entry.get("value_per_level", 0.0))
			if totals.has(stat_key):
				totals[stat_key] += value_per_level * float(level)


func _get_research_upgrade_cost(research_node: Dictionary, target_level: int) -> Dictionary:
	var costs: Array = research_node.get("costs", [])
	for cost_entry_variant in costs:
		var cost_entry: Dictionary = cost_entry_variant
		if int(cost_entry.get("level", 0)) == target_level:
			return cost_entry
	if costs.is_empty():
		return {}
	return costs[-1]


func _get_resource_bonus_key(resource_id: String) -> String:
	match resource_id:
		"gold":
			return "gold_gain_percent"
		"scrap":
			return "scrap_gain_percent"
		"core":
			return "core_gain_percent"
		"legend_shard":
			return "legend_shard_gain_percent"
		_:
			return ""


func _consume_resource(resource_id: String, amount: int) -> void:
	_apply_resource_delta(resource_id, -amount)


func _apply_resource_delta(resource_id: String, amount: int) -> void:
	match resource_id:
		"gold":
			gold = maxi(0, gold + amount)
		"scrap":
			scrap = maxi(0, scrap + amount)
		"core":
			core = maxi(0, core + amount)
		"legend_shard":
			legend_shard = maxi(0, legend_shard + amount)
		_:
			pass


func _sort_research_nodes(a: Dictionary, b: Dictionary) -> bool:
	return String(a.get("sort_id", "")) < String(b.get("sort_id", ""))
