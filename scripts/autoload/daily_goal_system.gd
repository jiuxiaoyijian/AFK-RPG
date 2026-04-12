extends Node

const DAILY_GOAL_STATE_KEY := "daily_goal_state"
const DAILY_GOAL_LAST_REFRESH_KEY := "daily_goal_last_refresh_date"
const DAILY_GOAL_SNAPSHOT_KEY := "daily_goal_progress_snapshot"
const TASK_STATUS_ACTIVE := "active"
const TASK_STATUS_COMPLETED := "completed"
const PRIMARY_PRIORITY := 100
const SIDE_RESEARCH_PRIORITY := 60
const SIDE_LOOT_PRIORITY := 40

var last_refresh_date: String = ""
var primary_goal: Dictionary = {}
var side_goals: Array = []
var last_recommendation_snapshot: Dictionary = {}

var _last_resource_snapshot: Dictionary = {}
var _last_research_total: int = 0
var _last_discovered_legendary_count: int = 0


func _ready() -> void:
	EventBus.config_loaded.connect(_on_config_loaded)
	EventBus.battle_finished.connect(_on_battle_finished)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.resources_changed.connect(_on_resources_changed)
	EventBus.research_changed.connect(_on_research_changed)
	EventBus.codex_changed.connect(_on_codex_changed)
	EventBus.loot_target_changed.connect(_on_loot_target_changed)
	_refresh_internal_snapshots()
	if not ConfigDB.chapter_nodes.is_empty():
		_on_config_loaded()


func build_save_data() -> Dictionary:
	return {
		DAILY_GOAL_STATE_KEY: {
			"primary_goal": primary_goal,
			"side_goals": side_goals,
		},
		DAILY_GOAL_LAST_REFRESH_KEY: last_refresh_date,
		DAILY_GOAL_SNAPSHOT_KEY: last_recommendation_snapshot,
	}


func load_save_data(payload: Dictionary) -> void:
	last_refresh_date = String(payload.get(DAILY_GOAL_LAST_REFRESH_KEY, last_refresh_date))
	var state_payload: Variant = payload.get(DAILY_GOAL_STATE_KEY, {})
	if state_payload is Dictionary:
		primary_goal = _normalize_goal(state_payload.get("primary_goal", {}))
		side_goals = _normalize_goals(state_payload.get("side_goals", []))
	last_recommendation_snapshot = _normalize_dictionary(payload.get(DAILY_GOAL_SNAPSHOT_KEY, {}))
	_refresh_internal_snapshots()
	refresh_daily_goals_if_needed()


func get_daily_goal_data() -> Dictionary:
	return {
		"last_refresh_date": last_refresh_date,
		"primary_goal": primary_goal.duplicate(true),
		"side_goals": side_goals.duplicate(true),
		"next_step_summary": get_next_step_summary(),
		"primary_goal_summary": get_primary_goal_summary(),
		"nearest_side_goal_summary": get_nearest_side_goal_summary(),
		"snapshot": last_recommendation_snapshot.duplicate(true),
	}


func get_primary_goal_summary() -> String:
	if primary_goal.is_empty():
		return "今日机缘: 暂无"
	return "今日机缘: %s (%s)" % [
		String(primary_goal.get("title", "未命名目标")),
		_get_goal_progress_text(primary_goal),
	]


func get_next_step_summary() -> String:
	if not primary_goal.is_empty() and String(primary_goal.get("status", TASK_STATUS_ACTIVE)) == TASK_STATUS_ACTIVE:
		return String(primary_goal.get("cta_text", "先推进今日主目标"))
	for goal_variant in side_goals:
		var goal: Dictionary = goal_variant
		if String(goal.get("status", TASK_STATUS_ACTIVE)) == TASK_STATUS_ACTIVE:
			return String(goal.get("cta_text", "先处理今日支线"))
	return "今日机缘已成，继续探境或回刷推荐节点。"


func get_nearest_side_goal_summary() -> String:
	if side_goals.is_empty():
		return "旁支: 暂无"
	var nearest_goal: Dictionary = side_goals[0]
	for goal_variant in side_goals:
		var goal: Dictionary = goal_variant
		if _get_goal_remaining(goal) < _get_goal_remaining(nearest_goal):
			nearest_goal = goal
	return "%s (%s)" % [
		String(nearest_goal.get("title", "支线目标")),
		_get_goal_progress_text(nearest_goal),
	]


func refresh_daily_goals_if_needed() -> void:
	if ConfigDB.chapter_nodes.is_empty():
		return
	var today_key: String = _get_today_key()
	if last_refresh_date != today_key or not _has_valid_goals():
		_generate_daily_goals(today_key)
	else:
		_refresh_dynamic_goal_texts()
		_refresh_recommendation_snapshot()
		_emit_goals_changed()
	_refresh_internal_snapshots()


func record_progress(event_name: String, payload: Dictionary = {}) -> void:
	if primary_goal.is_empty() and side_goals.is_empty():
		refresh_daily_goals_if_needed()
	if event_name == "battle_finished":
		_apply_battle_progress(payload)
	elif event_name == "enemy_kill":
		_apply_enemy_kill_progress(payload)
	elif event_name == "resource_gain":
		_apply_resource_progress(payload)
	elif event_name == "research_upgrade":
		_apply_research_progress(payload)
	elif event_name == "legendary_discovery":
		_apply_legendary_discovery_progress(payload)
	_refresh_dynamic_goal_texts()
	_refresh_recommendation_snapshot()
	_emit_goals_changed()


func _on_config_loaded() -> void:
	refresh_daily_goals_if_needed()


func _on_battle_finished(node_id: String, success: bool) -> void:
	if not success:
		return
	record_progress("battle_finished", {"node_id": node_id})


func _on_enemy_killed(enemy_id: String) -> void:
	record_progress("enemy_kill", {"enemy_id": enemy_id})


func _on_resources_changed() -> void:
	var current_snapshot: Dictionary = _build_resource_snapshot()
	var positive_deltas: Dictionary = {}
	for resource_id in current_snapshot.keys():
		var previous_value: int = int(_last_resource_snapshot.get(resource_id, current_snapshot[resource_id]))
		var current_value: int = int(current_snapshot.get(resource_id, 0))
		if current_value > previous_value:
			positive_deltas[resource_id] = current_value - previous_value
	_last_resource_snapshot = current_snapshot
	if positive_deltas.is_empty():
		return
	record_progress("resource_gain", {"resource_deltas": positive_deltas})


func _on_research_changed() -> void:
	var current_total: int = _get_total_research_levels()
	var delta: int = maxi(0, current_total - _last_research_total)
	_last_research_total = current_total
	if delta <= 0:
		return
	record_progress("research_upgrade", {"count": delta})


func _on_codex_changed() -> void:
	var current_count: int = int(LootCodexSystem.discovered_legendary_affix_ids.size())
	var delta: int = maxi(0, current_count - _last_discovered_legendary_count)
	_last_discovered_legendary_count = current_count
	if delta <= 0:
		return
	record_progress("legendary_discovery", {"count": delta})


func _on_loot_target_changed() -> void:
	if last_refresh_date.is_empty():
		return
	_refresh_loot_side_goal(true)
	_refresh_recommendation_snapshot()
	_emit_goals_changed()


func _generate_daily_goals(today_key: String) -> void:
	last_refresh_date = today_key
	primary_goal = _build_primary_goal()
	side_goals = []
	side_goals.append(_build_research_side_goal())
	side_goals.append(_build_loot_side_goal())
	_refresh_dynamic_goal_texts()
	_refresh_recommendation_snapshot()
	_emit_goals_changed()


func _build_primary_goal() -> Dictionary:
	var current_node: Dictionary = ConfigDB.get_chapter_node(GameManager.current_node_id)
	if current_node.is_empty():
		return _build_goal(
			"goal_push_fallback",
			"push_node",
			"完成当前节点",
			"继续沿当前探境主线推进。",
			1,
			PRIMARY_PRIORITY,
			"先推进当前节点，打开下一段探境。",
			GameManager.current_node_id,
			"",
			"推进章节 / 解锁新掉落"
		)

	var current_chapter: Dictionary = ConfigDB.get_chapter(String(current_node.get("chapter_id", GameManager.current_chapter_id)))
	var first_node_id: String = ConfigDB.get_chapter_first_node(String(current_chapter.get("id", GameManager.current_chapter_id)))
	var stable_node: Dictionary = ConfigDB.get_chapter_node(GameManager.stable_node_id)
	var is_new_chapter_first_node: bool = GameManager.current_node_id == first_node_id \
		and not stable_node.is_empty() \
		and String(stable_node.get("chapter_id", "")) != String(current_node.get("chapter_id", ""))
	var is_last_chapter_loop: bool = String(current_chapter.get("next_chapter_id", "")).is_empty() \
		and GameManager.current_node_id == first_node_id \
		and not stable_node.is_empty() \
		and String(stable_node.get("chapter_id", "")) == String(current_chapter.get("id", "")) \
		and String(stable_node.get("node_type", "")) == "boss"
	var build_advice: Dictionary = GameManager.get_build_advice_data()

	if is_last_chapter_loop:
		var farm_node: Dictionary = _get_high_value_farm_node(String(current_chapter.get("id", GameManager.current_chapter_id)))
		return _build_goal(
			"goal_push_chapter_farm",
			"push_farm",
			"刷取当前探境高价值节点",
			"当前探境主线已打通，继续刷高价值节点维持成长节奏。",
			3,
			PRIMARY_PRIORITY,
			"先刷 %s，继续积累后段成长资源。" % String(farm_node.get("label", GameManager.current_node_id)),
			String(farm_node.get("node_id", GameManager.current_node_id)),
			"",
			"维持成长曲线 / 补高价值掉落"
		)

	var diagnostic_goal: Dictionary = _build_diagnostic_primary_goal(build_advice, current_node)
	if not diagnostic_goal.is_empty():
		return diagnostic_goal

	if String(current_node.get("node_type", "normal")) == "boss":
		return _build_goal(
			"goal_push_boss_%s" % GameManager.current_node_id,
			"push_boss",
			"击败当前 Boss",
			"击穿当前探境关底，打开下一段推进空间。",
			1,
			PRIMARY_PRIORITY,
			"先击败当前 Boss，验证这套 build 能否完成阶段突破。",
			GameManager.current_node_id,
			"",
			"探境推进 / 新掉落池"
		)

	if is_new_chapter_first_node:
		return _build_goal(
			"goal_push_new_chapter_%s" % GameManager.current_node_id,
			"push_node",
			"通关新章节首节点",
			"先站稳新探境，再判断后续该继续推进还是回刷。",
			1,
			PRIMARY_PRIORITY,
			"先打通 %s，看看新章节掉落和压力变化。" % String(current_chapter.get("name", GameManager.current_chapter_id)),
			GameManager.current_node_id,
			"",
			"探境解锁 / 新敌人与奖励"
		)

	return _build_goal(
		"goal_push_node_%s" % GameManager.current_node_id,
		"push_node",
		"完成当前节点",
		"继续沿当前探境推进，优先验证是否能稳定过关。",
		1,
		PRIMARY_PRIORITY,
		"先完成当前节点，再决定是否需要转向悟道或刷装。",
		GameManager.current_node_id,
		"",
		"推进探境 / 拉高稳定层"
	)


func _build_diagnostic_primary_goal(build_advice: Dictionary, current_node: Dictionary) -> Dictionary:
	if build_advice.is_empty():
		return {}
	var pivot_type: String = String(build_advice.get("pivot_type", "push"))
	var gap_severity: String = String(build_advice.get("gap_severity", "mild"))
	var is_progress_blocked: bool = bool(build_advice.get("is_progress_blocked", false))
	if not is_progress_blocked and gap_severity != "severe":
		return {}

	var block_node_label: String = String(build_advice.get("block_node_label", String(current_node.get("id", GameManager.current_node_id))))
	var recommended_node_id: String = String(build_advice.get("recommended_node_id", GameManager.current_node_id))
	var recommended_node_label: String = String(build_advice.get("recommended_node_label", recommended_node_id))
	var gap_label: String = String(build_advice.get("gap_label", "当前缺口"))
	var pivot_summary: String = String(build_advice.get("pivot_summary", "先补当前卡点。"))

	match pivot_type:
		"research_upgrade":
			var research_name: String = String(build_advice.get("research_action_name", "当前悟道"))
			return _build_goal(
				"goal_research_primary_%s" % String(build_advice.get("research_action_name", research_name)),
				"research_upgrade",
				"先做一次悟道",
				"当前卡在 %s，先悟道 %s，优先补 %s 再回头推进。" % [
					block_node_label if not block_node_label.is_empty() else "当前探境",
					research_name,
					gap_label,
				],
				1,
				PRIMARY_PRIORITY,
				pivot_summary,
				"",
				"research",
				"稳住当前卡点 / 再回探境"
			)
		"research_resource":
			var resource_id: String = String(build_advice.get("research_action_resource_id", "core"))
			var missing_amount: int = maxi(1, int(build_advice.get("research_action_missing_amount", 1)))
			return _build_goal(
				"goal_research_resource_primary_%s" % resource_id,
				"resource_collect",
				"先筹悟道材料",
				"当前卡在 %s，先补 %s，再回头稳住当前道统。" % [
					block_node_label if not block_node_label.is_empty() else "当前探境",
					MetaProgressionSystem.get_resource_display_name(resource_id),
				],
				missing_amount,
				PRIMARY_PRIORITY,
				pivot_summary,
				recommended_node_id,
				"research",
				"补齐悟道材料 / 稳住当前卡点",
				{"resource_id": resource_id}
			)
		"farm":
			if recommended_node_id.is_empty():
				return {}
			return _build_goal(
				"goal_pivot_farm_%s" % recommended_node_id,
				"push_farm",
				"先补当前卡点",
				"当前卡在 %s，先回刷 %s，优先补 %s。" % [
					block_node_label if not block_node_label.is_empty() else "当前探境",
					recommended_node_label,
					gap_label,
				],
				3,
				PRIMARY_PRIORITY,
				pivot_summary,
				recommended_node_id,
				"codex",
				"回刷稳住强度 / 再回主线"
			)
		_:
			return {}


func _build_research_side_goal() -> Dictionary:
	var advice: Dictionary = GameManager.get_build_advice_data()
	var preferred_upgrade: Dictionary = _get_preferred_research_upgrade()
	if not preferred_upgrade.is_empty():
		var node_name: String = String(preferred_upgrade.get("name", "悟道"))
		var gap_label: String = String(advice.get("gap_label", "当前缺口"))
		return _build_goal(
			"goal_research_upgrade_%s" % String(preferred_upgrade.get("id", "")),
			"research_upgrade",
			"补悟道缺口",
			"优先提升 %s，先稳住 %s。" % [node_name, gap_label],
			1,
			SIDE_RESEARCH_PRIORITY,
			"先打开悟道面板，优先提升 %s。" % node_name,
			"",
			"research",
			"悟道成长 / 道统强化"
		)

	var resource_goal: Dictionary = _get_research_resource_goal()
	if not resource_goal.is_empty():
		return resource_goal

	return _build_goal(
		"goal_research_fallback",
		"resource_collect",
		"筹备悟道材料",
		"当前没有可立即提升的悟道，先积累灵核与真意残片。",
		6,
		SIDE_RESEARCH_PRIORITY,
		"先通过探境或闭关所得积累悟道材料，再回悟道面板。",
		GameManager.current_node_id,
		"research",
		"为后续悟道做准备",
		{"resource_id": "core"}
	)


func _build_loot_side_goal() -> Dictionary:
	var advice: Dictionary = GameManager.get_build_advice_data()
	var tracked_target_name: String = _get_tracked_target_name()
	var recommendation: Dictionary = {}
	var recommended_node_id: String = String(advice.get("recommended_node_id", GameManager.current_node_id))
	var recommendation_label: String = String(advice.get("recommended_node_label", recommended_node_id))
	if not LootCodexSystem.tracked_legendary_affix_id.is_empty():
		recommendation = LootCodexSystem.get_recommended_farm_node_for_legendary(LootCodexSystem.tracked_legendary_affix_id)
		recommended_node_id = String(recommendation.get("node_id", recommended_node_id))
		recommendation_label = String(recommendation.get("short_label", recommendation_label))
	var primary_target_name: String = String(advice.get("primary_target_name", tracked_target_name))
	var gap_summary: String = String(advice.get("gap_summary", "继续围绕当前道统刷装。"))
	var gap_category_label: String = String(advice.get("gap_category_label", "传承"))
	var gap_label: String = String(advice.get("gap_label", "当前缺口"))
	var description: String = "围绕当前机缘追踪继续刷装，推动道统成型。"
	if not primary_target_name.is_empty():
		description = "围绕 %s 继续刷装，%s" % [primary_target_name, gap_summary]
	return _build_goal(
		"goal_loot_farm_%s" % recommended_node_id,
		"loot_farm",
		"补%s缺口" % gap_category_label,
		description,
		3,
		SIDE_LOOT_PRIORITY,
		"先刷 %s，优先补 %s。" % [recommendation_label, gap_label if not gap_label.is_empty() else (primary_target_name if not primary_target_name.is_empty() else "当前道统核心件")],
		recommended_node_id,
		"codex",
		"机缘追踪 / 装备成型",
		{
			"target_name": primary_target_name if not primary_target_name.is_empty() else tracked_target_name,
			"recommendation_label": recommendation_label,
			"gap_summary": gap_summary,
		}
	)


func _build_goal(
	goal_id: String,
	goal_type: String,
	title: String,
	description: String,
	target_value: int,
	priority: int,
	cta_text: String,
	recommended_node_id: String,
	recommended_panel: String,
	reward_preview: String,
	extra: Dictionary = {}
) -> Dictionary:
	var goal: Dictionary = {
		"id": goal_id,
		"goal_type": goal_type,
		"title": title,
		"description": description,
		"target_value": maxi(1, target_value),
		"current_value": 0,
		"status": TASK_STATUS_ACTIVE,
		"priority": priority,
		"cta_text": cta_text,
		"recommended_node_id": recommended_node_id,
		"recommended_panel": recommended_panel,
		"reward_preview": reward_preview,
	}
	for key in extra.keys():
		goal[key] = extra[key]
	return goal


func _apply_battle_progress(payload: Dictionary) -> void:
	var node_id: String = String(payload.get("node_id", ""))
	if node_id.is_empty():
		return
	primary_goal = _apply_goal_battle_progress(primary_goal, node_id)
	for index in range(side_goals.size()):
		var goal: Dictionary = side_goals[index]
		side_goals[index] = _apply_goal_battle_progress(goal, node_id)


func _apply_goal_battle_progress(goal: Dictionary, node_id: String) -> Dictionary:
	if goal.is_empty():
		return goal
	if String(goal.get("status", TASK_STATUS_ACTIVE)) == TASK_STATUS_COMPLETED:
		return goal
	if not ["push_node", "push_boss", "push_farm", "loot_farm"].has(String(goal.get("goal_type", ""))):
		return goal
	if String(goal.get("recommended_node_id", "")) != node_id:
		return goal
	goal["current_value"] = mini(int(goal.get("target_value", 1)), int(goal.get("current_value", 0)) + 1)
	_update_goal_status(goal)
	return goal


func _apply_enemy_kill_progress(_payload: Dictionary) -> void:
	primary_goal = _apply_goal_enemy_kill_progress(primary_goal)
	for index in range(side_goals.size()):
		side_goals[index] = _apply_goal_enemy_kill_progress(side_goals[index])


func _apply_goal_enemy_kill_progress(goal: Dictionary) -> Dictionary:
	if goal.is_empty():
		return goal
	if String(goal.get("status", TASK_STATUS_ACTIVE)) == TASK_STATUS_COMPLETED:
		return goal
	if String(goal.get("goal_type", "")) != "enemy_kill":
		return goal
	goal["current_value"] = mini(int(goal.get("target_value", 1)), int(goal.get("current_value", 0)) + 1)
	_update_goal_status(goal)
	return goal


func _apply_resource_progress(payload: Dictionary) -> void:
	var deltas: Dictionary = payload.get("resource_deltas", {})
	primary_goal = _apply_goal_resource_progress(primary_goal, deltas)
	for index in range(side_goals.size()):
		var goal: Dictionary = side_goals[index]
		side_goals[index] = _apply_goal_resource_progress(goal, deltas)


func _apply_goal_resource_progress(goal: Dictionary, deltas: Dictionary) -> Dictionary:
	if goal.is_empty():
		return goal
	if String(goal.get("goal_type", "")) != "resource_collect":
		return goal
	var resource_id: String = String(goal.get("resource_id", ""))
	if resource_id.is_empty() or not deltas.has(resource_id):
		return goal
	goal["current_value"] = mini(
		int(goal.get("target_value", 1)),
		int(goal.get("current_value", 0)) + int(deltas.get(resource_id, 0))
	)
	_update_goal_status(goal)
	return goal


func _apply_research_progress(payload: Dictionary) -> void:
	var count: int = int(payload.get("count", 0))
	if count <= 0:
		return
	primary_goal = _apply_goal_research_progress(primary_goal, count)
	for index in range(side_goals.size()):
		var goal: Dictionary = side_goals[index]
		side_goals[index] = _apply_goal_research_progress(goal, count)


func _apply_goal_research_progress(goal: Dictionary, count: int) -> Dictionary:
	if goal.is_empty():
		return goal
	if String(goal.get("goal_type", "")) != "research_upgrade":
		return goal
	goal["current_value"] = mini(
		int(goal.get("target_value", 1)),
		int(goal.get("current_value", 0)) + count
	)
	_update_goal_status(goal)
	return goal


func _apply_legendary_discovery_progress(payload: Dictionary) -> void:
	var count: int = int(payload.get("count", 0))
	if count <= 0:
		return
	primary_goal = _apply_goal_legendary_progress(primary_goal, count)
	for index in range(side_goals.size()):
		var goal: Dictionary = side_goals[index]
		side_goals[index] = _apply_goal_legendary_progress(goal, count)


func _apply_goal_legendary_progress(goal: Dictionary, count: int) -> Dictionary:
	if goal.is_empty():
		return goal
	if String(goal.get("goal_type", "")) != "loot_discovery":
		return goal
	goal["current_value"] = mini(
		int(goal.get("target_value", 1)),
		int(goal.get("current_value", 0)) + count
	)
	_update_goal_status(goal)
	return goal


func _update_goal_status(goal: Dictionary) -> void:
	goal["status"] = TASK_STATUS_COMPLETED \
		if int(goal.get("current_value", 0)) >= int(goal.get("target_value", 1)) \
		else TASK_STATUS_ACTIVE


func _get_goal_progress_text(goal: Dictionary) -> String:
	if goal.is_empty():
		return "--"
	return "%d/%d%s" % [
		int(goal.get("current_value", 0)),
		int(goal.get("target_value", 1)),
		" 已完成" if String(goal.get("status", TASK_STATUS_ACTIVE)) == TASK_STATUS_COMPLETED else "",
	]


func _get_goal_remaining(goal: Dictionary) -> int:
	return maxi(0, int(goal.get("target_value", 1)) - int(goal.get("current_value", 0)))


func _get_today_key() -> String:
	var date_data: Dictionary = Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [
		int(date_data.get("year", 1970)),
		int(date_data.get("month", 1)),
		int(date_data.get("day", 1)),
	]


func _has_valid_goals() -> bool:
	return not primary_goal.is_empty() and side_goals.size() == 2


func _refresh_internal_snapshots() -> void:
	_last_resource_snapshot = _build_resource_snapshot()
	_last_research_total = _get_total_research_levels()
	_last_discovered_legendary_count = int(LootCodexSystem.discovered_legendary_affix_ids.size())


func _build_resource_snapshot() -> Dictionary:
	return {
		"gold": MetaProgressionSystem.gold,
		"scrap": MetaProgressionSystem.scrap,
		"core": MetaProgressionSystem.core,
		"legend_shard": MetaProgressionSystem.legend_shard,
	}


func _get_total_research_levels() -> int:
	var total: int = 0
	for level_variant in MetaProgressionSystem.research_levels.values():
		total += int(level_variant)
	return total


func _get_preferred_research_upgrade() -> Dictionary:
	for research_node_variant in MetaProgressionSystem.get_research_items("combat"):
		var research_node: Dictionary = research_node_variant
		if bool(MetaProgressionSystem.can_upgrade_research(String(research_node.get("id", ""))).get("ok", false)):
			return research_node
	for research_node_variant in MetaProgressionSystem.get_research_items("economy"):
		var research_node: Dictionary = research_node_variant
		if bool(MetaProgressionSystem.can_upgrade_research(String(research_node.get("id", ""))).get("ok", false)):
			return research_node
	for research_node_variant in MetaProgressionSystem.get_research_items("idle"):
		var research_node: Dictionary = research_node_variant
		if bool(MetaProgressionSystem.can_upgrade_research(String(research_node.get("id", ""))).get("ok", false)):
			return research_node
	return {}


func _get_research_resource_goal() -> Dictionary:
	var preferred_goal: Dictionary = {}
	for tree_filter in ["combat", "economy", "idle"]:
		for research_node_variant in MetaProgressionSystem.get_research_items(tree_filter):
			var research_node: Dictionary = research_node_variant
			var node_id: String = String(research_node.get("id", ""))
			var upgrade_state: Dictionary = MetaProgressionSystem.can_upgrade_research(node_id)
			if bool(upgrade_state.get("ok", false)):
				continue
			var reason: String = String(upgrade_state.get("reason", ""))
			if reason.contains("不足"):
				var current_level: int = MetaProgressionSystem.get_research_level(node_id)
				var cost_entry: Dictionary = _get_research_cost_entry(research_node, current_level + 1)
				if cost_entry.is_empty():
					continue
				var resource_id: String = String(cost_entry.get("resource_id", "core"))
				var total_cost: int = int(cost_entry.get("amount", 1))
				var current_amount: int = MetaProgressionSystem.get_resource_amount(resource_id)
				var missing_amount: int = maxi(1, total_cost - current_amount)
				preferred_goal = _build_goal(
					"goal_research_resource_%s" % node_id,
					"resource_collect",
					"筹备悟道材料",
					"为 %s 准备 %s x%d。" % [
						String(research_node.get("name", node_id)),
						MetaProgressionSystem.get_resource_display_name(resource_id),
						total_cost,
					],
					missing_amount,
					SIDE_RESEARCH_PRIORITY,
					"先攒够 %s，再打开悟道面板提升 %s。" % [
						MetaProgressionSystem.get_resource_display_name(resource_id),
						String(research_node.get("name", node_id)),
					],
					GameManager.current_node_id,
					"research",
					"补齐悟道消耗 / 解锁下一层成长",
					{
						"resource_id": resource_id,
						"research_id": node_id,
					}
				)
				return preferred_goal
	return preferred_goal


func _get_research_cost_entry(research_node: Dictionary, target_level: int) -> Dictionary:
	for cost_entry_variant in research_node.get("costs", []):
		var cost_entry: Dictionary = cost_entry_variant
		if int(cost_entry.get("level", 0)) == target_level:
			return cost_entry
	return {}


func _get_tracked_target_name() -> String:
	var tracked_id: String = LootCodexSystem.tracked_legendary_affix_id
	if tracked_id.is_empty():
		return ""
	for affix_variant in ConfigDB.get_all_legendary_affixes():
		var affix: Dictionary = affix_variant
		if String(affix.get("id", "")) == tracked_id:
			return String(affix.get("name", tracked_id))
	return tracked_id


func _get_high_value_farm_node(chapter_id: String) -> Dictionary:
	var chapter: Dictionary = ConfigDB.get_chapter(chapter_id)
	var node_ids: Array = chapter.get("node_ids", [])
	var best_node_id: String = GameManager.current_node_id
	var best_score: int = -1
	for node_id_variant in node_ids:
		var node_id: String = String(node_id_variant)
		var node_data: Dictionary = ConfigDB.get_chapter_node(node_id)
		var node_type: String = String(node_data.get("node_type", "normal"))
		var score: int = 1
		if node_type == "elite":
			score = 2
		elif node_type == "boss":
			score = 3
		if score > best_score:
			best_score = score
			best_node_id = node_id
	return {
		"node_id": best_node_id,
		"label": "%s / %s" % [String(chapter.get("name", chapter_id)), best_node_id],
	}


func _refresh_loot_side_goal(reset_progress: bool) -> void:
	for index in range(side_goals.size()):
		var goal: Dictionary = side_goals[index]
		if String(goal.get("goal_type", "")) == "loot_farm":
			var replacement: Dictionary = _build_loot_side_goal()
			if not reset_progress:
				replacement["current_value"] = goal.get("current_value", 0)
				replacement["status"] = goal.get("status", TASK_STATUS_ACTIVE)
			side_goals[index] = replacement
			return


func _refresh_dynamic_goal_texts() -> void:
	if primary_goal.is_empty():
		return
	primary_goal["progress_text"] = _get_goal_progress_text(primary_goal)
	for index in range(side_goals.size()):
		var goal: Dictionary = side_goals[index]
		goal["progress_text"] = _get_goal_progress_text(goal)
		side_goals[index] = goal


func _refresh_recommendation_snapshot() -> void:
	var build_advice: Dictionary = GameManager.get_build_advice_data()
	last_recommendation_snapshot = {
		"next_step_summary": get_next_step_summary(),
		"primary_goal_summary": get_primary_goal_summary(),
		"nearest_side_goal_summary": get_nearest_side_goal_summary(),
		"recommended_panel": _get_recommended_panel(),
		"build_gap_summary": String(build_advice.get("gap_summary", "")),
		"build_next_target_summary": String(build_advice.get("next_target_line", "")),
		"stall_summary": String(build_advice.get("stall_summary", "")),
		"pivot_summary": String(build_advice.get("pivot_summary", "")),
	}


func _get_recommended_panel() -> String:
	if not primary_goal.is_empty() and String(primary_goal.get("status", TASK_STATUS_ACTIVE)) == TASK_STATUS_ACTIVE:
		return String(primary_goal.get("recommended_panel", ""))
	for goal_variant in side_goals:
		var goal: Dictionary = goal_variant
		if String(goal.get("status", TASK_STATUS_ACTIVE)) == TASK_STATUS_ACTIVE:
			return String(goal.get("recommended_panel", ""))
	return ""


func _emit_goals_changed() -> void:
	EventBus.daily_goals_changed.emit()


func _normalize_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value.duplicate(true)
	return {}


func _normalize_goal(value: Variant) -> Dictionary:
	var goal: Dictionary = _normalize_dictionary(value)
	if goal.is_empty():
		return {}
	goal["current_value"] = int(goal.get("current_value", 0))
	goal["target_value"] = maxi(1, int(goal.get("target_value", 1)))
	goal["priority"] = int(goal.get("priority", 0))
	goal["status"] = String(goal.get("status", TASK_STATUS_ACTIVE))
	goal["recommended_node_id"] = String(goal.get("recommended_node_id", ""))
	goal["recommended_panel"] = String(goal.get("recommended_panel", ""))
	return goal


func _normalize_goals(value: Variant) -> Array:
	var goals: Array = []
	if not value is Array:
		return goals
	for goal_variant in value:
		goals.append(_normalize_goal(goal_variant))
	return goals
