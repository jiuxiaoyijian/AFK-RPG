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
const ARCHETYPE_SET_IDS := {
	"whirlwind": "set_wind",
	"bleed": "set_blood",
	"chain_lightning": "set_thunder",
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
	var generated_rarity: String = _pick_rarity(allowed_rarities)
	var item_level: int = randi_range(item_level_min, item_level_max)
	var base_candidates: Array = _get_base_candidates_by_level(item_level_min, item_level_max)
	if base_candidates.is_empty():
		return {}

	var set_data: Dictionary = {}
	if generated_rarity == "set":
		set_data = _pick_set_definition(selected_tags)
		base_candidates = _get_set_base_candidates(set_data, item_level_min, item_level_max)
		if base_candidates.is_empty():
			return {}

	var base_pick: Dictionary = _pick_base(base_candidates, selected_tags)
	var item: Dictionary = _build_item_from_base(
		base_pick,
		generated_rarity,
		item_level,
		selected_tags,
		profile_type,
		guaranteed_legendary_affix,
		legendary_source_type
	)
	if generated_rarity == "set":
		_apply_set_data(item, set_data)
	item["score"] = _calculate_item_score(item)
	return item


func generate_debug_item(
	base_id: String,
	rarity: String = "rare",
	item_level: int = -1,
	prefer_current_build: bool = true,
	force_legendary: bool = false
) -> Dictionary:
	var base_pick: Dictionary = _get_base_entry(base_id)
	if base_pick.is_empty():
		return {}

	var selected_tags: Array = GameManager.get_selected_archetype_tags() if prefer_current_build else []
	var resolved_item_level: int = item_level if item_level > 0 else int(base_pick.get("item_level", 1))
	var generated_rarity: String = rarity if GameManager.get_rarity_rank(rarity) > 0 else "rare"
	var item: Dictionary = _build_item_from_base(
		base_pick,
		generated_rarity,
		resolved_item_level,
		selected_tags,
		"boss",
		force_legendary,
		""
	)
	if generated_rarity == "set":
		var set_data: Dictionary = _pick_set_definition_for_slot(String(base_pick.get("slot", "")), selected_tags)
		if not set_data.is_empty():
			_apply_set_data(item, set_data)
	item["score"] = _calculate_item_score(item)
	return item


func upgrade_rare_item(item: Dictionary) -> Dictionary:
	if String(item.get("rarity", "")) != "rare":
		return {}
	var base_pick: Dictionary = _get_base_entry(String(item.get("base_id", "")))
	if base_pick.is_empty():
		return {}
	var selected_tags: Array = GameManager.get_selected_archetype_tags()
	var upgraded: Dictionary = _build_item_shell(base_pick, "epic", int(item.get("item_level", 1)))
	_copy_item_identity(item, upgraded)
	_populate_affixes(
		upgraded,
		base_pick,
		selected_tags,
		"normal",
		_build_locked_affix_map(item.get("affixes", [])),
		RARITY_AFFIX_COUNTS["epic"]
	)
	upgraded["legendary_affix"] = _roll_best_legendary_affix(base_pick, selected_tags, "normal", "", "epic")
	upgraded["score"] = _calculate_item_score(upgraded)
	return upgraded


func reforge_item(item: Dictionary) -> Dictionary:
	var rarity: String = String(item.get("rarity", "common"))
	if GameManager.get_rarity_rank(rarity) < GameManager.get_rarity_rank("epic"):
		return {}
	var base_pick: Dictionary = _get_base_entry(String(item.get("base_id", "")))
	if base_pick.is_empty():
		return {}
	var selected_tags: Array = GameManager.get_selected_archetype_tags()
	var reforged: Dictionary = _build_item_shell(base_pick, rarity, int(item.get("item_level", 1)))
	_copy_item_identity(item, reforged)
	if not String(item.get("set_id", "")).is_empty():
		reforged["set_id"] = String(item.get("set_id", ""))
		reforged["set_name"] = String(item.get("set_name", ""))
	_populate_affixes(reforged, base_pick, selected_tags, "normal", {}, RARITY_AFFIX_COUNTS.get(rarity, 1))
	reforged["legendary_affix"] = _roll_best_legendary_affix(base_pick, selected_tags, "normal", "", rarity)
	reforged.erase("refine_slot_index")
	reforged.erase("refine_count")
	reforged["score"] = _calculate_item_score(reforged)
	return reforged


func convert_set_item(item: Dictionary, target_slot: String) -> Dictionary:
	if String(item.get("rarity", "")) != "set":
		return {}
	var set_id: String = String(item.get("set_id", ""))
	var set_data: Dictionary = ConfigDB.get_set(set_id)
	if set_data.is_empty():
		return {}
	if target_slot.is_empty():
		return {}
	if _slots_compatible(String(item.get("slot", "")), target_slot):
		return {}
	var slot_candidates: Array = []
	for allowed_slot_variant in set_data.get("piece_slots", []):
		if _slots_compatible(String(allowed_slot_variant), target_slot):
			slot_candidates.append(allowed_slot_variant)
	if slot_candidates.is_empty():
		return {}

	var base_candidates: Array = _get_set_base_candidates(set_data, int(item.get("item_level", 1)), int(item.get("item_level", 1)), target_slot)
	if base_candidates.is_empty():
		return {}
	var selected_tags: Array = GameManager.get_selected_archetype_tags()
	var base_pick: Dictionary = _pick_base(base_candidates, selected_tags)
	var converted: Dictionary = _build_item_shell(base_pick, "set", int(item.get("item_level", 1)))
	_copy_item_identity(item, converted)
	_apply_set_data(converted, set_data)
	_populate_affixes(converted, base_pick, selected_tags, "normal", {}, RARITY_AFFIX_COUNTS["set"])
	converted["legendary_affix"] = _roll_best_legendary_affix(base_pick, selected_tags, "normal", "", "set")
	converted.erase("refine_slot_index")
	converted.erase("refine_count")
	converted["score"] = _calculate_item_score(converted)
	return converted


func refine_affix_item(item: Dictionary, affix_index: int) -> Dictionary:
	var rarity: String = String(item.get("rarity", "common"))
	if GameManager.get_rarity_rank(rarity) < GameManager.get_rarity_rank("epic"):
		return {}
	var current_affixes: Array = item.get("affixes", [])
	if current_affixes.is_empty():
		return {}
	var locked_index: int = int(item.get("refine_slot_index", affix_index))
	if locked_index < 0 or locked_index >= current_affixes.size():
		return {}
	if item.has("refine_slot_index") and locked_index != int(item.get("refine_slot_index", locked_index)):
		return {}
	var base_pick: Dictionary = _get_base_entry(String(item.get("base_id", "")))
	if base_pick.is_empty():
		return {}
	var selected_tags: Array = GameManager.get_selected_archetype_tags()
	var refined: Dictionary = item.duplicate(true)
	_copy_item_identity(item, refined)
	var locked_affixes: Dictionary = {}
	for index in range(current_affixes.size()):
		if index == locked_index:
			continue
		var current_affix: Dictionary = current_affixes[index]
		locked_affixes[index] = current_affix.duplicate(true)
	_populate_affixes(refined, base_pick, selected_tags, "normal", locked_affixes, current_affixes.size())
	refined["refine_slot_index"] = locked_index
	refined["refine_count"] = int(item.get("refine_count", 0)) + 1
	refined["score"] = _calculate_item_score(refined)
	return refined


func _get_base_candidates_by_level(item_level_min: int, item_level_max: int) -> Array:
	var base_candidates: Array = []
	for entry in ConfigDB.get_all_equipment_bases():
		var base_entry: Dictionary = entry
		var entry_level: int = int(base_entry.get("item_level", 1))
		if entry_level >= item_level_min and entry_level <= item_level_max:
			base_candidates.append(base_entry)
	return base_candidates


func _build_item_from_base(
	base_pick: Dictionary,
	rarity: String,
	item_level: int,
	selected_tags: Array,
	profile_type: String,
	guaranteed_legendary_affix: bool,
	legendary_source_type: String
) -> Dictionary:
	var item: Dictionary = _build_item_shell(base_pick, rarity, item_level)
	_populate_affixes(item, base_pick, selected_tags, profile_type, {}, RARITY_AFFIX_COUNTS.get(rarity, 1))
	if guaranteed_legendary_affix or rarity == "set" or GameManager.get_rarity_rank(rarity) >= GameManager.get_rarity_rank("legendary"):
		item["legendary_affix"] = _roll_best_legendary_affix(base_pick, selected_tags, profile_type, legendary_source_type, rarity)
	return item


func _build_item_shell(base_pick: Dictionary, rarity: String, item_level: int) -> Dictionary:
	var item: Dictionary = {
		"id": _generate_item_id(String(base_pick.get("id", "item"))),
		"base_id": String(base_pick.get("id", "")),
		"slot": String(base_pick.get("slot", "")),
		"name": String(base_pick.get("name", "装备")),
		"rarity": rarity,
		"item_level": item_level,
		"base_stats": [],
		"affixes": [],
		"legendary_affix": {},
		"score": 0.0,
	}
	for stat_entry_variant in base_pick.get("base_stats", []):
		var stat_entry: Dictionary = stat_entry_variant
		item["base_stats"].append({
			"stat_key": String(stat_entry.get("stat_key", "")),
			"value": float(stat_entry.get("value", 0.0)) + item_level * 0.5,
		})
	return item


func _copy_item_identity(source_item: Dictionary, target_item: Dictionary) -> void:
	target_item["id"] = _generate_item_id(String(target_item.get("base_id", "item")))
	target_item["is_locked"] = bool(source_item.get("is_locked", false))
	if source_item.has("set_id"):
		target_item["set_id"] = String(source_item.get("set_id", ""))
	if source_item.has("set_name"):
		target_item["set_name"] = String(source_item.get("set_name", ""))


func _apply_set_data(item: Dictionary, set_data: Dictionary) -> void:
	item["set_id"] = String(set_data.get("id", ""))
	item["set_name"] = String(set_data.get("name", ""))


func _populate_affixes(
	item: Dictionary,
	base_pick: Dictionary,
	selected_tags: Array,
	profile_type: String,
	locked_affixes: Dictionary,
	desired_affix_count: int
) -> void:
	var result_affixes: Array = []
	var used_affix_ids: Array[String] = []
	var used_buckets: Array[String] = []
	for index in range(desired_affix_count):
		if locked_affixes.has(index):
			var locked_affix: Dictionary = locked_affixes[index]
			result_affixes.append(locked_affix)
			used_affix_ids.append(String(locked_affix.get("affix_id", "")))
			var locked_bucket: String = String(locked_affix.get("bucket", ""))
			if not locked_bucket.is_empty():
				used_buckets.append(locked_bucket)
			continue
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
		result_affixes.append({
			"affix_id": String(affix.get("id", "")),
			"name": String(affix.get("name", "")),
			"stat_key": String(affix.get("stat_key", "")),
			"bucket": bucket,
			"value": _roll_affix_value(affix) if rarity_is_primal(String(item.get("rarity", ""))) == false else float(affix.get("value_max", 0.0)),
			"score_weight": float(affix.get("score_weight", 1.0)),
			"archetype_tags": affix.get("archetype_tags", []),
		})
	item["affixes"] = result_affixes


func rarity_is_primal(rarity: String) -> bool:
	return rarity == "ancient"


func _build_locked_affix_map(affixes: Array) -> Dictionary:
	var locked_affixes: Dictionary = {}
	for index in range(affixes.size()):
		var affix_data: Dictionary = affixes[index]
		locked_affixes[index] = affix_data.duplicate(true)
	return locked_affixes


func _roll_best_legendary_affix(base_pick: Dictionary, selected_tags: Array, profile_type: String, required_source_type: String, rarity: String) -> Dictionary:
	var is_primal: bool = rarity_is_primal(rarity)
	var legendary_affix: Dictionary = _pick_legendary_affix(
		String(base_pick.get("slot", "")),
		base_pick.get("legendary_pool_tags", []),
		selected_tags,
		profile_type,
		required_source_type
	)
	if legendary_affix.is_empty():
		legendary_affix = _pick_legendary_affix(
			String(base_pick.get("slot", "")),
			base_pick.get("legendary_pool_tags", []),
			selected_tags,
			"boss",
			""
		)
	if legendary_affix.is_empty():
		return {}
	return {
		"legendary_affix_id": String(legendary_affix.get("id", "")),
		"name": String(legendary_affix.get("name", "")),
		"description": String(legendary_affix.get("description", "")),
		"archetype_tags": legendary_affix.get("archetype_tags", []),
		"stat_key": String(legendary_affix.get("stat_key", "")),
		"value": _roll_legendary_value(legendary_affix, "value_min", "value_max") if not is_primal else float(legendary_affix.get("value_max", 0.0)),
		"secondary_stat_key": String(legendary_affix.get("secondary_stat_key", "")),
		"secondary_value": _roll_legendary_value(legendary_affix, "secondary_value_min", "secondary_value_max") if not is_primal else float(legendary_affix.get("secondary_value_max", 0.0)),
	}


func _pick_set_definition(selected_tags: Array) -> Dictionary:
	var candidate_sets: Array = ConfigDB.get_all_sets()
	if candidate_sets.is_empty():
		return {}
	var weighted_pool: Array = []
	var preferred_set_id: String = ""
	for tag_variant in selected_tags:
		var tag: String = String(tag_variant)
		if ARCHETYPE_SET_IDS.has(tag):
			preferred_set_id = String(ARCHETYPE_SET_IDS.get(tag, ""))
			break
	for set_variant in candidate_sets:
		var set_data: Dictionary = set_variant
		var copies: int = 1
		if String(set_data.get("id", "")) == preferred_set_id:
			copies = 4
		for _copy in range(copies):
			weighted_pool.append(set_data)
	return weighted_pool[randi() % weighted_pool.size()]


func _pick_set_definition_for_slot(slot: String, selected_tags: Array) -> Dictionary:
	var candidate_sets: Array = []
	for set_variant in ConfigDB.get_all_sets():
		var set_data: Dictionary = set_variant
		for set_slot_variant in set_data.get("piece_slots", []):
			if _slots_compatible(String(set_slot_variant), slot):
				candidate_sets.append(set_data)
				break
	if candidate_sets.is_empty():
		return {}
	var preferred_set_id: String = ""
	for tag_variant in selected_tags:
		var tag: String = String(tag_variant)
		if ARCHETYPE_SET_IDS.has(tag):
			preferred_set_id = String(ARCHETYPE_SET_IDS.get(tag, ""))
			break
	for set_data_variant in candidate_sets:
		var set_data: Dictionary = set_data_variant
		if String(set_data.get("id", "")) == preferred_set_id:
			return set_data
	return candidate_sets[randi() % candidate_sets.size()]


func _get_set_base_candidates(set_data: Dictionary, item_level_min: int, item_level_max: int, target_slot: String = "") -> Array:
	var candidates: Array = []
	if set_data.is_empty():
		return candidates
	for entry in ConfigDB.get_all_equipment_bases():
		var base_entry: Dictionary = entry
		var entry_level: int = int(base_entry.get("item_level", 1))
		if entry_level < item_level_min or entry_level > item_level_max:
			continue
		var base_slot: String = String(base_entry.get("slot", ""))
		var matches_set: bool = false
		for piece_slot_variant in set_data.get("piece_slots", []):
			if _slots_compatible(base_slot, String(piece_slot_variant)):
				matches_set = true
				break
		if not matches_set:
			continue
		if not target_slot.is_empty() and not _slots_compatible(base_slot, target_slot):
			continue
		candidates.append(base_entry)
	return candidates


func _get_base_entry(base_id: String) -> Dictionary:
	return ConfigDB.equipment_bases.get(base_id, {})


func _generate_item_id(base_id: String) -> String:
	return "%s_%d" % [base_id, Time.get_ticks_usec()]


func _slots_compatible(slot_a: String, slot_b: String) -> bool:
	return _normalize_slot(slot_a) == _normalize_slot(slot_b)


func _normalize_slot(slot_id: String) -> String:
	return "accessory" if slot_id.begins_with("accessory") else slot_id


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
			return _maybe_promote_rarity(String(rarity), allowed_rarities)

	return _maybe_promote_rarity(String(allowed_rarities[0]), allowed_rarities)


func _maybe_promote_rarity(rarity: String, allowed_rarities: Array) -> String:
	var quality_bonus: float = float(GameManager.get_meta_progression_bonuses().get("drop_quality_bonus", 0.0))
	if quality_bonus <= 0.0 or randf() > quality_bonus:
		return rarity
	var ordered_rarities: Array[String] = []
	for rarity_id in ["common", "uncommon", "rare", "epic", "set", "legendary", "ancient"]:
		if allowed_rarities.has(rarity_id):
			ordered_rarities.append(rarity_id)
	var current_index: int = ordered_rarities.find(rarity)
	if current_index == -1 or current_index >= ordered_rarities.size() - 1:
		return rarity
	return ordered_rarities[current_index + 1]


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

	for stat_entry_variant in item.get("base_stats", []):
		var stat_entry: Dictionary = stat_entry_variant
		score += absf(float(stat_entry.get("value", 0.0))) * 2.0
	for affix_entry_variant in item.get("affixes", []):
		var affix_entry: Dictionary = affix_entry_variant
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
