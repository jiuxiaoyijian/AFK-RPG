extends Node

const RARITY_AFFIX_COUNTS := {
	"common": 1,
	"uncommon": 2,
	"rare": 3,
	"epic": 4,
	"set": 4,
	"legendary": 5,
	"ancient": 6,
}


func generate_equipment_for_profile(drop_profile: Dictionary) -> Dictionary:
	var equipment_rules: Dictionary = drop_profile.get("equipment_rules", {})
	var allowed_rarities: Array = equipment_rules.get("allowed_rarities", [])
	var item_level_min: int = int(equipment_rules.get("item_level_min", 1))
	var item_level_max: int = int(equipment_rules.get("item_level_max", item_level_min))
	var prefer_current_build: bool = bool(equipment_rules.get("prefer_current_build", false))
	var guaranteed_legendary_affix: bool = bool(equipment_rules.get("guaranteed_legendary_affix", false))
	var legendary_source_type: String = String(equipment_rules.get("required_legendary_source_type", ""))
	var profile_type: String = String(drop_profile.get("profile_type", "normal"))

	var selected_tags: Array = GameManager.get_selected_archetype_tags() if prefer_current_build else []
	var base_candidates: Array = []
	for entry in ConfigDB.get_all_equipment_bases():
		var base_entry: Dictionary = entry
		var entry_level: int = int(base_entry.get("item_level", 1))
		if entry_level >= item_level_min and entry_level <= item_level_max:
			base_candidates.append(base_entry)

	if base_candidates.is_empty():
		return {}

	var base_pick: Dictionary = _pick_base(base_candidates, selected_tags)
	var generated_rarity: String = _pick_rarity(allowed_rarities)
	var item_level: int = randi_range(item_level_min, item_level_max)
	var is_primal: bool = generated_rarity == "ancient"
	var affix_count: int = RARITY_AFFIX_COUNTS.get(generated_rarity, 1)

	var item: Dictionary = {
		"id": "%s_%d" % [String(base_pick.get("id", "item")), Time.get_ticks_msec()],
		"base_id": String(base_pick.get("id", "")),
		"slot": String(base_pick.get("slot", "")),
		"name": String(base_pick.get("name", "装备")),
		"rarity": generated_rarity,
		"item_level": item_level,
		"base_stats": [],
		"affixes": [],
		"legendary_affix": {},
		"score": 0.0,
	}

	for stat_entry in base_pick.get("base_stats", []):
		var cloned: Dictionary = {
			"stat_key": String(stat_entry.get("stat_key", "")),
			"value": float(stat_entry.get("value", 0.0)) + item_level * 0.5,
		}
		item["base_stats"].append(cloned)

	var used_affix_ids: Array[String] = []
	var used_buckets: Array[String] = []
	for _i in affix_count:
		var affix: Dictionary = _pick_affix(
			String(base_pick.get("slot", "")),
			base_pick.get("affix_pool_tags", []),
			selected_tags,
			profile_type,
			used_affix_ids,
			used_buckets
		)
		if affix.is_empty():
			continue
		used_affix_ids.append(String(affix.get("id", "")))
		var bucket: String = String(affix.get("bucket", ""))
		if not bucket.is_empty():
			used_buckets.append(bucket)
		item["affixes"].append({
			"affix_id": String(affix.get("id", "")),
			"name": String(affix.get("name", "")),
			"stat_key": String(affix.get("stat_key", "")),
			"bucket": bucket,
			"value": _roll_affix_value(affix) if not is_primal else float(affix.get("value_max", 0.0)),
			"score_weight": float(affix.get("score_weight", 1.0)),
			"archetype_tags": affix.get("archetype_tags", []),
		})

	if guaranteed_legendary_affix or GameManager.get_rarity_rank(generated_rarity) >= GameManager.get_rarity_rank("legendary"):
		var legendary_affix: Dictionary = _pick_legendary_affix(
			String(base_pick.get("slot", "")),
			base_pick.get("legendary_pool_tags", []),
			selected_tags,
			profile_type,
			legendary_source_type
		)
		if not legendary_affix.is_empty():
			item["legendary_affix"] = {
				"legendary_affix_id": String(legendary_affix.get("id", "")),
				"name": String(legendary_affix.get("name", "")),
				"description": String(legendary_affix.get("description", "")),
				"archetype_tags": legendary_affix.get("archetype_tags", []),
				"stat_key": String(legendary_affix.get("stat_key", "")),
				"value": _roll_legendary_value(legendary_affix, "value_min", "value_max") if not is_primal else float(legendary_affix.get("value_max", 0.0)),
				"secondary_stat_key": String(legendary_affix.get("secondary_stat_key", "")),
				"secondary_value": _roll_legendary_value(legendary_affix, "secondary_value_min", "secondary_value_max") if not is_primal else float(legendary_affix.get("secondary_value_max", 0.0)),
			}

	item["score"] = _calculate_item_score(item)
	return item


func generate_debug_item(
	base_id: String,
	rarity: String = "rare",
	item_level: int = -1,
	prefer_current_build: bool = true,
	force_legendary: bool = false
) -> Dictionary:
	var base_pick: Dictionary = ConfigDB.equipment_bases.get(base_id, {})
	if base_pick.is_empty():
		return {}

	var selected_tags: Array = GameManager.get_selected_archetype_tags() if prefer_current_build else []
	var resolved_item_level: int = item_level if item_level > 0 else int(base_pick.get("item_level", 1))
	var generated_rarity: String = rarity if GameManager.get_rarity_rank(rarity) > 0 else "rare"
	var is_primal: bool = generated_rarity == "ancient"
	var affix_count: int = RARITY_AFFIX_COUNTS.get(generated_rarity, 2)

	var item: Dictionary = {
		"id": "%s_debug_%d" % [String(base_pick.get("id", "item")), Time.get_ticks_usec()],
		"base_id": String(base_pick.get("id", "")),
		"slot": String(base_pick.get("slot", "")),
		"name": String(base_pick.get("name", "装备")),
		"rarity": generated_rarity,
		"item_level": resolved_item_level,
		"base_stats": [],
		"affixes": [],
		"legendary_affix": {},
		"score": 0.0,
	}

	for stat_entry in base_pick.get("base_stats", []):
		item["base_stats"].append({
			"stat_key": String(stat_entry.get("stat_key", "")),
			"value": float(stat_entry.get("value", 0.0)) + resolved_item_level * 0.5,
		})

	var used_affix_ids: Array[String] = []
	var used_buckets: Array[String] = []
	for _i in affix_count:
		var affix: Dictionary = _pick_affix(
			String(base_pick.get("slot", "")),
			base_pick.get("affix_pool_tags", []),
			selected_tags,
			"boss",
			used_affix_ids,
			used_buckets
		)
		if affix.is_empty():
			continue
		used_affix_ids.append(String(affix.get("id", "")))
		var bucket: String = String(affix.get("bucket", ""))
		if not bucket.is_empty():
			used_buckets.append(bucket)
		item["affixes"].append({
			"affix_id": String(affix.get("id", "")),
			"name": String(affix.get("name", "")),
			"stat_key": String(affix.get("stat_key", "")),
			"bucket": bucket,
			"value": _roll_affix_value(affix) if not is_primal else float(affix.get("value_max", 0.0)),
			"score_weight": float(affix.get("score_weight", 1.0)),
			"archetype_tags": affix.get("archetype_tags", []),
		})

	if force_legendary or GameManager.get_rarity_rank(generated_rarity) >= GameManager.get_rarity_rank("legendary"):
		var legendary_affix: Dictionary = _pick_legendary_affix(
			String(base_pick.get("slot", "")),
			base_pick.get("legendary_pool_tags", []),
			selected_tags,
			"boss",
			""
		)
		if not legendary_affix.is_empty():
			item["legendary_affix"] = {
				"legendary_affix_id": String(legendary_affix.get("id", "")),
				"name": String(legendary_affix.get("name", "")),
				"description": String(legendary_affix.get("description", "")),
				"archetype_tags": legendary_affix.get("archetype_tags", []),
				"stat_key": String(legendary_affix.get("stat_key", "")),
				"value": _roll_legendary_value(legendary_affix, "value_min", "value_max") if not is_primal else float(legendary_affix.get("value_max", 0.0)),
				"secondary_stat_key": String(legendary_affix.get("secondary_stat_key", "")),
				"secondary_value": _roll_legendary_value(legendary_affix, "secondary_value_min", "secondary_value_max") if not is_primal else float(legendary_affix.get("secondary_value_max", 0.0)),
			}

	item["score"] = _calculate_item_score(item)
	return item


func _pick_base(base_candidates: Array, selected_tags: Array) -> Dictionary:
	var weighted_pool: Array = []
	for entry in base_candidates:
		var base_entry: Dictionary = entry
		var weight: int = 1
		for tag in selected_tags:
			if base_entry.get("affix_pool_tags", []).has(tag):
				weight += 2
			if base_entry.get("legendary_pool_tags", []).has(tag):
				weight += 2
		for _i in range(weight):
			weighted_pool.append(base_entry)
	if weighted_pool.is_empty():
		return base_candidates[randi() % base_candidates.size()]
	return weighted_pool[randi() % weighted_pool.size()]


func _pick_rarity(allowed_rarities: Array) -> String:
	if allowed_rarities.is_empty():
		return "common"

	var weights: Dictionary = {
		"common": 50,
		"uncommon": 30,
		"rare": 14,
		"epic": 4,
		"set": 1,
		"legendary": 1,
		"ancient": 0,
	}
	var total_weight: int = 0
	for rarity in allowed_rarities:
		total_weight += int(weights.get(String(rarity), 1))

	if total_weight <= 0:
		return String(allowed_rarities[0])

	var roll: int = randi_range(1, total_weight)
	var current: int = 0
	for rarity in allowed_rarities:
		current += int(weights.get(String(rarity), 1))
		if roll <= current:
			return String(rarity)

	return String(allowed_rarities[0])


func _pick_affix(slot: String, pool_tags: Array, selected_tags: Array, profile_type: String, excluded_ids: Array[String], excluded_buckets: Array[String]) -> Dictionary:
	var candidates: Array = []
	for entry in ConfigDB.get_all_affixes():
		var affix: Dictionary = entry
		var affix_id: String = String(affix.get("id", ""))
		if excluded_ids.has(affix_id):
			continue
		var bucket: String = String(affix.get("bucket", ""))
		if not bucket.is_empty() and excluded_buckets.has(bucket):
			continue
		var slot_tags: Array = affix.get("slot_tags", [])
		if not slot_tags.has(slot) and not (slot.begins_with("accessory") and slot_tags.has("accessory")):
			continue
		var source_profile_types: Array = affix.get("source_profile_types", [])
		if not source_profile_types.is_empty() and not source_profile_types.has(profile_type):
			continue
		var archetype_tags: Array = affix.get("archetype_tags", [])
		if not archetype_tags.is_empty():
			var matched: bool = false
			for tag in pool_tags:
				if archetype_tags.has(tag):
					matched = true
					break
			if not matched:
				continue
		candidates.append(affix)

	if candidates.is_empty():
		for entry in ConfigDB.get_all_affixes():
			var fallback_affix: Dictionary = entry
			var fallback_id: String = String(fallback_affix.get("id", ""))
			if excluded_ids.has(fallback_id):
				continue
			var fb_bucket: String = String(fallback_affix.get("bucket", ""))
			if not fb_bucket.is_empty() and excluded_buckets.has(fb_bucket):
				continue
			var source_profile_types: Array = fallback_affix.get("source_profile_types", [])
			if not source_profile_types.is_empty() and not source_profile_types.has(profile_type):
				continue
			var slot_tags: Array = fallback_affix.get("slot_tags", [])
			if slot_tags.has(slot) or (slot.begins_with("accessory") and slot_tags.has("accessory")):
				candidates.append(fallback_affix)

	if candidates.is_empty():
		return {}

	var total_weight: int = 0
	for affix in candidates:
		var weight: int = int(affix.get("rarity_weight", 1))
		for tag in selected_tags:
			if affix.get("archetype_tags", []).has(tag):
				weight += int(weight * 0.7)
		total_weight += weight

	var roll: int = randi_range(1, total_weight)
	var current: int = 0
	for affix in candidates:
		var weight: int = int(affix.get("rarity_weight", 1))
		for tag in selected_tags:
			if affix.get("archetype_tags", []).has(tag):
				weight += int(weight * 0.7)
		current += weight
		if roll <= current:
			return affix

	return candidates[0]


func _pick_legendary_affix(
	slot: String,
	pool_tags: Array,
	selected_tags: Array,
	profile_type: String,
	required_source_type: String
) -> Dictionary:
	var candidates: Array = []
	for entry in ConfigDB.get_all_legendary_affixes():
		var affix: Dictionary = entry
		var slot_tags: Array = affix.get("slot_tags", [])
		if not slot_tags.has(slot) and not (slot.begins_with("accessory") and slot_tags.has("accessory")):
			continue
		var source_profile_types: Array = affix.get("source_profile_types", [])
		if not required_source_type.is_empty():
			if source_profile_types.is_empty() or not source_profile_types.has(required_source_type):
				continue
		elif not source_profile_types.is_empty() and not source_profile_types.has(profile_type):
			continue
		var tag_matches: bool = affix.get("archetype_tags", []).is_empty()
		for tag in pool_tags:
			if affix.get("archetype_tags", []).has(tag):
				tag_matches = true
				break
		for tag in selected_tags:
			if affix.get("archetype_tags", []).has(tag):
				tag_matches = true
				break
		if tag_matches:
			candidates.append(affix)

	if candidates.is_empty():
		return {}

	var total_weight: int = 0
	for affix in candidates:
		total_weight += int(affix.get("drop_weight", 1))
	var roll: int = randi_range(1, total_weight)
	var current: int = 0
	for affix in candidates:
		current += int(affix.get("drop_weight", 1))
		if roll <= current:
			return affix
	return candidates[0]


func _roll_affix_value(affix: Dictionary) -> float:
	var min_value: float = float(affix.get("value_min", 0.0))
	var max_value: float = float(affix.get("value_max", min_value))
	return snappedf(randf_range(min_value, max_value), 0.01)


func _roll_legendary_value(affix: Dictionary, min_key: String, max_key: String) -> float:
	var min_value: float = float(affix.get(min_key, 0.0))
	var max_value: float = float(affix.get(max_key, min_value))
	return snappedf(randf_range(min_value, max_value), 0.01)


func _calculate_item_score(item: Dictionary) -> float:
	var selected_tags: Array = GameManager.get_selected_archetype_tags()
	var score: float = float(item.get("item_level", 1)) * 10.0
	score += GameManager.get_rarity_rank(String(item.get("rarity", "common"))) * 15.0

	var bucket_bonus: Dictionary = {
		"primary_stat": 3.0,
		"crit": 12.0,
		"skill_damage": 10.0,
		"elemental": 10.0,
		"defense": 2.0,
		"utility": 5.0,
		"elite": 14.0,
	}

	for stat_entry in item.get("base_stats", []):
		score += absf(float(stat_entry.get("value", 0.0))) * 2.0
	for affix_entry in item.get("affixes", []):
		var bucket: String = String(affix_entry.get("bucket", ""))
		var bucket_mult: float = bucket_bonus.get(bucket, 6.0)
		score += absf(float(affix_entry.get("value", 0.0))) * bucket_mult * float(affix_entry.get("score_weight", 1.0))
		for tag in selected_tags:
			if affix_entry.get("archetype_tags", []).has(tag):
				score += 20.0
	if not item.get("legendary_affix", {}).is_empty():
		var legendary_affix: Dictionary = item.get("legendary_affix", {})
		score += absf(float(legendary_affix.get("value", 0.0))) * 14.0
		score += absf(float(legendary_affix.get("secondary_value", 0.0))) * 10.0
		for tag in selected_tags:
			if legendary_affix.get("archetype_tags", []).has(tag):
				score += 35.0

	return score
