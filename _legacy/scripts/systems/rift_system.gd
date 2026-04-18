extends RefCounted

const DEFAULT_TIME_LIMIT := 75
const HUA_RING_SET_IDS := ["set_wind", "set_blood", "set_thunder", "set_iron"]


static func create_default_state() -> Dictionary:
	return {
		"current_level": 0,
		"highest_level": 0,
		"owned_keys": {},
		"recent_results": [],
		"active_run": {},
	}


static func sanitize_state(state: Dictionary) -> Dictionary:
	var sanitized: Dictionary = create_default_state()
	sanitized["current_level"] = int(state.get("current_level", 0))
	sanitized["highest_level"] = int(state.get("highest_level", 0))
	sanitized["owned_keys"] = state.get("owned_keys", {}).duplicate(true)
	sanitized["recent_results"] = state.get("recent_results", []).duplicate(true)
	sanitized["active_run"] = state.get("active_run", {}).duplicate(true)
	return sanitized


static func get_scaling_for_level(level: int) -> Dictionary:
	var best_entry: Dictionary = {}
	for entry_variant in ConfigDB.get_rift_scaling_entries():
		var entry: Dictionary = entry_variant
		if level >= int(entry.get("level", 0)):
			best_entry = entry
	if best_entry.is_empty():
		return {
			"level": 1,
			"enemy_hp_multiplier": 1.0,
			"enemy_damage_multiplier": 1.0,
			"reward_multiplier": 1.0,
		}
	if level <= int(best_entry.get("level", level)):
		return best_entry
	var delta: int = maxi(0, level - 50)
	if delta <= 0:
		return best_entry
	return {
		"level": level,
		"enemy_hp_multiplier": float(best_entry.get("enemy_hp_multiplier", 1.0)) * pow(1.17, delta),
		"enemy_damage_multiplier": float(best_entry.get("enemy_damage_multiplier", 1.0)) * pow(1.10, delta),
		"reward_multiplier": float(best_entry.get("reward_multiplier", 1.0)) + float(delta) * 0.15,
	}


static func get_best_available_key_id(state: Dictionary, target_level: int) -> String:
	var sanitized: Dictionary = sanitize_state(state)
	var owned_keys: Dictionary = sanitized.get("owned_keys", {})
	var eligible_keys: Array = []
	for key_variant in ConfigDB.get_rift_key_entries():
		var key_entry: Dictionary = key_variant
		if target_level < int(key_entry.get("required_level", 1)):
			continue
		if int(owned_keys.get(String(key_entry.get("id", "")), 0)) <= 0:
			continue
		eligible_keys.append(key_entry)
	if eligible_keys.is_empty():
		return ""
	eligible_keys.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("required_level", 1)) > int(b.get("required_level", 1))
	)
	return String(eligible_keys[0].get("id", ""))


static func can_start_run(state: Dictionary, target_level: int) -> Dictionary:
	var sanitized: Dictionary = sanitize_state(state)
	if not sanitized.get("active_run", {}).is_empty():
		return {"ok": false, "reason": "已有进行中的试剑秘境"}
	if target_level <= 0:
		return {"ok": false, "reason": "秘境层数必须大于 0"}
	var key_id: String = get_best_available_key_id(sanitized, target_level)
	if key_id.is_empty():
		return {"ok": false, "reason": "没有可用的试剑令"}
	return {"ok": true, "reason": "", "key_id": key_id}


static func start_run(state: Dictionary, target_level: int, base_node_id: String, base_time_limit: int) -> Dictionary:
	var sanitized: Dictionary = sanitize_state(state)
	var start_state: Dictionary = can_start_run(sanitized, target_level)
	if not bool(start_state.get("ok", false)):
		return start_state
	var key_id: String = String(start_state.get("key_id", ""))
	_consume_key(sanitized, key_id, 1)
	var scaling: Dictionary = get_scaling_for_level(target_level)
	var time_limit: int = maxi(DEFAULT_TIME_LIMIT, base_time_limit + int(target_level * 2))
	sanitized["current_level"] = target_level
	sanitized["active_run"] = {
		"level": target_level,
		"key_id": key_id,
		"base_node_id": base_node_id,
		"time_limit": time_limit,
		"enemy_hp_multiplier": float(scaling.get("enemy_hp_multiplier", 1.0)),
		"enemy_damage_multiplier": float(scaling.get("enemy_damage_multiplier", 1.0)),
		"reward_multiplier": float(scaling.get("reward_multiplier", 1.0)),
	}
	return {
		"ok": true,
		"reason": "",
		"state": sanitized,
		"active_run": sanitized["active_run"].duplicate(true),
	}


static func finish_run(state: Dictionary, success: bool) -> Dictionary:
	var sanitized: Dictionary = sanitize_state(state)
	var active_run: Dictionary = sanitized.get("active_run", {})
	if active_run.is_empty():
		return {"ok": false, "reason": "当前没有进行中的秘境", "state": sanitized}

	var cleared_level: int = int(active_run.get("level", 0))
	var summary_lines: Array[String] = []
	var reward_entries: Array = []
	if success:
		sanitized["highest_level"] = maxi(int(sanitized.get("highest_level", 0)), cleared_level)
		var reward_key_id: String = _get_reward_key_id_for_level(cleared_level)
		_add_key(sanitized, reward_key_id, 1)
		summary_lines.append("试剑秘境 Lv.%d 通关" % cleared_level)
		summary_lines.append("%s +1" % _get_key_name(reward_key_id))
		reward_entries = build_special_rewards(cleared_level)
	else:
		summary_lines.append("试剑秘境 Lv.%d 失败" % cleared_level)

	sanitized["recent_results"].push_front({
		"level": cleared_level,
		"success": success,
		"reward_multiplier": float(active_run.get("reward_multiplier", 1.0)),
		"summary": " | ".join(summary_lines),
		"timestamp": Time.get_unix_time_from_system(),
	})
	while sanitized["recent_results"].size() > 8:
		sanitized["recent_results"].pop_back()
	sanitized["active_run"] = {}
	return {
		"ok": true,
		"reason": "",
		"state": sanitized,
		"summary_lines": summary_lines,
		"reward_entries": reward_entries,
		"cleared_level": cleared_level,
	}


static func build_special_rewards(cleared_level: int) -> Array:
	var rewards: Array = []
	if cleared_level >= 10:
		rewards.append({
			"type": "gem",
			"min_level": cleared_level,
		})
	if cleared_level >= 20:
		rewards.append({
			"type": "hua_ring",
			"set_id": HUA_RING_SET_IDS[randi() % HUA_RING_SET_IDS.size()],
			"item_level": maxi(10, cleared_level),
		})
	return rewards


static func grant_boss_clear_key(state: Dictionary, node_data: Dictionary) -> Dictionary:
	var sanitized: Dictionary = sanitize_state(state)
	if String(node_data.get("node_type", "")) != "boss":
		return {"ok": false, "reason": "", "state": sanitized, "summary_lines": []}
	_add_key(sanitized, "rift_key_common", 1)
	return {
		"ok": true,
		"reason": "",
		"state": sanitized,
		"summary_lines": ["试剑令 +1"],
	}


static func build_runtime_summary(state: Dictionary) -> Dictionary:
	var sanitized: Dictionary = sanitize_state(state)
	var active_run: Dictionary = sanitized.get("active_run", {})
	var recommended_level: int = maxi(1, int(sanitized.get("highest_level", 0)) + 1)
	var start_state: Dictionary = can_start_run(sanitized, recommended_level)
	var key_segments: Array[String] = []
	for key_variant in ConfigDB.get_rift_key_entries():
		var key_entry: Dictionary = key_variant
		var key_id: String = String(key_entry.get("id", ""))
		key_segments.append("%s x%d" % [
			String(key_entry.get("name", key_id)),
			int(sanitized.get("owned_keys", {}).get(key_id, 0)),
		])
	return {
		"highest_level": int(sanitized.get("highest_level", 0)),
		"current_level": int(sanitized.get("current_level", 0)),
		"owned_keys": sanitized.get("owned_keys", {}).duplicate(true),
		"recent_results": sanitized.get("recent_results", []).duplicate(true),
		"active_run": active_run.duplicate(true),
		"key_summary": " | ".join(key_segments),
		"recommended_level": recommended_level,
		"can_start": bool(start_state.get("ok", false)),
		"blocked_reason": String(start_state.get("reason", "")),
	}


static func build_hua_ring_item(set_id: String, item_level: int) -> Dictionary:
	var set_data: Dictionary = ConfigDB.get_set(set_id)
	if set_data.is_empty():
		return {}
	var item: Dictionary = {
		"id": "hua_ring_%s_%d" % [set_id, Time.get_ticks_usec()],
		"base_id": "hua_ring_%s" % set_id,
		"slot": "accessory",
		"name": "%s华戒" % String(set_data.get("name", "传承")),
		"rarity": "legendary",
		"item_level": item_level,
		"base_stats": [
			{"stat_key": "crit_rate", "value": 0.03},
			{"stat_key": "hp_flat", "value": float(item_level) * 6.0},
		],
		"affixes": [],
		"legendary_affix": {},
		"hua_ring_set_id": set_id,
		"hua_ring_set_name": String(set_data.get("name", set_id)),
		"score": float(item_level) * 12.0 + GameManager.get_rarity_rank("legendary") * 18.0,
	}
	return item


static func _consume_key(state: Dictionary, key_id: String, amount: int) -> void:
	var owned_keys: Dictionary = state.get("owned_keys", {})
	owned_keys[key_id] = maxi(0, int(owned_keys.get(key_id, 0)) - amount)
	state["owned_keys"] = owned_keys


static func _add_key(state: Dictionary, key_id: String, amount: int) -> void:
	var owned_keys: Dictionary = state.get("owned_keys", {})
	owned_keys[key_id] = maxi(0, int(owned_keys.get(key_id, 0)) + amount)
	state["owned_keys"] = owned_keys


static func _get_reward_key_id_for_level(level: int) -> String:
	if level >= 15:
		return "rift_key_greater"
	return "rift_key_common"


static func _get_key_name(key_id: String) -> String:
	for key_variant in ConfigDB.get_rift_key_entries():
		var key_entry: Dictionary = key_variant
		if String(key_entry.get("id", "")) == key_id:
			return String(key_entry.get("name", key_id))
	return key_id
