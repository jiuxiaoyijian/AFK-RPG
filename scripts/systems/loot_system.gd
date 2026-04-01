extends Node

const EQUIPMENT_ICON_PATHS := {
	"weapon": "res://assets/generated/icons/equip_weapon.png",
	"helmet": "res://assets/generated/icons/equip_helmet.png",
	"armor": "res://assets/generated/icons/equip_armor.png",
	"gloves": "res://assets/generated/icons/equip_gloves.png",
}
const RESOURCE_ICON_PATHS := {
	"gold": "res://assets/generated/afk_rpg_formal/icons/resource_xianghuoqian.png",
	"scrap": "res://assets/generated/afk_rpg_formal/icons/resource_cihui.png",
	"core": "res://assets/generated/afk_rpg_formal/icons/resource_linghe.png",
	"legend_shard": "res://assets/generated/afk_rpg_formal/icons/resource_zhenyi_canpian.png",
}

@onready var equipment_generator: Node = $"../EquipmentGeneratorSystem"


func process_node_loot(node_data: Dictionary, context: Dictionary = {}) -> Dictionary:
	var summary_lines: Array[String] = []
	var dropped_items: Array = []
	var best_highlight: Dictionary = {}
	var material_rewards: Array = []
	var reward_multiplier: float = maxf(1.0, float(context.get("reward_multiplier", 1.0)))
	var profile_id: String = String(node_data.get("repeat_rewards_profile_id", ""))
	var drop_profile: Dictionary = ConfigDB.get_drop_profile(profile_id)
	if drop_profile.is_empty():
		GameManager.update_loot_summary(["未配置掉落表"])
		return {}

	var material_result: Dictionary = _generate_materials(drop_profile, reward_multiplier)
	var material_lines: Array[String] = material_result.get("lines", [])
	material_rewards = material_result.get("rewards", [])
	summary_lines.append_array(material_lines)

	var equipment_rolls: int = int(drop_profile.get("equipment_rolls", 1)) + int(floor((reward_multiplier - 1.0) / 2.0))
	var dropped_any_equipment := false
	for _i in range(equipment_rolls):
		var equipment_chance: float = minf(1.0, float(drop_profile.get("equipment_chance", 0.0)) * (1.0 + (reward_multiplier - 1.0) * 0.12))
		if randf() > equipment_chance:
			continue
		var generated_item: Dictionary = generate_equipment_for_profile(drop_profile)
		if generated_item.is_empty():
			continue
		dropped_any_equipment = true
		dropped_items.append(generated_item)
		var result: Dictionary = GameManager.process_loot_item(generated_item)
		var rarity: String = String(generated_item.get("rarity", "common"))
		var loot_prefix: String = ""
		if not generated_item.get("legendary_affix", {}).is_empty():
			loot_prefix = "异宝真意! "
		elif GameManager.get_rarity_rank(rarity) >= GameManager.get_rarity_rank("legendary"):
			loot_prefix = "异宝掉落! "
		match String(result.get("action", "none")):
			"equip":
				summary_lines.append("%s装备: %s" % [loot_prefix, String(result.get("item_name", ""))])
			"salvage":
				summary_lines.append("%s分解: %s -> %s +%d" % [
					loot_prefix,
					String(result.get("item_name", "")),
					MetaProgressionSystem.get_resource_display_name("scrap"),
					int(result.get("scrap", 0)),
				])
			"store":
				summary_lines.append("%s入包: %s" % [loot_prefix, String(result.get("item_name", ""))])
		best_highlight = _pick_better_highlight(best_highlight, generated_item, result, loot_prefix)
	if not dropped_any_equipment:
		summary_lines.append("未掉落装备")

	for reward_item_variant in context.get("extra_dropped_items", []):
		var reward_item: Dictionary = reward_item_variant
		if reward_item.is_empty():
			continue
		dropped_items.append(reward_item)
		var reward_result := {
			"item_name": "[%s] %s" % [
				GameManager.get_rarity_display_name(String(reward_item.get("rarity", "common"))),
				String(reward_item.get("name", "秘境赠礼")),
			],
			"action": "store",
		}
		best_highlight = _pick_better_highlight(best_highlight, reward_item, reward_result, "秘境赠礼! ")

	for extra_line_variant in context.get("extra_summary_lines", []):
		var extra_line: String = String(extra_line_variant).strip_edges()
		if extra_line.is_empty():
			continue
		summary_lines.append(extra_line)

	if summary_lines.is_empty():
		summary_lines.append("本次未获得额外奖励")

	LootCodexSystem.record_node_loot(String(node_data.get("id", "")), dropped_items)
	GameManager.set_loot_highlight(best_highlight)
	GameManager.update_loot_summary(summary_lines)
	return {
		"summary_lines": summary_lines,
		"dropped_items": dropped_items,
		"best_highlight": best_highlight,
		"material_rewards": material_rewards,
	}


func generate_equipment_for_profile(drop_profile: Dictionary) -> Dictionary:
	if equipment_generator == null or not equipment_generator.has_method("generate_equipment_for_profile"):
		return {}
	return equipment_generator.generate_equipment_for_profile(drop_profile)


func _generate_materials(drop_profile: Dictionary, reward_multiplier: float = 1.0) -> Dictionary:
	var lines: Array[String] = []
	var rewards: Array = []
	for entry in drop_profile.get("material_entries", []):
		var item_id: String = String(entry.get("item_id", ""))
		var min_count: int = int(entry.get("min_count", 1))
		var max_count: int = int(entry.get("max_count", min_count))
		var base_count: int = maxi(1, int(round(float(randi_range(min_count, max_count)) * reward_multiplier)))
		var applied_entries: Array = MetaProgressionSystem.grant_rewards([{"item_id": item_id, "count": base_count}])
		var count: int = base_count
		if not applied_entries.is_empty():
			count = int(applied_entries[0].get("count", base_count))
		rewards.append({
			"item_id": item_id,
			"count": count,
		})
		match item_id:
			"gold", "scrap", "core", "legend_shard":
				lines.append("%s +%d" % [MetaProgressionSystem.get_resource_display_name(item_id), count])
			_:
				lines.append("%s +%d" % [item_id, count])
	return {
		"lines": lines,
		"rewards": rewards,
	}


func _pick_better_highlight(current_best: Dictionary, item: Dictionary, result: Dictionary, loot_prefix: String) -> Dictionary:
	var legendary_affix: Dictionary = item.get("legendary_affix", {})
	var legendary_affix_id: String = String(legendary_affix.get("legendary_affix_id", ""))
	var is_tracked_target: bool = not legendary_affix_id.is_empty() and legendary_affix_id == LootCodexSystem.tracked_legendary_affix_id
	var candidate: Dictionary = {
		"item_id": String(item.get("id", "")),
		"slot": String(item.get("slot", "")),
		"target_slot": String(result.get("target_slot", String(item.get("slot", "")))),
		"rarity": String(item.get("rarity", "common")),
		"item_name": String(result.get("item_name", item.get("name", ""))),
		"action": String(result.get("action", "none")),
		"has_legendary_affix": not legendary_affix.is_empty(),
		"legendary_affix_id": legendary_affix_id,
		"legendary_name": String(legendary_affix.get("name", "")),
		"is_tracked_target": is_tracked_target,
		"prefix": loot_prefix,
		"score": float(item.get("score", 0.0)),
	}

	if current_best.is_empty():
		return candidate

	var candidate_rank: int = _get_highlight_rank(candidate)
	var current_rank: int = _get_highlight_rank(current_best)
	if candidate_rank > current_rank:
		return candidate
	if candidate_rank == current_rank and float(candidate.get("score", 0.0)) > float(current_best.get("score", 0.0)):
		return candidate
	return current_best


func _get_highlight_rank(highlight: Dictionary) -> int:
	if bool(highlight.get("is_tracked_target", false)):
		return 140
	if bool(highlight.get("has_legendary_affix", false)):
		return 100
	var rarity_rank: int = GameManager.get_rarity_rank(String(highlight.get("rarity", "common")))
	var action_bonus: int = 0
	match String(highlight.get("action", "none")):
		"equip":
			action_bonus = 12
		"store":
			action_bonus = 6
		"salvage":
			action_bonus = 0
		_:
			action_bonus = 0
	return rarity_rank * 10 + action_bonus


func build_death_drop_visuals(node_data: Dictionary, enemy_type: String) -> Array:
	var profile_id: String = String(node_data.get("repeat_rewards_profile_id", ""))
	var drop_profile: Dictionary = ConfigDB.get_drop_profile(profile_id)
	if drop_profile.is_empty():
		return []

	var material_entries: Array = drop_profile.get("material_entries", [])
	if material_entries.is_empty():
		return []

	var spawn_count: int = 2
	match enemy_type:
		"elite":
			spawn_count = 3
		"boss":
			spawn_count = 5
		_:
			spawn_count = 2

	var visuals: Array = []
	for i in range(spawn_count):
		var entry: Dictionary = material_entries[min(i % material_entries.size(), material_entries.size() - 1)]
		var item_id: String = String(entry.get("item_id", "gold"))
		visuals.append(_build_material_visual_data(item_id, false, false, 0))
	return visuals


func build_reward_drop_visuals(result: Dictionary, node_data: Dictionary) -> Array:
	var visuals: Array = []
	var is_boss_node: bool = String(node_data.get("node_type", "")) == "boss"
	for reward_variant in result.get("material_rewards", []):
		var reward: Dictionary = reward_variant
		var item_id: String = String(reward.get("item_id", ""))
		var count: int = int(reward.get("count", 0))
		visuals.append(_build_material_visual_data(item_id, true, is_boss_node, count))

	for item_variant in result.get("dropped_items", []):
		var item: Dictionary = item_variant
		visuals.append(_build_item_visual_data(item, is_boss_node))
	return visuals


func _build_material_visual_data(item_id: String, show_label: bool, boss_bonus: bool, count: int) -> Dictionary:
	var tint: Color = Color(0.9, 0.9, 0.96, 1.0)
	var beam_color: Color = tint
	var show_beam: bool = boss_bonus
	match item_id:
		"gold":
			tint = Color(1.0, 0.82, 0.34, 1.0)
			beam_color = tint
		"scrap":
			tint = Color(0.92, 0.58, 0.34, 1.0)
			beam_color = tint
		"core":
			tint = Color(0.42, 0.92, 1.0, 1.0)
			beam_color = tint
			show_beam = true
		"legend_shard":
			tint = Color(1.0, 0.72, 0.34, 1.0)
			beam_color = tint
			show_beam = true
		_:
			tint = Color(0.84, 0.88, 0.94, 1.0)
			beam_color = tint

	var label_text: String = ""
	if show_label:
		label_text = _get_resource_label(item_id, count)

	return {
		"icon_path": String(RESOURCE_ICON_PATHS.get(item_id, RESOURCE_ICON_PATHS["gold"])),
		"label": label_text,
		"show_label": show_label,
		"show_beam": show_beam,
		"pickup_target": "resources",
		"tint": tint,
		"beam_color": beam_color,
		"visual_scale": 0.72 if show_label else 0.56,
		"spread": 44.0 if show_label else 30.0,
		"auto_pickup_delay": 3.0,
		"drop_duration": 0.44 if show_label else 0.36,
		"arc_height": 118.0 if show_label else 96.0,
		"z_index": 22,
	}


func _build_item_visual_data(item: Dictionary, boss_bonus: bool) -> Dictionary:
	var rarity: String = String(item.get("rarity", "common"))
	var slot: String = String(item.get("slot", "weapon"))
	var legendary_affix: Dictionary = item.get("legendary_affix", {})
	var has_legendary_affix: bool = not legendary_affix.is_empty()
	var legendary_affix_id: String = String(legendary_affix.get("legendary_affix_id", ""))
	var is_tracked_target: bool = not legendary_affix_id.is_empty() and legendary_affix_id == LootCodexSystem.tracked_legendary_affix_id
	var tint: Color = _get_rarity_color(rarity)
	var beam_color: Color = Color(1.0, 0.36, 0.24, 1.0) if is_tracked_target else tint
	var show_beam: bool = boss_bonus or has_legendary_affix or GameManager.get_rarity_rank(rarity) >= GameManager.get_rarity_rank("epic")
	return {
		"icon_path": String(EQUIPMENT_ICON_PATHS.get(slot, EQUIPMENT_ICON_PATHS["weapon"])),
		"label": _format_drop_item_name(item, is_tracked_target),
		"show_label": true,
		"show_beam": show_beam,
		"pickup_target": "inventory",
		"tint": tint,
		"beam_color": beam_color,
		"visual_scale": 0.96 if is_tracked_target else 0.84,
		"spread": 60.0 if is_tracked_target else 54.0,
		"auto_pickup_delay": 3.6 if is_tracked_target else 3.0,
		"drop_duration": 0.56 if is_tracked_target else 0.5,
		"arc_height": 172.0 if is_tracked_target else (156.0 if show_beam else 128.0),
		"z_index": 26 if is_tracked_target else 24,
	}


func _get_resource_label(item_id: String, count: int) -> String:
	match item_id:
		"gold", "scrap", "core", "legend_shard":
			return "%s +%d" % [MetaProgressionSystem.get_resource_display_name(item_id), count]
		_:
			return "%s +%d" % [item_id, count]


func _get_rarity_color(rarity: String) -> Color:
	match rarity:
		"uncommon":
			return Color(0.54, 0.92, 0.52, 1.0)
		"rare":
			return Color(0.46, 0.74, 1.0, 1.0)
		"epic":
			return Color(0.82, 0.56, 1.0, 1.0)
		"legendary":
			return Color(1.0, 0.76, 0.32, 1.0)
		"ancient":
			return Color(1.0, 0.46, 0.28, 1.0)
		_:
			return Color(0.84, 0.88, 0.94, 1.0)


func _format_drop_item_name(item: Dictionary, is_tracked_target: bool = false) -> String:
	var prefix: String = "[追踪达成] " if is_tracked_target else ""
	return "%s[%s] %s" % [prefix, String(item.get("rarity", "common")), String(item.get("name", "未知装备"))]
