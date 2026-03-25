extends RefCounted

const MartialCodexSystem = preload("res://scripts/systems/martial_codex_system.gd")


static func get_recipe_entries() -> Array:
	return ConfigDB.get_all_cube_recipes()


static func get_recipe(recipe_id: String) -> Dictionary:
	return ConfigDB.get_cube_recipe(recipe_id)


static func can_execute_recipe(recipe_id: String, resource_reader: Callable) -> Dictionary:
	var recipe: Dictionary = get_recipe(recipe_id)
	if recipe.is_empty():
		return {"ok": false, "reason": "配方不存在"}
	for cost_variant in recipe.get("costs", []):
		var cost: Dictionary = cost_variant
		var resource_id: String = String(cost.get("resource_id", ""))
		var amount: int = int(cost.get("amount", 0))
		if int(resource_reader.call(resource_id)) < amount:
			return {"ok": false, "reason": "%s 不足" % MetaProgressionSystem.get_resource_display_name(resource_id)}
	return {"ok": true, "reason": ""}


static func execute_recipe(recipe_id: String, item: Dictionary, options: Dictionary, context: Dictionary) -> Dictionary:
	var recipe: Dictionary = get_recipe(recipe_id)
	if recipe.is_empty():
		return {"ok": false, "reason": "配方不存在", "recipe_id": recipe_id}
	if item.is_empty():
		return {"ok": false, "reason": "未找到要处理的物品", "recipe_id": recipe_id}
	var resource_reader: Callable = context.get("resource_reader", Callable())
	if resource_reader.is_null():
		return {"ok": false, "reason": "资源读取器不可用", "recipe_id": recipe_id}
	var affordability: Dictionary = can_execute_recipe(recipe_id, resource_reader)
	if not bool(affordability.get("ok", false)):
		return {"ok": false, "reason": String(affordability.get("reason", "")), "recipe_id": recipe_id}

	var result: Dictionary = {
		"ok": false,
		"reason": "",
		"recipe_id": recipe_id,
		"recipe_name": String(recipe.get("name", recipe_id)),
		"consumed_costs": recipe.get("costs", []).duplicate(true),
		"remove_input": false,
		"replacement_item": {},
		"added_items": [],
		"unlocked_effect_id": "",
		"summary": "",
	}
	var rarity: String = String(item.get("rarity", "common"))
	match recipe_id:
		"extract":
			var legendary_affix: Dictionary = item.get("legendary_affix", {})
			var effect_id: String = String(legendary_affix.get("legendary_affix_id", ""))
			if GameManager.get_rarity_rank(rarity) < GameManager.get_rarity_rank(String(recipe.get("input_rarity_min", "epic"))):
				return _with_reason(result, "只有真意及以上装备才能萃取")
			if effect_id.is_empty():
				return _with_reason(result, "该装备没有可萃取的武学")
			if MartialCodexSystem.sanitize_state(context.get("martial_codex_state", {})).get("unlocked_effect_ids", []).has(effect_id):
				return _with_reason(result, "该武学已解锁")
			result["ok"] = true
			result["remove_input"] = true
			result["unlocked_effect_id"] = effect_id
			result["summary"] = "萃取成功: %s" % String(legendary_affix.get("name", effect_id))
		"upgrade_rare":
			if rarity != String(recipe.get("input_rarity", "rare")):
				return _with_reason(result, "只有玄品装备才能精钢化真")
			var equipment_generator: Node = context.get("equipment_generator", null)
			if equipment_generator == null or not equipment_generator.has_method("upgrade_rare_item"):
				return _with_reason(result, "造物系统未就绪")
			var upgraded_item: Dictionary = equipment_generator.upgrade_rare_item(item)
			if upgraded_item.is_empty():
				return _with_reason(result, "该装备无法升级")
			result["ok"] = true
			result["remove_input"] = true
			result["replacement_item"] = upgraded_item
			result["summary"] = "化真成功: %s" % String(upgraded_item.get("name", "真意装备"))
		"reforge":
			if GameManager.get_rarity_rank(rarity) < GameManager.get_rarity_rank(String(recipe.get("input_rarity_min", "epic"))):
				return _with_reason(result, "只有真意及以上装备才能重铸")
			var reforge_generator: Node = context.get("equipment_generator", null)
			if reforge_generator == null or not reforge_generator.has_method("reforge_item"):
				return _with_reason(result, "造物系统未就绪")
			var reforged_item: Dictionary = reforge_generator.reforge_item(item)
			if reforged_item.is_empty():
				return _with_reason(result, "该装备无法重铸")
			result["ok"] = true
			result["remove_input"] = true
			result["replacement_item"] = reforged_item
			result["summary"] = "重铸完成: %s" % String(reforged_item.get("name", "装备"))
		"convert_set":
			if rarity != String(recipe.get("input_rarity", "set")):
				return _with_reason(result, "只有传承装备才能互转")
			var target_slot: String = String(options.get("target_slot", ""))
			if target_slot.is_empty():
				return _with_reason(result, "请选择目标槽位")
			var convert_generator: Node = context.get("equipment_generator", null)
			if convert_generator == null or not convert_generator.has_method("convert_set_item"):
				return _with_reason(result, "造物系统未就绪")
			var converted_item: Dictionary = convert_generator.convert_set_item(item, target_slot)
			if converted_item.is_empty():
				return _with_reason(result, "该传承无法互转到目标槽位")
			result["ok"] = true
			result["remove_input"] = true
			result["replacement_item"] = converted_item
			result["summary"] = "互转完成: %s -> %s" % [String(item.get("name", "")), String(converted_item.get("name", ""))]
		"refine_affix":
			if GameManager.get_rarity_rank(rarity) < GameManager.get_rarity_rank(String(recipe.get("input_rarity_min", "epic"))):
				return _with_reason(result, "只有真意及以上装备才能淬火")
			var refine_index: int = int(options.get("affix_index", -1))
			if item.has("refine_slot_index"):
				refine_index = int(item.get("refine_slot_index", refine_index))
			if refine_index < 0:
				return _with_reason(result, "请选择要淬火的词条")
			var refine_generator: Node = context.get("equipment_generator", null)
			if refine_generator == null or not refine_generator.has_method("refine_affix_item"):
				return _with_reason(result, "造物系统未就绪")
			var refined_item: Dictionary = refine_generator.refine_affix_item(item, refine_index)
			if refined_item.is_empty():
				return _with_reason(result, "该装备无法淬火当前词条")
			result["ok"] = true
			result["remove_input"] = true
			result["replacement_item"] = refined_item
			result["summary"] = "淬火完成: %s" % String(refined_item.get("name", "装备"))
		_:
			return _with_reason(result, "暂不支持该百炼坊配方")

	var resource_consumer: Callable = context.get("resource_consumer", Callable())
	if result["ok"] and not resource_consumer.is_null():
		for cost_variant in result.get("consumed_costs", []):
			var cost: Dictionary = cost_variant
			resource_consumer.call(String(cost.get("resource_id", "")), int(cost.get("amount", 0)))
	return result


static func _with_reason(result: Dictionary, reason: String) -> Dictionary:
	result["ok"] = false
	result["reason"] = reason
	return result
