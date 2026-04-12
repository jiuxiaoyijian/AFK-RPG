extends Node

const AVAILABLE_CORE_SKILLS := [
	"core_whirlwind",
	"core_deep_wound",
	"core_chain_lightning",
]
const BUILD_ARCHETYPE_PROFILES := {
	"whirlwind": {
		"display_name": "御风刀",
		"phase_text": "先成型风痕范围和攻速，再补道术爆发。",
		"new_player_summary": "优先补风痕范围和攻速，站稳后再拉道术伤害。",
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
				"label": "道术伤害",
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
		"new_player_summary": "先让血劫与断命线成型，再补攻击与道术伤害。",
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
				"label": "道术伤害",
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
		"new_player_summary": "优先补引雷次数和攻速，再拉高雷痕与道术伤害。",
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
	"legendary": "上古真意",
	"ancient": "绝世真意",
}
const RARITY_COLORS := {
	"common": Color(0.62, 0.62, 0.62),
	"uncommon": Color(0.12, 0.72, 0.12),
	"rare": Color(0.24, 0.48, 1.0),
	"epic": Color(1.0, 0.55, 0.0),
	"set": Color(0.0, 0.85, 0.35),
	"legendary": Color(1.0, 0.84, 0.0),
	"ancient": Color(1.0, 0.2, 0.2),
}
const ParagonSystem = preload("res://scripts/systems/paragon_system.gd")
const RiftSystem = preload("res://scripts/systems/rift_system.gd")
const GemSystem = preload("res://scripts/systems/gem_system.gd")
const CubeSystem = preload("res://scripts/systems/cube_system.gd")
const SeasonSystem = preload("res://scripts/systems/season_system.gd")
const SetSystem = preload("res://scripts/systems/set_system.gd")
const MartialCodexSystem = preload("res://scripts/systems/martial_codex_system.gd")
const HeroProgressionSystem = preload("res://scripts/systems/hero_progression_system.gd")

var research_levels: Dictionary = {}
var paragon_state: Dictionary = ParagonSystem.create_default_state()
var season_state: Dictionary = SeasonSystem.create_default_state()
var rift_state: Dictionary = RiftSystem.create_default_state()
var gem_state: Dictionary = GemSystem.create_default_state()
var martial_codex_state: Dictionary = MartialCodexSystem.create_default_state()
var hero_state: Dictionary = HeroProgressionSystem.create_default_state()
var ui_focus_requests: Dictionary = {}
var auto_salvage_below_rarity: String = "rare"
var last_loot_summary: String = "暂无掉落"
var last_loot_highlight: Dictionary = {}
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
	EventBus.node_changed.emit(current_node_id)
	EventBus.core_skill_changed.emit(selected_core_skill_id)
	EventBus.resources_changed.emit()
	EventBus.equipment_changed.emit()
	EventBus.loot_summary_changed.emit(last_loot_summary)
	EventBus.inventory_changed.emit()
	EventBus.research_changed.emit()


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
	var totals: Dictionary = {
		"weapon_damage": 0.0,
		"primary_stat": 0.0,
		"crit_rate": 0.0,
		"crit_damage": 0.5,
		"skill_damage_percent": 0.0,
		"elemental_damage_percent": 0.0,
		"set_bonus_percent": 0.0,
		"legendary_effect_percent": 0.0,
		"elite_damage_percent": 0.0,
		"attack_flat": 0.0,
		"hp_flat": 0.0,
		"defense_flat": 0.0,
		"attack_percent": 0.0,
		"attack_speed_percent": 0.0,
		"core_damage_percent": 0.0,
		"core_cooldown_reduction": 0.0,
		"whirlwind_radius_percent": 0.0,
		"bleed_dot_percent": 0.0,
		"execute_threshold": 0.0,
		"chain_count_bonus": 0.0,
		"chain_damage_percent": 0.0,
		"all_resist": 0.0,
		"armor_flat": 0.0,
		"life_regen": 0.0,
		"move_speed_percent": 0.0,
		"resource_cost_reduction": 0.0,
	}

	for item in equipped_items.values():
		if not item is Dictionary or item.is_empty():
			continue
		for stat_entry in item.get("base_stats", []):
			_add_stat_to_totals(totals, stat_entry)
		for affix_entry in item.get("affixes", []):
			_add_stat_to_totals(totals, affix_entry)
		if not item.get("legendary_affix", {}).is_empty():
			_add_stat_to_totals(totals, item.get("legendary_affix", {}))
			_add_secondary_stat_to_totals(totals, item.get("legendary_affix", {}))

	MetaProgressionSystem.apply_combat_bonuses_to_totals(totals)
	_merge_bonuses(totals, ParagonSystem.build_combat_bonuses(paragon_state))
	_merge_bonuses(totals, GemSystem.build_combat_bonuses(gem_state))
	_merge_bonuses(totals, MartialCodexSystem.build_combat_bonuses(martial_codex_state))
	_merge_bonuses(totals, SeasonSystem.build_combat_bonuses(season_state))
	var set_data: Dictionary = SetSystem.build_set_summary(equipped_items)
	_merge_bonuses(totals, set_data.get("total_bonuses", {}))
	return totals


func get_build_advice_data() -> Dictionary:
	var skill_data: Dictionary = get_selected_core_skill()
	if skill_data.is_empty():
		return {}

	var archetype_id: String = _get_primary_archetype_tag(skill_data)
	var profile: Dictionary = BUILD_ARCHETYPE_PROFILES.get(archetype_id, {})
	var chapter_data: Dictionary = ConfigDB.get_chapter(current_chapter_id)
	var chapter_name: String = String(chapter_data.get("name", current_chapter_id))
	var chapter_order: int = int(chapter_data.get("order", 1))
	var current_node: Dictionary = ConfigDB.get_chapter_node(current_node_id)
	var stable_node: Dictionary = ConfigDB.get_chapter_node(stable_node_id)
	var bonuses: Dictionary = get_total_combat_bonuses()
	var is_progress_blocked: bool = current_node_id != stable_node_id and not current_node.is_empty() and not stable_node.is_empty()
	var block_node_label: String = _get_node_short_label(current_node, chapter_data)

	var primary_gap: Dictionary = _get_primary_stat_gap(profile, bonuses, chapter_order)
	var survival_gap: Dictionary = _get_survival_gap(bonuses, chapter_order)
	var chosen_gap: Dictionary = primary_gap
	if chosen_gap.is_empty() or float(survival_gap.get("deficit_ratio", 0.0)) > float(chosen_gap.get("deficit_ratio", 0.0)) + 0.18:
		chosen_gap = survival_gap
	if chosen_gap.is_empty():
		chosen_gap = _get_default_gap(bonuses, chapter_order)

	var gap_severity: String = _get_gap_severity(float(chosen_gap.get("deficit_ratio", 0.0)))
	var gap_severity_label: String = _get_gap_severity_label(gap_severity)
	var recommendation_target: Dictionary = _build_recommendation_target(profile, chosen_gap)
	var research_action: Dictionary = _get_research_action_data()
	var tracked_target_line: String = _build_tracked_target_line()
	var recommendation_label: String = String(recommendation_target.get("recommended_node_label", chapter_name))
	var recommendation_short: String = String(recommendation_target.get("recommendation_short", "先刷当前可稳定通关的推荐节点"))
	var gap_stat_label: String = String(chosen_gap.get("label", "传承属性"))
	var gap_category_label: String = String(chosen_gap.get("category_label", "伤害"))
	var gap_metric_text: String = "%s/%s" % [
		_format_stat_value(String(chosen_gap.get("stat_key", "")), float(chosen_gap.get("current_value", 0.0))),
		_format_stat_value(String(chosen_gap.get("stat_key", "")), float(chosen_gap.get("target_value", 0.0))),
	]
	var primary_target_name: String = String(recommendation_target.get("primary_target_name", "当前传承核心掉落"))
	var secondary_target_name: String = String(recommendation_target.get("secondary_target_name", "对应词条"))
	var base_target_name: String = String(recommendation_target.get("base_target_name", "合适底材"))
	var next_target_segments: Array[String] = []
	for segment_variant in [primary_target_name, secondary_target_name, base_target_name]:
		var segment: String = String(segment_variant)
		if segment.is_empty() or next_target_segments.has(segment):
			continue
		next_target_segments.append(segment)

	var next_target_line: String = "下一件: %s" % (" / ".join(next_target_segments) if not next_target_segments.is_empty() else "继续补当前传承核心件")
	var recommendation_line: String = "推荐: %s | %s" % [recommendation_label, recommendation_short]
	var gap_line: String = "缺口: %s(%s) -> %s %s" % [gap_category_label, gap_severity_label, gap_stat_label, gap_metric_text]
	var pivot_data: Dictionary = _build_pivot_recommendation(
		chosen_gap,
		gap_severity,
		recommendation_target,
		research_action,
		is_progress_blocked,
		block_node_label
	)
	var unlock_preview_line: String = _build_unlock_preview_line(current_node, chapter_data)
	var action_lines: Array[String] = []
	action_lines.append(String(pivot_data.get("pivot_summary", "当前还能继续探境，边推边补当前缺口。")))
	action_lines.append("先补 %s，当前 %s，建议至少到 %s。" % [
			gap_stat_label,
			_format_stat_value(String(chosen_gap.get("stat_key", "")), float(chosen_gap.get("current_value", 0.0))),
			_format_stat_value(String(chosen_gap.get("stat_key", "")), float(chosen_gap.get("target_value", 0.0))),
		])
	action_lines.append("下一件优先找 %s，副目标看 %s。" % [primary_target_name, secondary_target_name])
	action_lines.append("推荐去 %s 刷，%s。" % [recommendation_label, recommendation_short])
	if not unlock_preview_line.is_empty():
		action_lines.append(unlock_preview_line)

	return {
		"archetype_id": archetype_id,
		"archetype_name": String(profile.get("display_name", String(skill_data.get("name", selected_core_skill_id)))),
		"chapter_name": chapter_name,
		"phase_text": String(profile.get("phase_text", "")),
		"new_player_summary": String(profile.get("new_player_summary", "")),
		"is_progress_blocked": is_progress_blocked,
		"block_node_id": current_node_id if is_progress_blocked else "",
		"block_node_label": block_node_label if is_progress_blocked else "",
		"gap_category": String(chosen_gap.get("category", "damage")),
		"gap_category_label": gap_category_label,
		"gap_label": gap_stat_label,
		"gap_severity": gap_severity,
		"gap_severity_label": gap_severity_label,
		"gap_metric_text": gap_metric_text,
		"gap_summary": "当前更缺 %s，先补 %s。" % [gap_category_label, gap_stat_label],
		"pivot_type": String(pivot_data.get("pivot_type", "push")),
		"pivot_summary": String(pivot_data.get("pivot_summary", "")),
		"stall_summary": String(pivot_data.get("stall_summary", recommendation_line)),
		"unlock_preview_line": unlock_preview_line,
		"tracked_target_line": tracked_target_line,
		"gap_line": gap_line,
		"next_target_line": next_target_line,
		"recommendation_line": recommendation_line,
		"primary_target_name": primary_target_name,
		"secondary_target_name": secondary_target_name,
		"base_target_name": base_target_name,
		"recommended_node_id": String(recommendation_target.get("recommended_node_id", current_node_id)),
		"recommended_node_label": recommendation_label,
		"recommendation_short": recommendation_short,
		"recommendation_reason": String(recommendation_target.get("reason", "")),
		"research_action_type": String(research_action.get("action_type", "")),
		"research_action_name": String(research_action.get("node_name", "")),
		"research_action_resource_id": String(research_action.get("resource_id", "")),
		"research_action_missing_amount": int(research_action.get("missing_amount", 0)),
		"research_action_summary": String(research_action.get("summary", "")),
		"action_lines": action_lines,
	}


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

	if equipped_items.has(target_slot):
		var equipped_item: Dictionary = equipped_items[target_slot]
		if equipped_item.is_empty() or _get_item_score(item) > _get_item_score(equipped_item):
			should_equip = true

	if should_equip:
		var old_item: Dictionary = equipped_items.get(target_slot, {})
		equipped_items[target_slot] = item
		result["action"] = "equip"
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


func get_auto_salvage_label() -> String:
	return "自动分解低于: %s" % auto_salvage_below_rarity


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
		EventBus.equipment_changed.emit()
		EventBus.inventory_changed.emit()
		EventBus.resources_changed.emit()
		return


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


func get_cube_screen_state(
	page: String,
	selected_entry_id: String,
	_selected_target_slot: String,
	_selected_affix_index: int
) -> Dictionary:
	var recipes: Array = CubeSystem.get_recipe_entries()
	var filtered: Array = []
	for r_variant in recipes:
		var r: Dictionary = r_variant
		if page.is_empty() or String(r.get("page", "")) == page or page == "all":
			filtered.append(r)
	var detail_text: String = ""
	var action_label: String = ""
	var action_enabled: bool = false
	var cost_text: String = ""
	if not selected_entry_id.is_empty():
		var recipe: Dictionary = CubeSystem.get_recipe(selected_entry_id)
		if not recipe.is_empty():
			detail_text = "%s\n%s" % [String(recipe.get("name", selected_entry_id)), String(recipe.get("description", ""))]
			action_label = String(recipe.get("action_label", "执行"))
			var affordability: Dictionary = CubeSystem.can_execute_recipe(
				selected_entry_id,
				func(res_id: String) -> int: return get_resource_count(res_id)
			)
			action_enabled = bool(affordability.get("ok", false))
			var cost_parts: Array[String] = []
			for cost_variant in recipe.get("costs", []):
				var cost: Dictionary = cost_variant
				cost_parts.append("%s x%d" % [String(cost.get("resource_id", "")), int(cost.get("amount", 0))])
			cost_text = " | ".join(cost_parts)
	return {
		"summary_text": "百炼坊 — 共 %d 种配方" % filtered.size(),
		"candidate_entries": filtered,
		"detail_text": detail_text,
		"action_label": action_label,
		"action_enabled": action_enabled,
		"option_slots": EQUIPMENT_SLOT_ORDER.duplicate(),
		"option_affixes": [],
		"result_preview": "",
		"cost_text": cost_text,
	}


func get_progression_hub_summary() -> Dictionary:
	var research_summary: String = get_research_overview_text("all")
	var paragon_summary: Dictionary = ParagonSystem.build_runtime_summary(paragon_state)
	var season_progress: Dictionary = {
		"stable_node_id": stable_node_id,
		"highest_rift_level": int(rift_state.get("highest_level", 0)),
		"is_rift_active": not rift_state.get("active_run", {}).is_empty(),
	}
	var season_summary: Dictionary = SeasonSystem.build_runtime_summary(season_state, season_progress)
	return {
		"summary_text": "悟道 · 宗师 · 轮回",
		"research_text": research_summary,
		"tree_tabs": ["combat", "economy", "idle"],
		"paragon": {
			"level": int(paragon_summary.get("level", 0)),
			"unspent_points": int(paragon_summary.get("available_points", 0)),
			"stats": paragon_summary.get("entries", []),
			"summary_text": String(paragon_summary.get("summary_text", "")),
		},
		"season": {
			"current_season": int(season_state.get("rebirth_count", 0)) + 1,
			"rebirth_available": bool(season_summary.get("can_rebirth", false)),
			"summary_text": String(season_summary.get("summary_text", "")),
		},
	}


func get_season_rebirth_preview() -> Dictionary:
	var season_progress: Dictionary = {
		"stable_node_id": stable_node_id,
		"highest_rift_level": int(rift_state.get("highest_level", 0)),
		"is_rift_active": not rift_state.get("active_run", {}).is_empty(),
	}
	var preview: Dictionary = SeasonSystem.build_rebirth_preview(season_state, season_progress)
	var preview_lines: Array[String] = []
	preview_lines.append("轮回次数: %d → %d" % [int(preview.get("current_count", 0)), int(preview.get("next_count", 0))])
	preview_lines.append("当前加成: %s" % String(preview.get("current_bonus_text", "无")))
	preview_lines.append("轮回后加成: %s" % String(preview.get("next_bonus_text", "无")))
	for line_variant in preview.get("keep_lines", []):
		preview_lines.append(String(line_variant))
	for line_variant in preview.get("reset_lines", []):
		preview_lines.append(String(line_variant))
	return {
		"preview_text": "\n".join(preview_lines),
		"rewards": [],
		"cost_text": "重置装备/章节/秘境进度",
		"can_rebirth": bool(preview.get("ok", false)),
	}


func allocate_paragon_point(stat_id: String) -> void:
	var result: Dictionary = ParagonSystem.allocate_point(paragon_state, stat_id)
	if bool(result.get("ok", false)):
		paragon_state = result.get("state", paragon_state)
		EventBus.resources_changed.emit()


func perform_season_rebirth() -> Dictionary:
	var check: Dictionary = SeasonSystem.can_rebirth(
		season_state,
		stable_node_id,
		int(rift_state.get("highest_level", 0)),
		not rift_state.get("active_run", {}).is_empty()
	)
	if not bool(check.get("ok", false)):
		return {"success": false, "message": String(check.get("reason", "条件不足"))}
	var result: Dictionary = SeasonSystem.perform_rebirth(season_state)
	if not bool(result.get("ok", false)):
		return {"success": false, "message": String(result.get("reason", "轮回失败"))}
	season_state = result.get("state", season_state)
	_reset_for_rebirth()
	return {"success": true, "message": String(result.get("summary", "重入江湖完成"))}


func reset_paragon_allocations() -> void:
	var result: Dictionary = ParagonSystem.reset_allocations(paragon_state)
	if bool(result.get("ok", false)):
		paragon_state = result.get("state", paragon_state)
		EventBus.resources_changed.emit()


func get_analysis_hub_summary() -> Dictionary:
	var rift_summary: Dictionary = RiftSystem.build_runtime_summary(rift_state)
	var gem_runtime: Dictionary = GemSystem.build_runtime_state(gem_state)
	var has_gems: bool = not gem_runtime.get("entries", []).is_empty()
	var rift_unlocked: bool = int(rift_summary.get("highest_level", 0)) > 0 or bool(rift_summary.get("can_start", false))
	return {
		"summary_text": "掉落分析 · 秘境 · 宝石",
		"total_kills": current_run_kills,
		"total_clears": current_run_clears,
		"rift": {
			"unlocked": rift_unlocked,
			"highest_level": int(rift_summary.get("highest_level", 0)),
			"summary_text": String(rift_summary.get("key_summary", "暂无试剑令")),
		},
		"gem": {
			"unlocked": has_gems,
			"slots": gem_runtime.get("equipped_lines", []),
			"summary_text": String(gem_runtime.get("summary_text", "暂无宝石")),
		},
		"tabs": ["overview", "rift", "gem"],
	}


func get_rift_runtime_summary() -> Dictionary:
	var summary: Dictionary = RiftSystem.build_runtime_summary(rift_state)
	var active_run: Dictionary = summary.get("active_run", {})
	return {
		"is_running": not active_run.is_empty(),
		"level": int(active_run.get("level", 0)),
		"progress": 0.0,
		"time_remaining": float(active_run.get("time_limit", 0)),
		"rewards": summary.get("recent_results", []),
		"summary_text": String(summary.get("key_summary", "暂无试剑令")),
		"highest_level": int(summary.get("highest_level", 0)),
		"recommended_level": int(summary.get("recommended_level", 1)),
		"can_start": bool(summary.get("can_start", false)),
		"blocked_reason": String(summary.get("blocked_reason", "")),
	}


func get_gem_runtime_state() -> Dictionary:
	var runtime: Dictionary = GemSystem.build_runtime_state(gem_state)
	return {
		"slots": runtime.get("equipped_lines", []),
		"available_gems": runtime.get("entries", []),
		"summary_text": String(runtime.get("summary_text", "暂无宝石")),
		"owned_gems": runtime.get("owned_gems", {}),
		"equipped_gems": runtime.get("equipped_gems", {}),
	}


func start_rift_run(level: int) -> Dictionary:
	var result: Dictionary = RiftSystem.start_run(rift_state, level, current_node_id, RiftSystem.DEFAULT_TIME_LIMIT)
	if not bool(result.get("ok", false)):
		return {"success": false, "message": String(result.get("reason", "无法开始秘境"))}
	rift_state = result.get("state", rift_state)
	EventBus.resources_changed.emit()
	return {"success": true, "message": "试剑秘境 Lv.%d 已开始" % level, "active_run": result.get("active_run", {})}


func equip_gem(slot_id: String, gem_id: String) -> Dictionary:
	var result: Dictionary = GemSystem.equip_gem(gem_state, slot_id, gem_id)
	if not bool(result.get("ok", false)):
		return {"success": false, "message": String(result.get("reason", "无法镶嵌宝石"))}
	gem_state = result.get("state", gem_state)
	EventBus.equipment_changed.emit()
	return {"success": true, "message": "宝石已镶嵌"}


func get_martial_codex_runtime_state() -> Dictionary:
	var runtime: Dictionary = MartialCodexSystem.build_runtime_state(martial_codex_state)
	return {
		"slots": runtime.get("active_effects", []),
		"available_effects": runtime.get("unlocked_effects", []),
		"summary_text": "已解锁 %d 种武学" % runtime.get("unlocked_effect_ids", []).size(),
		"active_slots": runtime.get("active_slots", {}),
		"available_by_slot": runtime.get("available_by_slot", {}),
	}


func activate_martial_codex_effect(slot_id: String, effect_id: String) -> Dictionary:
	var result: Dictionary = MartialCodexSystem.set_active_effect(martial_codex_state, slot_id, effect_id)
	if not bool(result.get("ok", false)):
		return {"success": false, "message": String(result.get("reason", "无法装备武学"))}
	martial_codex_state = result.get("state", martial_codex_state)
	EventBus.equipment_changed.emit()
	return {"success": true, "message": "武学已装备"}


func execute_cube_recipe(_page: String, entry_id: String, options: Dictionary, equipment_generator: Variant) -> Dictionary:
	var selected_item: Dictionary = options.get("selected_item", {})
	if selected_item.is_empty():
		var item_id: String = String(options.get("item_id", ""))
		if not item_id.is_empty():
			for inv_item in inventory:
				if String(inv_item.get("id", "")) == item_id:
					selected_item = inv_item
					break
	var context: Dictionary = {
		"resource_reader": func(res_id: String) -> int: return get_resource_count(res_id),
		"resource_consumer": func(res_id: String, amount: int) -> void: consume_resource(res_id, amount),
		"equipment_generator": equipment_generator,
		"martial_codex_state": martial_codex_state,
	}
	var result: Dictionary = CubeSystem.execute_recipe(entry_id, selected_item, options, context)
	if not bool(result.get("ok", false)):
		return {"success": false, "message": String(result.get("reason", "配方执行失败")), "result_items": []}
	if bool(result.get("remove_input", false)) and not selected_item.is_empty():
		var item_id: String = String(selected_item.get("id", ""))
		for i in range(inventory.size()):
			if String(inventory[i].get("id", "")) == item_id:
				inventory.remove_at(i)
				break
	var replacement: Dictionary = result.get("replacement_item", {})
	var result_items: Array = []
	if not replacement.is_empty():
		inventory.append(replacement)
		result_items.append(replacement)
	for added_variant in result.get("added_items", []):
		var added_item: Dictionary = added_variant
		if not added_item.is_empty():
			inventory.append(added_item)
			result_items.append(added_item)
	var unlocked_effect_id: String = String(result.get("unlocked_effect_id", ""))
	if not unlocked_effect_id.is_empty():
		var unlock_result: Dictionary = MartialCodexSystem.unlock_effect(martial_codex_state, unlocked_effect_id)
		if bool(unlock_result.get("ok", false)):
			martial_codex_state = unlock_result.get("state", martial_codex_state)
	EventBus.inventory_changed.emit()
	EventBus.resources_changed.emit()
	EventBus.equipment_changed.emit()
	return {"success": true, "message": String(result.get("summary", "配方执行成功")), "result_items": result_items}


func consume_ui_focus_request(panel_id: String) -> Dictionary:
	if ui_focus_requests.has(panel_id):
		var request: Dictionary = ui_focus_requests[panel_id]
		ui_focus_requests.erase(panel_id)
		return request
	return {}


func push_ui_focus_request(panel_id: String, data: Dictionary) -> void:
	ui_focus_requests[panel_id] = data


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
	if get_rarity_rank(rarity) < get_rarity_rank(auto_salvage_below_rarity):
		var salvage_scrap_base: int = maxi(2, int(item.get("item_level", 1)) * get_rarity_rank(rarity))
		var salvage_scrap: int = get_adjusted_salvage_scrap(salvage_scrap_base)
		MetaProgressionSystem.add_resource("scrap", salvage_scrap)
		result["action"] = "salvage"
		result["scrap"] = salvage_scrap
	else:
		item["is_locked"] = bool(item.get("is_locked", false))
		inventory.append(item)
		result["action"] = "store"


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


func _merge_bonuses(totals: Dictionary, bonuses: Dictionary) -> void:
	for key_variant in bonuses.keys():
		var key: String = String(key_variant)
		var value: float = float(bonuses.get(key_variant, 0.0))
		if totals.has(key):
			totals[key] += value
		else:
			totals[key] = value


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
	grant_hero_experience(1.0)
	EventBus.resources_changed.emit()


func complete_node(node_id: String) -> void:
	current_run_clears += 1
	stable_node_id = node_id
	var node_data: Dictionary = ConfigDB.get_chapter_node(node_id)
	grant_boss_rift_key(node_data)
	grant_hero_experience(5.0)
	grant_paragon_experience(2.0)
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
	EventBus.node_changed.emit(current_node_id)


func fallback_to_stable_node() -> void:
	current_node_id = stable_node_id
	EventBus.node_changed.emit(current_node_id)


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
		"label": "道术伤害",
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
		return "突破后续: 再过当前节点，将推进到 %s。" % next_node_id
	if String(current_node.get("node_type", "")) != "boss":
		return ""
	var next_chapter_id: String = String(chapter_data.get("next_chapter_id", ""))
	if next_chapter_id.is_empty():
		return "突破后续: 当前探境已到尽头，之后转为高价值回刷。"
	var next_chapter: Dictionary = ConfigDB.get_chapter(next_chapter_id)
	return "突破后续: 击破后将开启 %s。" % String(next_chapter.get("name", next_chapter_id))


func _get_node_short_label(node_data: Dictionary, chapter_data: Dictionary) -> String:
	if node_data.is_empty():
		return current_node_id
	return "%s/%s" % [
		String(chapter_data.get("name", current_chapter_id)),
		String(node_data.get("node_type", String(node_data.get("id", current_node_id)))),
	]


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
		return "追踪: 未设机缘，先按传承推荐刷装"
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


func get_resource_count(resource_id: String) -> int:
	return _get_resource_amount(resource_id)


func consume_resource(resource_id: String, amount: int) -> void:
	_consume_resource(resource_id, amount)


func finish_rift_run(success: bool) -> Dictionary:
	var result: Dictionary = RiftSystem.finish_run(rift_state, success)
	if not bool(result.get("ok", false)):
		return {"success": false, "message": String(result.get("reason", "无法结束秘境"))}
	rift_state = result.get("state", rift_state)
	var reward_entries: Array = result.get("reward_entries", [])
	for reward_variant in reward_entries:
		var reward: Dictionary = reward_variant
		match String(reward.get("type", "")):
			"gem":
				var preferred_gem_id: String = GemSystem.get_preferred_gem_id_for_skill(selected_core_skill_id)
				var gem_result: Dictionary = GemSystem.grant_rift_reward(gem_state, preferred_gem_id)
				if bool(gem_result.get("ok", false)):
					gem_state = gem_result.get("state", gem_state)
			"hua_ring":
				var hua_ring: Dictionary = RiftSystem.build_hua_ring_item(
					String(reward.get("set_id", "")),
					int(reward.get("item_level", 1))
				)
				if not hua_ring.is_empty():
					process_loot_item(hua_ring)
	EventBus.resources_changed.emit()
	EventBus.equipment_changed.emit()
	return {
		"success": true,
		"message": " | ".join(result.get("summary_lines", [])),
		"cleared_level": int(result.get("cleared_level", 0)),
	}


func grant_paragon_experience(base_amount: float) -> void:
	if not bool(paragon_state.get("is_unlocked", false)):
		var unlock_result: Dictionary = ParagonSystem.ensure_unlocked(paragon_state, stable_node_id)
		paragon_state = unlock_result.get("state", paragon_state)
		if not bool(paragon_state.get("is_unlocked", false)):
			return
	var meta_bonuses: Dictionary = ParagonSystem.build_meta_bonuses(paragon_state)
	var bonus_percent: float = float(meta_bonuses.get("paragon_exp_gain_percent", 0.0))
	var season_meta: Dictionary = SeasonSystem.build_meta_bonuses(season_state)
	bonus_percent += float(season_meta.get("paragon_exp_gain_percent", 0.0))
	var result: Dictionary = ParagonSystem.gain_experience(paragon_state, base_amount, bonus_percent)
	if bool(result.get("ok", false)):
		paragon_state = result.get("state", paragon_state)


func grant_boss_rift_key(node_data: Dictionary) -> void:
	var result: Dictionary = RiftSystem.grant_boss_clear_key(rift_state, node_data)
	if bool(result.get("ok", false)):
		rift_state = result.get("state", rift_state)


func get_set_summary() -> Dictionary:
	return SetSystem.build_set_summary(equipped_items)


func grant_hero_experience(base_amount: float) -> void:
	var result: Dictionary = HeroProgressionSystem.gain_experience(hero_state, base_amount)
	if not bool(result.get("ok", false)):
		return
	hero_state = result.get("state", hero_state)
	var overflow: float = float(result.get("overflow_experience", 0.0))
	if overflow > 0.0:
		grant_paragon_experience(overflow)
	EventBus.resources_changed.emit()


func get_hero_progression_summary() -> Dictionary:
	return HeroProgressionSystem.build_runtime_summary(hero_state)


func get_hero_level() -> int:
	return int(hero_state.get("level", 1))


func get_main_hud_state() -> Dictionary:
	var chapter_data: Dictionary = ConfigDB.get_chapter(current_chapter_id)
	var node_data: Dictionary = ConfigDB.get_chapter_node(current_node_id)
	var chapter_name: String = String(chapter_data.get("name", current_chapter_id))
	var node_name: String = String(node_data.get("name", current_node_id))
	var archetype_label_text: String = "流派: --"
	var skill_data: Dictionary = get_selected_core_skill()
	if not skill_data.is_empty():
		archetype_label_text = "流派: %s" % String(skill_data.get("name", selected_core_skill_id))

	var daily_data: Dictionary = DailyGoalSystem.get_daily_goal_data()
	var objective_title: String = "每日修行"
	var goal_text: String = String(daily_data.get("primary_goal_summary", "暂无目标"))
	var progress_text: String = "--"
	var cta_text: String = String(daily_data.get("next_step_summary", "继续推进主目标"))
	var next_step_text: String = String(daily_data.get("next_step_summary", "继续推进当前目标"))
	var primary_goal: Dictionary = daily_data.get("primary_goal", {})
	if not primary_goal.is_empty():
		goal_text = String(primary_goal.get("title", "暂无目标"))
		progress_text = String(primary_goal.get("progress_text", "--"))

	var core_skill_name: String = String(skill_data.get("name", "核心技能"))
	var set_summary: Dictionary = get_set_summary()
	var set_text: String = String(set_summary.get("summary_text", "传承未激活"))

	return {
		"objective_summary": {
			"title": objective_title,
			"goal_text": goal_text,
			"progress_text": progress_text,
			"cta_text": cta_text,
			"next_step_text": next_step_text,
		},
		"loot_feed": {
			"lines": get_loot_summary_lines(5),
		},
		"player_header": {
			"name": "无名侠客",
			"archetype": archetype_label_text,
		},
		"stage_header": {
			"title": "%s · %s" % [chapter_name, node_name],
			"subtitle": "节点推进中",
			"run_text": "击杀 %d | 清图 %d" % [current_run_kills, current_run_clears],
		},
		"combat_bar": {
			"core_skill_name": core_skill_name,
			"focus_text": "技能循环运行中",
			"set_summary_text": set_text,
			"active_slots": [],
		},
	}


func set_ui_focus_request(panel_id: String, data: Dictionary) -> void:
	push_ui_focus_request(panel_id, data)


func get_inventory_screen_state(
	page: int = 0,
	filter_id: String = "all",
	sort_id: String = "score_desc",
	p_selected_item_id: String = "",
	p_selected_slot_id: String = ""
) -> Dictionary:
	const InventoryVMService = preload("res://scripts/utils/inventory_view_model_service.gd")
	return InventoryVMService.build_screen_state(
		inventory, equipped_items, page, filter_id, sort_id,
		p_selected_item_id, p_selected_slot_id
	)


func get_equipment_screen_state() -> Dictionary:
	var equip_entries: Array = []
	for slot_id in EQUIPMENT_SLOT_ORDER:
		var item: Dictionary = equipped_items.get(slot_id, {})
		var is_empty: bool = item.is_empty()
		equip_entries.append({
			"slot_id": slot_id,
			"is_empty": is_empty,
			"display_name": EQUIPMENT_SLOT_ORDER[EQUIPMENT_SLOT_ORDER.find(slot_id)] if EQUIPMENT_SLOT_ORDER.has(slot_id) else slot_id,
			"title": String(item.get("name", "未装备")) if not is_empty else "未装备",
			"subtitle": get_item_detail_text(item) if not is_empty else "未装备",
			"rarity": String(item.get("rarity", "common")) if not is_empty else "common",
			"badges": [],
		})
	var set_summary: Dictionary = get_set_summary()
	var codex_summary: Dictionary = get_martial_codex_runtime_state()
	return {
		"inventory_summary": "背包 %d 件" % inventory.size(),
		"set_summary_line": String(set_summary.get("summary_text", "传承未激活")),
		"codex_summary_line": String(codex_summary.get("summary_text", "武学未激活")),
		"slots": equip_entries,
	}


func unequip_slot(slot_id: String) -> void:
	if not equipped_items.has(slot_id):
		return
	var item: Dictionary = equipped_items[slot_id]
	if item.is_empty():
		return
	inventory.append(item)
	equipped_items[slot_id] = {}
	EventBus.equipment_changed.emit()
	EventBus.inventory_changed.emit()


func get_skill_screen_state() -> Dictionary:
	var skill_data: Dictionary = get_selected_core_skill()
	var hero_summary: Dictionary = get_hero_progression_summary()
	var schools: Array = []
	for archetype_id in BUILD_ARCHETYPE_PROFILES:
		var profile: Dictionary = BUILD_ARCHETYPE_PROFILES[archetype_id]
		schools.append({
			"id": archetype_id,
			"name": String(profile.get("display_name", archetype_id)),
		})
	var slot_entries: Array = []
	var active_skills: Array = []
	for skill_id in AVAILABLE_CORE_SKILLS:
		var sd: Dictionary = ConfigDB.get_core_skill(skill_id)
		active_skills.append({
			"id": skill_id,
			"name": String(sd.get("name", skill_id)),
			"description": String(sd.get("description", "")),
			"is_selected": skill_id == selected_core_skill_id,
			"runes": sd.get("runes", []),
		})
	return {
		"selected_school_id": _get_primary_archetype_tag(skill_data) if not skill_data.is_empty() else "whirlwind",
		"hero_summary": hero_summary,
		"schools": schools,
		"slot_entries": slot_entries,
		"active_skills": active_skills,
		"passive_skills": [],
		"selected_passives": [],
	}


func get_combat_loadout_state() -> Dictionary:
	var skill_data: Dictionary = get_selected_core_skill()
	if skill_data.is_empty():
		return {}
	return {
		"school_id": _get_primary_archetype_tag(skill_data),
		"hero_summary": get_hero_progression_summary(),
		"active_skills": {
			"basic": {},
			"core": skill_data,
			"tactic": {},
			"burst": {},
		},
		"passives": [],
	}


func equip_active_skill(slot_type: String, skill_id: String) -> Dictionary:
	if skill_id.is_empty():
		return {"ok": false, "reason": "技能ID为空"}
	var sd: Dictionary = ConfigDB.get_core_skill(skill_id)
	if sd.is_empty():
		return {"ok": false, "reason": "找不到技能: %s" % skill_id}
	select_core_skill(skill_id)
	EventBus.skill_loadout_changed.emit(get_skill_screen_state())
	return {"ok": true, "slot_type": slot_type}


func equip_skill_rune(_skill_id: String, _rune_id: String) -> Dictionary:
	return {"ok": true, "reason": "符文系统尚未完整实现"}


func equip_passive(_passive_slot: int, _passive_id: String) -> Dictionary:
	return {"ok": true, "reason": "被动系统尚未完整实现"}


func _reset_for_rebirth() -> void:
	current_chapter_id = "chapter_1"
	current_node_id = "ch1_n1"
	stable_node_id = "ch1_n1"
	current_run_kills = 0
	current_run_clears = 0
	inventory.clear()
	for slot_key in EQUIPMENT_SLOT_ORDER:
		equipped_items[slot_key] = {}
	rift_state = RiftSystem.create_default_state()
	gem_state = GemSystem.create_default_state()
	EventBus.node_changed.emit(current_node_id)
	EventBus.equipment_changed.emit()
	EventBus.inventory_changed.emit()
	EventBus.resources_changed.emit()
	EventBus.research_changed.emit()
