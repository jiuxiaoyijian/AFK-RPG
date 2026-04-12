extends Node

const ParagonSystem = preload("res://scripts/systems/paragon_system.gd")
const SeasonSystem = preload("res://scripts/systems/season_system.gd")
const HeroProgressionSystem = preload("res://scripts/systems/hero_progression_system.gd")

const SAVE_SLOT_COUNT := 3
const DEFAULT_SAVE_SLOT := 1
const SAVE_PATH_TEMPLATE := "user://desktop_idle_save_%d.json"
const CURRENT_SAVE_VERSION := 4

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
		"hero_progression_state": GameManager.hero_progression_state,
		"skill_loadout_state": GameManager.skill_loadout_state,
		"selected_passives": GameManager.selected_passives,
		"skill_rune_state": GameManager.skill_rune_state,
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

	var loaded_payload: Dictionary = payload
	var saved_version: int = int(loaded_payload.get("save_version", 0))
	if saved_version < CURRENT_SAVE_VERSION:
		loaded_payload = _migrate_payload(loaded_payload, saved_version)

	GameManager.current_chapter_id = String(loaded_payload.get("current_chapter_id", GameManager.current_chapter_id))
	GameManager.current_node_id = String(loaded_payload.get("current_node_id", GameManager.current_node_id))
	GameManager.stable_node_id = String(loaded_payload.get("stable_node_id", GameManager.stable_node_id))
	GameManager.selected_core_skill_id = String(loaded_payload.get("selected_core_skill_id", GameManager.selected_core_skill_id))
	GameManager.hero_progression_state = loaded_payload.get("hero_progression_state", GameManager.hero_progression_state)
	GameManager.skill_loadout_state = loaded_payload.get("skill_loadout_state", GameManager.skill_loadout_state)
	var loaded_selected_passives: Variant = loaded_payload.get("selected_passives", GameManager.selected_passives)
	if loaded_selected_passives is Array:
		GameManager.selected_passives = loaded_selected_passives
	GameManager.skill_rune_state = loaded_payload.get("skill_rune_state", GameManager.skill_rune_state)
	GameManager.current_run_kills = int(loaded_payload.get("current_run_kills", GameManager.current_run_kills))
	GameManager.current_run_clears = int(loaded_payload.get("current_run_clears", GameManager.current_run_clears))
	GameManager.inventory = loaded_payload.get("inventory", GameManager.inventory)

	var loaded_equip: Variant = loaded_payload.get("equipped_items", null)
	if loaded_equip is Dictionary:
		for slot_key in GameManager.EQUIPMENT_SLOT_ORDER:
			if loaded_equip.has(slot_key):
				GameManager.equipped_items[slot_key] = loaded_equip[slot_key]
			else:
				GameManager.equipped_items[slot_key] = {}

	MetaProgressionSystem.load_save_data(loaded_payload)
	LootCodexSystem.load_save_data(loaded_payload)
	DailyGoalSystem.load_save_data(loaded_payload)
	StageEventSystem.load_save_data(loaded_payload)
	GameManager.auto_salvage_below_rarity = String(loaded_payload.get("auto_salvage_below_rarity", GameManager.auto_salvage_below_rarity))
	GameManager.last_loot_summary = String(loaded_payload.get("last_loot_summary", GameManager.last_loot_summary))
	GameManager.last_loot_highlight = loaded_payload.get("last_loot_highlight", GameManager.last_loot_highlight)
	GameManager.martial_codex_state = loaded_payload.get("martial_codex_state", GameManager.martial_codex_state)
	GameManager.set_summary = loaded_payload.get("set_summary", GameManager.set_summary)
	GameManager.rift_state = loaded_payload.get("rift_state", GameManager.rift_state)
	GameManager.gem_state = loaded_payload.get("gem_state", GameManager.gem_state)
	GameManager.paragon_state = loaded_payload.get("paragon_state", GameManager.paragon_state)
	GameManager.season_state = loaded_payload.get("season_state", GameManager.season_state)
	var saved_unix_time: int = int(loaded_payload.get("saved_unix_time", 0))
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
	var hero_state: Dictionary = HeroProgressionSystem.sanitize_state(payload.get("hero_progression_state", {}))
	summary["subtitle"] = "Lv.%d | 香火钱 %d | 背包 %d" % [
		int(hero_state.get("level", 1)),
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


func _migrate_payload(payload: Dictionary, saved_version: int) -> Dictionary:
	var migrated: Dictionary = payload.duplicate(true)
	if saved_version < 4:
		var legacy_core_skill_id: String = String(migrated.get("selected_core_skill_id", "core_whirlwind"))
		var school_id: String = _map_school_from_core_skill(legacy_core_skill_id)
		var hero_state: Dictionary = _build_migrated_hero_state(migrated)
		var skill_state: Dictionary = GameManager._build_default_skill_loadout_state(school_id)
		skill_state.get("active_slots", {})["core"] = legacy_core_skill_id
		var refund_payload: Dictionary = _build_research_refund(migrated.get("research_levels", {}))
		for resource_id_variant in refund_payload.keys():
			var resource_id: String = String(resource_id_variant)
			migrated[resource_id] = int(migrated.get(resource_id, 0)) + int(refund_payload.get(resource_id_variant, 0))
		migrated["hero_progression_state"] = hero_state
		migrated["skill_loadout_state"] = skill_state
		migrated["selected_passives"] = GameManager._build_default_passives_for_school(school_id)
		migrated["skill_rune_state"] = {}
		migrated["research_levels"] = {}
		migrated["save_version"] = CURRENT_SAVE_VERSION
	return migrated


func _build_migrated_hero_state(payload: Dictionary) -> Dictionary:
	var paragon_payload: Dictionary = payload.get("paragon_state", {})
	var paragon_level: int = int(paragon_payload.get("level", 0))
	var level: int = 1
	if paragon_level > 0 or bool(paragon_payload.get("is_unlocked", false)):
		level = HeroProgressionSystem.MAX_HERO_LEVEL
	else:
		level = GameManager.estimate_legacy_level_from_node(String(payload.get("stable_node_id", payload.get("current_node_id", "ch1_n1"))))
	var hero_state: Dictionary = HeroProgressionSystem.create_default_state()
	hero_state["level"] = level
	hero_state["experience"] = 0.0
	return HeroProgressionSystem.sanitize_state(hero_state)


func _build_research_refund(raw_levels: Variant) -> Dictionary:
	var refund := {
		"gold": 0,
		"scrap": 0,
		"core": 0,
		"legend_shard": 0,
	}
	if not raw_levels is Dictionary:
		return refund
	var research_levels: Dictionary = raw_levels
	for node_id_variant in research_levels.keys():
		var node_id: String = String(node_id_variant)
		var current_level: int = int(research_levels.get(node_id_variant, 0))
		if current_level <= 0:
			continue
		var node_data: Dictionary = ConfigDB.get_research_node(node_id)
		for target_level in range(1, current_level + 1):
			for cost_variant in node_data.get("costs", []):
				var cost_entry: Dictionary = cost_variant
				if int(cost_entry.get("level", 0)) != target_level:
					continue
				var resource_id: String = String(cost_entry.get("resource_id", ""))
				if refund.has(resource_id):
					refund[resource_id] += int(cost_entry.get("amount", 0))
				break
	return refund


func _map_school_from_core_skill(skill_id: String) -> String:
	match skill_id:
		"core_deep_wound":
			return "xuejie"
		"core_chain_lightning":
			return "wulei"
		_:
			return "yufeng"


func _emit_loaded_state() -> void:
	EventBus.node_changed.emit(GameManager.current_node_id)
	EventBus.core_skill_changed.emit(GameManager.selected_core_skill_id)
	EventBus.skill_loadout_changed.emit(GameManager.get_skill_screen_state())
	EventBus.hero_level_changed.emit(GameManager.get_hero_progression_summary())
	EventBus.hero_experience_changed.emit(GameManager.get_hero_progression_summary())
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
