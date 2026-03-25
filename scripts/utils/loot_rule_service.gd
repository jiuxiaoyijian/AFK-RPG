class_name LootRuleService
extends RefCounted


static func get_best_recommendation_entry(category: String, data: Dictionary, current_chapter_id: String, selected_tags: Array) -> Dictionary:
	var best_entry: Dictionary = {}
	var best_score: float = -INF
	var current_chapter_order: int = int(ConfigDB.get_chapter(current_chapter_id).get("order", 1))
	for node_id_variant in ConfigDB.chapter_nodes.keys():
		var node_id: String = String(node_id_variant)
		var node_data: Dictionary = ConfigDB.get_chapter_node(node_id)
		var profile_id: String = String(node_data.get("repeat_rewards_profile_id", ""))
		var drop_profile: Dictionary = ConfigDB.get_drop_profile(profile_id)
		if drop_profile.is_empty():
			continue
		if not profile_matches_entry(category, data, drop_profile):
			continue
		var chapter_data: Dictionary = ConfigDB.get_chapter(String(node_data.get("chapter_id", "")))
		var chapter_order: int = int(chapter_data.get("order", 9999))
		var node_type: String = String(node_data.get("node_type", "normal"))
		var score: float = score_recommendation_node(category, data, drop_profile, chapter_order, current_chapter_order, selected_tags)
		var metrics: Dictionary = get_expectation_metrics(category, data, drop_profile, node_data, selected_tags)
		if score > best_score:
			best_score = score
			var node_name: String = ConfigDB.get_chapter_node_name(node_id)
			var node_type_label: String = ConfigDB.get_node_type_display_name(node_type)
			best_entry = {
				"node_id": node_id,
				"chapter_id": String(node_data.get("chapter_id", "")),
				"label": "%s - %s (%s)" % [
					String(chapter_data.get("name", "")),
					node_name,
					node_type_label,
				],
				"short_label": "%s/%s" % [
					String(chapter_data.get("name", "")),
					node_name,
				],
				"reason": build_recommendation_reason(drop_profile, chapter_order, current_chapter_order, score),
				"expectation_text": build_expectation_text(category, data, drop_profile, node_data, selected_tags),
				"expected_per_clear": float(metrics.get("expected_per_clear", 0.0)),
				"expected_clears_per_hit": float(metrics.get("expected_clears_per_hit", 0.0)),
				"expected_minutes_per_hit": float(metrics.get("expected_minutes_per_hit", 0.0)),
				"score": score,
			}
	return best_entry


static func build_expectation_text(category: String, data: Dictionary, drop_profile: Dictionary, node_data: Dictionary, selected_tags: Array) -> String:
	var metrics: Dictionary = get_expectation_metrics(category, data, drop_profile, node_data, selected_tags)
	if metrics.is_empty():
		return "暂无法估算"
	return "单次期望 %.3f | 约 %.1f 次结算见 1 次 | 按时限约 %.1f 分钟" % [
		float(metrics.get("expected_per_clear", 0.0)),
		float(metrics.get("expected_clears_per_hit", 0.0)),
		float(metrics.get("expected_minutes_per_hit", 0.0)),
	]


static func get_expectation_metrics(category: String, data: Dictionary, drop_profile: Dictionary, node_data: Dictionary, selected_tags: Array) -> Dictionary:
	var expected_items_per_clear: float = float(drop_profile.get("equipment_rolls", 1)) * float(drop_profile.get("equipment_chance", 0.0))
	if expected_items_per_clear <= 0.0:
		return {}

	var equipment_rules: Dictionary = drop_profile.get("equipment_rules", {})
	var effective_tags: Array = selected_tags if bool(equipment_rules.get("prefer_current_build", false)) else []
	var base_distribution: Array = get_base_distribution(drop_profile, effective_tags)
	if base_distribution.is_empty():
		return {}

	var per_item_probability: float = 0.0
	match category:
		"base":
			per_item_probability = estimate_base_probability_per_item(String(data.get("id", "")), base_distribution)
		"affix":
			per_item_probability = estimate_affix_probability_per_item(data, drop_profile, base_distribution, effective_tags)
		_:
			per_item_probability = estimate_legendary_probability_per_item(data, drop_profile, base_distribution, effective_tags)

	if per_item_probability <= 0.0:
		return {}

	var expected_per_clear: float = expected_items_per_clear * per_item_probability
	var expected_clears_per_hit: float = 1.0 / expected_per_clear
	var time_limit_seconds: float = float(node_data.get("time_limit", 60))
	var expected_minutes_per_hit: float = (expected_clears_per_hit * time_limit_seconds) / 60.0
	return {
		"expected_per_clear": expected_per_clear,
		"expected_clears_per_hit": expected_clears_per_hit,
		"expected_minutes_per_hit": expected_minutes_per_hit,
	}


static func profile_matches_entry(category: String, data: Dictionary, drop_profile: Dictionary) -> bool:
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
			return profile_can_drop_legendary(drop_profile, source_types)


static func score_recommendation_node(
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
		for tag_variant in selected_tags:
			var tag: String = String(tag_variant)
			if base_tags.has(tag):
				score += 12.0
	elif category == "affix":
		for tag_variant in selected_tags:
			var tag: String = String(tag_variant)
			if data.get("archetype_tags", []).has(tag):
				score += 15.0
	elif category == "legendary":
		for tag_variant in selected_tags:
			var tag: String = String(tag_variant)
			if data.get("archetype_tags", []).has(tag):
				score += 20.0
	return score


static func build_recommendation_reason(drop_profile: Dictionary, chapter_order: int, current_chapter_order: int, score: float) -> String:
	var state_text: String = "当前可刷" if chapter_order <= current_chapter_order else "后续章节"
	return "%s，装备轮次 %d，掉装概率 %.0f%%，评分 %.1f，方向：%s" % [
		state_text,
		int(drop_profile.get("equipment_rolls", 1)),
		float(drop_profile.get("equipment_chance", 0.0)) * 100.0,
		score,
		String(drop_profile.get("drop_focus", "常规掉落")),
	]


static func get_base_distribution(drop_profile: Dictionary, selected_tags: Array) -> Array:
	var equipment_rules: Dictionary = drop_profile.get("equipment_rules", {})
	var item_level_min: int = int(equipment_rules.get("item_level_min", 1))
	var item_level_max: int = int(equipment_rules.get("item_level_max", item_level_min))
	var candidates: Array = []
	var total_weight: float = 0.0
	for entry_variant in ConfigDB.get_all_equipment_bases():
		var base_entry: Dictionary = entry_variant
		var entry_level: int = int(base_entry.get("item_level", 1))
		if entry_level < item_level_min or entry_level > item_level_max:
			continue
		var weight: float = get_base_weight(base_entry, selected_tags)
		total_weight += weight
		candidates.append({"base": base_entry, "weight": weight})
	if total_weight <= 0.0:
		return []
	for candidate_variant in candidates:
		var candidate: Dictionary = candidate_variant
		candidate["probability"] = float(candidate.get("weight", 0.0)) / total_weight
	return candidates


static func estimate_base_probability_per_item(base_id: String, base_distribution: Array) -> float:
	for candidate_variant in base_distribution:
		var candidate: Dictionary = candidate_variant
		var base_entry: Dictionary = candidate.get("base", {})
		if String(base_entry.get("id", "")) == base_id:
			return float(candidate.get("probability", 0.0))
	return 0.0


static func estimate_affix_probability_per_item(target_affix: Dictionary, drop_profile: Dictionary, base_distribution: Array, selected_tags: Array) -> float:
	var profile_type: String = String(drop_profile.get("profile_type", "normal"))
	var expected_probability: float = 0.0
	for candidate_variant in base_distribution:
		var candidate: Dictionary = candidate_variant
		var base_entry: Dictionary = candidate.get("base", {})
		var probability: float = float(candidate.get("probability", 0.0))
		var slot: String = String(base_entry.get("slot", ""))
		if not target_affix.get("slot_tags", []).has(slot):
			continue
		if not affix_matches_base(target_affix, base_entry, profile_type):
			continue
		var candidates: Array = get_affix_candidates_for_base(base_entry, profile_type)
		if candidates.is_empty():
			continue
		var target_weight: float = get_affix_weight(target_affix, selected_tags)
		var total_weight: float = 0.0
		for affix_variant in candidates:
			var affix: Dictionary = affix_variant
			total_weight += get_affix_weight(affix, selected_tags)
		if total_weight <= 0.0:
			continue
		var single_roll_probability: float = target_weight / total_weight
		var expected_hit_probability: float = get_expected_affix_hit_probability(drop_profile, single_roll_probability)
		expected_probability += probability * expected_hit_probability
	return clampf(expected_probability, 0.0, 1.0)


static func estimate_legendary_probability_per_item(target_legendary: Dictionary, drop_profile: Dictionary, base_distribution: Array, selected_tags: Array) -> float:
	var equipment_rules: Dictionary = drop_profile.get("equipment_rules", {})
	var profile_type: String = String(drop_profile.get("profile_type", "normal"))
	var rarity_gate_probability: float = get_legendary_rarity_gate_probability(drop_profile)
	var expected_probability: float = 0.0
	for candidate_variant in base_distribution:
		var candidate: Dictionary = candidate_variant
		var base_entry: Dictionary = candidate.get("base", {})
		var probability: float = float(candidate.get("probability", 0.0))
		var slot: String = String(base_entry.get("slot", ""))
		if not target_legendary.get("slot_tags", []).has(slot):
			continue
		var candidates: Array = get_legendary_candidates_for_base(
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


static func get_expected_affix_hit_probability(drop_profile: Dictionary, single_roll_probability: float) -> float:
	var rarity_affix_counts: Dictionary = {"common": 1, "uncommon": 2, "rare": 3, "epic": 4, "set": 4, "legendary": 5, "ancient": 6, "primal": 6}
	var rarity_probabilities: Dictionary = get_allowed_rarity_probabilities(drop_profile)
	var expected_probability: float = 0.0
	for rarity_key_variant in rarity_probabilities.keys():
		var rarity_key: String = String(rarity_key_variant)
		var rarity_probability: float = float(rarity_probabilities.get(rarity_key_variant, 0.0))
		var affix_count: int = int(rarity_affix_counts.get(rarity_key, 1))
		expected_probability += rarity_probability * (1.0 - pow(1.0 - single_roll_probability, affix_count))
	return clampf(expected_probability, 0.0, 1.0)


static func get_allowed_rarity_probabilities(drop_profile: Dictionary) -> Dictionary:
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
		"primal": 0.05,
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


static func get_legendary_rarity_gate_probability(drop_profile: Dictionary) -> float:
	var equipment_rules: Dictionary = drop_profile.get("equipment_rules", {})
	if bool(equipment_rules.get("guaranteed_legendary_affix", false)):
		return 1.0
	var rarity_probabilities: Dictionary = get_allowed_rarity_probabilities(drop_profile)
	return float(rarity_probabilities.get("legendary", 0.0)) + float(rarity_probabilities.get("ancient", 0.0)) + float(rarity_probabilities.get("primal", 0.0))


static func get_base_weight(base_entry: Dictionary, selected_tags: Array) -> float:
	var weight: float = 1.0
	for tag_variant in selected_tags:
		var tag: String = String(tag_variant)
		if base_entry.get("affix_pool_tags", []).has(tag):
			weight += 2.0
		if base_entry.get("legendary_pool_tags", []).has(tag):
			weight += 2.0
	return weight


static func get_affix_candidates_for_base(base_entry: Dictionary, profile_type: String) -> Array:
	var candidates: Array = []
	var slot: String = String(base_entry.get("slot", ""))
	for entry_variant in ConfigDB.get_all_affixes():
		var affix: Dictionary = entry_variant
		if not affix.get("slot_tags", []).has(slot):
			continue
		var source_profile_types: Array = affix.get("source_profile_types", [])
		if not source_profile_types.is_empty() and not source_profile_types.has(profile_type):
			continue
		if affix_matches_base(affix, base_entry, profile_type):
			candidates.append(affix)
	return candidates


static func affix_matches_base(affix: Dictionary, base_entry: Dictionary, profile_type: String) -> bool:
	var source_profile_types: Array = affix.get("source_profile_types", [])
	if not source_profile_types.is_empty() and not source_profile_types.has(profile_type):
		return false
	var archetype_tags: Array = affix.get("archetype_tags", [])
	if archetype_tags.is_empty():
		return true
	for tag_variant in base_entry.get("affix_pool_tags", []):
		var tag: String = String(tag_variant)
		if archetype_tags.has(tag):
			return true
	return false


static func get_affix_weight(affix: Dictionary, selected_tags: Array) -> float:
	var weight: float = float(affix.get("rarity_weight", 1))
	for tag_variant in selected_tags:
		var tag: String = String(tag_variant)
		if affix.get("archetype_tags", []).has(tag):
			weight += weight * 0.7
	return weight


static func get_legendary_candidates_for_base(base_entry: Dictionary, profile_type: String, selected_tags: Array, required_source_type: String) -> Array:
	var candidates: Array = []
	var slot: String = String(base_entry.get("slot", ""))
	for entry_variant in ConfigDB.get_all_legendary_affixes():
		var affix: Dictionary = entry_variant
		if not affix.get("slot_tags", []).has(slot):
			continue
		var source_profile_types: Array = affix.get("source_profile_types", [])
		if not required_source_type.is_empty():
			if source_profile_types.is_empty() or not source_profile_types.has(required_source_type):
				continue
		elif not source_profile_types.is_empty() and not source_profile_types.has(profile_type):
			continue
		var tag_matches: bool = affix.get("archetype_tags", []).is_empty()
		for tag_variant in base_entry.get("legendary_pool_tags", []):
			var base_tag: String = String(tag_variant)
			if affix.get("archetype_tags", []).has(base_tag):
				tag_matches = true
				break
		for tag_variant in selected_tags:
			var selected_tag: String = String(tag_variant)
			if affix.get("archetype_tags", []).has(selected_tag):
				tag_matches = true
				break
		if tag_matches:
			candidates.append(affix)
	return candidates


static func profile_can_drop_legendary(drop_profile: Dictionary, source_profile_types: Array) -> bool:
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


static func build_rate_comparison_text(label: String, expected_rate: float, actual_rate: float) -> String:
	if expected_rate <= 0.0:
		if actual_rate <= 0.0:
			return "%s理论 -- / 实测 -- / 无偏差" % label
		return "%s理论 -- / 实测 %.3f / 超出理论池" % [label, actual_rate]
	var delta_ratio: float = (actual_rate - expected_rate) / expected_rate
	return "%s理论 %.3f / 实测 %.3f / 偏差 %s / %s" % [
		label,
		expected_rate,
		actual_rate,
		_format_signed_percent(delta_ratio),
		_get_deviation_state_label(delta_ratio),
	]


static func build_visual_rate_entry(label: String, expected_rate: float, actual_rate: float, sample_count: int) -> Dictionary:
	var delta_ratio: float = 0.0
	var bar_value: float = 0.0
	var state_label: String = "暂无样本"
	if expected_rate > 0.0:
		delta_ratio = (actual_rate - expected_rate) / expected_rate
		bar_value = clampf((actual_rate / expected_rate) * 100.0, 0.0, 200.0)
		state_label = _get_deviation_state_label(delta_ratio)
	elif actual_rate > 0.0:
		bar_value = 200.0
		state_label = "超出理论池"
	return {
		"label": label,
		"expected_rate": expected_rate,
		"actual_rate": actual_rate,
		"delta_ratio": delta_ratio,
		"bar_value": bar_value,
		"sample_count": sample_count,
		"state_label": state_label,
		"delta_text": _format_signed_percent(delta_ratio),
	}


static func is_manual_decision_item(item: Dictionary) -> bool:
	if item.is_empty():
		return false
	if not item.get("legendary_affix", {}).is_empty():
		return true
	if not String(item.get("set_id", "")).is_empty():
		return true
	var rarity: String = String(item.get("rarity", "common"))
	return GameManager.get_rarity_rank(rarity) >= GameManager.get_rarity_rank("epic")


static func should_auto_equip_item(candidate_item: Dictionary, equipped_item: Dictionary) -> bool:
	if candidate_item.is_empty() or is_manual_decision_item(candidate_item):
		return false
	if equipped_item.is_empty():
		return true
	return float(candidate_item.get("score", 0.0)) > float(equipped_item.get("score", 0.0))


static func should_auto_salvage_item(item: Dictionary, auto_salvage_below_rarity: String) -> bool:
	if item.is_empty() or is_manual_decision_item(item):
		return false
	var rarity: String = String(item.get("rarity", "common"))
	return GameManager.get_rarity_rank(rarity) < GameManager.get_rarity_rank(auto_salvage_below_rarity)


static func _get_deviation_state_label(delta_ratio: float) -> String:
	if delta_ratio >= 0.25:
		return "明显高于期望"
	if delta_ratio >= 0.08:
		return "略高于期望"
	if delta_ratio <= -0.25:
		return "明显低于期望"
	if delta_ratio <= -0.08:
		return "略低于期望"
	return "接近期望"


static func _format_signed_percent(value: float) -> String:
	var percent: float = value * 100.0
	if percent >= 0.0:
		return "+%.0f%%" % percent
	return "%.0f%%" % percent
