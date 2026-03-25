extends Control

const UI_STYLE = preload("res://scripts/ui/ui_style.gd")
const RiftSystem = preload("res://scripts/systems/rift_system.gd")
const GemSystem = preload("res://scripts/systems/gem_system.gd")

@onready var title_label: Label = $Panel/TitleLabel
@onready var summary_label: Label = $Panel/SummaryLabel
@onready var tab_section_label: Label = $Panel/TabSectionLabel
@onready var analysis_tab_button: Button = $Panel/AnalysisTabButton
@onready var rift_tab_button: Button = $Panel/RiftTabButton
@onready var results_tab_button: Button = $Panel/ResultsTabButton
@onready var quick_section_label: Label = $Panel/QuickSectionLabel
@onready var list_section_label: Label = $Panel/ListSectionLabel
@onready var detail_section_label: Label = $Panel/DetailSectionLabel
@onready var rate_section_label: Label = $Panel/RateSectionLabel
@onready var recent_section_label: Label = $Panel/RecentSectionLabel
@onready var quick_hint_label: Label = $Panel/QuickHintLabel
@onready var current_button: Button = $Panel/CurrentButton
@onready var recommended_button: Button = $Panel/RecommendedButton
@onready var rift_down_button: Button = $Panel/RiftDownButton
@onready var rift_level_label: Label = $Panel/RiftLevelLabel
@onready var rift_up_button: Button = $Panel/RiftUpButton
@onready var rift_start_button: Button = $Panel/RiftStartButton
@onready var close_button: Button = $Panel/CloseButton
@onready var node_list: ItemList = $Panel/NodeList
@onready var page_status_label: RichTextLabel = $Panel/PageStatusLabel
@onready var detail_label: RichTextLabel = $Panel/DetailLabel
@onready var equipment_rate_label: RichTextLabel = $Panel/EquipmentRateLabel
@onready var equipment_rate_bar: ProgressBar = $Panel/EquipmentRateBar
@onready var legendary_rate_label: RichTextLabel = $Panel/LegendaryRateLabel
@onready var legendary_rate_bar: ProgressBar = $Panel/LegendaryRateBar
@onready var tracked_rate_label: RichTextLabel = $Panel/TrackedRateLabel
@onready var tracked_rate_bar: ProgressBar = $Panel/TrackedRateBar
@onready var recent_label: RichTextLabel = $Panel/RecentLabel
@onready var gem_summary_label: Label = $Panel/GemSummaryLabel
@onready var gem_slot1_button: Button = $Panel/GemSlot1Button
@onready var gem_slot2_button: Button = $Panel/GemSlot2Button

var selected_node_id: String = ""
var selected_rift_level: int = 1
var active_tab: String = "analysis"


func _ready() -> void:
	visible = false
	_apply_visual_style()
	analysis_tab_button.pressed.connect(_on_tab_pressed.bind("analysis"))
	rift_tab_button.pressed.connect(_on_tab_pressed.bind("rift"))
	results_tab_button.pressed.connect(_on_tab_pressed.bind("results"))
	current_button.pressed.connect(_on_current_pressed)
	recommended_button.pressed.connect(_on_recommended_pressed)
	rift_down_button.pressed.connect(_on_rift_down_pressed)
	rift_up_button.pressed.connect(_on_rift_up_pressed)
	rift_start_button.pressed.connect(_on_rift_start_pressed)
	gem_slot1_button.pressed.connect(_on_gem_slot_pressed.bind("accessory1"))
	gem_slot2_button.pressed.connect(_on_gem_slot_pressed.bind("accessory2"))
	close_button.pressed.connect(_on_close_pressed)
	node_list.item_selected.connect(_on_node_selected)

	EventBus.codex_changed.connect(_refresh)
	EventBus.node_changed.connect(_on_node_changed)
	EventBus.loot_target_changed.connect(_refresh)
	EventBus.rift_run_started.connect(_on_rift_state_changed)
	EventBus.rift_run_finished.connect(_on_rift_state_changed)
	EventBus.gem_upgraded.connect(_on_gem_upgraded)
	EventBus.inventory_changed.connect(_refresh)

	_refresh()


func _refresh() -> void:
	var hub_summary: Dictionary = GameManager.get_analysis_hub_summary()
	title_label.text = "推演与秘境"
	tab_section_label.text = "分析页签"
	summary_label.text = String(hub_summary.get("summary_text", "推演概览"))
	_update_tab_buttons()

	match active_tab:
		"rift":
			_refresh_rift_page()
		"results":
			_refresh_results_page()
		_:
			_refresh_analysis_page()


func _refresh_analysis_page() -> void:
	quick_section_label.text = "机缘捷径"
	list_section_label.text = "节点样本"
	detail_section_label.text = "节点详情"
	rate_section_label.text = "机缘效率"
	recent_section_label.text = "近期样本"
	current_button.text = "当前节点"
	recommended_button.text = "推荐机缘"

	_set_page_mode("analysis")
	var previous_selection: String = selected_node_id
	selected_node_id = ""
	node_list.clear()

	for entry_variant in LootCodexSystem.get_drop_stat_entries():
		var entry: Dictionary = entry_variant
		var node_id: String = String(entry.get("node_id", ""))
		var label: String = "%s%s - %s | 刷 %d | 装备 %d | 传奇 %d" % [
			"[当前] " if bool(entry.get("is_current", false)) else "",
			String(entry.get("chapter_name", "")),
			String(entry.get("node_name", node_id)),
			int(entry.get("clears", 0)),
			int(entry.get("equipment_drops", 0)),
			int(entry.get("legendary_drops", 0)),
		]
		node_list.add_item(label)
		node_list.set_item_metadata(node_list.item_count - 1, node_id)
		if node_id == previous_selection:
			selected_node_id = node_id
			node_list.select(node_list.item_count - 1)

	if selected_node_id.is_empty() and node_list.item_count > 0:
		var preferred_node_id: String = GameManager.current_node_id
		var recommendation: Dictionary = LootCodexSystem.get_recommended_farm_node_for_legendary(LootCodexSystem.tracked_legendary_affix_id)
		if not recommendation.is_empty():
			preferred_node_id = String(recommendation.get("node_id", preferred_node_id))
		var preferred_index: int = _find_index_by_node_id(preferred_node_id)
		if preferred_index < 0:
			preferred_index = _find_index_by_node_id(GameManager.current_node_id)
		if preferred_index < 0:
			preferred_index = 0
		node_list.select(preferred_index)
		selected_node_id = String(node_list.get_item_metadata(preferred_index))

	_refresh_analysis_detail()
	_refresh_analysis_hint()


func _refresh_analysis_detail() -> void:
	detail_label.text = LootCodexSystem.get_drop_stat_detail_text(selected_node_id)
	detail_label.scroll_to_line(0)
	detail_label.add_theme_color_override("default_color", Color(0.82, 0.90, 1.0, 1.0))

	var visual_data: Dictionary = LootCodexSystem.get_drop_stat_visual_data(selected_node_id)
	_apply_rate_entry(equipment_rate_label, equipment_rate_bar, visual_data.get("equipment", {}))
	_apply_rate_entry(legendary_rate_label, legendary_rate_bar, visual_data.get("legendary", {}))
	_apply_rate_entry(tracked_rate_label, tracked_rate_bar, visual_data.get("tracked_target", {}))

	var recent_lines: Array[String] = []
	for record_variant in LootCodexSystem.get_recent_drop_records(4, selected_node_id):
		var record: Dictionary = record_variant
		recent_lines.append("%d. [%s] %s" % [
			int(record.get("clear_index", 0)),
			_get_node_type_label(String(record.get("node_type", "normal"))),
			String(record.get("summary", "无掉落")),
		])
	if recent_lines.is_empty():
		recent_label.text = "暂无记录\n继续刷图后会在这里累计最近样本。"
	else:
		recent_label.text = "\n".join(recent_lines)
	recent_label.scroll_to_line(0)


func _refresh_analysis_hint() -> void:
	var recommendation: Dictionary = LootCodexSystem.get_recommended_farm_node_for_legendary(LootCodexSystem.tracked_legendary_affix_id)
	var recommendation_label: String = String(recommendation.get("short_label", "暂无推荐"))
	var analysis_summary: Dictionary = GameManager.get_analysis_hub_summary()
	quick_hint_label.text = "当前节点: %s | 推荐节点: %s | %s" % [
		ConfigDB.get_chapter_node_short_label(GameManager.current_node_id),
		recommendation_label,
		String(analysis_summary.get("rift_summary", "暂无秘境摘要")),
	]
	_update_button_style(current_button, Color(0.36, 0.64, 0.96, 1.0))
	_update_button_style(
		recommended_button,
		Color(0.98, 0.74, 0.32, 1.0) if not recommendation.is_empty() else Color(0.42, 0.42, 0.46, 1.0)
	)


func _refresh_rift_page() -> void:
	quick_section_label.text = "试剑入口"
	list_section_label.text = "秘境概览"
	detail_section_label.text = "当前层状态"
	rate_section_label.text = "试剑缩放"
	recent_section_label.text = "宝石 / 华戒"

	_set_page_mode("rift")
	_refresh_rift_controls()
	_refresh_gem_section(true)
	_refresh_rift_status_blocks()
	_refresh_rift_hint()


func _refresh_rift_status_blocks() -> void:
	var runtime: Dictionary = GameManager.get_rift_runtime_summary()
	var scaling: Dictionary = RiftSystem.get_scaling_for_level(selected_rift_level)
	var active_run: Dictionary = runtime.get("active_run", {})
	var status_lines: Array[String] = []
	status_lines.append("最高层: Lv.%d" % int(runtime.get("highest_level", 0)))
	status_lines.append("推荐层: Lv.%d" % int(runtime.get("recommended_level", selected_rift_level)))
	status_lines.append(String(runtime.get("key_summary", "暂无试剑令")))
	if not String(runtime.get("blocked_reason", "")).is_empty():
		status_lines.append("开启限制: %s" % String(runtime.get("blocked_reason", "")))
	if not active_run.is_empty():
		status_lines.append("进行中: Lv.%d | 奖励 x%.1f" % [
			int(active_run.get("level", 0)),
			float(active_run.get("reward_multiplier", 1.0)),
		])
	page_status_label.text = "\n".join(status_lines)
	page_status_label.scroll_to_line(0)

	if active_run.is_empty():
		detail_label.text = "目标层: Lv.%d\n钥石门槛已自动匹配。\n敌方气血倍率 x%.2f\n敌方伤害倍率 x%.2f\n奖励倍率 x%.2f" % [
			selected_rift_level,
			float(scaling.get("enemy_hp_multiplier", 1.0)),
			float(scaling.get("enemy_damage_multiplier", 1.0)),
			float(scaling.get("reward_multiplier", 1.0)),
		]
	else:
		detail_label.text = "正在进行: Lv.%d\n基底节点: %s\n剩余时限: %d 秒\n敌方气血倍率 x%.2f\n敌方伤害倍率 x%.2f\n奖励倍率 x%.2f" % [
			int(active_run.get("level", 0)),
			String(active_run.get("base_node_id", GameManager.current_node_id)),
			int(active_run.get("time_limit", 0)),
			float(active_run.get("enemy_hp_multiplier", 1.0)),
			float(active_run.get("enemy_damage_multiplier", 1.0)),
			float(active_run.get("reward_multiplier", 1.0)),
		]
	detail_label.add_theme_color_override("default_color", Color(0.82, 0.90, 1.0, 1.0))
	detail_label.scroll_to_line(0)

	var hp_multiplier: float = float(scaling.get("enemy_hp_multiplier", 1.0))
	var damage_multiplier: float = float(scaling.get("enemy_damage_multiplier", 1.0))
	var reward_multiplier: float = float(scaling.get("reward_multiplier", 1.0))
	equipment_rate_label.text = "敌方气血 | x%.2f" % hp_multiplier
	equipment_rate_bar.value = minf(200.0, hp_multiplier * 25.0)
	legendary_rate_label.text = "敌方伤害 | x%.2f" % damage_multiplier
	legendary_rate_bar.value = minf(200.0, damage_multiplier * 35.0)
	tracked_rate_label.text = "奖励倍率 | x%.2f" % reward_multiplier
	tracked_rate_bar.value = minf(200.0, reward_multiplier * 30.0)

	var recent_lines: Array[String] = []
	for result_variant in runtime.get("recent_results", []).slice(0, 4):
		var result: Dictionary = result_variant
		recent_lines.append("Lv.%d | %s" % [
			int(result.get("level", 0)),
			String(result.get("summary", "暂无结果")),
		])
	if recent_lines.is_empty():
		recent_label.text = "暂无秘境记录"
	else:
		recent_label.text = "\n".join(recent_lines)
	recent_label.scroll_to_line(0)


func _refresh_rift_controls() -> void:
	var runtime: Dictionary = GameManager.get_rift_runtime_summary()
	var highest_level: int = int(runtime.get("highest_level", 0))
	var active_run: Dictionary = runtime.get("active_run", {})
	var max_selectable_level: int = maxi(1, highest_level + 5)
	if active_run.is_empty():
		if selected_rift_level <= 0:
			selected_rift_level = int(runtime.get("recommended_level", 1))
		selected_rift_level = clampi(selected_rift_level, 1, max_selectable_level)
	else:
		selected_rift_level = int(active_run.get("level", selected_rift_level))

	rift_level_label.text = "试剑 Lv.%d" % selected_rift_level
	rift_down_button.disabled = not active_run.is_empty() or selected_rift_level <= 1
	rift_up_button.disabled = not active_run.is_empty() or selected_rift_level >= max_selectable_level
	if active_run.is_empty():
		var start_state: Dictionary = RiftSystem.can_start_run(GameManager.rift_state, selected_rift_level)
		rift_start_button.text = "开启秘境"
		rift_start_button.disabled = not bool(start_state.get("ok", false))
	else:
		rift_start_button.text = "秘境进行中"
		rift_start_button.disabled = true
	_update_button_style(rift_down_button, Color(0.42, 0.42, 0.46, 1.0))
	_update_button_style(rift_up_button, Color(0.42, 0.42, 0.46, 1.0))
	_update_button_style(rift_start_button, Color(0.54, 0.80, 0.42, 1.0))


func _refresh_rift_hint() -> void:
	var runtime: Dictionary = GameManager.get_rift_runtime_summary()
	var active_run: Dictionary = runtime.get("active_run", {})
	if active_run.is_empty():
		quick_hint_label.text = "驻守节点: %s | 推荐层: Lv.%d | %s%s" % [
			ConfigDB.get_chapter_node_short_label(GameManager.stable_node_id),
			int(runtime.get("recommended_level", selected_rift_level)),
			String(runtime.get("key_summary", "暂无试剑令")),
			"" if bool(runtime.get("can_start", false)) else " | %s" % String(runtime.get("blocked_reason", "")),
		]
	else:
		quick_hint_label.text = "秘境进行中: Lv.%d | 基底节点 %s | 奖励 x%.1f" % [
			int(active_run.get("level", 0)),
			ConfigDB.get_chapter_node_short_label(String(active_run.get("base_node_id", GameManager.current_node_id))),
			float(active_run.get("reward_multiplier", 1.0)),
		]


func _refresh_results_page() -> void:
	quick_section_label.text = "最近结算"
	list_section_label.text = "结算摘要"
	detail_section_label.text = "结算详情"
	rate_section_label.text = "奖励走势"
	recent_section_label.text = "秘境记录"

	_set_page_mode("results")
	_refresh_gem_section(false)
	var runtime: Dictionary = GameManager.get_rift_runtime_summary()
	var gem_runtime: Dictionary = GameManager.get_gem_runtime_state()
	var recent_results: Array = runtime.get("recent_results", [])
	var result_lines: Array[String] = []
	for result_variant in recent_results.slice(0, 6):
		var result: Dictionary = result_variant
		var reward_summary: String = String(result.get("reward_summary", ""))
		var line: String = "Lv.%d | %s" % [
			int(result.get("level", 0)),
			String(result.get("summary", "暂无结果")),
		]
		if not reward_summary.is_empty():
			line += " | %s" % reward_summary
		result_lines.append(line)
	page_status_label.text = "最近秘境结果\n\n%s" % ("\n".join(result_lines) if not result_lines.is_empty() else "暂无结算")
	page_status_label.scroll_to_line(0)

	var latest_result: Dictionary = recent_results[0] if not recent_results.is_empty() else {}
	if latest_result.is_empty():
		detail_label.text = "暂无秘境结算，先去试剑秘境冲一层。"
	else:
		var reward_lines: Array = latest_result.get("reward_lines", [])
		var reward_text: String = "奖励记录: %s" % (" | ".join(reward_lines) if not reward_lines.is_empty() else "暂无特殊奖励")
		detail_label.text = "最近结算\n层数: Lv.%d\n结果: %s\n奖励倍率: x%.2f\n%s" % [
			int(latest_result.get("level", 0)),
			"通关" if bool(latest_result.get("success", false)) else "失败",
			float(latest_result.get("reward_multiplier", 1.0)),
			reward_text,
		]
	detail_label.add_theme_color_override("default_color", Color(0.90, 0.88, 0.78, 1.0))
	detail_label.scroll_to_line(0)

	var success_count: int = 0
	for result_variant in recent_results.slice(0, 5):
		var result: Dictionary = result_variant
		if bool(result.get("success", false)):
			success_count += 1
	equipment_rate_label.text = "最高层数 | Lv.%d" % int(runtime.get("highest_level", 0))
	equipment_rate_bar.value = minf(200.0, float(int(runtime.get("highest_level", 0)) * 4))
	legendary_rate_label.text = "近五次通关 | %d 次" % success_count
	legendary_rate_bar.value = float(success_count) * 40.0
	tracked_rate_label.text = "已得宝石 | %d 种" % gem_runtime.get("entries", []).size()
	tracked_rate_bar.value = float(gem_runtime.get("entries", []).size()) * 40.0

	var recent_text_lines: Array[String] = []
	for entry_variant in gem_runtime.get("entries", []):
		var entry: Dictionary = entry_variant
		recent_text_lines.append("%s Lv.%d | %s" % [
			String(entry.get("name", "")),
			int(entry.get("level", 0)),
			String(entry.get("effect_summary", "")),
		])
	if recent_text_lines.is_empty():
		recent_label.text = "暂无传奇宝石记录"
	else:
		recent_label.text = "\n".join(recent_text_lines)
	recent_label.scroll_to_line(0)
	gem_summary_label.text = "当前镶嵌: %s" % String(gem_runtime.get("summary_text", "未镶嵌"))


func _refresh_gem_section(allow_switch: bool) -> void:
	var runtime: Dictionary = GameManager.get_gem_runtime_state()
	var summary_text: String = String(runtime.get("summary_text", ""))
	gem_summary_label.text = "宝石: %s" % (summary_text if not summary_text.is_empty() else "暂未获得秘境宝石")
	var entries: Array = runtime.get("entries", [])
	var equipped_gems: Dictionary = runtime.get("equipped_gems", {})
	gem_slot1_button.text = _build_gem_slot_button_text("饰品一", String(equipped_gems.get("accessory1", "")))
	gem_slot2_button.text = _build_gem_slot_button_text("饰品二", String(equipped_gems.get("accessory2", "")))
	var has_gems: bool = not entries.is_empty()
	gem_slot1_button.disabled = not has_gems or not allow_switch
	gem_slot2_button.disabled = not has_gems or not allow_switch
	_update_button_style(gem_slot1_button, Color(0.30, 0.65, 0.82, 1.0))
	_update_button_style(gem_slot2_button, Color(0.30, 0.65, 0.82, 1.0))


func _set_page_mode(page_id: String) -> void:
	var show_analysis_controls: bool = page_id == "analysis"
	var show_rift_controls: bool = page_id == "rift"
	var show_page_status: bool = page_id != "analysis"
	var show_gem_controls: bool = page_id != "analysis"

	current_button.visible = show_analysis_controls
	recommended_button.visible = show_analysis_controls
	rift_down_button.visible = show_rift_controls
	rift_level_label.visible = show_rift_controls
	rift_up_button.visible = show_rift_controls
	rift_start_button.visible = show_rift_controls
	node_list.visible = show_analysis_controls
	page_status_label.visible = show_page_status
	gem_summary_label.visible = show_gem_controls
	gem_slot1_button.visible = show_gem_controls
	gem_slot2_button.visible = show_gem_controls


func _on_tab_pressed(tab_id: String) -> void:
	active_tab = tab_id
	_refresh()


func _on_node_selected(index: int) -> void:
	selected_node_id = String(node_list.get_item_metadata(index))
	_refresh_analysis_detail()


func _on_current_pressed() -> void:
	var index: int = _find_index_by_node_id(GameManager.current_node_id)
	if index >= 0:
		node_list.select(index)
		selected_node_id = String(node_list.get_item_metadata(index))
	_refresh_analysis_detail()
	_refresh_analysis_hint()


func _on_recommended_pressed() -> void:
	var recommendation: Dictionary = LootCodexSystem.get_recommended_farm_node_for_legendary(LootCodexSystem.tracked_legendary_affix_id)
	var node_id: String = String(recommendation.get("node_id", ""))
	var index: int = _find_index_by_node_id(node_id)
	if index >= 0:
		node_list.select(index)
		selected_node_id = String(node_list.get_item_metadata(index))
	_refresh_analysis_detail()
	_refresh_analysis_hint()


func _on_rift_down_pressed() -> void:
	selected_rift_level = maxi(1, selected_rift_level - 1)
	_refresh_rift_page()


func _on_rift_up_pressed() -> void:
	selected_rift_level += 1
	_refresh_rift_page()


func _on_rift_start_pressed() -> void:
	var result: Dictionary = GameManager.start_rift_run(selected_rift_level)
	if not bool(result.get("ok", false)):
		quick_hint_label.text = "秘境开启失败: %s" % String(result.get("reason", "未知原因"))
		return
	visible = false
	EventBus.ui_close_requested.emit()


func _on_gem_slot_pressed(slot_id: String) -> void:
	var runtime: Dictionary = GameManager.get_gem_runtime_state()
	var owned_ids: Array[String] = [""]
	var equipped_gems: Dictionary = runtime.get("equipped_gems", {})
	var other_slot: String = "accessory2" if slot_id == "accessory1" else "accessory1"
	var blocked_gem_id: String = String(equipped_gems.get(other_slot, ""))
	for entry_variant in runtime.get("entries", []):
		var entry: Dictionary = entry_variant
		var gem_id: String = String(entry.get("id", ""))
		if gem_id == blocked_gem_id:
			continue
		owned_ids.append(gem_id)
	if owned_ids.size() <= 1:
		quick_hint_label.text = "当前没有可切换的宝石。"
		return
	var current_gem_id: String = String(equipped_gems.get(slot_id, ""))
	var current_index: int = owned_ids.find(current_gem_id)
	if current_index < 0:
		current_index = 0
	var next_gem_id: String = String(owned_ids[(current_index + 1) % owned_ids.size()])
	var result: Dictionary = GameManager.equip_gem(slot_id, next_gem_id)
	if not bool(result.get("ok", false)):
		quick_hint_label.text = "镶嵌失败: %s" % String(result.get("reason", "未知原因"))
		return
	_refresh()


func _on_gem_upgraded(_gem_id: String, _new_level: int) -> void:
	_refresh()


func _on_rift_state_changed(_payload: Dictionary) -> void:
	_refresh()


func _on_close_pressed() -> void:
	EventBus.ui_close_requested.emit()


func open_panel() -> void:
	visible = true
	_refresh()


func _on_node_changed(_node_id: String) -> void:
	_refresh()


func _update_tab_buttons() -> void:
	analysis_tab_button.disabled = active_tab == "analysis"
	rift_tab_button.disabled = active_tab == "rift"
	results_tab_button.disabled = active_tab == "results"
	_update_button_style(
		analysis_tab_button,
		Color(0.36, 0.64, 0.96, 1.0) if not analysis_tab_button.disabled else Color(0.24, 0.34, 0.60, 1.0)
	)
	_update_button_style(
		rift_tab_button,
		Color(0.54, 0.80, 0.42, 1.0) if not rift_tab_button.disabled else Color(0.30, 0.46, 0.26, 1.0)
	)
	_update_button_style(
		results_tab_button,
		Color(0.98, 0.74, 0.32, 1.0) if not results_tab_button.disabled else Color(0.56, 0.42, 0.22, 1.0)
	)


func _find_index_by_node_id(node_id: String) -> int:
	for i in range(node_list.item_count):
		if String(node_list.get_item_metadata(i)) == node_id:
			return i
	return -1


func _apply_rate_entry(label_node: RichTextLabel, bar_node: ProgressBar, entry: Dictionary) -> void:
	if entry.is_empty():
		label_node.text = "暂无数据"
		label_node.scroll_to_line(0)
		bar_node.value = 0.0
		return
	var label: String = String(entry.get("label", "效率"))
	var expected_rate: float = float(entry.get("expected_rate", 0.0))
	var actual_rate: float = float(entry.get("actual_rate", 0.0))
	var state_label: String = String(entry.get("state_label", "暂无样本"))
	var delta_text: String = String(entry.get("delta_text", "0%"))
	var status_text: String = String(entry.get("status", ""))
	label_node.text = "%s | 理论 %.3f / 实测 %.3f | %s | %s" % [
		label,
		expected_rate,
		actual_rate,
		delta_text,
		state_label,
	]
	if not status_text.is_empty():
		label_node.text += "\n%s" % status_text
	label_node.scroll_to_line(0)
	label_node.add_theme_color_override("default_color", _get_rate_color(state_label))
	bar_node.value = float(entry.get("bar_value", 0.0))
	bar_node.self_modulate = _get_rate_color(state_label)


func _get_rate_color(state_label: String) -> Color:
	if state_label.contains("明显高于") or state_label.contains("超出"):
		return Color(0.46, 0.9, 0.54, 1.0)
	if state_label.contains("略高于"):
		return Color(0.76, 0.92, 0.48, 1.0)
	if state_label.contains("明显低于"):
		return Color(1.0, 0.42, 0.42, 1.0)
	if state_label.contains("略低于") or state_label.contains("不产出"):
		return Color(1.0, 0.68, 0.36, 1.0)
	return Color(0.76, 0.84, 0.96, 1.0)


func _build_gem_slot_button_text(slot_name: String, gem_id: String) -> String:
	if gem_id.is_empty():
		return "%s: 未镶嵌" % slot_name
	var gem_data: Dictionary = ConfigDB.get_gem(gem_id)
	return "%s: %s Lv.%d" % [
		slot_name,
		String(gem_data.get("name", gem_id)),
		GemSystem.get_gem_level(GameManager.gem_state, gem_id),
	]


func _get_node_type_label(node_type: String) -> String:
	match node_type:
		"elite":
			return "精英"
		"boss":
			return "首领"
		_:
			return "常规"


func _apply_visual_style() -> void:
	UI_STYLE.style_label(title_label, "title")
	UI_STYLE.style_label(summary_label, "accent")
	UI_STYLE.style_label(tab_section_label, "heading")
	UI_STYLE.style_label(quick_section_label, "heading")
	UI_STYLE.style_label(list_section_label, "heading")
	UI_STYLE.style_label(detail_section_label, "heading")
	UI_STYLE.style_label(rate_section_label, "heading")
	UI_STYLE.style_label(recent_section_label, "warning")
	UI_STYLE.style_label(quick_hint_label, "muted")
	UI_STYLE.style_label(rift_level_label, "accent")
	UI_STYLE.style_label(gem_summary_label, "muted")
	UI_STYLE.style_item_list(node_list)
	UI_STYLE.style_rich_text(page_status_label)


func _update_button_style(button: Button, accent: Color) -> void:
	UI_STYLE.style_button(button, accent, button.disabled)
