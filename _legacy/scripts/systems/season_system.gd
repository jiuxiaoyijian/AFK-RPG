extends RefCounted

const REQUIRED_STABLE_NODE_ID := "ch2_boss"
const REQUIRED_RIFT_LEVEL := 20


static func create_default_state() -> Dictionary:
	return {
		"rebirth_count": 0,
		"permanent_bonuses": {},
		"last_rebirth_unix_time": 0,
	}


static func sanitize_state(state: Dictionary) -> Dictionary:
	var sanitized: Dictionary = create_default_state()
	sanitized["rebirth_count"] = maxi(0, int(state.get("rebirth_count", 0)))
	sanitized["last_rebirth_unix_time"] = maxi(0, int(state.get("last_rebirth_unix_time", 0)))
	sanitized["permanent_bonuses"] = build_permanent_bonuses(int(sanitized.get("rebirth_count", 0)))
	return sanitized


static func build_permanent_bonuses(rebirth_count: int) -> Dictionary:
	var count: int = maxi(0, rebirth_count)
	return {
		"primary_stat": float(count) * 5.0,
		"paragon_exp_gain_percent": float(count) * 0.10,
		"drop_quality_bonus": float(maxi(0, count - 1)) * 0.05,
		"gold_gain_percent": float(maxi(0, count - 2)) * 0.05,
	}


static func can_rebirth(state: Dictionary, stable_node_id: String, highest_rift_level: int, is_rift_active: bool = false) -> Dictionary:
	var sanitized: Dictionary = sanitize_state(state)
	if is_rift_active:
		return {"ok": false, "reason": "秘境进行中，需先完成当前试剑", "state": sanitized}
	if stable_node_id != REQUIRED_STABLE_NODE_ID:
		return {"ok": false, "reason": "需先击破第二章首领", "state": sanitized}
	if highest_rift_level < REQUIRED_RIFT_LEVEL:
		return {"ok": false, "reason": "需先通关试剑秘境 Lv.%d" % REQUIRED_RIFT_LEVEL, "state": sanitized}
	return {"ok": true, "reason": "", "state": sanitized}


static func perform_rebirth(state: Dictionary) -> Dictionary:
	var sanitized: Dictionary = sanitize_state(state)
	sanitized["rebirth_count"] = int(sanitized.get("rebirth_count", 0)) + 1
	sanitized["last_rebirth_unix_time"] = int(Time.get_unix_time_from_system())
	sanitized["permanent_bonuses"] = build_permanent_bonuses(int(sanitized.get("rebirth_count", 0)))
	return {
		"ok": true,
		"reason": "",
		"state": sanitized,
		"summary": "重入江湖完成，第 %d 次轮回已结算。" % int(sanitized.get("rebirth_count", 0)),
	}


static func build_runtime_summary(state: Dictionary, progress: Dictionary = {}) -> Dictionary:
	var sanitized: Dictionary = sanitize_state(state)
	var rebirth_count: int = int(sanitized.get("rebirth_count", 0))
	var permanent_bonuses: Dictionary = sanitized.get("permanent_bonuses", {}).duplicate(true)
	var last_rebirth_unix_time: int = int(sanitized.get("last_rebirth_unix_time", 0))
	var last_rebirth_text: String = "未曾重入江湖"
	if last_rebirth_unix_time > 0:
		last_rebirth_text = Time.get_datetime_string_from_unix_time(last_rebirth_unix_time, true)

	var check_result: Dictionary = can_rebirth(
		sanitized,
		String(progress.get("stable_node_id", "")),
		int(progress.get("highest_rift_level", 0)),
		bool(progress.get("is_rift_active", false))
	)
	var can_now_rebirth: bool = bool(check_result.get("ok", false))
	var status: String = "可重入江湖" if can_now_rebirth else "未满足条件"
	return {
		"title": "重入江湖",
		"status": status,
		"summary_text": "轮回次数: %d | 最近轮回: %s | 永久加成: %s" % [
			rebirth_count,
			last_rebirth_text,
			build_bonus_summary_text(permanent_bonuses),
		],
		"is_unlocked": can_now_rebirth,
		"rebirth_count": rebirth_count,
		"permanent_bonuses": permanent_bonuses,
		"last_rebirth_unix_time": last_rebirth_unix_time,
		"can_rebirth": can_now_rebirth,
		"blocked_reason": String(check_result.get("reason", "")),
	}


static func build_rebirth_preview(state: Dictionary, progress: Dictionary = {}) -> Dictionary:
	var sanitized: Dictionary = sanitize_state(state)
	var current_count: int = int(sanitized.get("rebirth_count", 0))
	var next_count: int = current_count + 1
	var current_bonuses: Dictionary = sanitized.get("permanent_bonuses", {}).duplicate(true)
	var next_bonuses: Dictionary = build_permanent_bonuses(next_count)
	var check_result: Dictionary = can_rebirth(
		sanitized,
		String(progress.get("stable_node_id", "")),
		int(progress.get("highest_rift_level", 0)),
		bool(progress.get("is_rift_active", false))
	)
	return {
		"ok": bool(check_result.get("ok", false)),
		"reason": String(check_result.get("reason", "")),
		"current_count": current_count,
		"next_count": next_count,
		"current_bonuses": current_bonuses,
		"next_bonuses": next_bonuses,
		"current_bonus_text": build_bonus_summary_text(current_bonuses),
		"next_bonus_text": build_bonus_summary_text(next_bonuses),
		"keep_lines": [
			"保留: 武学秘录、宗师修为、江湖见闻录",
			"保留: 已获得的江湖阅历永久加成",
		],
		"reset_lines": [
			"重置: 装备、背包、材料、章节推进",
			"重置: 试剑秘境层数与宝石镶嵌状态",
			"重置: 武学参悟进度与当前击杀/清图计数",
		],
	}


static func build_combat_bonuses(state: Dictionary) -> Dictionary:
	var sanitized: Dictionary = sanitize_state(state)
	var permanent_bonuses: Dictionary = sanitized.get("permanent_bonuses", {})
	var primary_stat_bonus: float = float(permanent_bonuses.get("primary_stat", 0.0))
	if primary_stat_bonus <= 0.0:
		return {}
	return {
		"primary_stat": primary_stat_bonus,
	}


static func build_meta_bonuses(state: Dictionary) -> Dictionary:
	var sanitized: Dictionary = sanitize_state(state)
	return sanitized.get("permanent_bonuses", {}).duplicate(true)


static func build_bonus_summary_text(permanent_bonuses: Dictionary) -> String:
	var segments: Array[String] = []
	var primary_stat: float = float(permanent_bonuses.get("primary_stat", 0.0))
	if primary_stat > 0.0:
		segments.append("全属性 +%.0f%%" % primary_stat)
	var paragon_exp_gain_percent: float = float(permanent_bonuses.get("paragon_exp_gain_percent", 0.0))
	if paragon_exp_gain_percent > 0.0:
		segments.append("修为获取 +%.0f%%" % (paragon_exp_gain_percent * 100.0))
	var drop_quality_bonus: float = float(permanent_bonuses.get("drop_quality_bonus", 0.0))
	if drop_quality_bonus > 0.0:
		segments.append("掉落品质 +%.0f%%" % (drop_quality_bonus * 100.0))
	var gold_gain_percent: float = float(permanent_bonuses.get("gold_gain_percent", 0.0))
	if gold_gain_percent > 0.0:
		segments.append("香火钱 +%.0f%%" % (gold_gain_percent * 100.0))
	if segments.is_empty():
		return "暂未获得永久加成"
	return " | ".join(segments)
