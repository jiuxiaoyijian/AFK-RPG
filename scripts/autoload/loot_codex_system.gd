extends Node

const BuildQueryService = preload("res://scripts/utils/build_query_service.gd")
const LootRuleService = preload("res://scripts/utils/loot_rule_service.gd")

var discovered_base_ids: Array[String] = []
var discovered_affix_ids: Array[String] = []
var discovered_legendary_affix_ids: Array[String] = []
var tracked_legendary_affix_id: String = ""
var node_drop_stats: Dictionary = {}
var recent_drop_records: Array = []
const MAX_RECENT_DROP_RECORDS := 24


func _ready() -> void:
	EventBus.config_loaded.connect(_ensure_valid_target)
	EventBus.core_skill_changed.connect(_on_core_skill_changed)
	if not ConfigDB.legendary_affixes.is_empty():
		_ensure_valid_target()


func build_save_data() -> Dictionary:
	return {
		"discovered_base_ids": discovered_base_ids,
		"discovered_affix_ids": discovered_affix_ids,
		"discovered_legendary_affix_ids": discovered_legendary_affix_ids,
		"tracked_legendary_affix_id": tracked_legendary_affix_id,
		"node_drop_stats": node_drop_stats,
		"recent_drop_records": recent_drop_records,
	}


func load_save_data(payload: Dictionary) -> void:
	discovered_base_ids = _variant_to_string_array(payload.get("discovered_base_ids", discovered_base_ids))
	discovered_affix_ids = _variant_to_string_array(payload.get("discovered_affix_ids", discovered_affix_ids))
	discovered_legendary_affix_ids = _variant_to_string_array(payload.get("discovered_legendary_affix_ids", discovered_legendary_affix_ids))
	tracked_legendary_affix_id = String(payload.get("tracked_legendary_affix_id", tracked_legendary_affix_id))
	node_drop_stats = _normalize_node_drop_stats(payload.get("node_drop_stats", {}))
	recent_drop_records = _normalize_recent_drop_records(payload.get("recent_drop_records", []))
	_ensure_valid_target()
	EventBus.codex_changed.emit()
	EventBus.loot_target_changed.emit()


func reset_runtime_state() -> void:
	discovered_base_ids.clear()
	discovered_affix_ids.clear()
	discovered_legendary_affix_ids.clear()
	tracked_legendary_affix_id = ""
	node_drop_stats.clear()
	recent_drop_records.clear()
	_ensure_valid_target()
	EventBus.codex_changed.emit()
	EventBus.loot_target_changed.emit()


func register_item(item: Dictionary) -> void:
	var changed: bool = false
	var new_legendary_affix_id: String = ""
	var new_legendary_name: String = ""
	changed = _register_unique(discovered_base_ids, String(item.get("base_id", ""))) or changed
	for affix_entry_variant in item.get("affixes", []):
		var affix_entry: Dictionary = affix_entry_variant
		changed = _register_unique(discovered_affix_ids, String(affix_entry.get("affix_id", ""))) or changed
	if not item.get("legendary_affix", {}).is_empty():
		var legendary_affix: Dictionary = item.get("legendary_affix", {})
		var legendary_affix_id: String = String(legendary_affix.get("legendary_affix_id", ""))
		var legendary_added: bool = _register_unique(discovered_legendary_affix_ids, legendary_affix_id)
		changed = legendary_added or changed
		if legendary_added:
			new_legendary_affix_id = legendary_affix_id
			new_legendary_name = String(legendary_affix.get("name", legendary_affix_id))
	if changed:
		EventBus.codex_changed.emit()
	if not new_legendary_affix_id.is_empty():
		EventBus.legendary_discovered.emit(
			new_legendary_affix_id,
			new_legendary_name,
			new_legendary_affix_id == tracked_legendary_affix_id
		)
	_ensure_valid_target()


func record_node_loot(node_id: String, items: Array) -> void:
	if node_id.is_empty():
		return
	var stats: Dictionary = _get_or_create_node_drop_stats(node_id)
	stats["clears"] = int(stats.get("clears", 0)) + 1
	stats["equipment_drops"] = int(stats.get("equipment_drops", 0)) + items.size()
	for item_variant in items:
		var item: Dictionary = item_variant
		_increment_stat_map(stats, "base_hits", String(item.get("base_id", "")), 1)
		for affix_entry_variant in item.get("affixes", []):
			var affix_entry: Dictionary = affix_entry_variant
			_increment_stat_map(stats, "affix_hits", String(affix_entry.get("affix_id", "")), 1)
		if not item.get("legendary_affix", {}).is_empty():
			var legendary_affix: Dictionary = item.get("legendary_affix", {})
			_increment_stat_map(stats, "legendary_hits", String(legendary_affix.get("legendary_affix_id", "")), 1)
			stats["legendary_drops"] = int(stats.get("legendary_drops", 0)) + 1
	node_drop_stats[node_id] = stats
	_append_recent_drop_record(node_id, items, stats)
	EventBus.codex_changed.emit()


func get_codex_summary_text() -> String:
	return "异闻录: 底材 %d/%d | 真意 %d/%d | 异宝 %d/%d | 样本 %d 次" % [
		discovered_base_ids.size(),
		ConfigDB.get_all_equipment_bases().size(),
		discovered_affix_ids.size(),
		ConfigDB.get_all_affixes().size(),
		discovered_legendary_affix_ids.size(),
		ConfigDB.get_all_legendary_affixes().size(),
		_get_total_recorded_clears(),
	]


func get_drop_stats_overview_text() -> String:
	var total_clears: int = 0
	var total_equipment_drops: int = 0
	var total_legendary_drops: int = 0
	for node_id_variant in node_drop_stats.keys():
		var node_id: String = String(node_id_variant)
		var stats: Dictionary = node_drop_stats.get(node_id, {})
		total_clears += int(stats.get("clears", 0))
		total_equipment_drops += int(stats.get("equipment_drops", 0))
		total_legendary_drops += int(stats.get("legendary_drops", 0))
	return "总样本 %d 次 | 装备 %d 件 | 异宝真意 %d 次 | 最近记录 %d 条" % [
		total_clears,
		total_equipment_drops,
		total_legendary_drops,
		recent_drop_records.size(),
	]


func get_drop_stats_overview_lines() -> Array[String]:
	var total_clears: int = 0
	var total_equipment_drops: int = 0
	var total_legendary_drops: int = 0
	for node_id_variant in node_drop_stats.keys():
		var node_id: String = String(node_id_variant)
		var stats: Dictionary = node_drop_stats.get(node_id, {})
		total_clears += int(stats.get("clears", 0))
		total_equipment_drops += int(stats.get("equipment_drops", 0))
		total_legendary_drops += int(stats.get("legendary_drops", 0))
	return [
		"总样本 %d 次" % total_clears,
		"装备样本 %d 件" % total_equipment_drops,
		"异宝真意 %d 次" % total_legendary_drops,
		"已记录节点 %d 个" % node_drop_stats.size(),
	]


func get_drop_stat_entries() -> Array:
	var entries: Array = []
	for node_id_variant in node_drop_stats.keys():
		var node_id: String = String(node_id_variant)
		var stats: Dictionary = node_drop_stats.get(node_id, {})
		var node_data: Dictionary = ConfigDB.get_chapter_node(node_id)
		var chapter_data: Dictionary = ConfigDB.get_chapter(String(node_data.get("chapter_id", "")))
		entries.append({
			"node_id": node_id,
			"node_name": ConfigDB.get_chapter_node_name(node_id),
			"chapter_name": String(chapter_data.get("name", "")),
			"node_type": String(node_data.get("node_type", "normal")),
			"clears": int(stats.get("clears", 0)),
			"equipment_drops": int(stats.get("equipment_drops", 0)),
			"legendary_drops": int(stats.get("legendary_drops", 0)),
			"is_current": node_id == GameManager.current_node_id,
		})
	entries.sort_custom(_sort_drop_stat_entries)
	return entries


func get_drop_stat_visual_data(node_id: String) -> Dictionary:
	if node_id.is_empty():
		return {}
	var node_data: Dictionary = ConfigDB.get_chapter_node(node_id)
	if node_data.is_empty():
		return {}
	var stats: Dictionary = node_drop_stats.get(node_id, {})
	var clears: int = int(stats.get("clears", 0))
	var drop_profile: Dictionary = ConfigDB.get_drop_profile(String(node_data.get("repeat_rewards_profile_id", "")))
	var expected_equipment_rate: float = float(drop_profile.get("equipment_rolls", 1)) * float(drop_profile.get("equipment_chance", 0.0))
	var actual_equipment_rate: float = float(stats.get("equipment_drops", 0)) / maxf(float(clears), 1.0)
	var expected_legendary_rate: float = expected_equipment_rate * LootRuleService.get_legendary_rarity_gate_probability(drop_profile)
	var actual_legendary_rate: float = float(stats.get("legendary_drops", 0)) / maxf(float(clears), 1.0)
	return {
		"equipment": _build_visual_rate_entry("装备效率", expected_equipment_rate, actual_equipment_rate, clears),
		"legendary": _build_visual_rate_entry("异宝效率", expected_legendary_rate, actual_legendary_rate, clears),
		"tracked_target": get_tracked_target_visual_data(node_id),
	}


func get_tracked_target_visual_data(node_id: String) -> Dictionary:
	if tracked_legendary_affix_id.is_empty():
		return {
			"label": "机缘追踪",
			"status": "未设置机缘追踪",
			"bar_value": 0.0,
			"expected_rate": 0.0,
			"actual_rate": 0.0,
			"delta_ratio": 0.0,
			"state_label": "未设置",
		}
	var node_data: Dictionary = ConfigDB.get_chapter_node(node_id)
	if node_data.is_empty():
		return {}
	var drop_profile: Dictionary = ConfigDB.get_drop_profile(String(node_data.get("repeat_rewards_profile_id", "")))
	var affix: Dictionary = _get_legendary_affix_by_id(tracked_legendary_affix_id)
	var target_name: String = String(affix.get("name", tracked_legendary_affix_id))
	if affix.is_empty():
		return {
			"label": target_name,
			"status": "机缘不存在",
			"bar_value": 0.0,
			"expected_rate": 0.0,
			"actual_rate": 0.0,
			"delta_ratio": 0.0,
			"state_label": "无效目标",
		}
	if not _profile_matches_entry("legendary", affix, drop_profile):
		return {
			"label": target_name,
			"status": "当前节点不产出该机缘",
			"bar_value": 0.0,
			"expected_rate": 0.0,
			"actual_rate": 0.0,
			"delta_ratio": 0.0,
			"state_label": "不产出",
		}
	var metrics: Dictionary = LootRuleService.get_expectation_metrics(
		"legendary",
		affix,
		drop_profile,
		node_data,
		GameManager.get_selected_archetype_tags()
	)
	if metrics.is_empty():
		return {
			"label": target_name,
			"status": "暂无法估算",
			"bar_value": 0.0,
			"expected_rate": 0.0,
			"actual_rate": 0.0,
			"delta_ratio": 0.0,
			"state_label": "无法估算",
		}
	var observed_stats: Dictionary = get_observed_entry_stats(tracked_legendary_affix_id, "legendary", node_id)
	var clears: int = int(observed_stats.get("clears", 0))
	var hits: int = int(observed_stats.get("hits", 0))
	var expected_rate: float = float(metrics.get("expected_per_clear", 0.0))
	var actual_rate: float = float(hits) / maxf(float(clears), 1.0)
	var visual_data: Dictionary = _build_visual_rate_entry(target_name, expected_rate, actual_rate, clears)
	if clears <= 0:
		visual_data["status"] = "暂无实测样本"
	elif hits <= 0:
		visual_data["status"] = "当前样本 %d 次仍未见到目标" % clears
	else:
		visual_data["status"] = "实测约 %.1f 次/见 1 次" % float(observed_stats.get("clears_per_hit", 0.0))
	return visual_data


func get_drop_stat_detail_text(node_id: String) -> String:
	if node_id.is_empty():
		return "未选择节点"
	var node_data: Dictionary = ConfigDB.get_chapter_node(node_id)
	if node_data.is_empty():
		return "节点不存在"
	var chapter_data: Dictionary = ConfigDB.get_chapter(String(node_data.get("chapter_id", "")))
	var stats: Dictionary = node_drop_stats.get(node_id, {})
	var clears: int = int(stats.get("clears", 0))
	var equipment_drops: int = int(stats.get("equipment_drops", 0))
	var legendary_drops: int = int(stats.get("legendary_drops", 0))
	var drop_profile: Dictionary = ConfigDB.get_drop_profile(String(node_data.get("repeat_rewards_profile_id", "")))
	var lines: Array[String] = []
	lines.append("%s - %s" % [String(chapter_data.get("name", "")), ConfigDB.get_chapter_node_name(node_id)])
	lines.append("类型: %s" % ConfigDB.get_node_type_display_name(String(node_data.get("node_type", "normal"))))
	lines.append("掉落方向: %s" % String(drop_profile.get("drop_focus", "常规掉落")))
	lines.append("样本次数: %d" % clears)
	lines.append("装备掉落: %d (%.2f / 次)" % [equipment_drops, float(equipment_drops) / maxf(float(clears), 1.0)])
	lines.append("异宝真意: %d (%.2f / 次)" % [legendary_drops, float(legendary_drops) / maxf(float(clears), 1.0)])
	lines.append(_get_node_rate_comparison_text(node_id))
	lines.append("节点时限: %d 秒" % int(node_data.get("time_limit", 60)))
	var tracked_recommendation: Dictionary = get_recommended_farm_node_for_legendary(tracked_legendary_affix_id)
	if String(tracked_recommendation.get("node_id", "")) == node_id:
		lines.append("机缘追踪推荐: 是")
	var tracked_target_comparison: String = _get_tracked_target_comparison_text(node_id, node_data, drop_profile)
	if not tracked_target_comparison.is_empty():
		lines.append(tracked_target_comparison)
	var recent_records: Array = get_recent_drop_records(5, node_id)
	if recent_records.is_empty():
		lines.append("最近记录: 暂无")
	else:
		lines.append("最近记录:")
		for record_variant in recent_records:
			var record: Dictionary = record_variant
			lines.append("- 第 %d 次: %s" % [
				int(record.get("clear_index", 0)),
				String(record.get("summary", "无掉落")),
			])
	return "\n".join(lines)


func get_recent_drop_records(limit: int = 8, node_id: String = "") -> Array:
	var entries: Array = []
	for record_variant in recent_drop_records:
		var record: Dictionary = record_variant
		if not node_id.is_empty() and String(record.get("node_id", "")) != node_id:
			continue
		entries.append(record)
		if entries.size() >= limit:
			break
	return entries


func _get_node_rate_comparison_text(node_id: String) -> String:
	var node_data: Dictionary = ConfigDB.get_chapter_node(node_id)
	if node_data.is_empty():
		return ""
	var stats: Dictionary = node_drop_stats.get(node_id, {})
	var clears: int = int(stats.get("clears", 0))
	if clears <= 0:
		return "偏差对比: 暂无样本"
	var drop_profile: Dictionary = ConfigDB.get_drop_profile(String(node_data.get("repeat_rewards_profile_id", "")))
	var expected_equipment_rate: float = float(drop_profile.get("equipment_rolls", 1)) * float(drop_profile.get("equipment_chance", 0.0))
	var actual_equipment_rate: float = float(stats.get("equipment_drops", 0)) / float(clears)
	var expected_legendary_rate: float = expected_equipment_rate * LootRuleService.get_legendary_rarity_gate_probability(drop_profile)
	var actual_legendary_rate: float = float(stats.get("legendary_drops", 0)) / float(clears)
	return "偏差对比: %s | %s" % [
		_build_rate_comparison_text("装备", expected_equipment_rate, actual_equipment_rate),
		_build_rate_comparison_text("异宝", expected_legendary_rate, actual_legendary_rate),
	]


func _get_tracked_target_comparison_text(node_id: String, node_data: Dictionary, drop_profile: Dictionary) -> String:
	if tracked_legendary_affix_id.is_empty():
		return ""
	var affix: Dictionary = _get_legendary_affix_by_id(tracked_legendary_affix_id)
	if affix.is_empty():
		return ""
	if not _profile_matches_entry("legendary", affix, drop_profile):
		return "机缘追踪对比: 当前节点不产出该机缘"
	var metrics: Dictionary = LootRuleService.get_expectation_metrics(
		"legendary",
		affix,
		drop_profile,
		node_data,
		GameManager.get_selected_archetype_tags()
	)
	if metrics.is_empty():
		return "机缘追踪对比: 暂无法估算"
	var observed_stats: Dictionary = get_observed_entry_stats(tracked_legendary_affix_id, "legendary", node_id)
	var clears: int = int(observed_stats.get("clears", 0))
	var hits: int = int(observed_stats.get("hits", 0))
	var expected_rate: float = float(metrics.get("expected_per_clear", 0.0))
	var actual_rate: float = 0.0
	if clears > 0:
		actual_rate = float(hits) / float(clears)
	var comparison_text: String = _build_rate_comparison_text(String(affix.get("name", tracked_legendary_affix_id)), expected_rate, actual_rate)
	if hits <= 0 and clears > 0 and expected_rate > 0.0:
		return "机缘追踪对比: %s | 当前样本 %d 次仍未见到机缘" % [comparison_text, clears]
	if hits <= 0:
		return "机缘追踪对比: %s | 暂无实测样本" % comparison_text
	return "机缘追踪对比: %s | 实测约 %.1f 次/见 1 次" % [
		comparison_text,
		float(observed_stats.get("clears_per_hit", 0.0)),
	]


func get_codex_entries(category: String = "legendary") -> Array:
	var entries: Array = []
	match category:
		"base":
			for entry_variant in ConfigDB.get_all_equipment_bases():
				var entry: Dictionary = entry_variant
				entries.append({
					"category": "base",
					"id": String(entry.get("id", "")),
					"name": String(entry.get("name", "")),
					"discovered": discovered_base_ids.has(String(entry.get("id", ""))),
					"data": entry,
				})
		"affix":
			for entry_variant in ConfigDB.get_all_affixes():
				var entry: Dictionary = entry_variant
				entries.append({
					"category": "affix",
					"id": String(entry.get("id", "")),
					"name": String(entry.get("name", "")),
					"discovered": discovered_affix_ids.has(String(entry.get("id", ""))),
					"data": entry,
				})
		_:
			for entry_variant in ConfigDB.get_all_legendary_affixes():
				var entry: Dictionary = entry_variant
				var legendary_id: String = String(entry.get("id", ""))
				entries.append({
					"category": "legendary",
					"id": legendary_id,
					"name": String(entry.get("name", "")),
					"discovered": discovered_legendary_affix_ids.has(legendary_id),
					"data": entry,
				})
	entries.sort_custom(_sort_codex_entries)
	return entries


func get_codex_detail_text(entry_id: String, category: String = "legendary") -> String:
	match category:
		"base":
			return _get_base_detail_text(entry_id)
		"affix":
			return _get_affix_detail_text(entry_id)
		_:
			return _get_legendary_detail_text(entry_id)


func is_legendary_discovered(legendary_affix_id: String) -> bool:
	return discovered_legendary_affix_ids.has(legendary_affix_id)


func set_tracked_legendary_affix(legendary_affix_id: String) -> void:
	if _get_legendary_affix_by_id(legendary_affix_id).is_empty():
		return
	tracked_legendary_affix_id = legendary_affix_id
	EventBus.loot_target_changed.emit()


func gm_unlock_all_codex() -> void:
	discovered_base_ids.clear()
	discovered_affix_ids.clear()
	discovered_legendary_affix_ids.clear()
	for entry_variant in ConfigDB.get_all_equipment_bases():
		var entry: Dictionary = entry_variant
		discovered_base_ids.append(String(entry.get("id", "")))
	for entry_variant in ConfigDB.get_all_affixes():
		var entry: Dictionary = entry_variant
		discovered_affix_ids.append(String(entry.get("id", "")))
	for entry_variant in ConfigDB.get_all_legendary_affixes():
		var entry: Dictionary = entry_variant
		discovered_legendary_affix_ids.append(String(entry.get("id", "")))
	_ensure_valid_target()
	EventBus.codex_changed.emit()
	EventBus.loot_target_changed.emit()


func gm_clear_drop_stats() -> void:
	node_drop_stats.clear()
	recent_drop_records.clear()
	EventBus.codex_changed.emit()


func cycle_target_for_current_build() -> void:
	var candidates: Array = _get_build_relevant_legendary_ids()
	if candidates.is_empty():
		return
	var current_index: int = candidates.find(tracked_legendary_affix_id)
	if current_index == -1:
		current_index = 0
	else:
		current_index = (current_index + 1) % candidates.size()
	tracked_legendary_affix_id = String(candidates[current_index])
	EventBus.loot_target_changed.emit()


func get_tracked_target_summary_text() -> String:
	var affix: Dictionary = _get_legendary_affix_by_id(tracked_legendary_affix_id)
	if affix.is_empty():
		return "当前目标: --"
	var recommendation: Dictionary = get_recommended_farm_node_for_legendary(tracked_legendary_affix_id)
	var label: String = String(affix.get("name", tracked_legendary_affix_id))
	if is_legendary_discovered(tracked_legendary_affix_id):
		label += " [已发现]"
	var recommendation_text: String = String(recommendation.get("short_label", "暂无推荐"))
	var expectation_text: String = ""
	if not recommendation.is_empty():
		expectation_text = " | 约 %.1f 次/见 1 次" % float(recommendation.get("expected_clears_per_hit", 0.0))
	return "当前目标: %s | 推荐刷图: %s%s" % [label, recommendation_text, expectation_text]


func get_recommended_farm_node_for_legendary(legendary_affix_id: String) -> Dictionary:
	var affix: Dictionary = _get_legendary_affix_by_id(legendary_affix_id)
	if affix.is_empty():
		return {}
	return _get_best_recommendation_entry("legendary", affix)


func get_recommended_farm_node_for_base(base_id: String) -> Dictionary:
	var base_entry: Dictionary = _get_base_by_id(base_id)
	if base_entry.is_empty():
		return {}
	return _get_best_recommendation_entry("base", base_entry)


func get_recommended_farm_node_for_affix(affix_id: String) -> Dictionary:
	var affix: Dictionary = _get_affix_by_id(affix_id)
	if affix.is_empty():
		return {}
	return _get_best_recommendation_entry("affix", affix)


func is_entry_discovered(entry_id: String, category: String) -> bool:
	match category:
		"base":
			return discovered_base_ids.has(entry_id)
		"affix":
			return discovered_affix_ids.has(entry_id)
		_:
			return discovered_legendary_affix_ids.has(entry_id)


func _ensure_valid_target() -> void:
	if _get_legendary_affix_by_id(tracked_legendary_affix_id).is_empty():
		var candidates: Array = _get_build_relevant_legendary_ids()
		if not candidates.is_empty():
			for candidate_id_variant in candidates:
				var candidate_id: String = String(candidate_id_variant)
				if not is_legendary_discovered(candidate_id):
					tracked_legendary_affix_id = candidate_id
					EventBus.loot_target_changed.emit()
					return
			tracked_legendary_affix_id = String(candidates[0])
			EventBus.loot_target_changed.emit()


func _on_core_skill_changed(_skill_id: String) -> void:
	_ensure_valid_target()
	EventBus.loot_target_changed.emit()


func _get_build_relevant_legendary_ids() -> Array:
	return BuildQueryService.get_build_relevant_legendary_ids(GameManager.get_selected_archetype_tags())


func _get_legendary_affix_by_id(legendary_affix_id: String) -> Dictionary:
	for entry in ConfigDB.get_all_legendary_affixes():
		var affix: Dictionary = entry
		if String(affix.get("id", "")) == legendary_affix_id:
			return affix
	return {}


func _get_base_by_id(base_id: String) -> Dictionary:
	for entry in ConfigDB.get_all_equipment_bases():
		var base_entry: Dictionary = entry
		if String(base_entry.get("id", "")) == base_id:
			return base_entry
	return {}


func _get_affix_by_id(affix_id: String) -> Dictionary:
	for entry in ConfigDB.get_all_affixes():
		var affix: Dictionary = entry
		if String(affix.get("id", "")) == affix_id:
			return affix
	return {}


func _get_legendary_detail_text(legendary_affix_id: String) -> String:
	var affix: Dictionary = _get_legendary_affix_by_id(legendary_affix_id)
	if affix.is_empty():
		return "未选择异宝机缘"
	var recommendation: Dictionary = get_recommended_farm_node_for_legendary(legendary_affix_id)
	var lines: Array[String] = []
	lines.append(String(affix.get("name", legendary_affix_id)))
	lines.append("分类: 异宝")
	lines.append("状态: %s" % ("已发现" if is_legendary_discovered(legendary_affix_id) else "未发现"))
	lines.append("追踪: %s" % ("当前机缘" if tracked_legendary_affix_id == legendary_affix_id else "否"))
	lines.append("适配道统: %s" % _format_array(affix.get("archetype_tags", []), "通用"))
	lines.append("描述: %s" % String(affix.get("description", "")))
	lines.append("掉落来源: %s" % _format_array(affix.get("source_profile_types", []), "任意高阶来源"))
	if not recommendation.is_empty():
		lines.append("推荐刷图: %s" % String(recommendation.get("label", "")))
		lines.append("推荐原因: %s" % String(recommendation.get("reason", "")))
		lines.append("期望收益: %s" % String(recommendation.get("expectation_text", "")))
	_append_observed_stats_lines(lines, legendary_affix_id, "legendary", recommendation)
	return "\n".join(lines)


func _get_base_detail_text(base_id: String) -> String:
	var base_entry: Dictionary = _get_base_by_id(base_id)
	if base_entry.is_empty():
		return "未选择底材"
	var recommendation: Dictionary = get_recommended_farm_node_for_base(base_id)
	var lines: Array[String] = []
	lines.append(String(base_entry.get("name", base_id)))
	lines.append("分类: 底材")
	lines.append("状态: %s" % ("已发现" if discovered_base_ids.has(base_id) else "未发现"))
	lines.append("部位: %s" % String(base_entry.get("slot", "")))
	lines.append("基础等级: %d" % int(base_entry.get("item_level", 1)))
	lines.append("底材方向: %s" % _format_array(base_entry.get("affix_pool_tags", []), "通用"))
	if recommendation.is_empty():
		lines.append("推荐刷图: 暂无匹配节点")
	else:
		lines.append("推荐刷图: %s" % String(recommendation.get("label", "")))
		lines.append("推荐原因: %s" % String(recommendation.get("reason", "")))
		lines.append("期望收益: %s" % String(recommendation.get("expectation_text", "")))
	_append_observed_stats_lines(lines, base_id, "base", recommendation)
	return "\n".join(lines)


func _get_affix_detail_text(affix_id: String) -> String:
	var affix: Dictionary = _get_affix_by_id(affix_id)
	if affix.is_empty():
		return "未选择真意"
	var recommendation: Dictionary = get_recommended_farm_node_for_affix(affix_id)
	var lines: Array[String] = []
	lines.append(String(affix.get("name", affix_id)))
	lines.append("分类: 真意")
	lines.append("状态: %s" % ("已发现" if discovered_affix_ids.has(affix_id) else "未发现"))
	lines.append("乘区分类: %s" % String(affix.get("bucket", affix.get("affix_type", ""))))
	lines.append("适配道统: %s" % _format_array(affix.get("archetype_tags", []), "通用"))
	lines.append("作用属性: %s" % String(affix.get("stat_key", "")))
	lines.append("数值范围: %.2f - %.2f" % [float(affix.get("value_min", 0.0)), float(affix.get("value_max", 0.0))])
	lines.append("掉落来源: %s" % _format_array(affix.get("source_profile_types", []), "常规来源"))
	if recommendation.is_empty():
		lines.append("推荐刷图: 暂无匹配节点")
	else:
		lines.append("推荐刷图: %s" % String(recommendation.get("label", "")))
		lines.append("推荐原因: %s" % String(recommendation.get("reason", "")))
		lines.append("期望收益: %s" % String(recommendation.get("expectation_text", "")))
	_append_observed_stats_lines(lines, affix_id, "affix", recommendation)
	return "\n".join(lines)


func _get_best_recommendation_entry(category: String, data: Dictionary) -> Dictionary:
	return LootRuleService.get_best_recommendation_entry(
		category,
		data,
		GameManager.current_chapter_id,
		GameManager.get_selected_archetype_tags()
	)


func _profile_matches_entry(category: String, data: Dictionary, drop_profile: Dictionary) -> bool:
	match category:
		"base":
			var item_level: int = int(data.get("item_level", 1))
			var equipment_rules: Dictionary = drop_profile.get("equipment_rules", {})
			return item_level >= int(equipment_rules.get("item_level_min", 1)) and item_level <= int(equipment_rules.get("item_level_max", item_level))
		"affix":
			var source_profile_types: Array = data.get("source_profile_types", [])
			var profile_type: String = String(drop_profile.get("profile_type", "normal"))
			if not source_profile_types.is_empty() and not source_profile_types.has(profile_type):
				return false
			var allowed_rarities: Array = drop_profile.get("equipment_rules", {}).get("allowed_rarities", [])
			return not allowed_rarities.is_empty()
		_:
			var source_types: Array = data.get("source_profile_types", [])
			return _profile_can_drop_legendary(drop_profile, source_types)


func _score_recommendation_node(
	category: String,
	data: Dictionary,
	drop_profile: Dictionary,
	chapter_order: int,
	current_chapter_order: int,
	selected_tags: Array
) -> float:
	var equipment_rules: Dictionary = drop_profile.get("equipment_rules", {})
	var score: float = float(drop_profile.get("equipment_rolls", 1)) * float(drop_profile.get("equipment_chance", 0.0)) * 100.0
	score += float(int(equipment_rules.get("item_level_max", 1))) * 4.0
	if bool(equipment_rules.get("guaranteed_legendary_affix", false)):
		score += 30.0
	if bool(equipment_rules.get("prefer_current_build", false)):
		score += 8.0
	if chapter_order <= current_chapter_order:
		score += 12.0
	else:
		score -= float(chapter_order - current_chapter_order) * 10.0
	match String(drop_profile.get("profile_type", "normal")):
		"boss":
			score += 18.0
		"elite":
			score += 10.0
		_:
			score += 0.0

	if category == "base":
		var base_tags: Array = data.get("affix_pool_tags", [])
		for tag in selected_tags:
			if base_tags.has(tag):
				score += 12.0
	elif category == "affix":
		for tag in selected_tags:
			if data.get("archetype_tags", []).has(tag):
				score += 15.0
	elif category == "legendary":
		for tag in selected_tags:
			if data.get("archetype_tags", []).has(tag):
				score += 20.0
	return score


func _build_recommendation_reason(drop_profile: Dictionary, chapter_order: int, current_chapter_order: int, score: float) -> String:
	var state_text: String = "当前可刷" if chapter_order <= current_chapter_order else "后续章节"
	return "%s，装备轮次 %d，掉装概率 %.0f%%，评分 %.1f，方向：%s" % [
		state_text,
		int(drop_profile.get("equipment_rolls", 1)),
		float(drop_profile.get("equipment_chance", 0.0)) * 100.0,
		score,
		String(drop_profile.get("drop_focus", "常规掉落")),
	]


func _build_expectation_text(category: String, data: Dictionary, drop_profile: Dictionary, node_data: Dictionary) -> String:
	return LootRuleService.build_expectation_text(
		category,
		data,
		drop_profile,
		node_data,
		GameManager.get_selected_archetype_tags()
	)


func _get_expectation_metrics(category: String, data: Dictionary, drop_profile: Dictionary, node_data: Dictionary) -> Dictionary:
	return LootRuleService.get_expectation_metrics(
		category,
		data,
		drop_profile,
		node_data,
		GameManager.get_selected_archetype_tags()
	)


func _get_base_distribution(drop_profile: Dictionary, selected_tags: Array) -> Array:
	var equipment_rules: Dictionary = drop_profile.get("equipment_rules", {})
	var item_level_min: int = int(equipment_rules.get("item_level_min", 1))
	var item_level_max: int = int(equipment_rules.get("item_level_max", item_level_min))
	var candidates: Array = []
	var total_weight: float = 0.0
	for entry in ConfigDB.get_all_equipment_bases():
		var base_entry: Dictionary = entry
		var entry_level: int = int(base_entry.get("item_level", 1))
		if entry_level < item_level_min or entry_level > item_level_max:
			continue
		var weight: float = _get_base_weight(base_entry, selected_tags)
		total_weight += weight
		candidates.append({"base": base_entry, "weight": weight})
	if total_weight <= 0.0:
		return []
	for candidate_variant in candidates:
		var candidate: Dictionary = candidate_variant
		candidate["probability"] = float(candidate.get("weight", 0.0)) / total_weight
	return candidates


func _estimate_base_probability_per_item(base_id: String, base_distribution: Array) -> float:
	for candidate_variant in base_distribution:
		var candidate: Dictionary = candidate_variant
		var base_entry: Dictionary = candidate.get("base", {})
		if String(base_entry.get("id", "")) == base_id:
			return float(candidate.get("probability", 0.0))
	return 0.0


func _estimate_affix_probability_per_item(target_affix: Dictionary, drop_profile: Dictionary, base_distribution: Array, selected_tags: Array) -> float:
	var profile_type: String = String(drop_profile.get("profile_type", "normal"))
	var expected_probability: float = 0.0
	for candidate_variant in base_distribution:
		var candidate: Dictionary = candidate_variant
		var base_entry: Dictionary = candidate.get("base", {})
		var probability: float = float(candidate.get("probability", 0.0))
		var slot: String = String(base_entry.get("slot", ""))
		if not target_affix.get("slot_tags", []).has(slot):
			continue
		var target_matches: bool = _affix_matches_base(target_affix, base_entry, profile_type)
		if not target_matches:
			continue
		var candidates: Array = _get_affix_candidates_for_base(base_entry, profile_type)
		if candidates.is_empty():
			continue
		var target_weight: float = _get_affix_weight(target_affix, selected_tags)
		var total_weight: float = 0.0
		for affix_variant in candidates:
			var affix: Dictionary = affix_variant
			total_weight += _get_affix_weight(affix, selected_tags)
		if total_weight <= 0.0:
			continue
		var single_roll_probability: float = target_weight / total_weight
		var expected_hit_probability: float = _get_expected_affix_hit_probability(drop_profile, single_roll_probability)
		expected_probability += probability * expected_hit_probability
	return clampf(expected_probability, 0.0, 1.0)


func _estimate_legendary_probability_per_item(target_legendary: Dictionary, drop_profile: Dictionary, base_distribution: Array, selected_tags: Array) -> float:
	var equipment_rules: Dictionary = drop_profile.get("equipment_rules", {})
	var profile_type: String = String(drop_profile.get("profile_type", "normal"))
	var rarity_gate_probability: float = _get_legendary_rarity_gate_probability(drop_profile)
	var expected_probability: float = 0.0
	for candidate_variant in base_distribution:
		var candidate: Dictionary = candidate_variant
		var base_entry: Dictionary = candidate.get("base", {})
		var probability: float = float(candidate.get("probability", 0.0))
		var slot: String = String(base_entry.get("slot", ""))
		if not target_legendary.get("slot_tags", []).has(slot):
			continue
		var candidates: Array = _get_legendary_candidates_for_base(
			base_entry,
			profile_type,
			selected_tags,
			String(equipment_rules.get("required_legendary_source_type", ""))
		)
		if candidates.is_empty():
			continue
		var target_found: bool = false
		var total_weight: float = 0.0
		var target_weight: float = 0.0
		for affix_variant in candidates:
			var affix: Dictionary = affix_variant
			var weight: float = float(affix.get("drop_weight", 1))
			total_weight += weight
			if String(affix.get("id", "")) == String(target_legendary.get("id", "")):
				target_found = true
				target_weight = weight
		if not target_found or total_weight <= 0.0:
			continue
		expected_probability += probability * (target_weight / total_weight)
	expected_probability *= rarity_gate_probability
	return clampf(expected_probability, 0.0, 1.0)


func _get_expected_affix_hit_probability(drop_profile: Dictionary, single_roll_probability: float) -> float:
	var rarity_affix_counts: Dictionary = {"common": 1, "uncommon": 2, "rare": 3, "epic": 4, "set": 4, "legendary": 5, "ancient": 6}
	var rarity_probabilities: Dictionary = _get_allowed_rarity_probabilities(drop_profile)
	var expected_probability: float = 0.0
	for rarity_key in rarity_probabilities.keys():
		var rarity: String = String(rarity_key)
		var rarity_probability: float = float(rarity_probabilities.get(rarity_key, 0.0))
		var affix_count: int = int(rarity_affix_counts.get(rarity, 1))
		expected_probability += rarity_probability * (1.0 - pow(1.0 - single_roll_probability, affix_count))
	return clampf(expected_probability, 0.0, 1.0)


func _get_allowed_rarity_probabilities(drop_profile: Dictionary) -> Dictionary:
	var equipment_rules: Dictionary = drop_profile.get("equipment_rules", {})
	var allowed_rarities: Array = equipment_rules.get("allowed_rarities", [])
	var weights: Dictionary = {
		"common": 50.0,
		"uncommon": 30.0,
		"rare": 14.0,
		"epic": 4.0,
		"set": 1.0,
		"legendary": 1.0,
		"ancient": 0.5,
	}
	var probabilities: Dictionary = {}
	var total_weight: float = 0.0
	for rarity_variant in allowed_rarities:
		total_weight += float(weights.get(String(rarity_variant), 1.0))
	if total_weight <= 0.0:
		return probabilities
	for rarity_variant in allowed_rarities:
		var rarity: String = String(rarity_variant)
		probabilities[rarity] = float(weights.get(rarity, 1.0)) / total_weight
	return probabilities


func _get_legendary_rarity_gate_probability(drop_profile: Dictionary) -> float:
	var equipment_rules: Dictionary = drop_profile.get("equipment_rules", {})
	if bool(equipment_rules.get("guaranteed_legendary_affix", false)):
		return 1.0
	var rarity_probabilities: Dictionary = _get_allowed_rarity_probabilities(drop_profile)
	return float(rarity_probabilities.get("legendary", 0.0)) + float(rarity_probabilities.get("ancient", 0.0))


func _get_base_weight(base_entry: Dictionary, selected_tags: Array) -> float:
	var weight: float = 1.0
	for tag in selected_tags:
		if base_entry.get("affix_pool_tags", []).has(tag):
			weight += 2.0
		if base_entry.get("legendary_pool_tags", []).has(tag):
			weight += 2.0
	return weight


func _get_affix_candidates_for_base(base_entry: Dictionary, profile_type: String) -> Array:
	var candidates: Array = []
	var slot: String = String(base_entry.get("slot", ""))
	for entry in ConfigDB.get_all_affixes():
		var affix: Dictionary = entry
		if not affix.get("slot_tags", []).has(slot):
			continue
		var source_profile_types: Array = affix.get("source_profile_types", [])
		if not source_profile_types.is_empty() and not source_profile_types.has(profile_type):
			continue
		if _affix_matches_base(affix, base_entry, profile_type):
			candidates.append(affix)
	return candidates


func _affix_matches_base(affix: Dictionary, base_entry: Dictionary, profile_type: String) -> bool:
	var source_profile_types: Array = affix.get("source_profile_types", [])
	if not source_profile_types.is_empty() and not source_profile_types.has(profile_type):
		return false
	var archetype_tags: Array = affix.get("archetype_tags", [])
	if archetype_tags.is_empty():
		return true
	for tag in base_entry.get("affix_pool_tags", []):
		if archetype_tags.has(tag):
			return true
	return false


func _get_affix_weight(affix: Dictionary, selected_tags: Array) -> float:
	var weight: float = float(affix.get("rarity_weight", 1))
	for tag in selected_tags:
		if affix.get("archetype_tags", []).has(tag):
			weight += weight * 0.7
	return weight


func _get_legendary_candidates_for_base(base_entry: Dictionary, profile_type: String, selected_tags: Array, required_source_type: String) -> Array:
	var candidates: Array = []
	var slot: String = String(base_entry.get("slot", ""))
	for entry in ConfigDB.get_all_legendary_affixes():
		var affix: Dictionary = entry
		if not affix.get("slot_tags", []).has(slot):
			continue
		var source_profile_types: Array = affix.get("source_profile_types", [])
		if not required_source_type.is_empty():
			if source_profile_types.is_empty() or not source_profile_types.has(required_source_type):
				continue
		elif not source_profile_types.is_empty() and not source_profile_types.has(profile_type):
			continue
		var tag_matches: bool = affix.get("archetype_tags", []).is_empty()
		for tag in base_entry.get("legendary_pool_tags", []):
			if affix.get("archetype_tags", []).has(tag):
				tag_matches = true
				break
		for tag in selected_tags:
			if affix.get("archetype_tags", []).has(tag):
				tag_matches = true
				break
		if tag_matches:
			candidates.append(affix)
	return candidates


func _append_observed_stats_lines(lines: Array[String], entry_id: String, category: String, recommendation: Dictionary) -> void:
	var global_stats: Dictionary = get_observed_entry_stats(entry_id, category)
	if int(global_stats.get("clears", 0)) <= 0:
		lines.append("实战统计: 暂无掉落样本")
		return
	lines.append("实战统计(全局): %s" % _format_observed_stats_text(global_stats, false))
	var recommended_node_id: String = String(recommendation.get("node_id", ""))
	if recommended_node_id.is_empty():
		return
	var recommended_stats: Dictionary = get_observed_entry_stats(entry_id, category, recommended_node_id)
	if int(recommended_stats.get("clears", 0)) <= 0:
		lines.append("实战统计(推荐节点): 尚未刷过该节点")
		return
	lines.append("实战统计(推荐节点): %s" % _format_observed_stats_text(recommended_stats, true))


func get_observed_entry_stats(entry_id: String, category: String, node_id: String = "") -> Dictionary:
	if entry_id.is_empty():
		return {}
	var total_clears: int = 0
	var total_hits: int = 0
	var weighted_seconds: float = 0.0
	if node_id.is_empty():
		for node_key_variant in node_drop_stats.keys():
			var current_node_id: String = String(node_key_variant)
			var stats: Dictionary = node_drop_stats.get(current_node_id, {})
			var clears: int = int(stats.get("clears", 0))
			total_clears += clears
			total_hits += _get_stat_map_count(stats, category, entry_id)
			weighted_seconds += float(clears) * float(ConfigDB.get_chapter_node(current_node_id).get("time_limit", 60))
	else:
		var stats: Dictionary = node_drop_stats.get(node_id, {})
		total_clears = int(stats.get("clears", 0))
		total_hits = _get_stat_map_count(stats, category, entry_id)
		weighted_seconds = float(total_clears) * float(ConfigDB.get_chapter_node(node_id).get("time_limit", 60))
	if total_clears <= 0:
		return {}
	var hit_rate: float = float(total_hits) / float(total_clears)
	var average_seconds_per_clear: float = weighted_seconds / float(total_clears)
	var result: Dictionary = {
		"clears": total_clears,
		"hits": total_hits,
		"hit_rate": hit_rate,
		"average_seconds_per_clear": average_seconds_per_clear,
	}
	if total_hits > 0:
		result["clears_per_hit"] = float(total_clears) / float(total_hits)
		result["minutes_per_hit"] = (float(total_clears) / float(total_hits)) * average_seconds_per_clear / 60.0
	return result


func _format_observed_stats_text(stats: Dictionary, include_time: bool) -> String:
	var clears: int = int(stats.get("clears", 0))
	var hits: int = int(stats.get("hits", 0))
	if hits <= 0:
		return "已刷 %d 次，暂未见到目标" % clears
	var clears_per_hit: float = float(stats.get("clears_per_hit", 0.0))
	if not include_time:
		return "已刷 %d 次，见到 %d 次，实际约 %.1f 次/见 1 次" % [clears, hits, clears_per_hit]
	return "已刷 %d 次，见到 %d 次，实际约 %.1f 次/见 1 次，约 %.1f 分钟/见 1 次" % [
		clears,
		hits,
		clears_per_hit,
		float(stats.get("minutes_per_hit", 0.0)),
	]


func _build_rate_comparison_text(label: String, expected_rate: float, actual_rate: float) -> String:
	return LootRuleService.build_rate_comparison_text(label, expected_rate, actual_rate)


func _build_visual_rate_entry(label: String, expected_rate: float, actual_rate: float, sample_count: int) -> Dictionary:
	return LootRuleService.build_visual_rate_entry(label, expected_rate, actual_rate, sample_count)


func _get_deviation_state_label(delta_ratio: float) -> String:
	if delta_ratio >= 0.25:
		return "明显高于期望"
	if delta_ratio >= 0.08:
		return "略高于期望"
	if delta_ratio <= -0.25:
		return "明显低于期望"
	if delta_ratio <= -0.08:
		return "略低于期望"
	return "接近期望"


func _format_signed_percent(value: float) -> String:
	var percent: float = value * 100.0
	if percent >= 0.0:
		return "+%.0f%%" % percent
	return "%.0f%%" % percent


func _append_recent_drop_record(node_id: String, items: Array, stats: Dictionary) -> void:
	var node_data: Dictionary = ConfigDB.get_chapter_node(node_id)
	var chapter_data: Dictionary = ConfigDB.get_chapter(String(node_data.get("chapter_id", "")))
	var record: Dictionary = {
		"node_id": node_id,
		"node_name": ConfigDB.get_chapter_node_name(node_id),
		"chapter_name": String(chapter_data.get("name", "")),
		"node_type": String(node_data.get("node_type", "normal")),
		"clear_index": int(stats.get("clears", 0)),
		"equipment_count": items.size(),
		"legendary_count": _count_legendary_items(items),
		"summary": _summarize_drop_record(items),
	}
	recent_drop_records.push_front(record)
	if recent_drop_records.size() > MAX_RECENT_DROP_RECORDS:
		recent_drop_records.resize(MAX_RECENT_DROP_RECORDS)


func _count_legendary_items(items: Array) -> int:
	var total: int = 0
	for item_variant in items:
		var item: Dictionary = item_variant
		if not item.get("legendary_affix", {}).is_empty():
			total += 1
	return total


func _summarize_drop_record(items: Array) -> String:
	if items.is_empty():
		return "未掉落装备"
	var labels: Array[String] = []
	for item_variant in items:
		var item: Dictionary = item_variant
		var label: String = String(item.get("name", "装备"))
		if not item.get("legendary_affix", {}).is_empty():
			var legendary_affix: Dictionary = item.get("legendary_affix", {})
			label += " <%s>" % String(legendary_affix.get("name", "传奇"))
		labels.append(label)
	return ", ".join(labels)


func _profile_can_drop_legendary(drop_profile: Dictionary, source_profile_types: Array) -> bool:
	var profile_type: String = String(drop_profile.get("profile_type", "normal"))
	var equipment_rules: Dictionary = drop_profile.get("equipment_rules", {})
	var required_source_type: String = String(equipment_rules.get("required_legendary_source_type", ""))
	var allowed_rarities: Array = equipment_rules.get("allowed_rarities", [])
	var can_roll_legendary: bool = bool(equipment_rules.get("guaranteed_legendary_affix", false)) or allowed_rarities.has("legendary") or allowed_rarities.has("ancient")
	if not can_roll_legendary:
		return false
	if source_profile_types.is_empty():
		return can_roll_legendary
	if not required_source_type.is_empty():
		return source_profile_types.has(required_source_type)
	return source_profile_types.has(profile_type)


func _get_total_recorded_clears() -> int:
	var total_clears: int = 0
	for node_id_variant in node_drop_stats.keys():
		var node_id: String = String(node_id_variant)
		var stats: Dictionary = node_drop_stats.get(node_id, {})
		total_clears += int(stats.get("clears", 0))
	return total_clears


func _get_or_create_node_drop_stats(node_id: String) -> Dictionary:
	var stats: Dictionary = node_drop_stats.get(node_id, {})
	if stats.is_empty():
		stats = {
			"clears": 0,
			"equipment_drops": 0,
			"legendary_drops": 0,
			"base_hits": {},
			"affix_hits": {},
			"legendary_hits": {},
		}
	else:
		if not stats.has("base_hits"):
			stats["base_hits"] = {}
		if not stats.has("affix_hits"):
			stats["affix_hits"] = {}
		if not stats.has("legendary_hits"):
			stats["legendary_hits"] = {}
	return stats


func _increment_stat_map(stats: Dictionary, map_key: String, entry_id: String, amount: int) -> void:
	if entry_id.is_empty():
		return
	var stat_map: Dictionary = stats.get(map_key, {})
	stat_map[entry_id] = int(stat_map.get(entry_id, 0)) + amount
	stats[map_key] = stat_map


func _get_stat_map_count(stats: Dictionary, category: String, entry_id: String) -> int:
	var map_key: String = ""
	match category:
		"base":
			map_key = "base_hits"
		"affix":
			map_key = "affix_hits"
		_:
			map_key = "legendary_hits"
	var stat_map: Dictionary = stats.get(map_key, {})
	return int(stat_map.get(entry_id, 0))


func _normalize_node_drop_stats(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not value is Dictionary:
		return result
	for node_id_variant in value.keys():
		var node_id: String = String(node_id_variant)
		var raw_stats: Variant = value.get(node_id_variant, {})
		if not raw_stats is Dictionary:
			continue
		var stats: Dictionary = raw_stats
		result[node_id] = {
			"clears": int(stats.get("clears", 0)),
			"equipment_drops": int(stats.get("equipment_drops", 0)),
			"legendary_drops": int(stats.get("legendary_drops", 0)),
			"base_hits": _normalize_stat_count_map(stats.get("base_hits", {})),
			"affix_hits": _normalize_stat_count_map(stats.get("affix_hits", {})),
			"legendary_hits": _normalize_stat_count_map(stats.get("legendary_hits", {})),
		}
	return result


func _normalize_stat_count_map(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not value is Dictionary:
		return result
	for key_variant in value.keys():
		result[String(key_variant)] = int(value.get(key_variant, 0))
	return result


func _normalize_recent_drop_records(value: Variant) -> Array:
	var result: Array = []
	if not value is Array:
		return result
	for entry_variant in value:
		if not entry_variant is Dictionary:
			continue
		var entry: Dictionary = entry_variant
		result.append({
			"node_id": String(entry.get("node_id", "")),
			"chapter_name": String(entry.get("chapter_name", "")),
			"node_type": String(entry.get("node_type", "normal")),
			"clear_index": int(entry.get("clear_index", 0)),
			"equipment_count": int(entry.get("equipment_count", 0)),
			"legendary_count": int(entry.get("legendary_count", 0)),
			"summary": String(entry.get("summary", "")),
		})
	return result


func _register_unique(target: Array[String], value: String) -> bool:
	if value.is_empty() or target.has(value):
		return false
	target.append(value)
	return true


func _variant_to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry in value:
			result.append(String(entry))
	return result


func _sort_codex_entries(a: Dictionary, b: Dictionary) -> bool:
	return String(a.get("name", "")) < String(b.get("name", ""))


func _sort_drop_stat_entries(a: Dictionary, b: Dictionary) -> bool:
	if bool(a.get("is_current", false)) != bool(b.get("is_current", false)):
		return bool(a.get("is_current", false))
	if int(a.get("clears", 0)) != int(b.get("clears", 0)):
		return int(a.get("clears", 0)) > int(b.get("clears", 0))
	return String(a.get("node_id", "")) < String(b.get("node_id", ""))


func _format_array(values: Array, fallback: String) -> String:
	if values.is_empty():
		return fallback
	var text_values: Array[String] = []
	for value in values:
		text_values.append(String(value))
	return ", ".join(text_values)
