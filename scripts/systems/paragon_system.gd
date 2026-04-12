extends RefCounted

const BASE_EXPERIENCE := 24.0
const PARAGON_UNLOCK_LEVEL := 70
const STAT_DEFINITIONS := [
	{
		"id": "paragon_attack_training",
		"name": "宗师·劲力",
		"category": "攻击",
		"description": "稳步抬高基础攻击百分比，适合所有道统。",
		"combat_stat_key": "attack_percent",
		"value_per_point": 0.005,
		"cap": 50,
		"effect_text": "每点攻击 +0.5%",
	},
	{
		"id": "paragon_vitality",
		"name": "宗师·命门",
		"category": "防御",
		"description": "增加基础生命值，让高层秘境容错更高。",
		"combat_stat_key": "hp_flat",
		"value_per_point": 6.0,
		"cap": 50,
		"effect_text": "每点生命 +6",
	},
	{
		"id": "paragon_guard",
		"name": "宗师·护体",
		"category": "防御",
		"description": "缓慢增加防御面板，适合长线补生存。",
		"combat_stat_key": "defense_flat",
		"value_per_point": 0.5,
		"cap": 50,
		"effect_text": "每点防御 +0.5",
	},
	{
		"id": "paragon_precision",
		"name": "宗师·洞察",
		"category": "技巧",
		"description": "补充暴击率，让真意和传承爆发更稳定。",
		"combat_stat_key": "crit_rate",
		"value_per_point": 0.002,
		"cap": 50,
		"effect_text": "每点暴击 +0.2%",
	},
	{
		"id": "paragon_crit_damage",
		"name": "宗师·断空",
		"category": "技巧",
		"description": "进一步提高暴击伤害，适合已成型 Build。",
		"combat_stat_key": "crit_damage",
		"value_per_point": 0.01,
		"cap": 50,
		"effect_text": "每点暴伤 +1%",
	},
	{
		"id": "paragon_fortune",
		"name": "宗师·财缘",
		"category": "辅助",
		"description": "提高香火钱获取，缓解百炼坊与参悟的资源压力。",
		"meta_stat_key": "gold_gain_percent",
		"value_per_point": 0.01,
		"cap": -1,
		"effect_text": "每点香火钱 +1%",
	},
	{
		"id": "paragon_insight",
		"name": "宗师·悟性",
		"category": "辅助",
		"description": "提高宗师修为获取，让后续长线成长更顺滑。",
		"meta_stat_key": "paragon_exp_gain_percent",
		"value_per_point": 0.01,
		"cap": -1,
		"effect_text": "每点修为获取 +1%",
	},
]


static func create_default_state() -> Dictionary:
	return {
		"is_unlocked": false,
		"level": 0,
		"experience": 0.0,
		"available_points": 0,
		"allocated": {},
	}


static func sanitize_state(state: Dictionary) -> Dictionary:
	var sanitized: Dictionary = create_default_state()
	sanitized["is_unlocked"] = bool(state.get("is_unlocked", false))
	sanitized["level"] = maxi(0, int(state.get("level", 0)))
	sanitized["experience"] = maxf(0.0, float(state.get("experience", 0.0)))
	sanitized["available_points"] = maxi(0, int(state.get("available_points", 0)))

	var allocated: Dictionary = {}
	var raw_allocated: Dictionary = state.get("allocated", {})
	for definition_variant in STAT_DEFINITIONS:
		var definition: Dictionary = definition_variant
		var stat_id: String = String(definition.get("id", ""))
		if stat_id.is_empty():
			continue
		allocated[stat_id] = maxi(0, int(raw_allocated.get(stat_id, 0)))
	sanitized["allocated"] = allocated
	return sanitized


static func is_unlocked_by_progress(progress_gate: Variant) -> bool:
	if progress_gate is int:
		return int(progress_gate) >= PARAGON_UNLOCK_LEVEL
	if progress_gate is float:
		return int(progress_gate) >= PARAGON_UNLOCK_LEVEL
	return String(progress_gate) == "ch2_boss"


static func ensure_unlocked(state: Dictionary, progress_gate: Variant) -> Dictionary:
	var sanitized: Dictionary = sanitize_state(state)
	var was_unlocked: bool = bool(sanitized.get("is_unlocked", false))
	if not was_unlocked and is_unlocked_by_progress(progress_gate):
		sanitized["is_unlocked"] = true
	return {
		"state": sanitized,
		"newly_unlocked": not was_unlocked and bool(sanitized.get("is_unlocked", false)),
	}


static func get_experience_to_next_level(level: int) -> int:
	return maxi(12, int(round(BASE_EXPERIENCE * pow(1.0 + 0.05 * float(maxi(level, 0)), 2.0))))


static func gain_experience(state: Dictionary, base_amount: float, bonus_percent: float = 0.0) -> Dictionary:
	var sanitized: Dictionary = sanitize_state(state)
	if not bool(sanitized.get("is_unlocked", false)):
		return {"ok": false, "reason": "宗师修为尚未开启", "state": sanitized}
	if base_amount <= 0.0:
		return {"ok": false, "reason": "未获得修为", "state": sanitized}

	var gained_experience: float = maxf(0.0, base_amount * (1.0 + maxf(bonus_percent, 0.0)))
	sanitized["experience"] = float(sanitized.get("experience", 0.0)) + gained_experience

	var gained_levels: int = 0
	while true:
		var current_level: int = int(sanitized.get("level", 0))
		var need_experience: int = get_experience_to_next_level(current_level)
		if float(sanitized.get("experience", 0.0)) < float(need_experience):
			break
		sanitized["experience"] = float(sanitized.get("experience", 0.0)) - float(need_experience)
		sanitized["level"] = current_level + 1
		sanitized["available_points"] = int(sanitized.get("available_points", 0)) + 1
		gained_levels += 1

	return {
		"ok": true,
		"reason": "",
		"state": sanitized,
		"gained_experience": int(round(gained_experience)),
		"gained_levels": gained_levels,
		"summary": "宗师修为 +%d%s" % [
			int(round(gained_experience)),
			" | 连升 %d 级" % gained_levels if gained_levels > 0 else "",
		],
	}


static func allocate_point(state: Dictionary, stat_id: String) -> Dictionary:
	var sanitized: Dictionary = sanitize_state(state)
	if not bool(sanitized.get("is_unlocked", false)):
		return {"ok": false, "reason": "宗师修为尚未开启", "state": sanitized}
	if int(sanitized.get("available_points", 0)) <= 0:
		return {"ok": false, "reason": "当前没有可分配的宗师点", "state": sanitized}

	var definition: Dictionary = get_stat_definition(stat_id)
	if definition.is_empty():
		return {"ok": false, "reason": "未知宗师修为项", "state": sanitized}

	var allocated: Dictionary = sanitized.get("allocated", {})
	var current_points: int = int(allocated.get(stat_id, 0))
	var cap: int = int(definition.get("cap", -1))
	if cap >= 0 and current_points >= cap:
		return {"ok": false, "reason": "该项已达到上限", "state": sanitized}

	allocated[stat_id] = current_points + 1
	sanitized["allocated"] = allocated
	sanitized["available_points"] = int(sanitized.get("available_points", 0)) - 1
	return {
		"ok": true,
		"reason": "",
		"state": sanitized,
		"summary": "%s +1" % String(definition.get("name", stat_id)),
	}


static func reset_allocations(state: Dictionary) -> Dictionary:
	var sanitized: Dictionary = sanitize_state(state)
	var allocated: Dictionary = sanitized.get("allocated", {})
	var refunded_points: int = 0
	for stat_id_variant in allocated.keys():
		refunded_points += int(allocated.get(stat_id_variant, 0))
		allocated[stat_id_variant] = 0
	sanitized["allocated"] = allocated
	sanitized["available_points"] = int(sanitized.get("available_points", 0)) + refunded_points
	return {
		"ok": true,
		"reason": "",
		"state": sanitized,
		"refunded_points": refunded_points,
		"summary": "宗师修为已重置，返还 %d 点。" % refunded_points,
	}


static func build_stat_entries(state: Dictionary) -> Array:
	var sanitized: Dictionary = sanitize_state(state)
	var allocated: Dictionary = sanitized.get("allocated", {})
	var entries: Array = []
	for definition_variant in STAT_DEFINITIONS:
		var definition: Dictionary = definition_variant
		var stat_id: String = String(definition.get("id", ""))
		var points: int = int(allocated.get(stat_id, 0))
		var cap: int = int(definition.get("cap", -1))
		var value_per_point: float = float(definition.get("value_per_point", 0.0))
		entries.append({
			"id": stat_id,
			"name": String(definition.get("name", stat_id)),
			"category": String(definition.get("category", "")),
			"description": String(definition.get("description", "")),
			"points": points,
			"cap": cap,
			"is_capped": cap >= 0 and points >= cap,
			"value_per_point": value_per_point,
			"total_value": float(points) * value_per_point,
			"effect_text": String(definition.get("effect_text", "")),
		})
	return entries


static func build_stat_detail_text(state: Dictionary, stat_id: String) -> String:
	var definition: Dictionary = get_stat_definition(stat_id)
	if definition.is_empty():
		return "未选择宗师修为项"

	var sanitized: Dictionary = sanitize_state(state)
	var allocated: Dictionary = sanitized.get("allocated", {})
	var points: int = int(allocated.get(stat_id, 0))
	var cap: int = int(definition.get("cap", -1))
	var value_per_point: float = float(definition.get("value_per_point", 0.0))
	var total_value: float = float(points) * value_per_point
	var lines: Array[String] = []
	lines.append(String(definition.get("name", stat_id)))
	lines.append("分类: %s" % String(definition.get("category", "宗师修为")))
	lines.append("说明: %s" % String(definition.get("description", "")))
	lines.append("当前点数: %d%s" % [
		points,
		" / %d" % cap if cap >= 0 else " / 无上限",
	])
	lines.append("单点收益: %s" % String(definition.get("effect_text", "")))
	lines.append("当前累计: %s" % _format_stat_total(String(definition.get("combat_stat_key", definition.get("meta_stat_key", ""))), total_value))
	return "\n".join(lines)


static func build_runtime_summary(state: Dictionary) -> Dictionary:
	var sanitized: Dictionary = sanitize_state(state)
	var entries: Array = build_stat_entries(sanitized)
	var allocated_points: int = 0
	for entry_variant in entries:
		var entry: Dictionary = entry_variant
		allocated_points += int(entry.get("points", 0))

	var current_level: int = int(sanitized.get("level", 0))
	var current_experience: float = float(sanitized.get("experience", 0.0))
	var next_level_experience: int = get_experience_to_next_level(current_level)
	var is_unlocked: bool = bool(sanitized.get("is_unlocked", false))
	var status: String = "已开启" if is_unlocked else "未解锁"
	var summary_text: String = "英雄达到 Lv.70 后开启宗师修为。" if not is_unlocked else "宗师等级: %d | 当前修为: %d/%d | 可用点数: %d | 已分配: %d" % [
		current_level,
		int(round(current_experience)),
		next_level_experience,
		int(sanitized.get("available_points", 0)),
		allocated_points,
	]

	return {
		"title": "宗师修为",
		"status": status,
		"summary_text": summary_text,
		"is_unlocked": is_unlocked,
		"level": current_level,
		"experience": current_experience,
		"next_level_experience": next_level_experience,
		"available_points": int(sanitized.get("available_points", 0)),
		"allocated_points": allocated_points,
		"entries": entries,
	}


static func build_combat_bonuses(state: Dictionary) -> Dictionary:
	var sanitized: Dictionary = sanitize_state(state)
	var allocated: Dictionary = sanitized.get("allocated", {})
	var totals: Dictionary = {}
	for definition_variant in STAT_DEFINITIONS:
		var definition: Dictionary = definition_variant
		var combat_stat_key: String = String(definition.get("combat_stat_key", ""))
		if combat_stat_key.is_empty():
			continue
		var points: int = int(allocated.get(String(definition.get("id", "")), 0))
		if points <= 0:
			continue
		totals[combat_stat_key] = float(totals.get(combat_stat_key, 0.0)) + float(points) * float(definition.get("value_per_point", 0.0))
	return totals


static func build_meta_bonuses(state: Dictionary) -> Dictionary:
	var sanitized: Dictionary = sanitize_state(state)
	var allocated: Dictionary = sanitized.get("allocated", {})
	var totals: Dictionary = {}
	for definition_variant in STAT_DEFINITIONS:
		var definition: Dictionary = definition_variant
		var meta_stat_key: String = String(definition.get("meta_stat_key", ""))
		if meta_stat_key.is_empty():
			continue
		var points: int = int(allocated.get(String(definition.get("id", "")), 0))
		if points <= 0:
			continue
		totals[meta_stat_key] = float(totals.get(meta_stat_key, 0.0)) + float(points) * float(definition.get("value_per_point", 0.0))
	return totals


static func build_summary(state: Dictionary) -> Dictionary:
	var sanitized: Dictionary = sanitize_state(state)
	return {
		"is_unlocked": bool(sanitized.get("is_unlocked", false)),
		"level": int(sanitized.get("level", 0)),
		"experience": float(sanitized.get("experience", 0.0)),
		"available_points": int(sanitized.get("available_points", 0)),
		"allocated": sanitized.get("allocated", {}).duplicate(true),
	}


static func get_stat_definition(stat_id: String) -> Dictionary:
	for definition_variant in STAT_DEFINITIONS:
		var definition: Dictionary = definition_variant
		if String(definition.get("id", "")) == stat_id:
			return definition
	return {}


static func _format_stat_total(stat_key: String, total_value: float) -> String:
	match stat_key:
		"attack_percent", "crit_rate", "crit_damage", "gold_gain_percent", "paragon_exp_gain_percent":
			return "%+.1f%%" % (total_value * 100.0)
		"hp_flat", "defense_flat":
			return "%+.1f" % total_value
		_:
			return "%+.2f" % total_value
