extends Node

const DEFAULT_MAX_OFFLINE_SECONDS := 28800
const DEFAULT_OFFLINE_EFFICIENCY := 0.65
const DEFAULT_SECONDS_PER_RUN := 22.0
const MAX_OFFLINE_EQUIPMENT := 6


func process_saved_timestamp(saved_unix_time: int) -> void:
	if saved_unix_time <= 0:
		return
	call_deferred("_process_offline_rewards", saved_unix_time)


func _process_offline_rewards(saved_unix_time: int) -> void:
	var now_unix_time: int = int(Time.get_unix_time_from_system())
	var elapsed_seconds: int = maxi(0, now_unix_time - saved_unix_time)
	if elapsed_seconds < 60:
		return

	var node_id: String = GameManager.stable_node_id if not GameManager.stable_node_id.is_empty() else GameManager.current_node_id
	var node_data: Dictionary = ConfigDB.get_chapter_node(node_id)
	if node_data.is_empty():
		return

	var profile_id: String = String(node_data.get("repeat_rewards_profile_id", ""))
	var drop_profile: Dictionary = ConfigDB.get_drop_profile(profile_id)
	if drop_profile.is_empty():
		return

	var meta_bonuses: Dictionary = MetaProgressionSystem.get_meta_progression_bonuses()
	var max_offline_seconds_bonus: int = int(round(float(meta_bonuses.get("max_offline_seconds_bonus", 0.0))))
	var capped_seconds: int = mini(
		elapsed_seconds,
		int(drop_profile.get("max_offline_seconds", DEFAULT_MAX_OFFLINE_SECONDS)) + max_offline_seconds_bonus
	)
	var seconds_per_run: float = float(drop_profile.get("offline_seconds_per_run", DEFAULT_SECONDS_PER_RUN))
	var efficiency: float = float(drop_profile.get("offline_efficiency", DEFAULT_OFFLINE_EFFICIENCY)) + float(meta_bonuses.get("offline_efficiency_bonus", 0.0))
	efficiency = clampf(efficiency, 0.1, 1.5)
	var simulated_runs: int = int(floor(float(capped_seconds) / seconds_per_run))
	if simulated_runs <= 0:
		return

	var summary_lines: Array[String] = []
	summary_lines.append("闭关时长: %d 分 %d 秒" % [int(capped_seconds / 60.0), int(capped_seconds % 60)])
	summary_lines.append("闭关节点: %s" % node_id)
	summary_lines.append("掉落方向: %s" % String(drop_profile.get("drop_focus", "常规掉落")))
	summary_lines.append("模拟轮次: %d" % simulated_runs)
	summary_lines.append("悟道修正: 效率 x%.2f, 上限 %+d 秒" % [efficiency, max_offline_seconds_bonus])

	var material_lines: Array[String] = _grant_offline_materials(drop_profile, simulated_runs, efficiency)
	summary_lines.append_array(material_lines)

	var equipment_lines: Array[String] = _grant_offline_equipment(drop_profile, simulated_runs, efficiency)
	summary_lines.append_array(equipment_lines)

	if summary_lines.size() <= 4:
		summary_lines.append("本次离线未获得额外收益")

	EventBus.offline_report_ready.emit("\n".join(summary_lines))


func _grant_offline_materials(drop_profile: Dictionary, simulated_runs: int, efficiency: float) -> Array[String]:
	var lines: Array[String] = []
	for entry in drop_profile.get("material_entries", []):
		var item_id: String = String(entry.get("item_id", ""))
		var min_count: int = int(entry.get("min_count", 1))
		var max_count: int = int(entry.get("max_count", min_count))
		var average_count: float = (float(min_count) + float(max_count)) * 0.5
		var base_count: int = maxi(1, int(round(average_count * simulated_runs * efficiency)))
		var applied_entries: Array = MetaProgressionSystem.grant_rewards([{"item_id": item_id, "count": base_count}])
		var total_count: int = base_count
		if not applied_entries.is_empty():
			total_count = int(applied_entries[0].get("count", base_count))
		match item_id:
			"gold", "scrap", "core", "legend_shard":
				lines.append("%s +%d" % [MetaProgressionSystem.get_resource_display_name(item_id), total_count])
			_:
				lines.append("%s +%d" % [item_id, total_count])
	return lines


func _grant_offline_equipment(drop_profile: Dictionary, simulated_runs: int, efficiency: float) -> Array[String]:
	var lines: Array[String] = []
	var loot_system: Node = _get_loot_system()
	if loot_system == null:
		lines.append("闭关装备结算未接入 LootSystem")
		return lines

	var equipment_rolls: int = int(drop_profile.get("equipment_rolls", 1))
	var equipment_chance: float = float(drop_profile.get("equipment_chance", 0.0))
	var equipment_count: int = mini(
		MAX_OFFLINE_EQUIPMENT,
		int(round(float(simulated_runs) * float(equipment_rolls) * equipment_chance * efficiency))
	)

	if equipment_count <= 0:
		lines.append("闭关未掉落装备")
		return lines

	for _i in range(equipment_count):
		if not loot_system.has_method("generate_equipment_for_profile"):
			break
		var item: Dictionary = loot_system.generate_equipment_for_profile(drop_profile)
		if item.is_empty():
			continue
		var result: Dictionary = GameManager.process_loot_item(item)
		var prefix: String = ""
		if not item.get("legendary_affix", {}).is_empty():
			prefix = "异宝真意! "
		elif GameManager.get_rarity_rank(String(item.get("rarity", "common"))) >= GameManager.get_rarity_rank("legendary"):
			prefix = "异宝掉落! "
		match String(result.get("action", "none")):
			"equip":
				lines.append("%s闭关装备: %s" % [prefix, String(result.get("item_name", ""))])
			"salvage":
				lines.append("%s闭关分解: %s -> %s +%d" % [
					prefix,
					String(result.get("item_name", "")),
					MetaProgressionSystem.get_resource_display_name("scrap"),
					int(result.get("scrap", 0)),
				])
			"store":
				lines.append("%s闭关入包: %s" % [prefix, String(result.get("item_name", ""))])
	return lines


func _get_loot_system() -> Node:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("Systems/LootSystem")
