class_name BuildQueryService
extends RefCounted

const MartialCodexSystem = preload("res://scripts/systems/martial_codex_system.gd")
const GemSystem = preload("res://scripts/systems/gem_system.gd")
const ParagonSystem = preload("res://scripts/systems/paragon_system.gd")
const SeasonSystem = preload("res://scripts/systems/season_system.gd")

static func get_total_combat_bonuses(
	equipped_items: Dictionary,
	set_summary: Dictionary,
	martial_codex_state: Dictionary,
	gem_state: Dictionary,
	paragon_state: Dictionary,
	season_state: Dictionary
) -> Dictionary:
	var totals: Dictionary = {
		"weapon_damage": 0.0,
		"primary_stat": 0.0,
		"crit_rate": 0.0,
		"crit_damage": 0.5,
		"skill_damage_percent": 0.0,
		"elemental_damage_percent": 0.0,
		"set_bonus_percent": 0.0,
		"legendary_effect_percent": 0.0,
		"elite_damage_percent": 0.0,
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
		"all_resist": 0.0,
		"armor_flat": 0.0,
		"life_regen": 0.0,
		"move_speed_percent": 0.0,
		"resource_cost_reduction": 0.0,
	}

	for item_variant in equipped_items.values():
		var item: Dictionary = item_variant
		if item.is_empty():
			continue
		for stat_entry_variant in item.get("base_stats", []):
			_add_stat_to_totals(totals, stat_entry_variant)
		for affix_entry_variant in item.get("affixes", []):
			_add_stat_to_totals(totals, affix_entry_variant)
		var legendary_affix: Dictionary = item.get("legendary_affix", {})
		if not legendary_affix.is_empty():
			_add_stat_to_totals(totals, legendary_affix)
			_add_secondary_stat_to_totals(totals, legendary_affix)

	MetaProgressionSystem.apply_combat_bonuses_to_totals(totals)
	_merge_bonus_dict(totals, set_summary.get("total_bonuses", {}))
	_merge_bonus_dict(totals, MartialCodexSystem.build_combat_bonuses(martial_codex_state))
	_merge_bonus_dict(totals, GemSystem.build_combat_bonuses(gem_state))
	_merge_bonus_dict(totals, ParagonSystem.build_combat_bonuses(paragon_state))
	_merge_bonus_dict(totals, SeasonSystem.build_combat_bonuses(season_state))
	return totals


static func get_build_advice_data() -> Dictionary:
	var skill_data: Dictionary = GameManager.get_selected_core_skill()
	if skill_data.is_empty():
		return {}

	var archetype_id: String = _get_primary_archetype_tag(skill_data)
	var profile: Dictionary = GameManager.BUILD_ARCHETYPE_PROFILES.get(archetype_id, {})
	var chapter_data: Dictionary = ConfigDB.get_chapter(GameManager.current_chapter_id)
	var chapter_name: String = String(chapter_data.get("name", GameManager.current_chapter_id))
	var chapter_order: int = int(chapter_data.get("order", 1))
	var current_node: Dictionary = ConfigDB.get_chapter_node(GameManager.current_node_id)
	var stable_node: Dictionary = ConfigDB.get_chapter_node(GameManager.stable_node_id)
	var bonuses: Dictionary = get_total_combat_bonuses(
		GameManager.equipped_items,
		GameManager.set_summary,
		GameManager.martial_codex_state,
		GameManager.gem_state,
		GameManager.paragon_state,
		GameManager.season_state
	)
	var is_progress_blocked: bool = GameManager.current_node_id != GameManager.stable_node_id and not current_node.is_empty() and not stable_node.is_empty()
	var block_node_label: String = _get_node_short_label(current_node, chapter_data)

	var primary_gap: Dictionary = _get_primary_stat_gap(profile, bonuses, chapter_order)
	var survival_gap: Dictionary = _get_survival_gap(bonuses, chapter_order)
	var chosen_gap: Dictionary = primary_gap
	if chosen_gap.is_empty() or float(survival_gap.get("deficit_ratio", 0.0)) > float(chosen_gap.get("deficit_ratio", 0.0)) + 0.18:
		chosen_gap = survival_gap
	if chosen_gap.is_empty():
		chosen_gap = _get_default_gap(bonuses, chapter_order)

	var gap_severity: String = _get_gap_severity(float(chosen_gap.get("deficit_ratio", 0.0)))
	var gap_severity_label: String = _get_gap_severity_label(gap_severity)
	var recommendation_target: Dictionary = _build_recommendation_target(profile, chosen_gap)
	var research_action: Dictionary = _get_research_action_data()
	var tracked_target_line: String = _build_tracked_target_line()
	var recommendation_label: String = String(recommendation_target.get("recommended_node_label", chapter_name))
	var recommendation_short: String = String(recommendation_target.get("recommendation_short", "先刷当前可稳定通关的推荐节点"))
	var gap_stat_label: String = String(chosen_gap.get("label", "传承属性"))
	var gap_category_label: String = String(chosen_gap.get("category_label", "伤害"))
	var gap_metric_text: String = "%s/%s" % [
		_format_stat_value(String(chosen_gap.get("stat_key", "")), float(chosen_gap.get("current_value", 0.0))),
		_format_stat_value(String(chosen_gap.get("stat_key", "")), float(chosen_gap.get("target_value", 0.0))),
	]
	var primary_target_name: String = String(recommendation_target.get("primary_target_name", "当前传承核心掉落"))
	var secondary_target_name: String = String(recommendation_target.get("secondary_target_name", "对应词条"))
	var base_target_name: String = String(recommendation_target.get("base_target_name", "合适底材"))
	var next_target_segments: Array[String] = []
	for segment_variant in [primary_target_name, secondary_target_name, base_target_name]:
		var segment: String = String(segment_variant)
		if segment.is_empty() or next_target_segments.has(segment):
			continue
		next_target_segments.append(segment)

	var next_target_line: String = "下一件: %s" % (" / ".join(next_target_segments) if not next_target_segments.is_empty() else "继续补当前传承核心件")
	var recommendation_line: String = "推荐: %s | %s" % [recommendation_label, recommendation_short]
	var gap_line: String = "缺口: %s(%s) -> %s %s" % [gap_category_label, gap_severity_label, gap_stat_label, gap_metric_text]
	var pivot_data: Dictionary = _build_pivot_recommendation(
		chosen_gap,
		gap_severity,
		recommendation_target,
		research_action,
		is_progress_blocked,
		block_node_label
	)
	var unlock_preview_line: String = _build_unlock_preview_line(current_node, chapter_data)
	var action_lines: Array[String] = []
	action_lines.append(String(pivot_data.get("pivot_summary", "当前还能继续探境，边推边补当前缺口。")))
	action_lines.append("先补 %s，当前 %s，建议至少到 %s。" % [
		gap_stat_label,
		_format_stat_value(String(chosen_gap.get("stat_key", "")), float(chosen_gap.get("current_value", 0.0))),
		_format_stat_value(String(chosen_gap.get("stat_key", "")), float(chosen_gap.get("target_value", 0.0))),
	])
	action_lines.append("下一件优先找 %s，副目标看 %s。" % [primary_target_name, secondary_target_name])
	action_lines.append("推荐去 %s 刷，%s。" % [recommendation_label, recommendation_short])
	if not unlock_preview_line.is_empty():
		action_lines.append(unlock_preview_line)

	return {
		"archetype_id": archetype_id,
		"archetype_name": String(profile.get("display_name", String(skill_data.get("name", GameManager.selected_core_skill_id)))),
		"chapter_name": chapter_name,
		"phase_text": String(profile.get("phase_text", "")),
		"new_player_summary": String(profile.get("new_player_summary", "")),
		"is_progress_blocked": is_progress_blocked,
		"block_node_id": GameManager.current_node_id if is_progress_blocked else "",
		"block_node_label": block_node_label if is_progress_blocked else "",
		"gap_category": String(chosen_gap.get("category", "damage")),
		"gap_category_label": gap_category_label,
		"gap_label": gap_stat_label,
		"gap_severity": gap_severity,
		"gap_severity_label": gap_severity_label,
		"gap_metric_text": gap_metric_text,
		"gap_summary": "当前更缺 %s，先补 %s。" % [gap_category_label, gap_stat_label],
		"pivot_type": String(pivot_data.get("pivot_type", "push")),
		"pivot_summary": String(pivot_data.get("pivot_summary", "")),
		"stall_summary": String(pivot_data.get("stall_summary", recommendation_line)),
		"unlock_preview_line": unlock_preview_line,
		"tracked_target_line": tracked_target_line,
		"gap_line": gap_line,
		"next_target_line": next_target_line,
		"recommendation_line": recommendation_line,
		"primary_target_name": primary_target_name,
		"secondary_target_name": secondary_target_name,
		"base_target_name": base_target_name,
		"recommended_node_id": String(recommendation_target.get("recommended_node_id", GameManager.current_node_id)),
		"recommended_node_label": recommendation_label,
		"recommendation_short": recommendation_short,
		"recommendation_reason": String(recommendation_target.get("reason", "")),
		"research_action_type": String(research_action.get("action_type", "")),
		"research_action_name": String(research_action.get("node_name", "")),
		"research_action_resource_id": String(research_action.get("resource_id", "")),
		"research_action_missing_amount": int(research_action.get("missing_amount", 0)),
		"research_action_summary": String(research_action.get("summary", "")),
		"action_lines": action_lines,
	}


static func _add_stat_to_totals(totals: Dictionary, entry_variant: Variant) -> void:
	var entry: Dictionary = entry_variant
	var stat_key: String = String(entry.get("stat_key", ""))
	var value: float = float(entry.get("value", 0.0))
	if totals.has(stat_key):
		totals[stat_key] += value


static func _add_secondary_stat_to_totals(totals: Dictionary, entry: Dictionary) -> void:
	var stat_key: String = String(entry.get("secondary_stat_key", ""))
	var value: float = float(entry.get("secondary_value", 0.0))
	if totals.has(stat_key):
		totals[stat_key] += value


static func _merge_bonus_dict(totals: Dictionary, bonus_dict: Dictionary) -> void:
	for stat_key_variant in bonus_dict.keys():
		var stat_key: String = String(stat_key_variant)
		if totals.has(stat_key):
			totals[stat_key] += float(bonus_dict.get(stat_key_variant, 0.0))


static func _get_primary_archetype_tag(skill_data: Dictionary) -> String:
	var archetype_tags: Array = skill_data.get("archetype_tags", [])
	if archetype_tags.is_empty():
		return ""
	return String(archetype_tags[0])


static func _get_primary_stat_gap(profile: Dictionary, totals: Dictionary, chapter_order: int) -> Dictionary:
	var best_gap: Dictionary = {}
	var best_score: float = -1.0
	for entry_variant in profile.get("primary_stats", []):
		var entry: Dictionary = entry_variant
		var stat_key: String = String(entry.get("stat_key", ""))
		var target_value: float = float(entry.get("target_base", 0.0)) + float(maxi(chapter_order - 1, 0)) * float(entry.get("target_per_chapter", 0.0))
		var current_value: float = float(totals.get(stat_key, 0.0))
		var deficit_ratio: float = maxf(0.0, target_value - current_value) / maxf(target_value, 0.001)
		var score: float = deficit_ratio
		if String(entry.get("category", "")) == "function":
			score += 0.08
		if current_value <= 0.0:
			score += 0.06
		if score > best_score:
			best_score = score
			best_gap = entry.duplicate(true)
			best_gap["target_value"] = target_value
			best_gap["current_value"] = current_value
			best_gap["deficit_ratio"] = deficit_ratio
	return best_gap


static func _get_survival_gap(totals: Dictionary, chapter_order: int) -> Dictionary:
	var hp_target: float = 34.0 + float(chapter_order) * 26.0
	var defense_target: float = 4.0 + float(chapter_order) * 2.0
	var hp_value: float = float(totals.get("hp_flat", 0.0))
	var defense_value: float = float(totals.get("defense_flat", 0.0))
	var hp_ratio: float = maxf(0.0, hp_target - hp_value) / maxf(hp_target, 1.0)
	var defense_ratio: float = maxf(0.0, defense_target - defense_value) / maxf(defense_target, 1.0)
	return {
		"stat_key": "hp_flat",
		"label": "生存面板",
		"category": "survival",
		"category_label": "生存",
		"current_value": hp_value + defense_value * 4.0,
		"target_value": hp_target + defense_target * 4.0,
		"deficit_ratio": (hp_ratio + defense_ratio) * 0.5,
		"affix_ids": ["affix_hp_flat", "affix_defense_flat"],
		"legendary_ids": ["legend_boss_tyrant_shell"],
	}


static func _get_default_gap(bonuses: Dictionary, chapter_order: int) -> Dictionary:
	return {
		"stat_key": "core_damage_percent",
		"category": "damage",
		"category_label": "伤害",
		"label": "武学伤害",
		"current_value": float(bonuses.get("core_damage_percent", 0.0)),
		"target_value": 0.24 + float(maxi(chapter_order - 1, 0)) * 0.08,
		"deficit_ratio": 0.0,
		"affix_ids": ["affix_core_damage"],
		"legendary_ids": ["legend_time_fissure"],
	}


static func _get_gap_severity(deficit_ratio: float) -> String:
	if deficit_ratio >= 0.55:
		return "severe"
	if deficit_ratio >= 0.28:
		return "moderate"
	return "mild"


static func _get_gap_severity_label(severity: String) -> String:
	match severity:
		"severe":
			return "严重"
		"moderate":
			return "明显"
		_:
			return "轻度"


static func _build_pivot_recommendation(
	gap: Dictionary,
	gap_severity: String,
	recommendation_target: Dictionary,
	research_action: Dictionary,
	is_progress_blocked: bool,
	block_node_label: String
) -> Dictionary:
	var gap_label: String = String(gap.get("label", "当前缺口"))
	var recommended_node_label: String = String(recommendation_target.get("recommended_node_label", GameManager.current_node_id))
	var recommended_node_id: String = String(recommendation_target.get("recommended_node_id", GameManager.current_node_id))
	var research_summary: String = String(research_action.get("summary", ""))
	var pivot_type: String = "push"
	var pivot_summary: String = "当前还能继续探境，边打边补 %s。" % gap_label
	var stall_summary: String = "当前可继续推进，边打边补 %s。" % gap_label

	if is_progress_blocked:
		if String(research_action.get("action_type", "")) == "research_upgrade" and gap_severity != "mild":
			pivot_type = "research_upgrade"
			pivot_summary = "先去成长中心，立刻补一层 %s。" % String(research_action.get("node_name", "当前参悟"))
			stall_summary = "卡在 %s，先做一次参悟再回头推进。" % block_node_label
		elif String(research_action.get("action_type", "")) == "resource_collect" and gap_severity == "severe":
			pivot_type = "research_resource"
			pivot_summary = research_summary if not research_summary.is_empty() else "先筹够参悟材料，再回头推当前卡点。"
			stall_summary = "卡在 %s，先筹材料做参悟更稳。" % block_node_label
		elif not recommended_node_id.is_empty() and recommended_node_id != GameManager.current_node_id:
			pivot_type = "farm"
			pivot_summary = "先回刷 %s，优先补 %s。" % [recommended_node_label, gap_label]
			stall_summary = "卡在 %s，先回刷 %s 补 %s。" % [block_node_label, recommended_node_label, gap_label]
		else:
			stall_summary = "当前卡在 %s，继续补 %s 后再推。" % [block_node_label, gap_label]
	elif String(research_action.get("action_type", "")) == "research_upgrade" and gap_severity == "severe":
		pivot_type = "research_upgrade"
		pivot_summary = "当前还能推进，但先做一次参悟会更稳。"
		stall_summary = "先做一次参悟，再继续推进会更稳。"
	elif not recommended_node_id.is_empty() and recommended_node_id != GameManager.current_node_id and gap_severity == "severe":
		pivot_type = "farm"
		pivot_summary = "先刷 %s，优先补 %s。" % [recommended_node_label, gap_label]
		stall_summary = "先回刷 %s 补 %s，再继续推进。" % [recommended_node_label, gap_label]

	return {
		"pivot_type": pivot_type,
		"pivot_summary": pivot_summary,
		"stall_summary": stall_summary,
	}


static func _get_research_action_data() -> Dictionary:
	for tree_filter in ["combat", "economy", "idle"]:
		for research_node_variant in MetaProgressionSystem.get_research_items(tree_filter):
			var research_node: Dictionary = research_node_variant
			var node_id: String = String(research_node.get("id", ""))
			var upgrade_state: Dictionary = MetaProgressionSystem.can_upgrade_research(node_id)
			if bool(upgrade_state.get("ok", false)):
				return {
					"action_type": "research_upgrade",
					"node_id": node_id,
					"node_name": String(research_node.get("name", node_id)),
					"summary": "成长中心可立刻提升 %s。" % String(research_node.get("name", node_id)),
				}
			var reason: String = String(upgrade_state.get("reason", ""))
			if reason.contains("不足"):
				var current_level: int = MetaProgressionSystem.get_research_level(node_id)
				var cost_entry: Dictionary = _get_research_upgrade_cost(research_node, current_level + 1)
				if cost_entry.is_empty():
					continue
				var resource_id: String = String(cost_entry.get("resource_id", ""))
				var cost_amount: int = int(cost_entry.get("amount", 0))
				var current_amount: int = MetaProgressionSystem.get_resource_amount(resource_id)
				var missing_amount: int = maxi(1, cost_amount - current_amount)
				return {
					"action_type": "resource_collect",
					"node_id": node_id,
					"node_name": String(research_node.get("name", node_id)),
					"resource_id": resource_id,
					"missing_amount": missing_amount,
					"summary": "还差 %s x%d，才能参悟 %s。" % [
						MetaProgressionSystem.get_resource_display_name(resource_id),
						missing_amount,
						String(research_node.get("name", node_id)),
					],
				}
	return {}


static func _get_research_upgrade_cost(research_node: Dictionary, target_level: int) -> Dictionary:
	var costs: Array = research_node.get("costs", [])
	for cost_entry_variant in costs:
		var cost_entry: Dictionary = cost_entry_variant
		if int(cost_entry.get("level", 0)) == target_level:
			return cost_entry
	if costs.is_empty():
		return {}
	return costs[-1]


static func _build_unlock_preview_line(current_node: Dictionary, chapter_data: Dictionary) -> String:
	if current_node.is_empty():
		return ""
	var next_node_id: String = String(current_node.get("next_node_id", ""))
	if not next_node_id.is_empty():
		return "突破后续: 再过当前节点，将推进到 %s。" % ConfigDB.get_chapter_node_short_label(next_node_id)
	if String(current_node.get("node_type", "")) != "boss":
		return ""
	var next_chapter_id: String = String(chapter_data.get("next_chapter_id", ""))
	if next_chapter_id.is_empty():
		return "突破后续: 当前推图已到尽头，之后转为高价值回刷。"
	var next_chapter: Dictionary = ConfigDB.get_chapter(next_chapter_id)
	return "突破后续: 击破后将开启 %s。" % String(next_chapter.get("name", next_chapter_id))


static func _get_node_short_label(node_data: Dictionary, _chapter_data: Dictionary) -> String:
	if node_data.is_empty():
		return GameManager.current_node_id
	return ConfigDB.get_chapter_node_short_label(String(node_data.get("id", GameManager.current_node_id)))


static func _build_recommendation_target(profile: Dictionary, gap: Dictionary) -> Dictionary:
	var legendary_ids: Array = gap.get("legendary_ids", [])
	var affix_ids: Array = gap.get("affix_ids", [])
	var primary_legendary_id: String = _pick_prioritized_entry_id(legendary_ids, "legendary")
	var primary_affix_id: String = _pick_prioritized_entry_id(affix_ids, "affix")
	var base_id: String = _pick_recommended_base_id(profile, primary_legendary_id, primary_affix_id)
	var recommendation: Dictionary = {}
	if not primary_legendary_id.is_empty():
		recommendation = LootCodexSystem.get_recommended_farm_node_for_legendary(primary_legendary_id)
	if recommendation.is_empty() and not primary_affix_id.is_empty():
		recommendation = LootCodexSystem.get_recommended_farm_node_for_affix(primary_affix_id)
	if recommendation.is_empty() and not base_id.is_empty():
		recommendation = LootCodexSystem.get_recommended_farm_node_for_base(base_id)

	var expectation: String = ""
	if not recommendation.is_empty():
		expectation = "约 %.1f 次/见 1 次" % float(recommendation.get("expected_clears_per_hit", 0.0))
	return {
		"primary_target_name": _get_named_entry(primary_legendary_id, "legendary").get("name", _get_named_entry(primary_affix_id, "affix").get("name", "核心件")),
		"secondary_target_name": _get_named_entry(primary_affix_id, "affix").get("name", _get_named_entry(primary_legendary_id, "legendary").get("name", "功能真意")),
		"base_target_name": _get_named_entry(base_id, "base").get("name", "合适底材"),
		"recommended_node_id": String(recommendation.get("node_id", GameManager.current_node_id)),
		"recommended_node_label": String(recommendation.get("short_label", GameManager.current_node_id)),
		"recommendation_short": _build_recommendation_short_text(recommendation, expectation),
		"reason": String(recommendation.get("reason", "")),
	}


static func _build_recommendation_short_text(recommendation: Dictionary, expectation: String) -> String:
	if recommendation.is_empty():
		return "先刷当前能稳定通关的节点"
	var reason: String = String(recommendation.get("reason", ""))
	var state_text: String = "当前可刷"
	if reason.begins_with("后续章节"):
		state_text = "后续章节"
	return "%s，%s" % [state_text, expectation if not expectation.is_empty() else "看掉率推荐推进"]


static func _pick_prioritized_entry_id(candidate_ids: Array, category: String) -> String:
	for candidate_variant in candidate_ids:
		var candidate_id: String = String(candidate_variant)
		if candidate_id.is_empty():
			continue
		if category == "legendary" and not LootCodexSystem.is_legendary_discovered(candidate_id):
			return candidate_id
		if not _get_named_entry(candidate_id, category).is_empty():
			return candidate_id
	return ""


static func _pick_recommended_base_id(profile: Dictionary, legendary_id: String, affix_id: String) -> String:
	var preferred_slot_tags: Array = []
	var legendary_entry: Dictionary = _get_named_entry(legendary_id, "legendary")
	if not legendary_entry.is_empty():
		preferred_slot_tags = legendary_entry.get("slot_tags", [])
	var affix_entry: Dictionary = _get_named_entry(affix_id, "affix")
	if preferred_slot_tags.is_empty() and not affix_entry.is_empty():
		preferred_slot_tags = affix_entry.get("slot_tags", [])

	var recommended_ids: Array = profile.get("recommended_base_ids", [])
	for base_id_variant in recommended_ids:
		var base_id: String = String(base_id_variant)
		var base_entry: Dictionary = _get_named_entry(base_id, "base")
		if base_entry.is_empty():
			continue
		if preferred_slot_tags.is_empty() or preferred_slot_tags.has(String(base_entry.get("slot", ""))):
			return base_id
	for base_entry_variant in ConfigDB.get_all_equipment_bases():
		var base_entry: Dictionary = base_entry_variant
		if preferred_slot_tags.is_empty() or preferred_slot_tags.has(String(base_entry.get("slot", ""))):
			return String(base_entry.get("id", ""))
	return ""


static func _get_named_entry(entry_id: String, category: String) -> Dictionary:
	if entry_id.is_empty():
		return {}
	var pool: Array = []
	match category:
		"base":
			pool = ConfigDB.get_all_equipment_bases()
		"affix":
			pool = ConfigDB.get_all_affixes()
		_:
			pool = ConfigDB.get_all_legendary_affixes()
	for entry_variant in pool:
		var entry: Dictionary = entry_variant
		if String(entry.get("id", "")) == entry_id:
			return entry
	return {}


static func _build_tracked_target_line() -> String:
	var tracked_id: String = LootCodexSystem.tracked_legendary_affix_id
	if tracked_id.is_empty():
		return "追踪: 未设目标，先按传承推荐刷装"
	var target_name: String = String(_get_named_entry(tracked_id, "legendary").get("name", tracked_id))
	var recommendation: Dictionary = LootCodexSystem.get_recommended_farm_node_for_legendary(tracked_id)
	var recommendation_label: String = String(recommendation.get("short_label", GameManager.current_node_id))
	return "追踪: %s -> %s" % [target_name, recommendation_label]


static func get_build_relevant_legendary_ids(selected_tags: Array) -> Array:
	var relevant_ids: Array[String] = []
	var fallback_ids: Array[String] = []
	for entry_variant in ConfigDB.get_all_legendary_affixes():
		var affix: Dictionary = entry_variant
		var affix_id: String = String(affix.get("id", ""))
		fallback_ids.append(affix_id)
		if selected_tags.is_empty():
			continue
		for tag_variant in selected_tags:
			var tag: String = String(tag_variant)
			if affix.get("archetype_tags", []).has(tag):
				relevant_ids.append(affix_id)
				break
	if not relevant_ids.is_empty():
		return relevant_ids
	return fallback_ids


static func _format_stat_value(stat_key: String, value: float) -> String:
	match stat_key:
		"attack_speed_percent", "attack_percent", "core_damage_percent", "core_cooldown_reduction", "whirlwind_radius_percent", "bleed_dot_percent", "execute_threshold", "chain_damage_percent":
			return "%d%%" % int(round(value * 100.0))
		"chain_count_bonus":
			return "+%d" % int(round(value))
		_:
			return "%d" % int(round(value))
