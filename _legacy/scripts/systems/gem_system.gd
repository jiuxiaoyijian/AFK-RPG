extends RefCounted

const GEM_SLOT_IDS := ["accessory1", "accessory2"]
const SKILL_TO_GEM := {
	"core_whirlwind": "gem_wind_echo",
	"core_deep_wound": "gem_blood_oath",
	"core_chain_lightning": "gem_thunder_vein",
}


static func create_default_state() -> Dictionary:
	return {
		"owned_gems": {},
		"equipped_gems": {
			"accessory1": "",
			"accessory2": "",
		},
	}


static func sanitize_state(state: Dictionary) -> Dictionary:
	var sanitized: Dictionary = create_default_state()
	sanitized["owned_gems"] = state.get("owned_gems", {}).duplicate(true)
	var equipped_gems: Dictionary = sanitized.get("equipped_gems", {})
	var raw_equipped: Dictionary = state.get("equipped_gems", {})
	for slot_id in GEM_SLOT_IDS:
		equipped_gems[slot_id] = String(raw_equipped.get(slot_id, ""))
	sanitized["equipped_gems"] = equipped_gems
	for slot_id in GEM_SLOT_IDS:
		var gem_id: String = String(equipped_gems.get(slot_id, ""))
		if gem_id.is_empty():
			continue
		if get_gem_level(sanitized, gem_id) <= 0:
			equipped_gems[slot_id] = ""
	return sanitized


static func get_gem_level(state: Dictionary, gem_id: String) -> int:
	var owned_gems: Dictionary = state.get("owned_gems", {})
	return int(owned_gems.get(gem_id, 0))


static func get_owned_gem_ids(state: Dictionary) -> Array[String]:
	var sanitized: Dictionary = sanitize_state(state)
	var gem_ids: Array[String] = []
	for gem_variant in ConfigDB.get_all_gems():
		var gem_data: Dictionary = gem_variant
		var gem_id: String = String(gem_data.get("id", ""))
		if gem_id.is_empty():
			continue
		if get_gem_level(sanitized, gem_id) <= 0:
			continue
		gem_ids.append(gem_id)
	return gem_ids


static func equip_gem(state: Dictionary, slot_id: String, gem_id: String) -> Dictionary:
	var sanitized: Dictionary = sanitize_state(state)
	if not GEM_SLOT_IDS.has(slot_id):
		return {"ok": false, "reason": "未知宝石槽位", "state": sanitized}
	if gem_id.is_empty():
		var empty_slot_map: Dictionary = sanitized.get("equipped_gems", {})
		empty_slot_map[slot_id] = ""
		sanitized["equipped_gems"] = empty_slot_map
		return {"ok": true, "reason": "", "state": sanitized}
	if get_gem_level(sanitized, gem_id) <= 0:
		return {"ok": false, "reason": "尚未获得该宝石", "state": sanitized}
	var equipped_gems: Dictionary = sanitized.get("equipped_gems", {})
	for other_slot in GEM_SLOT_IDS:
		if other_slot == slot_id:
			continue
		if String(equipped_gems.get(other_slot, "")) == gem_id:
			return {"ok": false, "reason": "同一宝石不能同时镶入两个饰品槽", "state": sanitized}
	equipped_gems[slot_id] = gem_id
	sanitized["equipped_gems"] = equipped_gems
	return {"ok": true, "reason": "", "state": sanitized}


static func grant_rift_reward(state: Dictionary, preferred_gem_id: String = "") -> Dictionary:
	var sanitized: Dictionary = sanitize_state(state)
	var chosen_gem_id: String = _pick_reward_gem_id(sanitized, preferred_gem_id)
	if chosen_gem_id.is_empty():
		return {"ok": false, "reason": "当前没有可用宝石定义", "state": sanitized}
	var gem_data: Dictionary = ConfigDB.get_gem(chosen_gem_id)
	var current_level: int = get_gem_level(sanitized, chosen_gem_id)
	var max_level: int = int(gem_data.get("max_level", 100))
	var new_level: int = mini(max_level, current_level + 1)
	var owned_gems: Dictionary = sanitized.get("owned_gems", {})
	owned_gems[chosen_gem_id] = new_level
	sanitized["owned_gems"] = owned_gems

	var auto_equipped_slots: Array[String] = []
	var equipped_gems: Dictionary = sanitized.get("equipped_gems", {})
	if current_level <= 0:
		for slot_id in GEM_SLOT_IDS:
			if String(equipped_gems.get(slot_id, "")).is_empty():
				equipped_gems[slot_id] = chosen_gem_id
				auto_equipped_slots.append(slot_id)
				break
	sanitized["equipped_gems"] = equipped_gems

	return {
		"ok": true,
		"reason": "",
		"state": sanitized,
		"gem_id": chosen_gem_id,
		"new_level": new_level,
		"leveled_up": new_level > current_level,
		"auto_equipped_slots": auto_equipped_slots,
		"summary": "%s 升至 %d 级" % [
			String(gem_data.get("name", chosen_gem_id)),
			new_level,
		],
	}


static func build_runtime_state(state: Dictionary) -> Dictionary:
	var sanitized: Dictionary = sanitize_state(state)
	var entries: Array = []
	for gem_variant in ConfigDB.get_all_gems():
		var gem_data: Dictionary = gem_variant
		var gem_id: String = String(gem_data.get("id", ""))
		var level: int = get_gem_level(sanitized, gem_id)
		if level <= 0:
			continue
		entries.append({
			"id": gem_id,
			"name": String(gem_data.get("name", gem_id)),
			"level": level,
			"effect_summary": String(gem_data.get("effect_summary", "")),
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("level", 0)) != int(b.get("level", 0)):
			return int(a.get("level", 0)) > int(b.get("level", 0))
		return String(a.get("id", "")) < String(b.get("id", ""))
	)

	var equipped_lines: Array[String] = []
	for slot_id in GEM_SLOT_IDS:
		var gem_id: String = String(sanitized.get("equipped_gems", {}).get(slot_id, ""))
		if gem_id.is_empty():
			equipped_lines.append("%s: 未镶嵌" % _get_slot_name(slot_id))
			continue
		var gem_data: Dictionary = ConfigDB.get_gem(gem_id)
		equipped_lines.append("%s: %s Lv.%d" % [
			_get_slot_name(slot_id),
			String(gem_data.get("name", gem_id)),
			get_gem_level(sanitized, gem_id),
		])

	return {
		"owned_gems": sanitized.get("owned_gems", {}).duplicate(true),
		"equipped_gems": sanitized.get("equipped_gems", {}).duplicate(true),
		"entries": entries,
		"equipped_lines": equipped_lines,
		"summary_text": " | ".join(equipped_lines),
	}


static func build_combat_bonuses(state: Dictionary) -> Dictionary:
	var sanitized: Dictionary = sanitize_state(state)
	var totals: Dictionary = {}
	for slot_id in GEM_SLOT_IDS:
		var gem_id: String = String(sanitized.get("equipped_gems", {}).get(slot_id, ""))
		if gem_id.is_empty():
			continue
		var level: int = get_gem_level(sanitized, gem_id)
		if level <= 0:
			continue
		_merge_bonus_dict(totals, _build_bonus_for_gem(gem_id, level))
	return totals


static func get_preferred_gem_id_for_skill(skill_id: String) -> String:
	return String(SKILL_TO_GEM.get(skill_id, ""))


static func _pick_reward_gem_id(state: Dictionary, preferred_gem_id: String) -> String:
	var candidate_ids: Array[String] = []
	for gem_variant in ConfigDB.get_all_gems():
		var gem_data: Dictionary = gem_variant
		var gem_id: String = String(gem_data.get("id", ""))
		if gem_id.is_empty():
			continue
		var max_level: int = int(gem_data.get("max_level", 100))
		if get_gem_level(state, gem_id) >= max_level:
			continue
		candidate_ids.append(gem_id)
	if candidate_ids.is_empty():
		return ""
	if not preferred_gem_id.is_empty() and candidate_ids.has(preferred_gem_id):
		return preferred_gem_id
	return candidate_ids[randi() % candidate_ids.size()]


static func _build_bonus_for_gem(gem_id: String, level: int) -> Dictionary:
	match gem_id:
		"gem_wind_echo":
			return {
				"core_damage_percent": float(level) * 0.012,
				"whirlwind_radius_percent": float(level) * 0.006,
			}
		"gem_blood_oath":
			return {
				"bleed_dot_percent": float(level) * 0.015,
				"execute_threshold": float(level) * 0.001,
			}
		"gem_thunder_vein":
			return {
				"chain_damage_percent": float(level) * 0.014,
				"attack_speed_percent": float(level) * 0.008,
				"chain_count_bonus": floor(float(level) / 25.0),
			}
		_:
			return {}


static func _merge_bonus_dict(target: Dictionary, source: Dictionary) -> void:
	for stat_key_variant in source.keys():
		var stat_key: String = String(stat_key_variant)
		target[stat_key] = float(target.get(stat_key, 0.0)) + float(source.get(stat_key_variant, 0.0))


static func _get_slot_name(slot_id: String) -> String:
	match slot_id:
		"accessory1":
			return "饰品一"
		"accessory2":
			return "饰品二"
		_:
			return slot_id
