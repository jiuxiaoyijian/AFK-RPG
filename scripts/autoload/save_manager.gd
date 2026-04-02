extends Node

const ParagonSystem = preload("res://scripts/systems/paragon_system.gd")
const SeasonSystem = preload("res://scripts/systems/season_system.gd")

const SAVE_SLOT_COUNT := 3
const DEFAULT_SAVE_SLOT := 1
const SAVE_PATH_TEMPLATE := "user://desktop_idle_save_%d.json"
const CURRENT_SAVE_VERSION := 3

var active_save_slot: int = DEFAULT_SAVE_SLOT


func _ready() -> void:
	active_save_slot = DEFAULT_SAVE_SLOT


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_quick_save"):
		save_game(active_save_slot)
		EventBus.combat_state_changed.emit("手动存档完成 [档位 %d]" % active_save_slot)
	elif event.is_action_pressed("ui_quick_load"):
		load_game(active_save_slot)
		EventBus.combat_state_changed.emit("手动读档完成 [档位 %d]" % active_save_slot)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game(active_save_slot)


func save_game(slot: int = DEFAULT_SAVE_SLOT) -> bool:
	if not _is_valid_slot(slot):
		return false
	active_save_slot = slot
	var payload: Dictionary = {
		"save_version": CURRENT_SAVE_VERSION,
		"current_chapter_id": GameManager.current_chapter_id,
		"current_node_id": GameManager.current_node_id,
		"stable_node_id": GameManager.stable_node_id,
		"selected_core_skill_id": GameManager.selected_core_skill_id,
		"current_run_kills": GameManager.current_run_kills,
		"current_run_clears": GameManager.current_run_clears,
		"inventory": GameManager.inventory,
		"equipped_items": GameManager.equipped_items,
		"auto_salvage_below_rarity": GameManager.auto_salvage_below_rarity,
		"last_loot_summary": GameManager.last_loot_summary,
		"last_loot_highlight": GameManager.last_loot_highlight,
		"martial_codex_state": GameManager.martial_codex_state,
		"set_summary": GameManager.set_summary,
		"rift_state": GameManager.rift_state,
		"gem_state": GameManager.gem_state,
		"paragon_state": GameManager.paragon_state,
		"season_state": GameManager.season_state,
		"saved_unix_time": Time.get_unix_time_from_system(),
	}
	payload.merge(MetaProgressionSystem.build_save_data(), true)
	payload.merge(LootCodexSystem.build_save_data(), true)
	payload.merge(DailyGoalSystem.build_save_data(), true)
	payload.merge(StageEventSystem.build_save_data(), true)
	var file: FileAccess = FileAccess.open(_get_save_path(slot), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true


func load_game(slot: int = DEFAULT_SAVE_SLOT) -> bool:
	if not _is_valid_slot(slot):
		return false
	var save_path: String = _get_save_path(slot)
	if not FileAccess.file_exists(save_path):
		return false
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return false
	var text: String = file.get_as_text()
	file.close()
	var payload: Variant = JSON.parse_string(text)
	if not payload is Dictionary:
		return false
	active_save_slot = slot

	var saved_version: int = int(payload.get("save_version", 0))
	if saved_version < CURRENT_SAVE_VERSION:
		push_warning("SaveManager: 检测到旧版存档 (v%d < v%d)，执行清空重置" % [saved_version, CURRENT_SAVE_VERSION])
		_wipe_save(slot)
		return false

	GameManager.current_chapter_id = String(payload.get("current_chapter_id", GameManager.current_chapter_id))
	GameManager.current_node_id = String(payload.get("current_node_id", GameManager.current_node_id))
	GameManager.stable_node_id = String(payload.get("stable_node_id", GameManager.stable_node_id))
	GameManager.selected_core_skill_id = String(payload.get("selected_core_skill_id", GameManager.selected_core_skill_id))
	GameManager.current_run_kills = int(payload.get("current_run_kills", GameManager.current_run_kills))
	GameManager.current_run_clears = int(payload.get("current_run_clears", GameManager.current_run_clears))
	GameManager.inventory = payload.get("inventory", GameManager.inventory)

	var loaded_equip: Variant = payload.get("equipped_items", null)
	if loaded_equip is Dictionary:
		for slot_key in GameManager.EQUIPMENT_SLOT_ORDER:
			if loaded_equip.has(slot_key):
				GameManager.equipped_items[slot_key] = loaded_equip[slot_key]
			else:
				GameManager.equipped_items[slot_key] = {}

	MetaProgressionSystem.load_save_data(payload)
	LootCodexSystem.load_save_data(payload)
	DailyGoalSystem.load_save_data(payload)
	StageEventSystem.load_save_data(payload)
	GameManager.auto_salvage_below_rarity = String(payload.get("auto_salvage_below_rarity", GameManager.auto_salvage_below_rarity))
	GameManager.last_loot_summary = String(payload.get("last_loot_summary", GameManager.last_loot_summary))
	GameManager.last_loot_highlight = payload.get("last_loot_highlight", GameManager.last_loot_highlight)
	GameManager.martial_codex_state = payload.get("martial_codex_state", GameManager.martial_codex_state)
	GameManager.set_summary = payload.get("set_summary", GameManager.set_summary)
	GameManager.rift_state = payload.get("rift_state", GameManager.rift_state)
	GameManager.gem_state = payload.get("gem_state", GameManager.gem_state)
	GameManager.paragon_state = payload.get("paragon_state", GameManager.paragon_state)
	GameManager.season_state = payload.get("season_state", GameManager.season_state)
	var saved_unix_time: int = int(payload.get("saved_unix_time", 0))
	GameManager.refresh_build_state(false)
	_emit_loaded_state()
	OfflineSystem.process_saved_timestamp(saved_unix_time)
	return true


func get_save_slot_count() -> int:
	return SAVE_SLOT_COUNT


func get_active_save_slot() -> int:
	return active_save_slot


func set_active_save_slot(slot: int) -> bool:
	if not _is_valid_slot(slot):
		return false
	active_save_slot = slot
	return true


func start_new_game(slot: int = DEFAULT_SAVE_SLOT) -> bool:
	if not _is_valid_slot(slot):
		return false
	active_save_slot = slot
	GameManager.reset_for_public_demo()
	save_game(slot)
	return true


func delete_save_slot(slot: int) -> bool:
	if not _is_valid_slot(slot):
		return false
	_wipe_save(slot)
	return true


func get_save_slot_summary(slot: int) -> Dictionary:
	var summary := {
		"slot": slot,
		"has_save": false,
		"title": "空档位",
		"subtitle": "尚未创建试玩进度",
		"saved_unix_time": 0,
	}
	if not _is_valid_slot(slot):
		return summary
	var save_path: String = _get_save_path(slot)
	if not FileAccess.file_exists(save_path):
		return summary
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return summary
	var text: String = file.get_as_text()
	file.close()
	var payload: Variant = JSON.parse_string(text)
	if not payload is Dictionary:
		return summary
	var node_id: String = String(payload.get("current_node_id", "ch1_n1"))
	var chapter_id: String = String(payload.get("current_chapter_id", "chapter_1"))
	var chapter_name: String = String(ConfigDB.get_chapter(chapter_id).get("name", chapter_id))
	var inventory_entries: Array = payload.get("inventory", [])
	summary["has_save"] = true
	summary["title"] = "%s · %s" % [chapter_name, ConfigDB.get_chapter_node_name(node_id)]
	summary["subtitle"] = "香火钱 %d | 背包 %d" % [
		int(payload.get("gold", 0)),
		inventory_entries.size(),
	]
	summary["saved_unix_time"] = int(payload.get("saved_unix_time", 0))
	return summary


func get_save_slot_path(slot: int) -> String:
	return _get_save_path(slot)


func has_save_slot(slot: int) -> bool:
	if not _is_valid_slot(slot):
		return false
	return FileAccess.file_exists(_get_save_path(slot))


func _get_save_path(slot: int) -> String:
	return SAVE_PATH_TEMPLATE % slot


func _is_valid_slot(slot: int) -> bool:
	return slot >= 1 and slot <= SAVE_SLOT_COUNT


func _wipe_save(slot: int) -> void:
	var path: String = _get_save_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	push_warning("SaveManager: 已删除档位 %d 的旧版存档" % slot)


func _emit_loaded_state() -> void:
	EventBus.node_changed.emit(GameManager.current_node_id)
	EventBus.core_skill_changed.emit(GameManager.selected_core_skill_id)
	EventBus.resources_changed.emit()
	EventBus.equipment_changed.emit()
	EventBus.loot_summary_changed.emit(GameManager.last_loot_summary)
	EventBus.inventory_changed.emit()
	EventBus.research_changed.emit()
	EventBus.codex_changed.emit()
	EventBus.loot_target_changed.emit()
	EventBus.daily_goals_changed.emit()
	EventBus.set_bonus_changed.emit(GameManager.set_summary)
	EventBus.martial_codex_changed.emit(GameManager.get_martial_codex_runtime_state())
	EventBus.paragon_changed.emit(ParagonSystem.build_runtime_summary(GameManager.paragon_state))
	EventBus.season_reborn.emit(SeasonSystem.build_runtime_summary(GameManager.season_state, GameManager._build_progression_context()))
