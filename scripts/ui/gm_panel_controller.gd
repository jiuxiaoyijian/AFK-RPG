extends Control

const RESOURCE_IDS := ["gold", "scrap", "core", "legend_shard"]
const RARITY_IDS := ["common", "uncommon", "rare", "epic", "set", "legendary", "ancient"]

@onready var equipment_generator: Node = $"../../Systems/EquipmentGeneratorSystem"
@onready var title_label: Label = $Panel/TitleLabel
@onready var summary_label: Label = $Panel/SummaryLabel
@onready var close_button: Button = $Panel/CloseButton
@onready var resource_option: OptionButton = $Panel/ResourceSection/ResourceOption
@onready var resource_amount_spin: SpinBox = $Panel/ResourceSection/ResourceAmountSpin
@onready var resource_add_button: Button = $Panel/ResourceSection/ResourceAddButton
@onready var resource_set_button: Button = $Panel/ResourceSection/ResourceSetButton
@onready var base_option: OptionButton = $Panel/ItemSection/BaseOption
@onready var rarity_option: OptionButton = $Panel/ItemSection/RarityOption
@onready var item_count_spin: SpinBox = $Panel/ItemSection/ItemCountSpin
@onready var item_level_spin: SpinBox = $Panel/ItemSection/ItemLevelSpin
@onready var force_legendary_check: CheckBox = $Panel/ItemSection/ForceLegendaryCheck
@onready var add_item_button: Button = $Panel/ItemSection/AddItemButton
@onready var node_option: OptionButton = $Panel/NodeSection/NodeOption
@onready var jump_node_button: Button = $Panel/NodeSection/JumpNodeButton
@onready var restart_node_button: Button = $Panel/NodeSection/RestartNodeButton
@onready var unlock_research_button: Button = $Panel/ProgressSection/UnlockResearchButton
@onready var unlock_codex_button: Button = $Panel/ProgressSection/UnlockCodexButton
@onready var unlock_all_button: Button = $Panel/ProgressSection/UnlockAllButton
@onready var max_resources_button: Button = $Panel/ProgressSection/MaxResourcesButton
@onready var reset_resources_button: Button = $Panel/ProgressSection/ResetResourcesButton
@onready var clear_inventory_button: Button = $Panel/ProgressSection/ClearInventoryButton
@onready var clear_drop_stats_button: Button = $Panel/ProgressSection/ClearDropStatsButton
@onready var save_slot_option: OptionButton = $Panel/ProgressSection/SaveSlotOption
@onready var save_button: Button = $Panel/ProgressSection/SaveButton
@onready var load_button: Button = $Panel/ProgressSection/LoadButton
@onready var slot_hint_label: Label = $Panel/ProgressSection/SlotHintLabel
@onready var action_log_label: Label = $Panel/ActionLogLabel


func _ready() -> void:
	visible = false
	_apply_visual_style()
	_populate_resource_options()
	_populate_rarity_options()
	_populate_base_options()
	_populate_node_options()
	_populate_save_slot_options()

	close_button.pressed.connect(_on_close_pressed)
	resource_add_button.pressed.connect(_on_resource_add_pressed)
	resource_set_button.pressed.connect(_on_resource_set_pressed)
	add_item_button.pressed.connect(_on_add_item_pressed)
	jump_node_button.pressed.connect(_on_jump_node_pressed)
	restart_node_button.pressed.connect(_on_restart_node_pressed)
	unlock_research_button.pressed.connect(_on_unlock_research_pressed)
	unlock_codex_button.pressed.connect(_on_unlock_codex_pressed)
	unlock_all_button.pressed.connect(_on_unlock_all_pressed)
	max_resources_button.pressed.connect(_on_max_resources_pressed)
	reset_resources_button.pressed.connect(_on_reset_resources_pressed)
	clear_inventory_button.pressed.connect(_on_clear_inventory_pressed)
	clear_drop_stats_button.pressed.connect(_on_clear_drop_stats_pressed)
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)

	EventBus.resources_changed.connect(_refresh)
	EventBus.inventory_changed.connect(_refresh)
	EventBus.research_changed.connect(_refresh)
	EventBus.codex_changed.connect(_refresh)
	EventBus.node_changed.connect(_refresh)

	_refresh()


func open_panel() -> void:
	visible = true
	_refresh()


func _refresh(_unused: Variant = null) -> void:
	title_label.text = "GM 调试面板"
	summary_label.text = "节点 %s | 库存 %d 件 | 香火钱 %d | 祠灰 %d | 灵核 %d | 真意残片 %d" % [
		GameManager.current_node_id,
		GameManager.get_inventory_count(),
		MetaProgressionSystem.get_resource_amount("gold"),
		MetaProgressionSystem.get_resource_amount("scrap"),
		MetaProgressionSystem.get_resource_amount("core"),
		MetaProgressionSystem.get_resource_amount("legend_shard"),
	]
	slot_hint_label.text = "快捷键 F5/F8 默认作用于档位 1 | GM 面板可读写 1~3 档"
	_sync_node_selection()


func _populate_resource_options() -> void:
	resource_option.clear()
	for resource_id in RESOURCE_IDS:
		resource_option.add_item(_get_resource_label(resource_id))
		resource_option.set_item_metadata(resource_option.item_count - 1, resource_id)
	if resource_option.item_count > 0:
		resource_option.select(0)


func _populate_rarity_options() -> void:
	rarity_option.clear()
	for rarity_id in RARITY_IDS:
		rarity_option.add_item(rarity_id)
		rarity_option.set_item_metadata(rarity_option.item_count - 1, rarity_id)
	rarity_option.select(2)


func _populate_base_options() -> void:
	base_option.clear()
	var entries: Array = ConfigDB.get_all_equipment_bases()
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("name", "")) < String(b.get("name", ""))
	)
	for entry_variant in entries:
		var entry: Dictionary = entry_variant
		base_option.add_item("%s | %s" % [String(entry.get("slot", "")), String(entry.get("name", ""))])
		base_option.set_item_metadata(base_option.item_count - 1, String(entry.get("id", "")))
	if base_option.item_count > 0:
		base_option.select(0)


func _populate_node_options() -> void:
	node_option.clear()
	var node_entries: Array[Dictionary] = []
	for node_id_variant in ConfigDB.chapter_nodes.keys():
		var node_id: String = String(node_id_variant)
		var node_data: Dictionary = ConfigDB.get_chapter_node(node_id)
		var chapter_data: Dictionary = ConfigDB.get_chapter(String(node_data.get("chapter_id", "")))
		node_entries.append({
			"node_id": node_id,
			"label": "%s | %s | %s" % [
				String(chapter_data.get("name", "")),
				node_id,
				String(node_data.get("node_type", "normal")),
			],
		})
	node_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("label", "")) < String(b.get("label", ""))
	)
	for entry in node_entries:
		node_option.add_item(String(entry.get("label", "")))
		node_option.set_item_metadata(node_option.item_count - 1, String(entry.get("node_id", "")))
	if node_option.item_count > 0:
		node_option.select(0)


func _populate_save_slot_options() -> void:
	save_slot_option.clear()
	for slot in range(1, SaveManager.get_save_slot_count() + 1):
		save_slot_option.add_item("存档位 %d" % slot)
		save_slot_option.set_item_metadata(save_slot_option.item_count - 1, slot)
	if save_slot_option.item_count > 0:
		save_slot_option.select(0)


func _sync_node_selection() -> void:
	for index in range(node_option.item_count):
		if String(node_option.get_item_metadata(index)) == GameManager.current_node_id:
			node_option.select(index)
			return


func _on_close_pressed() -> void:
	EventBus.ui_close_requested.emit()


func _on_resource_add_pressed() -> void:
	var resource_id: String = _get_selected_option_metadata(resource_option)
	var amount: int = int(resource_amount_spin.value)
	MetaProgressionSystem.add_resource(resource_id, amount)
	_push_action_log("已增加资源 %s +%d" % [_get_resource_label(resource_id), amount])


func _on_resource_set_pressed() -> void:
	var resource_id: String = _get_selected_option_metadata(resource_option)
	var amount: int = int(resource_amount_spin.value)
	MetaProgressionSystem.gm_set_resource(resource_id, amount)
	_push_action_log("已设置资源 %s = %d" % [_get_resource_label(resource_id), amount])


func _on_add_item_pressed() -> void:
	if equipment_generator == null or not equipment_generator.has_method("generate_debug_item"):
		_push_action_log("装备调试生成器不可用")
		return
	var base_id: String = _get_selected_option_metadata(base_option)
	var rarity: String = _get_selected_option_metadata(rarity_option)
	var item_count: int = maxi(1, int(item_count_spin.value))
	var item_level: int = maxi(1, int(item_level_spin.value))
	var created_count: int = 0
	for _i in range(item_count):
		var item: Dictionary = equipment_generator.generate_debug_item(
			base_id,
			rarity,
			item_level,
			true,
			force_legendary_check.button_pressed
		)
		if item.is_empty():
			continue
		GameManager.gm_add_inventory_item(item)
		created_count += 1
	var base_data: Dictionary = ConfigDB.equipment_bases.get(base_id, {})
	_push_action_log("已添加装备 %s x%d" % [String(base_data.get("name", base_id)), created_count])


func _on_jump_node_pressed() -> void:
	var node_id: String = _get_selected_option_metadata(node_option)
	if GameManager.gm_jump_to_node(node_id):
		_push_action_log("已跳转到节点 %s" % node_id)
	else:
		_push_action_log("节点跳转失败")


func _on_restart_node_pressed() -> void:
	EventBus.node_changed.emit(GameManager.current_node_id)
	_push_action_log("已重开当前节点 %s" % GameManager.current_node_id)


func _on_unlock_research_pressed() -> void:
	MetaProgressionSystem.gm_unlock_all_research()
	_push_action_log("已解锁全部天赋树")


func _on_unlock_codex_pressed() -> void:
	LootCodexSystem.gm_unlock_all_codex()
	_push_action_log("已解锁全部异闻录")


func _on_unlock_all_pressed() -> void:
	MetaProgressionSystem.gm_unlock_all_research()
	LootCodexSystem.gm_unlock_all_codex()
	_push_action_log("已解锁全部悟道与异闻录")


func _on_max_resources_pressed() -> void:
	for resource_id in RESOURCE_IDS:
		MetaProgressionSystem.gm_set_resource(resource_id, 999999)
	_push_action_log("已将常用资源拉满")


func _on_reset_resources_pressed() -> void:
	MetaProgressionSystem.gm_reset_all_resources()
	_push_action_log("已重置全部系统资源")


func _on_clear_inventory_pressed() -> void:
	GameManager.gm_clear_inventory()
	_push_action_log("已清空背包")


func _on_clear_drop_stats_pressed() -> void:
	LootCodexSystem.gm_clear_drop_stats()
	_push_action_log("已清空机缘推演样本")


func _on_save_pressed() -> void:
	var slot: int = _get_selected_save_slot()
	if SaveManager.save_game(slot):
		_push_action_log("GM 手动存档完成 [档位 %d]" % slot)
	else:
		_push_action_log("GM 手动存档失败")


func _on_load_pressed() -> void:
	var slot: int = _get_selected_save_slot()
	if SaveManager.load_game(slot):
		_push_action_log("GM 手动读档完成 [档位 %d]" % slot)
	else:
		_push_action_log("GM 读档失败，该档位暂无存档")


func _get_selected_option_metadata(option_button: OptionButton) -> String:
	if option_button.item_count <= 0 or option_button.selected < 0:
		return ""
	return String(option_button.get_item_metadata(option_button.selected))


func _get_selected_save_slot() -> int:
	if save_slot_option.item_count <= 0 or save_slot_option.selected < 0:
		return 1
	return int(save_slot_option.get_item_metadata(save_slot_option.selected))


func _get_resource_label(resource_id: String) -> String:
	match resource_id:
		"gold":
			return "香火钱"
		"scrap":
			return "祠灰"
		"core":
			return "灵核"
		"legend_shard":
			return "真意残片"
		_:
			return resource_id


func _push_action_log(text: String) -> void:
	action_log_label.text = "最近操作: %s" % text
	EventBus.combat_state_changed.emit("GM: %s" % text)


func _apply_visual_style() -> void:
	title_label.add_theme_color_override("font_color", Color(0.98, 0.92, 0.72, 1.0))
	summary_label.add_theme_color_override("font_color", Color(0.78, 0.84, 0.96, 1.0))
	action_log_label.add_theme_color_override("font_color", Color(0.56, 0.96, 0.70, 1.0))
	slot_hint_label.add_theme_color_override("font_color", Color(0.82, 0.86, 0.96, 1.0))
	for button in [
		close_button,
		resource_add_button,
		resource_set_button,
		add_item_button,
		jump_node_button,
		restart_node_button,
		unlock_research_button,
		unlock_codex_button,
		unlock_all_button,
		max_resources_button,
		reset_resources_button,
		clear_inventory_button,
		clear_drop_stats_button,
		save_button,
		load_button,
	]:
		button.self_modulate = Color(0.34, 0.50, 0.84, 1.0)
