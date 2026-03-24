extends Node

const SAVE_SLOT_COUNT := 3
const DEFAULT_SAVE_SLOT := 1
const SAVE_PATH_TEMPLATE := "user://desktop_idle_save_%d.json"
const CURRENT_SAVE_VERSION := 2


func _ready() -> void:
	call_deferred("load_game", DEFAULT_SAVE_SLOT)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_quick_save"):
		save_game(DEFAULT_SAVE_SLOT)
		EventBus.combat_state_changed.emit("手动存档完成 [档位 %d]" % DEFAULT_SAVE_SLOT)
	elif event.is_action_pressed("ui_quick_load"):
		load_game(DEFAULT_SAVE_SLOT)
		EventBus.combat_state_changed.emit("手动读档完成 [档位 %d]" % DEFAULT_SAVE_SLOT)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game(DEFAULT_SAVE_SLOT)


func save_game(slot: int = DEFAULT_SAVE_SLOT) -> bool:
	if not _is_valid_slot(slot):
		return false
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
	var saved_unix_time: int = int(payload.get("saved_unix_time", 0))
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
	OfflineSystem.process_saved_timestamp(saved_unix_time)
	return true


func get_save_slot_count() -> int:
	return SAVE_SLOT_COUNT


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
