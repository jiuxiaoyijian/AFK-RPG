extends RefCounted

const MAX_HERO_LEVEL := 70
const DEFAULT_SKILL_SLOT_COUNT := 2


static func create_default_state() -> Dictionary:
	return sanitize_state({
		"level": 1,
		"experience": 0.0,
		"experience_to_next": get_experience_to_next_level(1),
		"unlocked_skill_slots": DEFAULT_SKILL_SLOT_COUNT,
		"unlocked_passive_slots": 0,
		"unlocked_rune_tiers": 0,
	})


static func sanitize_state(state: Dictionary) -> Dictionary:
	var sanitized := {
		"level": clampi(int(state.get("level", 1)), 1, MAX_HERO_LEVEL),
		"experience": maxf(0.0, float(state.get("experience", 0.0))),
		"experience_to_next": 0,
		"unlocked_skill_slots": DEFAULT_SKILL_SLOT_COUNT,
		"unlocked_passive_slots": 0,
		"unlocked_rune_tiers": 0,
	}
	var unlocks: Dictionary = get_unlock_summary_for_level(int(sanitized["level"]))
	sanitized["unlocked_skill_slots"] = int(unlocks.get("skill_slots", DEFAULT_SKILL_SLOT_COUNT))
	sanitized["unlocked_passive_slots"] = int(unlocks.get("passive_slots", 0))
	sanitized["unlocked_rune_tiers"] = int(unlocks.get("rune_tiers", 0))
	sanitized["experience_to_next"] = get_experience_to_next_level(int(sanitized["level"]))
	if int(sanitized["level"]) >= MAX_HERO_LEVEL:
		sanitized["experience"] = 0.0
	return sanitized


static func get_experience_to_next_level(level: int) -> int:
	if level >= MAX_HERO_LEVEL:
		return 0
	var entry: Dictionary = ConfigDB.get_hero_level_entry(level)
	return maxi(1, int(entry.get("exp_required", 1)))


static func get_unlock_summary_for_level(level: int) -> Dictionary:
	var skill_slots: int = DEFAULT_SKILL_SLOT_COUNT
	var passive_slots: int = 0
	var rune_tiers: int = 0
	if level >= 4:
		skill_slots = 3
	if level >= 12:
		skill_slots = 4
	if level >= 8:
		passive_slots = 1
	if level >= 20:
		passive_slots = 2
	if level >= 40:
		passive_slots = 3
	if level >= 16:
		rune_tiers = 1
	if level >= 30:
		rune_tiers = 2
	if level >= 50:
		rune_tiers = 3
	return {
		"skill_slots": skill_slots,
		"passive_slots": passive_slots,
		"rune_tiers": rune_tiers,
	}


static func gain_experience(state: Dictionary, base_amount: float, bonus_percent: float = 0.0) -> Dictionary:
	var sanitized: Dictionary = sanitize_state(state)
	if base_amount <= 0.0:
		return {
			"ok": false,
			"reason": "未获得阅历",
			"state": sanitized,
			"gained_experience": 0,
			"gained_levels": 0,
			"overflow_experience": 0.0,
			"unlock_events": [],
		}

	var gained_experience: float = maxf(0.0, base_amount * (1.0 + maxf(bonus_percent, 0.0)))
	if int(sanitized.get("level", 1)) >= MAX_HERO_LEVEL:
		return {
			"ok": true,
			"reason": "",
			"state": sanitized,
			"gained_experience": int(round(gained_experience)),
			"gained_levels": 0,
			"overflow_experience": gained_experience,
			"unlock_events": [],
			"summary": "阅历已转入宗师修为",
		}

	sanitized["experience"] = float(sanitized.get("experience", 0.0)) + gained_experience
	var gained_levels: int = 0
	var unlock_events: Array[String] = []
	while int(sanitized.get("level", 1)) < MAX_HERO_LEVEL:
		var current_level: int = int(sanitized.get("level", 1))
		var need_experience: int = get_experience_to_next_level(current_level)
		if float(sanitized.get("experience", 0.0)) < float(need_experience):
			break
		sanitized["experience"] = float(sanitized.get("experience", 0.0)) - float(need_experience)
		sanitized["level"] = current_level + 1
		gained_levels += 1
		unlock_events.append_array(_get_unlock_events_for_level(current_level + 1))

	var overflow_experience: float = 0.0
	if int(sanitized.get("level", 1)) >= MAX_HERO_LEVEL:
		overflow_experience = float(sanitized.get("experience", 0.0))
		sanitized["experience"] = 0.0

	sanitized = sanitize_state(sanitized)
	var summary: String = "阅历 +%d" % int(round(gained_experience))
	if gained_levels > 0:
		summary += " | 升至 Lv.%d" % int(sanitized.get("level", 1))
	return {
		"ok": true,
		"reason": "",
		"state": sanitized,
		"gained_experience": int(round(gained_experience)),
		"gained_levels": gained_levels,
		"overflow_experience": overflow_experience,
		"unlock_events": unlock_events,
		"summary": summary,
	}


static func build_runtime_summary(state: Dictionary) -> Dictionary:
	var sanitized: Dictionary = sanitize_state(state)
	var level: int = int(sanitized.get("level", 1))
	var experience_to_next: int = int(sanitized.get("experience_to_next", 0))
	return {
		"level": level,
		"experience": int(round(float(sanitized.get("experience", 0.0)))),
		"experience_to_next": experience_to_next,
		"experience_ratio": 1.0 if experience_to_next <= 0 else clampf(float(sanitized.get("experience", 0.0)) / float(experience_to_next), 0.0, 1.0),
		"unlocked_skill_slots": int(sanitized.get("unlocked_skill_slots", DEFAULT_SKILL_SLOT_COUNT)),
		"unlocked_passive_slots": int(sanitized.get("unlocked_passive_slots", 0)),
		"unlocked_rune_tiers": int(sanitized.get("unlocked_rune_tiers", 0)),
		"is_max_level": level >= MAX_HERO_LEVEL,
		"status_text": "Lv.%d | 阅历 %d/%d" % [
			level,
			int(round(float(sanitized.get("experience", 0.0)))),
			experience_to_next,
		] if level < MAX_HERO_LEVEL else "Lv.70 | 阅历转入宗师修为",
	}


static func _get_unlock_events_for_level(level: int) -> Array[String]:
	var unlock_events: Array[String] = []
	match level:
		4:
			unlock_events.append("已解锁战术位")
		8:
			unlock_events.append("已解锁被动位 1")
		12:
			unlock_events.append("已解锁爆发位")
		16:
			unlock_events.append("已解锁符文层 1")
		20:
			unlock_events.append("已解锁被动位 2")
		30:
			unlock_events.append("已解锁符文层 2")
		40:
			unlock_events.append("已解锁被动位 3")
		50:
			unlock_events.append("已解锁符文层 3")
		70:
			unlock_events.append("已踏入宗师修为")
		_:
			pass
	return unlock_events
