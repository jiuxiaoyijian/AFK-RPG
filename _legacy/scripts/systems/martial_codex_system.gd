extends RefCounted

const SLOT_ORDER := ["weapon", "armor", "accessory"]
const SLOT_GROUPS := {
	"weapon": ["weapon", "gloves"],
	"armor": ["helmet", "armor", "legs", "boots", "belt"],
	"accessory": ["accessory", "accessory1", "accessory2"],
}


static func create_default_state() -> Dictionary:
	return {
		"unlocked_effect_ids": [],
		"active_slots": {
			"weapon": "",
			"armor": "",
			"accessory": "",
		},
	}


static func sanitize_state(state: Dictionary) -> Dictionary:
	var sanitized: Dictionary = create_default_state()
	var unlocked_ids: Array = state.get("unlocked_effect_ids", [])
	var seen_ids: Dictionary = {}
	for effect_id_variant in unlocked_ids:
		var effect_id: String = String(effect_id_variant)
		if effect_id.is_empty() or seen_ids.has(effect_id):
			continue
		if get_effect_definition(effect_id).is_empty():
			continue
		sanitized["unlocked_effect_ids"].append(effect_id)
		seen_ids[effect_id] = true
	var active_slots: Dictionary = state.get("active_slots", {})
	for slot_id in SLOT_ORDER:
		var effect_id: String = String(active_slots.get(slot_id, ""))
		if effect_id.is_empty():
			continue
		if not sanitized["unlocked_effect_ids"].has(effect_id):
			continue
		if get_effect_slot_bucket(effect_id) != slot_id:
			continue
		sanitized["active_slots"][slot_id] = effect_id
	return sanitized


static func get_effect_definition(effect_id: String) -> Dictionary:
	for entry_variant in ConfigDB.get_all_legendary_affixes():
		var entry: Dictionary = entry_variant
		if String(entry.get("id", "")) == effect_id:
			return entry
	return {}


static func get_effect_slot_bucket(effect_id: String) -> String:
	var effect_data: Dictionary = get_effect_definition(effect_id)
	if effect_data.is_empty():
		return ""
	var slot_tags: Array = effect_data.get("slot_tags", [])
	for slot_id in SLOT_ORDER:
		for slot_tag_variant in SLOT_GROUPS.get(slot_id, []):
			if slot_tags.has(slot_tag_variant):
				return slot_id
	return ""


static func unlock_effect(state: Dictionary, effect_id: String) -> Dictionary:
	var sanitized: Dictionary = sanitize_state(state)
	if effect_id.is_empty():
		return {"ok": false, "reason": "未找到可萃取的武学"}
	if get_effect_definition(effect_id).is_empty():
		return {"ok": false, "reason": "武学效果不存在"}
	if sanitized["unlocked_effect_ids"].has(effect_id):
		return {"ok": false, "reason": "该武学已解锁"}
	sanitized["unlocked_effect_ids"].append(effect_id)
	return {
		"ok": true,
		"reason": "",
		"state": sanitized,
		"runtime_state": build_runtime_state(sanitized),
	}


static func set_active_effect(state: Dictionary, slot_id: String, effect_id: String) -> Dictionary:
	var sanitized: Dictionary = sanitize_state(state)
	if not SLOT_ORDER.has(slot_id):
		return {"ok": false, "reason": "武学槽位不存在"}
	if effect_id.is_empty():
		sanitized["active_slots"][slot_id] = ""
		return {
			"ok": true,
			"reason": "",
			"state": sanitized,
			"runtime_state": build_runtime_state(sanitized),
		}
	if not sanitized["unlocked_effect_ids"].has(effect_id):
		return {"ok": false, "reason": "该武学尚未解锁"}
	if get_effect_slot_bucket(effect_id) != slot_id:
		return {"ok": false, "reason": "该武学无法装备到当前槽位"}
	sanitized["active_slots"][slot_id] = effect_id
	return {
		"ok": true,
		"reason": "",
		"state": sanitized,
		"runtime_state": build_runtime_state(sanitized),
	}


static func build_active_effects(state: Dictionary) -> Array:
	var active_effects: Array = []
	var active_slots: Dictionary = sanitize_state(state).get("active_slots", {})
	for slot_id in SLOT_ORDER:
		var effect_id: String = String(active_slots.get(slot_id, ""))
		if effect_id.is_empty():
			continue
		var effect_data: Dictionary = get_effect_definition(effect_id)
		if effect_data.is_empty():
			continue
		active_effects.append({
			"slot_id": slot_id,
			"effect_id": effect_id,
			"name": String(effect_data.get("name", effect_id)),
			"description": String(effect_data.get("description", "")),
			"stat_key": String(effect_data.get("stat_key", "")),
			"value": float(effect_data.get("value_max", effect_data.get("value_min", 0.0))),
			"secondary_stat_key": String(effect_data.get("secondary_stat_key", "")),
			"secondary_value": float(effect_data.get("secondary_value_max", effect_data.get("secondary_value_min", 0.0))),
		})
	return active_effects


static func build_runtime_state(state: Dictionary) -> Dictionary:
	var sanitized: Dictionary = sanitize_state(state)
	var unlocked_effects: Array = []
	var available_by_slot: Dictionary = {
		"weapon": [],
		"armor": [],
		"accessory": [],
	}
	for effect_id_variant in sanitized.get("unlocked_effect_ids", []):
		var effect_id: String = String(effect_id_variant)
		var effect_data: Dictionary = get_effect_definition(effect_id)
		if effect_data.is_empty():
			continue
		var slot_id: String = get_effect_slot_bucket(effect_id)
		var effect_summary: Dictionary = {
			"effect_id": effect_id,
			"slot_id": slot_id,
			"name": String(effect_data.get("name", effect_id)),
			"description": String(effect_data.get("description", "")),
			"stat_key": String(effect_data.get("stat_key", "")),
			"value": float(effect_data.get("value_max", effect_data.get("value_min", 0.0))),
			"secondary_stat_key": String(effect_data.get("secondary_stat_key", "")),
			"secondary_value": float(effect_data.get("secondary_value_max", effect_data.get("secondary_value_min", 0.0))),
		}
		unlocked_effects.append(effect_summary)
		if available_by_slot.has(slot_id):
			available_by_slot[slot_id].append(effect_summary)
	unlocked_effects.sort_custom(_sort_effect_summaries)
	for slot_id in SLOT_ORDER:
		available_by_slot[slot_id].sort_custom(_sort_effect_summaries)
	return {
		"unlocked_effect_ids": sanitized["unlocked_effect_ids"].duplicate(true),
		"active_slots": sanitized["active_slots"].duplicate(true),
		"active_effects": build_active_effects(sanitized),
		"unlocked_effects": unlocked_effects,
		"available_by_slot": available_by_slot,
	}


static func build_combat_bonuses(state: Dictionary) -> Dictionary:
	var totals: Dictionary = {}
	for effect_variant in build_active_effects(state):
		var effect: Dictionary = effect_variant
		_add_bonus(totals, String(effect.get("stat_key", "")), float(effect.get("value", 0.0)))
		_add_bonus(totals, String(effect.get("secondary_stat_key", "")), float(effect.get("secondary_value", 0.0)))
	return totals


static func _add_bonus(totals: Dictionary, stat_key: String, value: float) -> void:
	if stat_key.is_empty():
		return
	totals[stat_key] = float(totals.get(stat_key, 0.0)) + value


static func _sort_effect_summaries(a: Dictionary, b: Dictionary) -> bool:
	var a_slot: String = String(a.get("slot_id", ""))
	var b_slot: String = String(b.get("slot_id", ""))
	if a_slot != b_slot:
		return SLOT_ORDER.find(a_slot) < SLOT_ORDER.find(b_slot)
	return String(a.get("effect_id", "")) < String(b.get("effect_id", ""))
