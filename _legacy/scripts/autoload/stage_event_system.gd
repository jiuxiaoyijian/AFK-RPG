extends Node

const STAGE_EVENT_STATE_KEY := "stage_event_state"

var cleared_boss_node_ids: Array[String] = []
var unlocked_chapter_ids: Array[String] = []
var celebrated_research_keys: Array[String] = []
var celebrated_legendary_ids: Array[String] = []
var tracked_target_completed_ids: Array[String] = []


func _ready() -> void:
	EventBus.config_loaded.connect(_on_config_loaded)
	EventBus.battle_finished.connect(_on_battle_finished)
	EventBus.research_upgraded.connect(_on_research_upgraded)
	EventBus.legendary_discovered.connect(_on_legendary_discovered)
	if not ConfigDB.chapter_nodes.is_empty():
		_on_config_loaded()


func build_save_data() -> Dictionary:
	return {
		STAGE_EVENT_STATE_KEY: {
			"cleared_boss_node_ids": cleared_boss_node_ids,
			"unlocked_chapter_ids": unlocked_chapter_ids,
			"celebrated_research_keys": celebrated_research_keys,
			"celebrated_legendary_ids": celebrated_legendary_ids,
			"tracked_target_completed_ids": tracked_target_completed_ids,
		}
	}


func load_save_data(payload: Dictionary) -> void:
	var state_payload: Variant = payload.get(STAGE_EVENT_STATE_KEY, {})
	if state_payload is Dictionary:
		cleared_boss_node_ids = _variant_to_string_array(state_payload.get("cleared_boss_node_ids", cleared_boss_node_ids))
		unlocked_chapter_ids = _variant_to_string_array(state_payload.get("unlocked_chapter_ids", unlocked_chapter_ids))
		celebrated_research_keys = _variant_to_string_array(state_payload.get("celebrated_research_keys", celebrated_research_keys))
		celebrated_legendary_ids = _variant_to_string_array(state_payload.get("celebrated_legendary_ids", celebrated_legendary_ids))
		tracked_target_completed_ids = _variant_to_string_array(state_payload.get("tracked_target_completed_ids", tracked_target_completed_ids))
	_bootstrap_progress_state()


func reset_runtime_state() -> void:
	cleared_boss_node_ids.clear()
	unlocked_chapter_ids.clear()
	celebrated_research_keys.clear()
	celebrated_legendary_ids.clear()
	tracked_target_completed_ids.clear()
	_bootstrap_progress_state()


func _on_config_loaded() -> void:
	_bootstrap_progress_state()


func _on_battle_finished(node_id: String, success: bool) -> void:
	if not success:
		return
	var node_data: Dictionary = ConfigDB.get_chapter_node(node_id)
	if String(node_data.get("node_type", "")) != "boss":
		return
	if not _register_unique(cleared_boss_node_ids, node_id):
		return

	var chapter_id: String = String(node_data.get("chapter_id", ""))
	var chapter_data: Dictionary = ConfigDB.get_chapter(chapter_id)
	var boss_name: String = _get_node_event_name(node_id)
	_queue_event({
		"event_type": "boss_first_clear",
		"title": "首诛",
		"highlight": "首诛 %s" % boss_name,
		"content_lines": [
			"你已击败 %s。" % boss_name,
			"当前探境 %s 已被打穿，主线推进进入下一阶段。" % String(chapter_data.get("name", chapter_id)),
			"这是本轮最明确的一次破局。",
		],
		"goal_lines": _build_default_goal_lines(),
		"boss_style": true,
	})

	var next_chapter_id: String = String(chapter_data.get("next_chapter_id", ""))
	if next_chapter_id.is_empty():
		return
	if not _register_unique(unlocked_chapter_ids, next_chapter_id):
		return
	var next_chapter: Dictionary = ConfigDB.get_chapter(next_chapter_id)
	_queue_event({
		"event_type": "chapter_unlock",
		"title": "探境已开",
		"highlight": "已开启 %s" % String(next_chapter.get("name", next_chapter_id)),
		"content_lines": [
			"新的探境区域已经开放。",
			"探境: %s" % String(next_chapter.get("name", next_chapter_id)),
			"建议先打通首节点，再判断是继续探境还是回刷道统核心件。",
		],
		"goal_lines": _build_default_goal_lines(),
		"boss_style": false,
	})


func _on_research_upgraded(node_id: String, new_level: int) -> void:
	var research_node: Dictionary = ConfigDB.get_research_node(node_id)
	if research_node.is_empty():
		return
	var max_level: int = int(research_node.get("max_level", 1))
	var milestone_type: String = ""
	if new_level == 1:
		milestone_type = "unlock"
	elif new_level >= max_level:
		milestone_type = "max"
	else:
		return

	var celebrate_key: String = "%s@%s" % [node_id, milestone_type]
	if not _register_unique(celebrated_research_keys, celebrate_key):
		return

	var milestone_label: String = "悟道初成" if milestone_type == "unlock" else "悟道圆满"
	_queue_event({
		"event_type": "research_milestone",
		"title": milestone_label,
		"highlight": "%s: %s" % [milestone_label, String(research_node.get("name", node_id))],
		"content_lines": [
			"悟道节点 %s 已达到关键阶段。" % String(research_node.get("name", node_id)),
			"当前等级: Lv.%d/%d" % [new_level, max_level],
			"效果方向: %s" % String(research_node.get("description", "")),
		],
		"goal_lines": _build_default_goal_lines(),
		"boss_style": false,
	})


func _on_legendary_discovered(legendary_affix_id: String, legendary_name: String, is_tracked_target: bool) -> void:
	if _register_unique(celebrated_legendary_ids, legendary_affix_id):
		_queue_event({
			"event_type": "legendary_first_find",
			"title": "异宝现世",
			"highlight": "首次得见 %s" % legendary_name,
			"content_lines": [
				"新的异宝真意已进入你的道统池。",
				"目标真意: %s" % legendary_name,
				"记得回背包和异闻录确认是否要围绕它调整道统。",
			],
			"goal_lines": _build_default_goal_lines(),
			"boss_style": true,
		})

	if not is_tracked_target:
		return
	if not _register_unique(tracked_target_completed_ids, legendary_affix_id):
		return
	_queue_event({
		"event_type": "tracked_target_complete",
		"title": "机缘已成",
		"highlight": "已达成机缘追踪 %s" % legendary_name,
		"content_lines": [
			"当前追踪异宝已经首次到手。",
			"目标件: %s" % legendary_name,
			"建议检查当前道统缺口，再决定是否切换到下一件机缘目标。",
		],
		"goal_lines": _build_default_goal_lines(),
		"boss_style": true,
	})


func _queue_event(event_data: Dictionary) -> void:
	EventBus.stage_event_ready.emit(event_data)


func _build_default_goal_lines() -> Array[String]:
	var build_advice: Dictionary = GameManager.get_build_advice_data()
	return [
		String(DailyGoalSystem.get_next_step_summary()),
		"道统缺口: %s" % String(build_advice.get("gap_summary", "继续补当前道统核心属性")),
		String(build_advice.get("next_target_line", "下一件: 继续追当前目标件")),
	]


func _bootstrap_progress_state() -> void:
	if ConfigDB.chapters.is_empty():
		return
	var current_order: int = int(ConfigDB.get_chapter(GameManager.current_chapter_id).get("order", 1))
	for chapter_variant in ConfigDB.chapters.values():
		var chapter: Dictionary = chapter_variant
		var chapter_id: String = String(chapter.get("id", ""))
		var chapter_order: int = int(chapter.get("order", 999))
		if chapter_order <= current_order:
			_register_unique(unlocked_chapter_ids, chapter_id)
		if chapter_order < current_order:
			var boss_node_id: String = _get_chapter_boss_node_id(chapter_id)
			if not boss_node_id.is_empty():
				_register_unique(cleared_boss_node_ids, boss_node_id)
	var stable_node: Dictionary = ConfigDB.get_chapter_node(GameManager.stable_node_id)
	if String(stable_node.get("node_type", "")) == "boss":
		_register_unique(cleared_boss_node_ids, String(stable_node.get("id", "")))


func _get_chapter_boss_node_id(chapter_id: String) -> String:
	var chapter: Dictionary = ConfigDB.get_chapter(chapter_id)
	for node_id_variant in chapter.get("node_ids", []):
		var node_id: String = String(node_id_variant)
		var node_data: Dictionary = ConfigDB.get_chapter_node(node_id)
		if String(node_data.get("node_type", "")) == "boss":
			return node_id
	return ""


func _get_node_event_name(node_id: String) -> String:
	var node_data: Dictionary = ConfigDB.get_chapter_node(node_id)
	if node_data.is_empty():
		return node_id
	var pool_data: Dictionary = ConfigDB.get_enemy_pool(String(node_data.get("enemy_pool_id", "")))
	var enemy_ids: Array = pool_data.get("enemy_ids", [])
	if not enemy_ids.is_empty():
		var enemy_data: Dictionary = ConfigDB.get_enemy(String(enemy_ids[0]))
		var enemy_name: String = String(enemy_data.get("name", ""))
		if not enemy_name.is_empty():
			return enemy_name
	return "%s 首领" % String(node_data.get("id", node_id))


func _register_unique(target: Array[String], value: String) -> bool:
	if value.is_empty() or target.has(value):
		return false
	target.append(value)
	return true


func _variant_to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	for entry_variant in value:
		var entry: String = String(entry_variant)
		if entry.is_empty() or result.has(entry):
			continue
		result.append(entry)
	return result
