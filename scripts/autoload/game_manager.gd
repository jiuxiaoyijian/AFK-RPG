extends Node

const BuildQueryService = preload("res://scripts/utils/build_query_service.gd")
const CubeSystem = preload("res://scripts/systems/cube_system.gd")
const CubeViewModelService = preload("res://scripts/utils/cube_view_model_service.gd")
const EquipmentViewModelService = preload("res://scripts/utils/equipment_view_model_service.gd")
const InventoryViewModelService = preload("res://scripts/utils/inventory_view_model_service.gd")
const ItemPresentationService = preload("res://scripts/utils/item_presentation_service.gd")
const LootRuleService = preload("res://scripts/utils/loot_rule_service.gd")
const MartialCodexSystem = preload("res://scripts/systems/martial_codex_system.gd")
const SetSystem = preload("res://scripts/systems/set_system.gd")
const RiftSystem = preload("res://scripts/systems/rift_system.gd")
const GemSystem = preload("res://scripts/systems/gem_system.gd")
const ParagonSystem = preload("res://scripts/systems/paragon_system.gd")
const SeasonSystem = preload("res://scripts/systems/season_system.gd")

const AVAILABLE_CORE_SKILLS := [
	"core_whirlwind",
	"core_deep_wound",
	"core_chain_lightning",
]
const BUILD_ARCHETYPE_PROFILES := {
	"whirlwind": {
		"display_name": "御风刀",
		"phase_text": "先成型风痕范围和攻速，再补武学爆发。",
		"new_player_summary": "优先补风痕范围和攻速，站稳后再拉武学伤害。",
		"primary_stats": [
			{
				"stat_key": "whirlwind_radius_percent",
				"label": "旋风范围",
				"category": "function",
				"category_label": "功能词条",
				"target_base": 0.16,
				"target_per_chapter": 0.08,
				"affix_ids": ["affix_whirlwind_radius", "affix_elite_vortex"],
				"legendary_ids": ["legend_whirlwind_eye", "legend_boss_maelstrom_crown"],
			},
			{
				"stat_key": "attack_speed_percent",
				"label": "攻速",
				"category": "damage",
				"category_label": "伤害",
				"target_base": 0.22,
				"target_per_chapter": 0.08,
				"affix_ids": ["affix_attack_speed"],
				"legendary_ids": ["legend_time_fissure", "legend_boss_tyrant_shell"],
			},
			{
				"stat_key": "core_damage_percent",
				"label": "武学伤害",
				"category": "damage",
				"category_label": "伤害",
				"target_base": 0.24,
				"target_per_chapter": 0.08,
				"affix_ids": ["affix_core_damage", "affix_whirlwind_power"],
				"legendary_ids": ["legend_whirlwind_eye", "legend_boss_maelstrom_crown"],
			},
		],
		"recommended_base_ids": ["gloves_static_grips", "gloves_hunter_wrap", "weapon_saw_cleaver"],
	},
	"bleed": {
		"display_name": "血劫手",
		"phase_text": "先补血劫倍率和断命线，再抬高单点爆发。",
		"new_player_summary": "先让血劫与断命线成型，再补攻击与武学伤害。",
		"primary_stats": [
			{
				"stat_key": "bleed_dot_percent",
				"label": "流血倍率",
				"category": "damage",
				"category_label": "伤害",
				"target_base": 0.22,
				"target_per_chapter": 0.10,
				"affix_ids": ["affix_bleed_dot"],
				"legendary_ids": ["legend_blood_edict", "legend_boss_crimson_decree"],
			},
			{
				"stat_key": "execute_threshold",
				"label": "处决线",
				"category": "function",
				"category_label": "功能词条",
				"target_base": 0.05,
				"target_per_chapter": 0.03,
				"affix_ids": ["affix_elite_bloodhunt"],
				"legendary_ids": ["legend_blood_edict", "legend_boss_crimson_decree"],
			},
			{
				"stat_key": "core_damage_percent",
				"label": "武学伤害",
				"category": "damage",
				"category_label": "伤害",
				"target_base": 0.26,
				"target_per_chapter": 0.10,
				"affix_ids": ["affix_core_damage", "affix_bleed_power"],
				"legendary_ids": ["legend_blood_edict", "legend_boss_crimson_decree"],
			},
		],
		"recommended_base_ids": ["helmet_war_mask", "weapon_saw_cleaver", "helmet_scout_hood"],
	},
	"chain_lightning": {
		"display_name": "五雷掌",
		"phase_text": "先把引雷次数拉起来，再追攻速和雷痕伤害。",
		"new_player_summary": "优先补引雷次数和攻速，再拉高雷痕与武学伤害。",
		"primary_stats": [
			{
				"stat_key": "chain_count_bonus",
				"label": "连锁次数",
				"category": "function",
				"category_label": "功能词条",
				"target_base": 1.0,
				"target_per_chapter": 1.0,
				"affix_ids": ["affix_chain_count"],
				"legendary_ids": ["legend_storm_matrix", "legend_boss_thunder_throne"],
			},
			{
				"stat_key": "attack_speed_percent",
				"label": "攻速",
				"category": "damage",
				"category_label": "伤害",
				"target_base": 0.20,
				"target_per_chapter": 0.08,
				"affix_ids": ["affix_chain_speed", "affix_attack_speed"],
				"legendary_ids": ["legend_time_fissure", "legend_boss_tyrant_shell"],
			},
			{
				"stat_key": "chain_damage_percent",
				"label": "连锁伤害",
				"category": "damage",
				"category_label": "伤害",
				"target_base": 0.22,
				"target_per_chapter": 0.10,
				"affix_ids": ["affix_chain_damage", "affix_elite_overcharge"],
				"legendary_ids": ["legend_storm_matrix", "legend_boss_thunder_throne"],
			},
		],
		"recommended_base_ids": ["weapon_tempest_emitter", "gloves_static_grips", "weapon_arc_orb"],
	},
}

var current_chapter_id: String = "chapter_1"
var current_node_id: String = "ch1_n1"
var stable_node_id: String = "ch1_n1"
var selected_core_skill_id: String = "core_whirlwind"

var gold: int = 0
var scrap: int = 0
var core: int = 0
var legend_shard: int = 0
var current_run_kills: int = 0
var current_run_clears: int = 0
var inventory: Array = []
var equipped_items: Dictionary = {
	"weapon": {},
	"helmet": {},
	"armor": {},
	"gloves": {},
	"legs": {},
	"boots": {},
	"accessory1": {},
	"accessory2": {},
	"belt": {},
}
const EQUIPMENT_SLOT_ORDER := ["weapon", "helmet", "armor", "gloves", "legs", "boots", "accessory1", "accessory2", "belt"]
const RARITY_DISPLAY_NAMES := {
	"common": "凡品",
	"uncommon": "精良",
	"rare": "玄品",
	"epic": "真意",
	"set": "传承",
	"legendary": "真意",
	"ancient": "上古真意",
}
const RARITY_COLORS := {
	"common": Color(0.62, 0.62, 0.62),
	"uncommon": Color(0.30, 0.61, 1.0),
	"rare": Color(1.0, 0.84, 0.29),
	"epic": Color(1.0, 0.55, 0.0),
	"set": Color(0.0, 0.85, 0.35),
	"legendary": Color(1.0, 0.58, 0.18),
	"ancient": Color(1.0, 0.82, 0.18),
}
var research_levels: Dictionary = {}
var auto_salvage_below_rarity: String = "rare"
var last_loot_summary: String = "暂无掉落"
var last_loot_highlight: Dictionary = {}
var martial_codex_state: Dictionary = MartialCodexSystem.create_default_state()
var set_summary: Dictionary = {
	"counts": {},
	"active_sets": [],
	"total_bonuses": {},
	"primary_active_set": {},
}
var rift_state: Dictionary = RiftSystem.create_default_state()
var gem_state: Dictionary = GemSystem.create_default_state()
var paragon_state: Dictionary = ParagonSystem.create_default_state()
var season_state: Dictionary = SeasonSystem.create_default_state()
var pending_ui_focus: Dictionary = {}
const SALVAGE_THRESHOLDS := ["common", "uncommon", "rare", "epic", "set", "legendary", "ancient"]
const RESEARCH_META_KEYS := {
	"offline_efficiency_bonus": 0.0,
	"max_offline_seconds_bonus": 0.0,
	"gold_gain_percent": 0.0,
	"scrap_gain_percent": 0.0,
	"core_gain_percent": 0.0,
	"legend_shard_gain_percent": 0.0,
	"salvage_scrap_percent": 0.0,
}


func _ready() -> void:
	EventBus.config_loaded.connect(_on_config_loaded)
	if not ConfigDB.chapter_nodes.is_empty():
		_on_config_loaded()


func _on_config_loaded() -> void:
	if current_node_id.is_empty():
		current_node_id = ConfigDB.get_chapter_first_node(current_chapter_id)
	if stable_node_id.is_empty():
		stable_node_id = current_node_id
	refresh_build_state(false)
	EventBus.node_changed.emit(current_node_id)
	EventBus.core_skill_changed.emit(selected_core_skill_id)
	EventBus.resources_changed.emit()
	EventBus.equipment_changed.emit()
	EventBus.loot_summary_changed.emit(last_loot_summary)
	EventBus.inventory_changed.emit()
	EventBus.research_changed.emit()
	EventBus.set_bonus_changed.emit(set_summary)
	EventBus.martial_codex_changed.emit(get_martial_codex_runtime_state())


func get_selected_core_skill() -> Dictionary:
	return ConfigDB.get_core_skill(selected_core_skill_id)


func get_selected_archetype_tags() -> Array:
	return get_selected_core_skill().get("archetype_tags", [])


func select_core_skill(skill_id: String) -> void:
	if not AVAILABLE_CORE_SKILLS.has(skill_id):
		return
	if ConfigDB.get_core_skill(skill_id).is_empty():
		return
	selected_core_skill_id = skill_id
	EventBus.core_skill_changed.emit(skill_id)


func grant_rewards(reward_entries: Array) -> Array:
	return MetaProgressionSystem.grant_rewards(reward_entries)


func get_rarity_rank(rarity: String) -> int:
	match rarity:
		"common":
			return 1
		"uncommon":
			return 2
		"rare":
			return 3
		"epic":
			return 4
		"set":
			return 5
		"legendary":
			return 6
		"ancient":
			return 7
		_:
			return 0


func get_rarity_display_name(rarity: String) -> String:
	return RARITY_DISPLAY_NAMES.get(rarity, rarity)


func get_rarity_color(rarity: String) -> Color:
	return RARITY_COLORS.get(rarity, Color.WHITE)


func get_total_combat_bonuses() -> Dictionary:
	return BuildQueryService.get_total_combat_bonuses(
		equipped_items,
		set_summary,
		martial_codex_state,
		gem_state,
		paragon_state,
		season_state
	)


func get_build_advice_data() -> Dictionary:
	return BuildQueryService.get_build_advice_data()


func get_progression_hub_summary() -> Dictionary:
	_ensure_progression_unlocks(false)
	var upgradable_count: int = 0
	for research_node_variant in MetaProgressionSystem.get_research_items("all"):
		var research_node: Dictionary = research_node_variant
		var state: Dictionary = MetaProgressionSystem.can_upgrade_research(String(research_node.get("id", "")))
		if bool(state.get("ok", false)):
			upgradable_count += 1
	var paragon_summary: Dictionary = ParagonSystem.build_runtime_summary(paragon_state)
	var season_summary: Dictionary = SeasonSystem.build_runtime_summary(season_state, _build_progression_context())
	var paragon_status_text: String = String(paragon_summary.get("status", "未解锁"))
	if bool(paragon_summary.get("is_unlocked", false)):
		paragon_status_text = "Lv.%d / 点数 %d" % [
			int(paragon_summary.get("level", 0)),
			int(paragon_summary.get("available_points", 0)),
		]
	var season_status_text: String = String(season_summary.get("status", "未满足条件"))
	if bool(season_summary.get("can_rebirth", false)):
		season_status_text = "已轮回 %d 次" % int(season_summary.get("rebirth_count", 0))
	return {
		"title": "成长中心",
		"research_summary": "武学参悟: 可提升 %d 项" % upgradable_count,
		"paragon_summary": paragon_status_text,
		"season_summary": season_status_text,
		"summary_text": "武学参悟: 可提升 %d 项 | 宗师修为: %s | 重入江湖: %s" % [
			upgradable_count,
			paragon_status_text,
			season_status_text,
		],
		"paragon": paragon_summary,
		"season": season_summary,
	}


func get_analysis_hub_summary() -> Dictionary:
	var rift_summary: Dictionary = get_rift_runtime_summary()
	var gem_summary: Dictionary = get_gem_runtime_state()
	var recent_results: Array = rift_summary.get("recent_results", [])
	var latest_result: String = "暂无秘境结算"
	if not recent_results.is_empty():
		var latest_entry: Dictionary = recent_results[0]
		latest_result = "Lv.%d | %s" % [
			int(latest_entry.get("level", 0)),
			String(latest_entry.get("summary", "暂无记录")),
		]
	return {
		"title": "推演与秘境",
		"analysis_summary": "机缘推演: 当前节点 %s" % ConfigDB.get_chapter_node_short_label(current_node_id),
		"rift_summary": "试剑秘境: 最高 Lv.%d | %s" % [
			int(rift_summary.get("highest_level", 0)),
			String(rift_summary.get("key_summary", "暂无试剑令")),
		],
		"results_summary": "最近结算: %s | 宝石 %d 种" % [
			latest_result,
			gem_summary.get("entries", []).size(),
		],
		"summary_text": "机缘推演: %s | 试剑秘境: 最高 Lv.%d | 宝石 %d 种" % [
			ConfigDB.get_chapter_node_short_label(current_node_id),
			int(rift_summary.get("highest_level", 0)),
			gem_summary.get("entries", []).size(),
		],
	}


func get_main_hud_state() -> Dictionary:
	var skill_data: Dictionary = get_selected_core_skill()
	var profile_id: String = String(skill_data.get("build_profile_id", ""))
	var build_profile: Dictionary = BUILD_ARCHETYPE_PROFILES.get(profile_id, {})
	var goal_data: Dictionary = DailyGoalSystem.get_daily_goal_data()
	var primary_goal: Dictionary = goal_data.get("primary_goal", {})
	var chapter_data: Dictionary = ConfigDB.get_chapter(current_chapter_id)
	var node_data: Dictionary = ConfigDB.get_chapter_node(current_node_id)
	var codex_runtime: Dictionary = get_martial_codex_runtime_state()
	var active_codex_count: int = 0
	for slot_id in ["weapon", "armor", "accessory"]:
		if not String(codex_runtime.get("active_slots", {}).get(slot_id, "")).is_empty():
			active_codex_count += 1
	var primary_set: Dictionary = set_summary.get("primary_active_set", {})
	var set_summary_text: String = "传承未激活"
	if not primary_set.is_empty():
		set_summary_text = "%s %d/6" % [
			String(primary_set.get("name", "传承")),
			int(primary_set.get("piece_count", 0)),
		]
	return {
		"player_header": {
			"name": "无名侠客",
			"archetype": "流派: %s" % String(build_profile.get("display_name", skill_data.get("name", "江湖弟子"))),
			"resource_text": "香火钱 %d | 祠灰 %d | 灵核 %d | 真意残片 %d | 背包 %d" % [
				MetaProgressionSystem.gold,
				MetaProgressionSystem.scrap,
				MetaProgressionSystem.core,
				MetaProgressionSystem.legend_shard,
				get_inventory_count(),
			],
			"portrait_path": "res://assets/generated/afk_rpg_formal/characters/disciple_male_portrait.png",
		},
		"stage_header": {
			"title": "%s · %s" % [
				String(chapter_data.get("name", current_chapter_id)),
				ConfigDB.get_chapter_node_name(current_node_id),
			],
			"subtitle": "节点类型: %s" % ConfigDB.get_node_type_display_name(String(node_data.get("node_type", "normal"))),
			"run_text": "击杀 %d | 清图 %d" % [current_run_kills, current_run_clears],
			"node_short_label": ConfigDB.get_chapter_node_short_label(current_node_id),
		},
		"objective_summary": {
			"title": "任务目标",
			"goal_text": String(primary_goal.get("title", "暂无目标")),
			"progress_text": String(primary_goal.get("progress_text", "--")),
			"cta_text": String(primary_goal.get("cta_text", "继续推进主目标")),
			"next_step_text": String(goal_data.get("next_step_summary", "继续推进当前目标")),
		},
		"loot_feed": {
			"lines": get_loot_summary_lines(5),
			"highlight": get_loot_highlight(),
			"summary_text": last_loot_summary,
		},
		"combat_bar": {
			"core_skill_id": selected_core_skill_id,
			"core_skill_name": String(skill_data.get("name", selected_core_skill_id)),
			"set_summary_text": set_summary_text,
			"codex_summary_text": "武学秘录 %d/3 已激活" % active_codex_count,
			"focus_text": get_current_drop_focus(),
		},
		"entry_badges": {
			"inventory_count": get_inventory_count(),
			"research_summary": get_progression_hub_summary().get("research_summary", ""),
			"analysis_summary": get_analysis_hub_summary().get("rift_summary", ""),
		},
	}


func get_martial_codex_runtime_state() -> Dictionary:
	return MartialCodexSystem.build_runtime_state(martial_codex_state)


func get_gem_runtime_state() -> Dictionary:
	return GemSystem.build_runtime_state(gem_state)


func get_rift_runtime_summary() -> Dictionary:
	return RiftSystem.build_runtime_summary(rift_state)


func is_rift_active() -> bool:
	return not RiftSystem.sanitize_state(rift_state).get("active_run", {}).is_empty()


func get_active_combat_node_id() -> String:
	if not is_rift_active():
		return current_node_id
	return String(RiftSystem.sanitize_state(rift_state).get("active_run", {}).get("base_node_id", current_node_id))


func start_rift_run(level: int) -> Dictionary:
	var base_node_id: String = stable_node_id if not stable_node_id.is_empty() else current_node_id
	var base_node_data: Dictionary = ConfigDB.get_chapter_node(base_node_id)
	var result: Dictionary = RiftSystem.start_run(
		rift_state,
		level,
		base_node_id,
		int(base_node_data.get("time_limit", RiftSystem.DEFAULT_TIME_LIMIT))
	)
	if not bool(result.get("ok", false)):
		return result
	rift_state = result.get("state", rift_state)
	EventBus.rift_run_started.emit(get_rift_runtime_summary())
	EventBus.combat_state_changed.emit("试剑秘境 Lv.%d 已开启" % level)
	return result


func finish_rift_run(success: bool) -> Dictionary:
	var active_run: Dictionary = RiftSystem.sanitize_state(rift_state).get("active_run", {}).duplicate(true)
	var result: Dictionary = RiftSystem.finish_run(rift_state, success)
	if not bool(result.get("ok", false)):
		return result

	rift_state = result.get("state", rift_state)
	var paragon_summary_text: String = ""
	var cleared_level: int = int(result.get("cleared_level", 0))
	var paragon_base_experience: float = float(cleared_level) * (5.0 if success else 2.0) + (16.0 if success else 4.0)
	var paragon_result: Dictionary = _grant_paragon_progress(paragon_base_experience)
	if bool(paragon_result.get("ok", false)):
		paragon_summary_text = String(paragon_result.get("summary", ""))
	var reward_summary_lines: Array[String] = []
	var reward_items: Array = []
	for reward_variant in result.get("reward_entries", []):
		var reward_entry: Dictionary = reward_variant
		match String(reward_entry.get("type", "")):
			"gem":
				var gem_result: Dictionary = GemSystem.grant_rift_reward(
					gem_state,
					GemSystem.get_preferred_gem_id_for_skill(selected_core_skill_id)
				)
				if not bool(gem_result.get("ok", false)):
					continue
				gem_state = gem_result.get("state", gem_state)
				reward_summary_lines.append("宝石馈赠: %s" % String(gem_result.get("summary", "")))
				EventBus.gem_upgraded.emit(
					String(gem_result.get("gem_id", "")),
					int(gem_result.get("new_level", 0))
				)
			"hua_ring":
				var hua_ring_item: Dictionary = RiftSystem.build_hua_ring_item(
					String(reward_entry.get("set_id", "")),
					int(reward_entry.get("item_level", 1))
				)
				if hua_ring_item.is_empty():
					continue
				inventory.append(hua_ring_item)
				LootCodexSystem.register_item(hua_ring_item)
				reward_items.append(hua_ring_item)
				reward_summary_lines.append("华戒入包: %s" % _format_item_name(hua_ring_item))

	if not reward_summary_lines.is_empty():
		var recent_results: Array = rift_state.get("recent_results", []).duplicate(true)
		if not recent_results.is_empty():
			var latest_result: Dictionary = recent_results[0].duplicate(true)
			latest_result["reward_lines"] = reward_summary_lines.duplicate(true)
			latest_result["reward_summary"] = " | ".join(reward_summary_lines)
			latest_result["summary"] = "%s | %s" % [
				String(latest_result.get("summary", "")),
				String(latest_result.get("reward_summary", "")),
			]
			recent_results[0] = latest_result
			rift_state["recent_results"] = recent_results
	if not paragon_summary_text.is_empty():
		var paragon_results: Array = rift_state.get("recent_results", []).duplicate(true)
		if not paragon_results.is_empty():
			var latest_paragon_result: Dictionary = paragon_results[0].duplicate(true)
			var latest_summary: String = String(latest_paragon_result.get("summary", ""))
			latest_paragon_result["summary"] = "%s | %s" % [latest_summary, paragon_summary_text] if not latest_summary.is_empty() else paragon_summary_text
			paragon_results[0] = latest_paragon_result
			rift_state["recent_results"] = paragon_results

	refresh_build_state(true)
	if not reward_items.is_empty():
		EventBus.inventory_changed.emit()
	EventBus.rift_run_finished.emit({
		"success": success,
		"runtime_summary": get_rift_runtime_summary(),
		"summary_lines": result.get("summary_lines", []).duplicate(true),
		"reward_summary_lines": reward_summary_lines,
		"paragon_summary": paragon_summary_text,
	})
	return {
		"ok": true,
		"reason": "",
		"summary_lines": result.get("summary_lines", []).duplicate(true),
		"reward_summary_lines": reward_summary_lines,
		"reward_items": reward_items,
		"reward_multiplier": float(active_run.get("reward_multiplier", 1.0)),
		"paragon_summary": paragon_summary_text,
	}


func grant_boss_rift_key(node_data: Dictionary) -> Dictionary:
	var result: Dictionary = RiftSystem.grant_boss_clear_key(rift_state, node_data)
	if not bool(result.get("ok", false)):
		return result
	rift_state = result.get("state", rift_state)
	return result


func equip_gem(slot_id: String, gem_id: String) -> Dictionary:
	var result: Dictionary = GemSystem.equip_gem(gem_state, slot_id, gem_id)
	if not bool(result.get("ok", false)):
		return result
	gem_state = result.get("state", gem_state)
	refresh_build_state(true)
	return result


func activate_martial_codex_effect(slot_id: String, effect_id: String) -> Dictionary:
	var result: Dictionary = MartialCodexSystem.set_active_effect(martial_codex_state, slot_id, effect_id)
	if not bool(result.get("ok", false)):
		return result
	martial_codex_state = result.get("state", martial_codex_state)
	refresh_build_state(true)
	return result


func refresh_build_state(emit_signals: bool = true) -> void:
	martial_codex_state = MartialCodexSystem.sanitize_state(martial_codex_state)
	rift_state = RiftSystem.sanitize_state(rift_state)
	gem_state = GemSystem.sanitize_state(gem_state)
	paragon_state = ParagonSystem.sanitize_state(paragon_state)
	season_state = SeasonSystem.sanitize_state(season_state)
	_ensure_progression_unlocks(emit_signals)
	set_summary = SetSystem.build_set_summary(equipped_items)
	if emit_signals:
		EventBus.set_bonus_changed.emit(set_summary)
		EventBus.martial_codex_changed.emit(get_martial_codex_runtime_state())
		EventBus.paragon_changed.emit(ParagonSystem.build_runtime_summary(paragon_state))


func get_meta_progression_bonuses() -> Dictionary:
	return MetaProgressionSystem.get_meta_progression_bonuses()


func get_adjusted_reward_count(item_id: String, base_count: int) -> int:
	return MetaProgressionSystem.get_adjusted_reward_count(item_id, base_count)


func get_adjusted_salvage_scrap(base_scrap: int) -> int:
	return MetaProgressionSystem.get_adjusted_salvage_scrap(base_scrap)


func get_research_level(node_id: String) -> int:
	return MetaProgressionSystem.get_research_level(node_id)


func can_upgrade_research(node_id: String) -> Dictionary:
	return MetaProgressionSystem.can_upgrade_research(node_id)


func upgrade_research(node_id: String) -> Dictionary:
	return MetaProgressionSystem.upgrade_research(node_id)


func get_research_items(tree_filter: String = "all") -> Array:
	return MetaProgressionSystem.get_research_items(tree_filter)


func get_research_overview_text(tree_filter: String = "all") -> String:
	return MetaProgressionSystem.get_research_overview_text(tree_filter)


func get_research_detail_text(node_id: String) -> String:
	return MetaProgressionSystem.get_research_detail_text(node_id)


func process_loot_item(item: Dictionary) -> Dictionary:
	LootCodexSystem.register_item(item)
	var result: Dictionary = {
		"action": "none",
		"item_name": _format_item_name(item),
	}
	var slot: String = String(item.get("slot", ""))
	var target_slot: String = _resolve_equip_slot(slot, item)
	var should_equip: bool = false

	if equipped_items.has(target_slot) and _can_auto_equip_item(item):
		var equipped_item: Dictionary = equipped_items[target_slot]
		if equipped_item.is_empty() or _get_item_score(item) > _get_item_score(equipped_item):
			should_equip = true

	if should_equip:
		var old_item: Dictionary = equipped_items.get(target_slot, {})
		equipped_items[target_slot] = item
		refresh_build_state()
		result["action"] = "equip"
		result["target_slot"] = target_slot
		if not old_item.is_empty():
			_store_or_salvage_item(old_item, result)
		EventBus.equipment_changed.emit()
		EventBus.resources_changed.emit()
		EventBus.inventory_changed.emit()
		return result

	_store_or_salvage_item(item, result)
	EventBus.equipment_changed.emit()
	EventBus.resources_changed.emit()
	EventBus.inventory_changed.emit()
	return result


func _resolve_equip_slot(slot: String, item: Dictionary) -> String:
	if slot == "accessory":
		var a1: Dictionary = equipped_items.get("accessory1", {})
		var a2: Dictionary = equipped_items.get("accessory2", {})
		if a1.is_empty():
			return "accessory1"
		if a2.is_empty():
			return "accessory2"
		if _get_item_score(item) > _get_item_score(a1) and _get_item_score(a1) <= _get_item_score(a2):
			return "accessory1"
		if _get_item_score(item) > _get_item_score(a2):
			return "accessory2"
		return "accessory1"
	return slot


func get_equipment_summary() -> String:
	var lines: Array[String] = []
	for slot in EQUIPMENT_SLOT_ORDER:
		var item: Dictionary = equipped_items.get(slot, {})
		if item.is_empty():
			lines.append("%s: --" % slot)
		else:
			lines.append("%s: %s" % [slot, _format_item_name(item)])
	return "\n".join(lines)


func get_equipped_item(slot: String) -> Dictionary:
	return equipped_items.get(slot, {})


func get_inventory_count() -> int:
	return inventory.size()


func get_inventory_items() -> Array:
	return inventory


func set_ui_focus_request(panel_id: String, payload: Dictionary = {}) -> void:
	pending_ui_focus[panel_id] = payload.duplicate(true)


func consume_ui_focus_request(panel_id: String) -> Dictionary:
	if not pending_ui_focus.has(panel_id):
		return {}
	var payload: Dictionary = pending_ui_focus.get(panel_id, {}).duplicate(true)
	pending_ui_focus.erase(panel_id)
	return payload


func get_inventory_screen_state(
	page: int = 0,
	filter_id: String = InventoryViewModelService.FILTER_ALL,
	sort_id: String = InventoryViewModelService.SORT_SCORE_DESC,
	selected_item_id: String = "",
	selected_slot_id: String = ""
) -> Dictionary:
	return InventoryViewModelService.build_screen_state(
		inventory,
		equipped_items,
		page,
		filter_id,
		sort_id,
		selected_item_id,
		selected_slot_id
	)


func get_equipment_screen_state() -> Dictionary:
	return EquipmentViewModelService.build_screen_state(
		equipped_items,
		inventory,
		set_summary,
		get_martial_codex_runtime_state(),
		get_build_advice_data()
	)


func get_cube_screen_state(
	page_id: String,
	selected_entry_id: String = "",
	selected_target_slot: String = "",
	selected_affix_index: int = -1
) -> Dictionary:
	return CubeViewModelService.build_screen_state(
		page_id,
		inventory,
		get_martial_codex_runtime_state(),
		selected_entry_id,
		selected_target_slot,
		selected_affix_index
	)


func get_auto_salvage_label() -> String:
	return "自动分解低于: %s" % get_rarity_display_name(auto_salvage_below_rarity)


func get_current_drop_focus() -> String:
	var node_data: Dictionary = ConfigDB.get_chapter_node(current_node_id)
	var profile_id: String = String(node_data.get("repeat_rewards_profile_id", ""))
	var profile: Dictionary = ConfigDB.get_drop_profile(profile_id)
	return String(profile.get("drop_focus", "常规掉落"))


func get_item_detail_text(item: Dictionary) -> String:
	if item.is_empty():
		return "未选择物品"

	var lines: Array[String] = []
	lines.append(_format_item_name(item))
	lines.append("部位: %s" % String(item.get("slot", "--")))
	lines.append("等级: %d" % int(item.get("item_level", 1)))
	lines.append("评分: %.1f" % float(item.get("score", 0.0)))
	if not String(item.get("set_name", "")).is_empty():
		lines.append("传承: %s" % String(item.get("set_name", "")))
	if not String(item.get("hua_ring_set_name", "")).is_empty():
		lines.append("华戒映照: %s (+2件)" % String(item.get("hua_ring_set_name", "")))
	if item.has("refine_slot_index"):
		lines.append("精炼词条: #%d" % (int(item.get("refine_slot_index", -1)) + 1))
		lines.append("精炼次数: %d" % int(item.get("refine_count", 0)))
	lines.append("锁定: %s" % ("是" if bool(item.get("is_locked", false)) else "否"))
	lines.append("基础属性:")
	for stat_entry in item.get("base_stats", []):
		lines.append("- %s %+0.2f" % [String(stat_entry.get("stat_key", "")), float(stat_entry.get("value", 0.0))])
	lines.append("词条:")
	for affix_entry in item.get("affixes", []):
		var affix_name: String = String(affix_entry.get("name", String(affix_entry.get("stat_key", ""))))
		lines.append("- %s %+0.2f" % [affix_name, float(affix_entry.get("value", 0.0))])
	if not item.get("legendary_affix", {}).is_empty():
		var legendary_affix: Dictionary = item.get("legendary_affix", {})
		lines.append("异宝真意:")
		lines.append("- %s" % String(legendary_affix.get("name", "")))
		lines.append("- %s" % String(legendary_affix.get("description", "")))
		lines.append("- %s %+0.2f" % [String(legendary_affix.get("stat_key", "")), float(legendary_affix.get("value", 0.0))])
		if String(legendary_affix.get("secondary_stat_key", "")).length() > 0:
			lines.append("- %s %+0.2f" % [
				String(legendary_affix.get("secondary_stat_key", "")),
				float(legendary_affix.get("secondary_value", 0.0)),
			])
	return "\n".join(lines)


func get_item_card_title(item: Dictionary) -> String:
	return ItemPresentationService.build_item_title(item)


func get_item_card_subtitle(item: Dictionary) -> String:
	return ItemPresentationService.build_item_subtitle(item)


func get_loot_summary_lines(limit: int = 3) -> Array[String]:
	var lines: Array[String] = []
	for line_variant in String(last_loot_summary).split("\n", false):
		var line: String = String(line_variant).strip_edges()
		if line.is_empty():
			continue
		lines.append(line)
		if lines.size() >= limit:
			break
	return lines


func toggle_inventory_lock(item_id: String) -> void:
	for i in range(inventory.size()):
		var item: Dictionary = inventory[i]
		if String(item.get("id", "")) == item_id:
			item["is_locked"] = not bool(item.get("is_locked", false))
			inventory[i] = item
			EventBus.inventory_changed.emit()
			return


func equip_inventory_item(item_id: String) -> void:
	for i in range(inventory.size()):
		var item: Dictionary = inventory[i]
		if String(item.get("id", "")) != item_id:
			continue

		var slot: String = String(item.get("slot", ""))
		var target_slot: String = _resolve_equip_slot(slot, item)
		var old_item: Dictionary = equipped_items.get(target_slot, {})
		equipped_items[target_slot] = item
		inventory.remove_at(i)
		if not old_item.is_empty():
			inventory.append(old_item)
		refresh_build_state()
		EventBus.equipment_changed.emit()
		EventBus.inventory_changed.emit()
		EventBus.resources_changed.emit()
		return


func unequip_slot(slot_id: String) -> void:
	if not equipped_items.has(slot_id):
		return
	var item: Dictionary = equipped_items.get(slot_id, {})
	if item.is_empty():
		return
	equipped_items[slot_id] = {}
	inventory.append(item)
	refresh_build_state()
	EventBus.equipment_changed.emit()
	EventBus.inventory_changed.emit()
	EventBus.resources_changed.emit()


func execute_cube_recipe(recipe_id: String, item_id: String, options: Dictionary = {}, equipment_generator: Node = null) -> Dictionary:
	var item_index: int = _find_inventory_index_by_id(item_id)
	if item_index == -1:
		return {"ok": false, "reason": "未找到对应背包物品", "recipe_id": recipe_id}
	var item: Dictionary = inventory[item_index]
	var result: Dictionary = CubeSystem.execute_recipe(
		recipe_id,
		item,
		options,
		{
			"resource_reader": Callable(self, "_get_resource_amount"),
			"resource_consumer": Callable(self, "_consume_cube_resource"),
			"equipment_generator": equipment_generator,
			"martial_codex_state": martial_codex_state,
		}
	)
	if not bool(result.get("ok", false)):
		return result

	if bool(result.get("remove_input", false)):
		inventory.remove_at(item_index)

	var unlock_result: Dictionary = {}
	var unlocked_effect_id: String = String(result.get("unlocked_effect_id", ""))
	if not unlocked_effect_id.is_empty():
		unlock_result = MartialCodexSystem.unlock_effect(martial_codex_state, unlocked_effect_id)
		if not bool(unlock_result.get("ok", false)):
			return {
				"ok": false,
				"reason": String(unlock_result.get("reason", "武学解锁失败")),
				"recipe_id": recipe_id,
			}
		martial_codex_state = unlock_result.get("state", martial_codex_state)

	var replacement_item: Dictionary = result.get("replacement_item", {})
	if not replacement_item.is_empty():
		inventory.append(replacement_item.duplicate(true))

	for added_item_variant in result.get("added_items", []):
		var added_item: Dictionary = added_item_variant
		if added_item.is_empty():
			continue
		inventory.append(added_item.duplicate(true))

	refresh_build_state()
	EventBus.inventory_changed.emit()
	result["runtime_codex_state"] = get_martial_codex_runtime_state()
	EventBus.cube_operation_completed.emit(result)
	return result


func salvage_inventory_item(item_id: String) -> bool:
	for i in range(inventory.size()):
		var item: Dictionary = inventory[i]
		if String(item.get("id", "")) != item_id:
			continue
		if bool(item.get("is_locked", false)):
			return false
		var salvage_scrap_base: int = maxi(2, int(item.get("item_level", 1)) * get_rarity_rank(String(item.get("rarity", "common"))))
		var salvage_scrap: int = get_adjusted_salvage_scrap(salvage_scrap_base)
		MetaProgressionSystem.add_resource("scrap", salvage_scrap)
		inventory.remove_at(i)
		update_loot_summary(["手动分解: %s -> %s +%d" % [_format_item_name(item), MetaProgressionSystem.get_resource_display_name("scrap"), salvage_scrap]])
		EventBus.inventory_changed.emit()
		return true
	return false


func cycle_auto_salvage_threshold() -> void:
	var current_index: int = SALVAGE_THRESHOLDS.find(auto_salvage_below_rarity)
	if current_index == -1:
		current_index = 0
	current_index = (current_index + 1) % SALVAGE_THRESHOLDS.size()
	auto_salvage_below_rarity = SALVAGE_THRESHOLDS[current_index]
	EventBus.inventory_changed.emit()


func update_loot_summary(lines: Array[String]) -> void:
	last_loot_summary = "\n".join(lines)
	EventBus.loot_summary_changed.emit(last_loot_summary)


func set_loot_highlight(highlight_data: Dictionary) -> void:
	last_loot_highlight = highlight_data.duplicate(true)


func get_loot_highlight() -> Dictionary:
	return last_loot_highlight


func gm_add_inventory_item(item: Dictionary) -> void:
	if item.is_empty():
		return
	var cloned_item: Dictionary = item.duplicate(true)
	cloned_item["is_locked"] = bool(cloned_item.get("is_locked", false))
	inventory.append(cloned_item)
	LootCodexSystem.register_item(cloned_item)
	EventBus.inventory_changed.emit()
	EventBus.codex_changed.emit()


func gm_jump_to_node(node_id: String) -> bool:
	var node_data: Dictionary = ConfigDB.get_chapter_node(node_id)
	if node_data.is_empty():
		return false
	current_chapter_id = String(node_data.get("chapter_id", current_chapter_id))
	current_node_id = node_id
	stable_node_id = node_id
	EventBus.node_changed.emit(current_node_id)
	return true


func gm_clear_inventory() -> void:
	inventory.clear()
	EventBus.inventory_changed.emit()


func _store_or_salvage_item(item: Dictionary, result: Dictionary) -> void:
	var rarity: String = String(item.get("rarity", "common"))
	if _must_enter_manual_item_flow(item):
		item["is_locked"] = bool(item.get("is_locked", false))
		result["manual_review"] = true
		inventory.append(item)
		result["action"] = "store"
	elif LootRuleService.should_auto_salvage_item(item, auto_salvage_below_rarity):
		var salvage_scrap_base: int = maxi(2, int(item.get("item_level", 1)) * get_rarity_rank(rarity))
		var salvage_scrap: int = get_adjusted_salvage_scrap(salvage_scrap_base)
		MetaProgressionSystem.add_resource("scrap", salvage_scrap)
		result["action"] = "salvage"
		result["scrap"] = salvage_scrap
	else:
		item["is_locked"] = bool(item.get("is_locked", false))
		inventory.append(item)
		result["action"] = "store"


func _can_auto_equip_item(item: Dictionary) -> bool:
	return LootRuleService.should_auto_equip_item(item, {})


func _must_enter_manual_item_flow(item: Dictionary) -> bool:
	return LootRuleService.is_manual_decision_item(item)


func _add_stat_to_totals(totals: Dictionary, entry: Dictionary) -> void:
	var stat_key: String = String(entry.get("stat_key", ""))
	var value: float = float(entry.get("value", 0.0))
	if totals.has(stat_key):
		totals[stat_key] += value


func _add_secondary_stat_to_totals(totals: Dictionary, entry: Dictionary) -> void:
	var stat_key: String = String(entry.get("secondary_stat_key", ""))
	var value: float = float(entry.get("secondary_value", 0.0))
	if totals.has(stat_key):
		totals[stat_key] += value


func _apply_research_bonuses_to_totals(totals: Dictionary) -> void:
	MetaProgressionSystem.apply_combat_bonuses_to_totals(totals)


func _get_research_upgrade_cost(research_node: Dictionary, target_level: int) -> Dictionary:
	var costs: Array = research_node.get("costs", [])
	for cost_entry_variant in costs:
		var cost_entry: Dictionary = cost_entry_variant
		if int(cost_entry.get("level", 0)) == target_level:
			return cost_entry
	if costs.is_empty():
		return {}
	return costs[-1]


func _get_resource_amount(resource_id: String) -> int:
	return MetaProgressionSystem.get_resource_amount(resource_id)


func _get_resource_bonus_key(_resource_id: String) -> String:
	return ""


func _consume_resource(resource_id: String, amount: int) -> void:
	MetaProgressionSystem.add_resource(resource_id, -amount)


func _consume_cube_resource(resource_id: String, amount: int) -> void:
	MetaProgressionSystem.add_resource(resource_id, -amount)


func _find_inventory_index_by_id(item_id: String) -> int:
	for index in range(inventory.size()):
		var item: Dictionary = inventory[index]
		if String(item.get("id", "")) == item_id:
			return index
	return -1


func _sort_research_nodes(a: Dictionary, b: Dictionary) -> bool:
	return String(a.get("sort_id", "")) < String(b.get("sort_id", ""))


func _get_item_score(item: Dictionary) -> float:
	return float(item.get("score", 0.0))


func _format_item_name(item: Dictionary) -> String:
	var rarity_key: String = String(item.get("rarity", "common"))
	var display_rarity: String = RARITY_DISPLAY_NAMES.get(rarity_key, rarity_key)
	return "[%s] %s" % [display_rarity, String(item.get("name", "未知装备"))]


func record_kill() -> void:
	current_run_kills += 1
	EventBus.resources_changed.emit()


func complete_node(node_id: String) -> void:
	current_run_clears += 1
	stable_node_id = node_id
	var node_data: Dictionary = ConfigDB.get_chapter_node(node_id)
	var chapter_data: Dictionary = ConfigDB.get_chapter(String(node_data.get("chapter_id", current_chapter_id)))
	var paragon_base_experience: float = 6.0 + float(int(chapter_data.get("order", 1)) - 1) * 4.0
	match String(node_data.get("node_type", "normal")):
		"elite":
			paragon_base_experience += 4.0
		"boss":
			paragon_base_experience += 10.0
		_:
			pass
	var paragon_result: Dictionary = _grant_paragon_progress(paragon_base_experience)
	var next_node_id: String = String(node_data.get("next_node_id", ""))
	if next_node_id.is_empty():
		var current_chapter: Dictionary = ConfigDB.get_chapter(current_chapter_id)
		var next_chapter_id: String = String(current_chapter.get("next_chapter_id", ""))
		if not next_chapter_id.is_empty() and not ConfigDB.get_chapter(next_chapter_id).is_empty():
			current_chapter_id = next_chapter_id
			current_node_id = ConfigDB.get_chapter_first_node(current_chapter_id)
			stable_node_id = current_node_id
		else:
			current_node_id = ConfigDB.get_chapter_first_node(current_chapter_id)
	else:
		current_node_id = next_node_id
	if bool(paragon_result.get("ok", false)):
		EventBus.combat_state_changed.emit(String(paragon_result.get("summary", "宗师修为已增长")))
	EventBus.node_changed.emit(current_node_id)


func fallback_to_stable_node() -> void:
	current_node_id = stable_node_id
	EventBus.node_changed.emit(current_node_id)


func allocate_paragon_point(stat_id: String) -> Dictionary:
	var result: Dictionary = ParagonSystem.allocate_point(paragon_state, stat_id)
	if not bool(result.get("ok", false)):
		return result
	paragon_state = result.get("state", paragon_state)
	refresh_build_state(true)
	EventBus.paragon_changed.emit(ParagonSystem.build_runtime_summary(paragon_state))
	EventBus.combat_state_changed.emit(String(result.get("summary", "宗师修为已分配")))
	return result


func reset_paragon_allocations() -> Dictionary:
	var result: Dictionary = ParagonSystem.reset_allocations(paragon_state)
	if not bool(result.get("ok", false)):
		return result
	paragon_state = result.get("state", paragon_state)
	refresh_build_state(true)
	EventBus.paragon_changed.emit(ParagonSystem.build_runtime_summary(paragon_state))
	EventBus.combat_state_changed.emit(String(result.get("summary", "宗师修为已重置")))
	return result


func get_season_rebirth_preview() -> Dictionary:
	return SeasonSystem.build_rebirth_preview(season_state, _build_progression_context())


func perform_season_rebirth() -> Dictionary:
	var check_result: Dictionary = SeasonSystem.can_rebirth(
		season_state,
		stable_node_id,
		int(get_rift_runtime_summary().get("highest_level", 0)),
		is_rift_active()
	)
	if not bool(check_result.get("ok", false)):
		return check_result

	var result: Dictionary = SeasonSystem.perform_rebirth(season_state)
	if not bool(result.get("ok", false)):
		return result
	season_state = result.get("state", season_state)
	_reset_for_rebirth()
	refresh_build_state(true)
	_emit_progression_state_changed()
	update_loot_summary([
		String(result.get("summary", "重入江湖完成")),
		"当前永久加成: %s" % String(SeasonSystem.build_runtime_summary(season_state, _build_progression_context()).get("summary_text", "")),
	])
	EventBus.stage_event_ready.emit({
		"event_type": "season_rebirth",
		"title": "重入江湖",
		"highlight": "江湖阅历已结算，第 %d 次轮回开始" % int(season_state.get("rebirth_count", 0)),
		"content_lines": [
			"当前轮回已重置装备、材料、章节与秘境进度。",
			"永久加成: %s" % String(SeasonSystem.build_bonus_summary_text(season_state.get("permanent_bonuses", {}))),
			"先回第一章稳住核心件，再决定何时重开百炼与秘境。",
		],
		"goal_lines": [
			String(DailyGoalSystem.get_next_step_summary()),
			"当前节点: %s" % current_node_id,
			"建议: 先补首轮基础件与参悟，再冲第二章毕业。",
		],
		"boss_style": true,
	})
	EventBus.combat_state_changed.emit(String(result.get("summary", "重入江湖完成")))
	return result


func _build_progression_context() -> Dictionary:
	return {
		"stable_node_id": stable_node_id,
		"highest_rift_level": int(get_rift_runtime_summary().get("highest_level", 0)),
		"is_rift_active": is_rift_active(),
	}


func _ensure_progression_unlocks(emit_signals: bool = true) -> void:
	var unlock_result: Dictionary = ParagonSystem.ensure_unlocked(paragon_state, stable_node_id)
	paragon_state = unlock_result.get("state", paragon_state)
	if bool(unlock_result.get("newly_unlocked", false)):
		last_loot_summary = "%s\n%s" % [
			last_loot_summary,
			"宗师修为已开启",
		] if not String(last_loot_summary).is_empty() else "宗师修为已开启"
		EventBus.loot_summary_changed.emit(last_loot_summary)
		if emit_signals:
			EventBus.combat_state_changed.emit("宗师修为已开启")


func _grant_paragon_progress(base_amount: float) -> Dictionary:
	_ensure_progression_unlocks(false)
	var meta_bonuses: Dictionary = get_meta_progression_bonuses()
	var result: Dictionary = ParagonSystem.gain_experience(
		paragon_state,
		base_amount,
		float(meta_bonuses.get("paragon_exp_gain_percent", 0.0))
	)
	if not bool(result.get("ok", false)):
		return result
	paragon_state = result.get("state", paragon_state)
	EventBus.paragon_changed.emit(ParagonSystem.build_runtime_summary(paragon_state))
	return result


func _reset_for_rebirth() -> void:
	current_chapter_id = "chapter_1"
	current_node_id = ConfigDB.get_chapter_first_node(current_chapter_id)
	stable_node_id = current_node_id
	current_run_kills = 0
	current_run_clears = 0
	inventory.clear()
	for slot_id in EQUIPMENT_SLOT_ORDER:
		equipped_items[slot_id] = {}
	MetaProgressionSystem.gm_reset_all_resources()
	MetaProgressionSystem.research_levels = {}
	auto_salvage_below_rarity = "rare"
	last_loot_summary = "暂无掉落"
	last_loot_highlight = {}
	set_summary = {
		"counts": {},
		"active_sets": [],
		"total_bonuses": {},
		"primary_active_set": {},
	}
	rift_state = RiftSystem.create_default_state()
	gem_state = GemSystem.create_default_state()


func _emit_progression_state_changed() -> void:
	EventBus.node_changed.emit(current_node_id)
	EventBus.resources_changed.emit()
	EventBus.equipment_changed.emit()
	EventBus.inventory_changed.emit()
	EventBus.research_changed.emit()
	EventBus.set_bonus_changed.emit(set_summary)
	EventBus.martial_codex_changed.emit(get_martial_codex_runtime_state())
	EventBus.paragon_changed.emit(ParagonSystem.build_runtime_summary(paragon_state))
	EventBus.season_reborn.emit(SeasonSystem.build_runtime_summary(season_state, _build_progression_context()))


func _get_primary_archetype_tag(skill_data: Dictionary) -> String:
	var archetype_tags: Array = skill_data.get("archetype_tags", [])
	if archetype_tags.is_empty():
		return ""
	return String(archetype_tags[0])


func _get_primary_stat_gap(profile: Dictionary, totals: Dictionary, chapter_order: int) -> Dictionary:
	var best_gap: Dictionary = {}
	var best_score: float = -1.0
	for entry_variant in profile.get("primary_stats", []):
		var entry: Dictionary = entry_variant
		var stat_key: String = String(entry.get("stat_key", ""))
		var target_value: float = float(entry.get("target_base", 0.0)) + float(maxi(chapter_order - 1, 0)) * float(entry.get("target_per_chapter", 0.0))
		var current_value: float = float(totals.get(stat_key, 0.0))
		var deficit_ratio: float = maxf(0.0, target_value - current_value) / maxf(target_value, 0.001)
		var score: float = deficit_ratio
		if String(entry.get("category", "")) == "function":
			score += 0.08
		if current_value <= 0.0:
			score += 0.06
		if score > best_score:
			best_score = score
			best_gap = entry.duplicate(true)
			best_gap["target_value"] = target_value
			best_gap["current_value"] = current_value
			best_gap["deficit_ratio"] = deficit_ratio
	return best_gap


func _get_survival_gap(totals: Dictionary, chapter_order: int) -> Dictionary:
	var hp_target: float = 34.0 + float(chapter_order) * 26.0
	var defense_target: float = 4.0 + float(chapter_order) * 2.0
	var hp_value: float = float(totals.get("hp_flat", 0.0))
	var defense_value: float = float(totals.get("defense_flat", 0.0))
	var hp_ratio: float = maxf(0.0, hp_target - hp_value) / maxf(hp_target, 1.0)
	var defense_ratio: float = maxf(0.0, defense_target - defense_value) / maxf(defense_target, 1.0)
	return {
		"stat_key": "hp_flat",
		"label": "生存面板",
		"category": "survival",
		"category_label": "生存",
		"current_value": hp_value + defense_value * 4.0,
		"target_value": hp_target + defense_target * 4.0,
		"deficit_ratio": (hp_ratio + defense_ratio) * 0.5,
		"affix_ids": ["affix_hp_flat", "affix_defense_flat"],
		"legendary_ids": ["legend_boss_tyrant_shell"],
	}


func _get_default_gap(bonuses: Dictionary, chapter_order: int) -> Dictionary:
	return {
		"stat_key": "core_damage_percent",
		"category": "damage",
		"category_label": "伤害",
		"label": "武学伤害",
		"current_value": float(bonuses.get("core_damage_percent", 0.0)),
		"target_value": 0.24 + float(maxi(chapter_order - 1, 0)) * 0.08,
		"deficit_ratio": 0.0,
		"affix_ids": ["affix_core_damage"],
		"legendary_ids": ["legend_time_fissure"],
	}


func _get_gap_severity(deficit_ratio: float) -> String:
	if deficit_ratio >= 0.55:
		return "severe"
	if deficit_ratio >= 0.28:
		return "moderate"
	return "mild"


func _get_gap_severity_label(severity: String) -> String:
	match severity:
		"severe":
			return "严重"
		"moderate":
			return "明显"
		_:
			return "轻度"


func _build_pivot_recommendation(
	gap: Dictionary,
	gap_severity: String,
	recommendation_target: Dictionary,
	research_action: Dictionary,
	is_progress_blocked: bool,
	block_node_label: String
) -> Dictionary:
	var gap_label: String = String(gap.get("label", "当前缺口"))
	var recommended_node_label: String = String(recommendation_target.get("recommended_node_label", current_node_id))
	var recommended_node_id: String = String(recommendation_target.get("recommended_node_id", current_node_id))
	var research_summary: String = String(research_action.get("summary", ""))
	var pivot_type: String = "push"
	var pivot_summary: String = "当前还能继续探境，边打边补 %s。" % gap_label
	var stall_summary: String = "当前可继续推进，边打边补 %s。" % gap_label

	if is_progress_blocked:
		if String(research_action.get("action_type", "")) == "research_upgrade" and gap_severity != "mild":
			pivot_type = "research_upgrade"
			pivot_summary = "先去悟道，立刻补一层 %s。" % String(research_action.get("node_name", "当前悟道"))
			stall_summary = "卡在 %s，先做一次悟道再回头推进。" % block_node_label
		elif String(research_action.get("action_type", "")) == "resource_collect" and gap_severity == "severe":
			pivot_type = "research_resource"
			pivot_summary = research_summary if not research_summary.is_empty() else "先筹够悟道材料，再回头推当前卡点。"
			stall_summary = "卡在 %s，先筹材料做悟道更稳。" % block_node_label
		elif not recommended_node_id.is_empty() and recommended_node_id != current_node_id:
			pivot_type = "farm"
			pivot_summary = "先回刷 %s，优先补 %s。" % [recommended_node_label, gap_label]
			stall_summary = "卡在 %s，先回刷 %s 补 %s。" % [block_node_label, recommended_node_label, gap_label]
		else:
			stall_summary = "当前卡在 %s，继续补 %s 后再推。" % [block_node_label, gap_label]
	elif String(research_action.get("action_type", "")) == "research_upgrade" and gap_severity == "severe":
		pivot_type = "research_upgrade"
		pivot_summary = "当前还能推进，但先做一次悟道会更稳。"
		stall_summary = "先做一次悟道，再继续推进会更稳。"
	elif not recommended_node_id.is_empty() and recommended_node_id != current_node_id and gap_severity == "severe":
		pivot_type = "farm"
		pivot_summary = "先刷 %s，优先补 %s。" % [recommended_node_label, gap_label]
		stall_summary = "先回刷 %s 补 %s，再继续推进。" % [recommended_node_label, gap_label]

	return {
		"pivot_type": pivot_type,
		"pivot_summary": pivot_summary,
		"stall_summary": stall_summary,
	}


func _get_research_action_data() -> Dictionary:
	for tree_filter in ["combat", "economy", "idle"]:
		for research_node_variant in MetaProgressionSystem.get_research_items(tree_filter):
			var research_node: Dictionary = research_node_variant
			var node_id: String = String(research_node.get("id", ""))
			var upgrade_state: Dictionary = MetaProgressionSystem.can_upgrade_research(node_id)
			if bool(upgrade_state.get("ok", false)):
				return {
					"action_type": "research_upgrade",
					"node_id": node_id,
					"node_name": String(research_node.get("name", node_id)),
					"summary": "悟道可立刻提升 %s。" % String(research_node.get("name", node_id)),
				}
			var reason: String = String(upgrade_state.get("reason", ""))
			if reason.contains("不足"):
				var current_level: int = MetaProgressionSystem.get_research_level(node_id)
				var cost_entry: Dictionary = _get_research_upgrade_cost(research_node, current_level + 1)
				if cost_entry.is_empty():
					continue
				var resource_id: String = String(cost_entry.get("resource_id", ""))
				var cost_amount: int = int(cost_entry.get("amount", 0))
				var current_amount: int = MetaProgressionSystem.get_resource_amount(resource_id)
				var missing_amount: int = maxi(1, cost_amount - current_amount)
				return {
					"action_type": "resource_collect",
					"node_id": node_id,
					"node_name": String(research_node.get("name", node_id)),
					"resource_id": resource_id,
					"missing_amount": missing_amount,
					"summary": "还差 %s x%d，才能悟道 %s。" % [
						MetaProgressionSystem.get_resource_display_name(resource_id),
						missing_amount,
						String(research_node.get("name", node_id)),
					],
				}
	return {}


func _build_unlock_preview_line(current_node: Dictionary, chapter_data: Dictionary) -> String:
	if current_node.is_empty():
		return ""
	var next_node_id: String = String(current_node.get("next_node_id", ""))
	if not next_node_id.is_empty():
		return "突破后续: 再过当前节点，将推进到 %s。" % ConfigDB.get_chapter_node_short_label(next_node_id)
	if String(current_node.get("node_type", "")) != "boss":
		return ""
	var next_chapter_id: String = String(chapter_data.get("next_chapter_id", ""))
	if next_chapter_id.is_empty():
		return "突破后续: 当前探境已到尽头，之后转为高价值回刷。"
	var next_chapter: Dictionary = ConfigDB.get_chapter(next_chapter_id)
	return "突破后续: 击破后将开启 %s。" % String(next_chapter.get("name", next_chapter_id))


func _get_node_short_label(node_data: Dictionary, _chapter_data: Dictionary) -> String:
	if node_data.is_empty():
		return current_node_id
	return ConfigDB.get_chapter_node_short_label(String(node_data.get("id", current_node_id)))


func _build_recommendation_target(profile: Dictionary, gap: Dictionary) -> Dictionary:
	var legendary_ids: Array = gap.get("legendary_ids", [])
	var affix_ids: Array = gap.get("affix_ids", [])
	var primary_legendary_id: String = _pick_prioritized_entry_id(legendary_ids, "legendary")
	var primary_affix_id: String = _pick_prioritized_entry_id(affix_ids, "affix")
	var base_id: String = _pick_recommended_base_id(profile, primary_legendary_id, primary_affix_id)
	var recommendation: Dictionary = {}
	if not primary_legendary_id.is_empty():
		recommendation = LootCodexSystem.get_recommended_farm_node_for_legendary(primary_legendary_id)
	if recommendation.is_empty() and not primary_affix_id.is_empty():
		recommendation = LootCodexSystem.get_recommended_farm_node_for_affix(primary_affix_id)
	if recommendation.is_empty() and not base_id.is_empty():
		recommendation = LootCodexSystem.get_recommended_farm_node_for_base(base_id)

	var expectation: String = ""
	if not recommendation.is_empty():
		expectation = "约 %.1f 次/见 1 次" % float(recommendation.get("expected_clears_per_hit", 0.0))
	return {
		"primary_target_name": _get_named_entry(primary_legendary_id, "legendary").get("name", _get_named_entry(primary_affix_id, "affix").get("name", "核心件")),
		"secondary_target_name": _get_named_entry(primary_affix_id, "affix").get("name", _get_named_entry(primary_legendary_id, "legendary").get("name", "功能真意")),
		"base_target_name": _get_named_entry(base_id, "base").get("name", "合适底材"),
		"recommended_node_id": String(recommendation.get("node_id", current_node_id)),
		"recommended_node_label": String(recommendation.get("short_label", current_node_id)),
		"recommendation_short": _build_recommendation_short_text(recommendation, expectation),
		"reason": String(recommendation.get("reason", "")),
	}


func _build_recommendation_short_text(recommendation: Dictionary, expectation: String) -> String:
	if recommendation.is_empty():
		return "先刷当前能稳定通关的节点"
	var reason: String = String(recommendation.get("reason", ""))
	var state_text: String = "当前可刷"
	if reason.begins_with("后续章节"):
		state_text = "后续章节"
	return "%s，%s" % [state_text, expectation if not expectation.is_empty() else "看掉率推荐推进"]


func _pick_prioritized_entry_id(candidate_ids: Array, category: String) -> String:
	for candidate_variant in candidate_ids:
		var candidate_id: String = String(candidate_variant)
		if candidate_id.is_empty():
			continue
		if category == "legendary" and not LootCodexSystem.is_legendary_discovered(candidate_id):
			return candidate_id
		if not _get_named_entry(candidate_id, category).is_empty():
			return candidate_id
	return ""


func _pick_recommended_base_id(profile: Dictionary, legendary_id: String, affix_id: String) -> String:
	var preferred_slot_tags: Array = []
	var legendary_entry: Dictionary = _get_named_entry(legendary_id, "legendary")
	if not legendary_entry.is_empty():
		preferred_slot_tags = legendary_entry.get("slot_tags", [])
	var affix_entry: Dictionary = _get_named_entry(affix_id, "affix")
	if preferred_slot_tags.is_empty() and not affix_entry.is_empty():
		preferred_slot_tags = affix_entry.get("slot_tags", [])

	var recommended_ids: Array = profile.get("recommended_base_ids", [])
	for base_id_variant in recommended_ids:
		var base_id: String = String(base_id_variant)
		var base_entry: Dictionary = _get_named_entry(base_id, "base")
		if base_entry.is_empty():
			continue
		if preferred_slot_tags.is_empty() or preferred_slot_tags.has(String(base_entry.get("slot", ""))):
			return base_id
	for base_entry_variant in ConfigDB.get_all_equipment_bases():
		var base_entry: Dictionary = base_entry_variant
		if preferred_slot_tags.is_empty() or preferred_slot_tags.has(String(base_entry.get("slot", ""))):
			return String(base_entry.get("id", ""))
	return ""


func _get_named_entry(entry_id: String, category: String) -> Dictionary:
	if entry_id.is_empty():
		return {}
	var pool: Array = []
	match category:
		"base":
			pool = ConfigDB.get_all_equipment_bases()
		"affix":
			pool = ConfigDB.get_all_affixes()
		_:
			pool = ConfigDB.get_all_legendary_affixes()
	for entry_variant in pool:
		var entry: Dictionary = entry_variant
		if String(entry.get("id", "")) == entry_id:
			return entry
	return {}


func _build_tracked_target_line() -> String:
	var tracked_id: String = LootCodexSystem.tracked_legendary_affix_id
	if tracked_id.is_empty():
		return "追踪: 未设机缘，先按道统推荐刷装"
	var target_name: String = String(_get_named_entry(tracked_id, "legendary").get("name", tracked_id))
	var recommendation: Dictionary = LootCodexSystem.get_recommended_farm_node_for_legendary(tracked_id)
	var recommendation_label: String = String(recommendation.get("short_label", current_node_id))
	return "追踪: %s -> %s" % [target_name, recommendation_label]


func _format_stat_value(stat_key: String, value: float) -> String:
	match stat_key:
		"attack_speed_percent", "attack_percent", "core_damage_percent", "core_cooldown_reduction", "whirlwind_radius_percent", "bleed_dot_percent", "execute_threshold", "chain_damage_percent":
			return "%d%%" % int(round(value * 100.0))
		"chain_count_bonus":
			return "+%d" % int(round(value))
		_:
			return "%d" % int(round(value))
