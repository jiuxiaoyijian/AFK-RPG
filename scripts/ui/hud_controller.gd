extends Control

const CORE_SKILL_ICON_PATHS := {
	"core_whirlwind": "res://assets/generated/afk_rpg_formal/icons/school_yufengdao_highlight.png",
	"core_deep_wound": "res://assets/generated/afk_rpg_formal/icons/school_xuejiedao_highlight.png",
	"core_chain_lightning": "res://assets/generated/afk_rpg_formal/icons/school_wuleidao_highlight.png",
}
const DAILY_GOAL_ICON_PATH := "res://assets/generated/afk_rpg_formal/icons/system_jinrijiyuan.png"
const EQUIPMENT_ICON_PATHS := {
	"weapon": "res://assets/generated/icons/equip_weapon.png",
	"helmet": "res://assets/generated/icons/equip_helmet.png",
	"armor": "res://assets/generated/icons/equip_armor.png",
	"gloves": "res://assets/generated/icons/equip_gloves.png",
	"legs": "res://assets/generated/icons/equip_armor.png",
	"boots": "res://assets/generated/icons/equip_gloves.png",
	"accessory1": "res://assets/generated/icons/equip_weapon.png",
	"accessory2": "res://assets/generated/icons/equip_weapon.png",
	"belt": "res://assets/generated/icons/equip_armor.png",
}
const SLOT_DISPLAY_NAMES := {
	"weapon": "兵器",
	"helmet": "头冠",
	"armor": "护甲",
	"gloves": "手套",
	"legs": "腿甲",
	"boots": "靴子",
	"accessory1": "佩饰1",
	"accessory2": "佩饰2",
	"belt": "腰带",
}
const HUD_RESULT_CARD_PATH := "res://assets/generated/afk_rpg_formal/ui/result_card_template_common.png"
const HUD_RARITY_FRAME_PATHS := {
	"common": "res://assets/generated/ui/frame_common.png",
	"uncommon": "res://assets/generated/ui/frame_common.png",
	"rare": "res://assets/generated/ui/frame_rare.png",
	"epic": "res://assets/generated/ui/frame_epic.png",
	"set": "res://assets/generated/ui/frame_epic.png",
	"legendary": "res://assets/generated/ui/frame_legendary.png",
	"ancient": "res://assets/generated/ui/frame_ancient.png",
}
const LOOT_ICON_PATHS := {
	"legendary": "res://assets/generated/afk_rpg_formal/icons/drop_rare.png",
	"equip": "res://assets/generated/afk_rpg_formal/icons/drop_equipment.png",
	"store": "res://assets/generated/afk_rpg_formal/icons/drop_equipment.png",
	"salvage": "res://assets/generated/icons/drop_salvage.png",
}
const CARD_SIDE_MARGIN := 16.0

@onready var resource_label: Label = $TopBar/ResourceLabel
@onready var run_label: Label = $TopBar/RunLabel
@onready var combat_highlight_panel: Panel = $CombatHighlightPanel
@onready var combat_highlight_title: Label = $CombatHighlightPanel/CombatHighlightTitle
@onready var combat_highlight_subtitle: Label = $CombatHighlightPanel/CombatHighlightSubtitle
@onready var combat_highlight_detail: Label = $CombatHighlightPanel/CombatHighlightDetail
@onready var battle_card: Panel = $BattleCard
@onready var node_label: Label = $BattleCard/NodeLabel
@onready var state_label: Label = $BattleCard/StateLabel
@onready var hp_bar: ProgressBar = $BattleCard/HpBar
@onready var hp_label: Label = $BattleCard/HpLabel
@onready var skill_label: Label = $BattleCard/SkillLabel
@onready var skill_icon_texture: TextureRect = $BattleCard/SkillIconPanel/SkillIconTexture
@onready var focus_label: Label = $BattleCard/FocusLabel
@onready var battle_safe_frame: Panel = $BattleSafeFrame
@onready var target_card: Panel = $TargetCard
@onready var target_title_label: Label = $TargetCard/TargetTitleLabel
@onready var target_label: Label = $TargetCard/TargetLabel
@onready var build_gap_label: Label = $TargetCard/BuildGapLabel
@onready var next_target_label: Label = $TargetCard/NextTargetLabel
@onready var codex_label: Label = $TargetCard/CodexLabel
@onready var set_label: Label = $TargetCard/SetLabel
@onready var daily_goal_card: Panel = $DailyGoalCard
@onready var daily_goal_icon: TextureRect = $DailyGoalCard/DailyGoalIcon
@onready var daily_goal_title_label: Label = $DailyGoalCard/DailyGoalTitleLabel
@onready var primary_goal_label: Label = $DailyGoalCard/PrimaryGoalLabel
@onready var primary_goal_progress_label: Label = $DailyGoalCard/PrimaryProgressLabel
@onready var primary_goal_cta_label: Label = $DailyGoalCard/PrimaryCtaLabel
@onready var side_goals_label: Label = $DailyGoalCard/SideGoalsLabel
@onready var next_step_label: Label = $DailyGoalCard/NextStepLabel
@onready var equip_card: Panel = $EquipCard
@onready var equip_card_art: TextureRect = $EquipCard/CardArt
@onready var equip_title_label: Label = $EquipCard/EquipTitleLabel
var equip_slot_labels: Dictionary = {}
var equip_slot_nodes: Dictionary = {}
@onready var loot_card: Panel = $LootCard
@onready var loot_card_art: TextureRect = $LootCard/CardArt
@onready var loot_icon: TextureRect = $LootCard/LootIcon
@onready var highlight_label: Label = $LootCard/HighlightLabel
@onready var loot_label: Label = $LootCard/LootLabel
@onready var drop_toast: Panel = $DropToast
@onready var toast_icon: TextureRect = $DropToast/ToastIcon
@onready var toast_title: Label = $DropToast/ToastTitle
@onready var toast_label: Label = $DropToast/ToastLabel
@onready var main_nav_bar: Control = $"../MainNavBar"

var drop_toast_tween: Tween
var drop_toast_base_position: Vector2 = Vector2.ZERO
var combat_highlight_tween: Tween


func _ready() -> void:
	target_card.visible = false
	battle_safe_frame.visible = false
	_apply_card_art()
	_wire_card_interactions()
	_apply_slot_icons()
	_apply_battle_safe_frame_style()
	_apply_compact_typography()
	get_viewport().size_changed.connect(_apply_hud_layout)
	EventBus.node_changed.connect(_on_node_changed)
	EventBus.combat_state_changed.connect(_on_state_changed)
	EventBus.combat_highlight_requested.connect(_on_combat_highlight_requested)
	EventBus.player_hp_changed.connect(_on_hp_changed)
	EventBus.resources_changed.connect(_on_resources_changed)
	EventBus.core_skill_changed.connect(_on_skill_changed)
	EventBus.equipment_changed.connect(_on_equipment_changed)
	EventBus.loot_summary_changed.connect(_on_loot_summary_changed)
	EventBus.codex_changed.connect(_on_codex_changed)
	EventBus.loot_target_changed.connect(_on_target_changed)
	EventBus.daily_goals_changed.connect(_on_daily_goals_changed)
	EventBus.research_changed.connect(_on_build_relevant_state_changed)
	EventBus.set_bonus_changed.connect(_on_build_relevant_state_changed)
	EventBus.martial_codex_changed.connect(_on_build_relevant_state_changed)

	_on_node_changed(GameManager.current_node_id)
	_on_state_changed("准备中")
	_on_hp_changed(0.0, 0.0)
	_on_resources_changed()
	_on_skill_changed(GameManager.selected_core_skill_id)
	_on_focus_changed()
	_on_target_changed()
	_on_codex_changed()
	_on_daily_goals_changed()
	_on_equipment_changed()
	_on_loot_summary_changed(GameManager.last_loot_summary)
	_apply_daily_goal_typography()
	_apply_target_card_typography()
	_apply_combat_highlight_style()
	call_deferred("_apply_hud_layout")


func _wire_card_interactions() -> void:
	for panel in [target_card, daily_goal_card, equip_card, loot_card]:
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	target_card.gui_input.connect(_on_target_card_input)
	daily_goal_card.gui_input.connect(_on_daily_goal_card_input)
	equip_card.gui_input.connect(_on_equip_card_input)
	loot_card.gui_input.connect(_on_loot_card_input)


func _on_node_changed(node_id: String) -> void:
	var node_data: Dictionary = ConfigDB.get_chapter_node(node_id)
	var chapter_id: String = String(node_data.get("chapter_id", GameManager.current_chapter_id))
	var chapter_data: Dictionary = ConfigDB.get_chapter(chapter_id)
	node_label.text = "%s  ·  %s  ·  %s" % [
		String(chapter_data.get("name", chapter_id)),
		ConfigDB.get_chapter_node_name(node_id),
		ConfigDB.get_node_type_display_name(String(node_data.get("node_type", "--"))),
	]
	_on_focus_changed()
	_refresh_target_card()
	_on_resources_changed()


func _on_state_changed(state_text: String) -> void:
	state_label.text = "状态: %s" % state_text
	state_label.add_theme_color_override("font_color", _get_state_color(state_text))


func _on_hp_changed(current_hp: float, max_hp: float) -> void:
	if max_hp <= 0.0:
		hp_label.text = "生命: --"
		hp_bar.value = 0.0
		return
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp
	hp_label.text = "生命: %d / %d" % [int(current_hp), int(max_hp)]


func _on_resources_changed() -> void:
	resource_label.text = "香火钱 %d  |  祠灰 %d  |  灵核 %d  |  真意残片 %d  |  背包 %d" % [
		MetaProgressionSystem.gold,
		MetaProgressionSystem.scrap,
		MetaProgressionSystem.core,
		MetaProgressionSystem.legend_shard,
		GameManager.get_inventory_count(),
	]
	run_label.text = "击杀 %d  |  清图 %d  |  当前节点 %s" % [
		GameManager.current_run_kills,
		GameManager.current_run_clears,
		ConfigDB.get_chapter_node_short_label(GameManager.current_node_id),
	]


func _on_skill_changed(skill_id: String) -> void:
	var skill_data: Dictionary = ConfigDB.get_core_skill(skill_id)
	skill_label.text = "流派: %s" % String(skill_data.get("name", skill_id))
	skill_label.add_theme_color_override("font_color", _get_skill_color(skill_id))
	_update_skill_icon(skill_id)
	_on_target_changed()


func _on_focus_changed() -> void:
	focus_label.text = "掉落方向: %s" % GameManager.get_current_drop_focus()
	focus_label.add_theme_color_override("font_color", Color(0.92, 0.8, 0.45, 1.0))


func _on_target_changed() -> void:
	_refresh_target_card()


func _on_codex_changed() -> void:
	_refresh_target_card()


func _on_daily_goals_changed() -> void:
	var goal_data: Dictionary = DailyGoalSystem.get_daily_goal_data()
	var primary_goal: Dictionary = goal_data.get("primary_goal", {})
	var side_goals: Array = goal_data.get("side_goals", [])
	daily_goal_title_label.text = "当前目标"
	if primary_goal.is_empty():
		primary_goal_label.text = "主目标: 暂无"
		primary_goal_progress_label.text = "进度: --"
		primary_goal_cta_label.text = "建议: 等待系统生成目标"
		side_goals_label.text = "旁支: 暂无"
		next_step_label.text = "下一步: 暂无"
		return

	var primary_completed: bool = String(primary_goal.get("status", "active")) == "completed"
	primary_goal_label.text = "主目标: %s" % _truncate_ui_text(String(primary_goal.get("title", "未命名目标")), 14)
	primary_goal_progress_label.text = "进度: %s" % String(primary_goal.get("progress_text", "--"))
	primary_goal_cta_label.text = "建议: %s" % _truncate_ui_text(String(primary_goal.get("cta_text", "继续推进主目标")), 18)
	side_goals_label.text = _build_side_goals_text(side_goals)
	next_step_label.text = "下一步: %s" % _truncate_ui_text(String(goal_data.get("next_step_summary", "继续推进当前目标")), 18)

	primary_goal_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.82, 0.44, 1.0) if primary_completed else Color(0.96, 0.92, 0.76, 1.0)
	)
	primary_goal_progress_label.add_theme_color_override(
		"font_color",
		Color(0.72, 0.92, 0.74, 1.0) if primary_completed else Color(0.76, 0.86, 1.0, 1.0)
	)
	primary_goal_cta_label.add_theme_color_override("font_color", Color(0.84, 0.9, 1.0, 1.0))
	side_goals_label.add_theme_color_override("font_color", Color(0.74, 0.84, 0.94, 1.0))
	next_step_label.add_theme_color_override("font_color", Color(0.98, 0.86, 0.54, 1.0))
	_refresh_target_card()


func _on_equipment_changed() -> void:
	for slot_id in GameManager.EQUIPMENT_SLOT_ORDER:
		if equip_slot_labels.has(slot_id):
			_update_equipped_slot(slot_id, equip_slot_labels[slot_id])
	_refresh_target_card()


func _on_loot_summary_changed(summary_text: String) -> void:
	var summary_lines: Array[String] = GameManager.get_loot_summary_lines(3)
	var highlight_line: String = "高价值掉落: 暂无"
	for line_variant in summary_lines:
		var line: String = String(line_variant)
		if line.contains("传奇"):
			highlight_line = "高价值掉落: %s" % line
			break
	if highlight_line == "高价值掉落: 暂无" and not summary_lines.is_empty():
		highlight_line = "高价值掉落: %s" % String(summary_lines[0])
	highlight_label.text = _truncate_ui_text(highlight_line, 18)
	highlight_label.add_theme_color_override("font_color", _get_loot_highlight_color(highlight_line))
	loot_card_art.modulate = _get_loot_card_modulate(highlight_line)
	_apply_loot_icon()
	if summary_lines.size() <= 1:
		loot_label.text = _truncate_ui_text(summary_text, 30)
	else:
		var compact_lines: Array[String] = []
		for line_variant in summary_lines.slice(1):
			compact_lines.append(_truncate_ui_text(String(line_variant), 14))
		loot_label.text = " | ".join(compact_lines)
	loot_label.add_theme_color_override("font_color", Color(0.82, 0.86, 0.9, 1.0))
	loot_card.tooltip_text = _build_loot_card_tooltip()
	_maybe_show_drop_toast(highlight_line)


func _on_combat_highlight_requested(highlight_data: Dictionary) -> void:
	var highlight_type: String = String(highlight_data.get("highlight_type", "generic"))
	combat_highlight_title.text = String(highlight_data.get("title", "战斗高光"))
	combat_highlight_subtitle.text = String(highlight_data.get("subtitle", ""))
	combat_highlight_detail.text = String(highlight_data.get("detail", ""))
	var colors: Dictionary = _get_combat_highlight_colors(highlight_type)
	combat_highlight_title.add_theme_color_override("font_color", colors.get("title", Color(1, 1, 1, 1)))
	combat_highlight_subtitle.add_theme_color_override("font_color", colors.get("subtitle", Color(1, 1, 1, 1)))
	combat_highlight_detail.add_theme_color_override("font_color", colors.get("detail", Color(1, 1, 1, 1)))
	_apply_panel_tint(combat_highlight_panel, colors.get("panel", Color(0.18, 0.22, 0.30, 0.92)))
	_show_combat_highlight_banner()


func _update_equipped_slot(slot: String, label: Label) -> void:
	var item: Dictionary = GameManager.get_equipped_item(slot)
	var display_name: String = SLOT_DISPLAY_NAMES.get(slot, slot)
	if item.is_empty():
		label.text = "%s: --" % display_name
		label.add_theme_color_override("font_color", Color(0.52, 0.54, 0.58, 1.0))
		return
	var rarity: String = String(item.get("rarity", "common"))
	var _rarity_display: String = GameManager.get_rarity_display_name(rarity)
	label.text = "%s: %s" % [display_name, String(item.get("name", "--"))]
	label.add_theme_color_override("font_color", GameManager.get_rarity_color(rarity))


func _get_rarity_color(rarity: String) -> Color:
	return GameManager.get_rarity_color(rarity)


func _get_skill_color(skill_id: String) -> Color:
	match skill_id:
		"core_deep_wound":
			return Color(0.96, 0.38, 0.42, 1.0)
		"core_chain_lightning":
			return Color(0.72, 0.54, 1.0, 1.0)
		_:
			return Color(0.42, 0.78, 1.0, 1.0)


func _get_state_color(state_text: String) -> Color:
	if state_text.contains("失败"):
		return Color(1.0, 0.45, 0.45, 1.0)
	if state_text.contains("完成") or state_text.contains("结算"):
		return Color(1.0, 0.8, 0.35, 1.0)
	if state_text.contains("准备") or state_text.contains("下一波"):
		return Color(0.76, 0.84, 1.0, 1.0)
	return Color(0.84, 0.9, 1.0, 1.0)


func _get_loot_highlight_color(text: String) -> Color:
	if text.contains("传奇"):
		return Color(1.0, 0.78, 0.32, 1.0)
	if text.contains("装备"):
		return Color(0.8, 0.9, 1.0, 1.0)
	if text.contains("分解"):
		return Color(0.92, 0.64, 0.48, 1.0)
	return Color(0.86, 0.9, 0.96, 1.0)


func _update_skill_icon(skill_id: String) -> void:
	var texture_path: String = String(CORE_SKILL_ICON_PATHS.get(skill_id, ""))
	if texture_path.is_empty():
		skill_icon_texture.texture = null
		return

	skill_icon_texture.texture = _load_runtime_texture(texture_path)


func _apply_card_art() -> void:
	var result_card_texture: Texture2D = _load_runtime_texture(HUD_RESULT_CARD_PATH)
	equip_card_art.texture = result_card_texture
	loot_card_art.texture = result_card_texture
	equip_card_art.modulate = Color(0.86, 0.9, 0.95, 0.4)
	loot_card_art.modulate = Color(0.9, 0.92, 0.98, 0.45)
	daily_goal_icon.texture = _load_runtime_texture(DAILY_GOAL_ICON_PATH)


func _apply_compact_typography() -> void:
	_apply_font_size_recursive(self)


func _apply_battle_safe_frame_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.18, 0.26, 0.05)
	style.border_color = Color(0.54, 0.76, 0.96, 0.36)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	battle_safe_frame.add_theme_stylebox_override("panel", style)


func _apply_hud_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	combat_highlight_panel.position = Vector2((viewport_size.x - combat_highlight_panel.size.x) * 0.5, 66.0)
	equip_card.size = Vector2(404.0, 100.0)
	equip_card.position = Vector2(CARD_SIDE_MARGIN, battle_card.position.y + battle_card.size.y + 16.0)
	var right_card_width := 328.0
	var right_card_x := viewport_size.x - right_card_width - CARD_SIDE_MARGIN
	var right_column_top := 124.0
	target_card.size = Vector2(right_card_width, 118.0)
	target_card.position = Vector2(right_card_x, right_column_top)
	daily_goal_card.size = Vector2(right_card_width, 136.0)
	var next_stack_y := right_column_top
	if target_card.visible:
		next_stack_y = target_card.position.y + target_card.size.y + 10.0
	daily_goal_card.position = Vector2(right_card_x, next_stack_y)
	loot_card.size = Vector2(right_card_width, 112.0)
	loot_card.position = Vector2(right_card_x, daily_goal_card.position.y + daily_goal_card.size.y + 10.0)
	drop_toast_base_position = Vector2(
		(viewport_size.x - drop_toast.size.x) * 0.5,
		64.0
	)
	if not drop_toast.visible:
		drop_toast.position = drop_toast_base_position


func _apply_font_size_recursive(node: Node) -> void:
	if node is Label:
		var label_node: Label = node
		label_node.add_theme_font_size_override("font_size", 14)
	elif node is RichTextLabel:
		var rich_text_node: RichTextLabel = node
		rich_text_node.add_theme_font_size_override("normal_font_size", 14)
	elif node is Button:
		var button_node: Button = node
		button_node.add_theme_font_size_override("font_size", 14)
	for child in node.get_children():
		_apply_font_size_recursive(child)


func _apply_daily_goal_typography() -> void:
	for label in [
		daily_goal_title_label,
		primary_goal_label,
		primary_goal_progress_label,
		primary_goal_cta_label,
		side_goals_label,
		next_step_label,
	]:
		label.add_theme_font_size_override("font_size", 9)


func _apply_target_card_typography() -> void:
	for label in [
		target_label,
		build_gap_label,
		next_target_label,
		codex_label,
		set_label,
	]:
		label.add_theme_font_size_override("font_size", 9)


func _apply_combat_highlight_style() -> void:
	combat_highlight_title.add_theme_font_size_override("font_size", 20)
	combat_highlight_subtitle.add_theme_font_size_override("font_size", 14)
	combat_highlight_detail.add_theme_font_size_override("font_size", 12)
	_apply_panel_tint(combat_highlight_panel, Color(0.18, 0.22, 0.30, 0.92))
	combat_highlight_panel.visible = false


func _refresh_target_card() -> void:
	var advice: Dictionary = GameManager.get_build_advice_data()
	var equipment_state: Dictionary = GameManager.get_equipment_screen_state()
	target_title_label.text = "当前 Build"
	target_card.tooltip_text = "点击打开推演与秘境，查看当前追踪目标与推荐刷图。"
	daily_goal_card.tooltip_text = "点击打开成长中心，继续推进当前目标。"
	equip_card.tooltip_text = "点击打开背包，查看纸娃娃与格子库存。"
	if advice.is_empty():
		target_label.text = "当前追踪: --"
		build_gap_label.text = _truncate_ui_text(String(equipment_state.get("inventory_summary", "Build 缺口: --")), 22)
		next_target_label.text = _truncate_ui_text(String(equipment_state.get("next_target_line", "下一件: --")), 22)
		codex_label.text = _truncate_ui_text(String(equipment_state.get("codex_summary_line", LootCodexSystem.get_codex_summary_text())), 22)
		set_label.text = _build_set_summary_line()
		return

	target_label.text = _truncate_ui_text(String(advice.get("tracked_target_line", "当前追踪: --")).replace("追踪:", "当前追踪:"), 22)
	build_gap_label.text = _truncate_ui_text(String(advice.get("gap_line", "Build 缺口: --")).replace("缺口:", "Build 缺口:"), 22)
	next_target_label.text = _truncate_ui_text(String(equipment_state.get(
		"next_target_line",
		String(advice.get("next_target_line", "下一件: --"))
	)), 22)
	codex_label.text = _truncate_ui_text(String(
		equipment_state.get("codex_summary_line", "")
		if not String(equipment_state.get("codex_summary_line", "")).is_empty()
		else advice.get("stall_summary", String(advice.get("recommendation_line", LootCodexSystem.get_codex_summary_text())))
	), 22)
	set_label.text = _build_set_summary_line()

	target_label.add_theme_color_override("font_color", Color(0.92, 0.86, 1.0, 1.0))
	build_gap_label.add_theme_color_override("font_color", Color(0.98, 0.84, 0.54, 1.0))
	next_target_label.add_theme_color_override("font_color", Color(0.84, 0.92, 0.76, 1.0))
	codex_label.add_theme_color_override(
		"font_color",
		Color(0.98, 0.78, 0.52, 1.0) if bool(advice.get("is_progress_blocked", false)) else Color(0.74, 0.82, 1.0, 1.0)
	)
	set_label.add_theme_color_override("font_color", Color(0.62, 0.92, 0.70, 1.0))


func _on_build_relevant_state_changed(_payload: Variant = null) -> void:
	_refresh_target_card()


func _build_set_summary_line() -> String:
	var primary_set: Dictionary = GameManager.set_summary.get("primary_active_set", {})
	if primary_set.is_empty():
		return "传承: 当前未激活"
	var piece_count: int = int(primary_set.get("piece_count", 0))
	return _truncate_ui_text("传承: %s %d/6" % [
		String(primary_set.get("name", "传承")),
		piece_count,
	], 22)


func _build_side_goals_text(goals: Array) -> String:
	if goals.is_empty():
		return "支线: 暂无"
	var first_goal: Dictionary = goals[0]
	var suffix: String = " 等%d项" % goals.size() if goals.size() > 1 else ""
	return "支线: %s%s" % [
		_truncate_ui_text(String(first_goal.get("title", "支线目标")), 10),
		suffix,
	]


func _truncate_ui_text(text: String, max_chars: int) -> String:
	var single_line: String = text.replace("\n", " ").strip_edges()
	if single_line.length() <= max_chars:
		return single_line
	return "%s…" % single_line.substr(0, max_chars)


func _apply_slot_icons() -> void:
	for old_slot_name in ["WeaponSlot", "HelmetSlot", "ArmorSlot", "GlovesSlot"]:
		var old_node: Node = equip_card.get_node_or_null(old_slot_name)
		if old_node:
			old_node.queue_free()
	var title_label_node: Node = equip_card.get_node_or_null("EquipTitleLabel")
	if title_label_node and title_label_node is Label:
		title_label_node.text = "已穿装备 · 9槽"

	equip_slot_labels.clear()
	equip_slot_nodes.clear()
	var columns := 3
	var cell_w := 110.0
	var cell_h := 22.0
	var gap_x := 4.0
	var gap_y := 2.0
	var start_x := 8.0
	var start_y := 28.0

	for idx in GameManager.EQUIPMENT_SLOT_ORDER.size():
		var slot_id: String = GameManager.EQUIPMENT_SLOT_ORDER[idx]
		var col: int = idx % columns
		@warning_ignore("integer_division")
		var row: int = idx / columns
		var slot_label := Label.new()
		slot_label.name = "EqLabel_%s" % slot_id
		slot_label.text = "%s: --" % SLOT_DISPLAY_NAMES.get(slot_id, slot_id)
		slot_label.position = Vector2(start_x + col * (cell_w + gap_x), start_y + row * (cell_h + gap_y))
		slot_label.size = Vector2(cell_w, cell_h)
		slot_label.add_theme_font_size_override("font_size", 11)
		slot_label.add_theme_color_override("font_color", Color(0.78, 0.84, 0.92))
		slot_label.clip_text = true
		equip_card.add_child(slot_label)
		equip_slot_labels[slot_id] = slot_label


func _apply_loot_icon() -> void:
	var highlight: Dictionary = GameManager.get_loot_highlight()
	var texture_path: String = ""
	if bool(highlight.get("has_legendary_affix", false)):
		texture_path = LOOT_ICON_PATHS["legendary"]
	else:
		texture_path = String(LOOT_ICON_PATHS.get(String(highlight.get("action", "store")), LOOT_ICON_PATHS["store"]))
	loot_icon.texture = _load_runtime_texture(texture_path)


func _on_target_card_input(event: InputEvent) -> void:
	if _is_primary_click(event):
		EventBus.ui_panel_requested.emit("drop_stats")


func _on_daily_goal_card_input(event: InputEvent) -> void:
	if _is_primary_click(event):
		EventBus.ui_panel_requested.emit("research")


func _on_equip_card_input(event: InputEvent) -> void:
	if not _is_primary_click(event):
		return
	GameManager.set_ui_focus_request("inventory", {
		"filter_id": "all",
		"sort_id": "score_desc",
	})
	EventBus.ui_panel_requested.emit("inventory")


func _on_loot_card_input(event: InputEvent) -> void:
	if not _is_primary_click(event):
		return
	var highlight: Dictionary = GameManager.get_loot_highlight()
	if highlight.is_empty():
		EventBus.ui_panel_requested.emit("inventory")
		return
	var item_id: String = String(highlight.get("item_id", ""))
	if bool(highlight.get("has_legendary_affix", false)) and not item_id.is_empty() and String(highlight.get("action", "")) != "equip":
		GameManager.set_ui_focus_request("cube", {
			"page_id": "extract",
			"selected_entry_id": item_id,
			"status_text": "已从掉落高光锁定萃取目标",
		})
		EventBus.ui_panel_requested.emit("cube")
		return
	if String(highlight.get("action", "")) == "equip":
		GameManager.set_ui_focus_request("inventory", {
			"selected_slot_id": String(highlight.get("target_slot", highlight.get("slot", ""))),
			"filter_id": "all",
			"sort_id": "score_desc",
		})
	else:
		GameManager.set_ui_focus_request("inventory", {
			"selected_item_id": item_id,
			"filter_id": "high_value" if bool(highlight.get("is_tracked_target", false)) else "all",
			"sort_id": "score_desc",
		})
	EventBus.ui_panel_requested.emit("inventory")


func _maybe_show_drop_toast(highlight_line: String) -> void:
	var highlight: Dictionary = GameManager.get_loot_highlight()
	if highlight.is_empty():
		drop_toast.visible = false
		return

	var should_show: bool = bool(highlight.get("has_legendary_affix", false))
	should_show = should_show or GameManager.get_rarity_rank(String(highlight.get("rarity", "common"))) >= GameManager.get_rarity_rank("epic")
	should_show = should_show or String(highlight.get("action", "")) == "equip"
	if not should_show:
		drop_toast.visible = false
		return

	toast_icon.texture = loot_icon.texture
	toast_title.text = _get_drop_toast_title(highlight)
	toast_label.text = String(highlight.get("item_name", highlight_line))
	drop_toast.modulate = _get_drop_toast_color(highlight)
	drop_toast.visible = true
	drop_toast.position = drop_toast_base_position
	if drop_toast_tween:
		drop_toast_tween.kill()
	drop_toast_tween = create_tween()
	var lift_offset: float = 18.0 if bool(highlight.get("is_tracked_target", false)) else 10.0
	var hold_time: float = 2.4 if bool(highlight.get("is_tracked_target", false)) else (2.0 if bool(highlight.get("has_legendary_affix", false)) else 1.5)
	drop_toast_tween.tween_property(drop_toast, "position:y", drop_toast_base_position.y - lift_offset, 0.25)
	drop_toast_tween.parallel().tween_property(drop_toast, "scale", Vector2.ONE * (1.06 if bool(highlight.get("is_tracked_target", false)) else 1.0), 0.22)
	drop_toast_tween.parallel().tween_property(drop_toast, "modulate:a", 1.0, 0.15)
	drop_toast_tween.tween_interval(hold_time)
	drop_toast_tween.tween_property(drop_toast, "modulate:a", 0.0, 0.35)
	drop_toast_tween.finished.connect(func() -> void:
		drop_toast.visible = false
		drop_toast.modulate.a = 1.0
		drop_toast.scale = Vector2.ONE
		drop_toast.position = drop_toast_base_position
	)


func _build_loot_card_tooltip() -> String:
	var highlight: Dictionary = GameManager.get_loot_highlight()
	if highlight.is_empty():
		return "点击打开背包，检查最近掉落。"
	if bool(highlight.get("has_legendary_affix", false)) and String(highlight.get("action", "")) != "equip":
		return "点击直达百炼坊的萃取页，处理这件武学装备。"
	if String(highlight.get("action", "")) == "equip":
		return "点击打开背包，并聚焦已替换上的装备槽位。"
	return "点击打开背包，并聚焦最近这件高价值掉落。"


func _is_primary_click(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT


func _get_loot_card_modulate(text: String) -> Color:
	if text.contains("传奇"):
		return Color(1.0, 0.82, 0.46, 0.62)
	if text.contains("装备"):
		return Color(0.72, 0.86, 1.0, 0.56)
	if text.contains("分解"):
		return Color(0.94, 0.72, 0.52, 0.52)
	return Color(0.9, 0.92, 0.98, 0.45)


func _show_combat_highlight_banner() -> void:
	combat_highlight_panel.visible = true
	combat_highlight_panel.modulate = Color(1, 1, 1, 0.0)
	combat_highlight_panel.scale = Vector2.ONE * 0.96
	if combat_highlight_tween:
		combat_highlight_tween.kill()
	combat_highlight_tween = create_tween()
	combat_highlight_tween.tween_property(combat_highlight_panel, "modulate:a", 1.0, 0.12)
	combat_highlight_tween.parallel().tween_property(combat_highlight_panel, "scale", Vector2.ONE, 0.18)
	combat_highlight_tween.tween_interval(1.45)
	combat_highlight_tween.tween_property(combat_highlight_panel, "modulate:a", 0.0, 0.3)
	combat_highlight_tween.finished.connect(func() -> void:
		combat_highlight_panel.visible = false
		combat_highlight_panel.modulate.a = 1.0
		combat_highlight_panel.scale = Vector2.ONE
	)


func _apply_panel_tint(panel: Panel, bg_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = Color(minf(bg_color.r + 0.18, 1.0), minf(bg_color.g + 0.18, 1.0), minf(bg_color.b + 0.18, 1.0), 0.92)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", style)


func _get_combat_highlight_colors(highlight_type: String) -> Dictionary:
	match highlight_type:
		"elite", "elite_kill":
			return {
				"panel": Color(0.34, 0.18, 0.10, 0.94),
				"title": Color(1.0, 0.78, 0.42, 1.0),
				"subtitle": Color(1.0, 0.90, 0.72, 1.0),
				"detail": Color(0.98, 0.84, 0.66, 1.0),
			}
		"boss", "boss_kill":
			return {
				"panel": Color(0.34, 0.10, 0.10, 0.96),
				"title": Color(1.0, 0.70, 0.38, 1.0),
				"subtitle": Color(1.0, 0.88, 0.78, 1.0),
				"detail": Color(1.0, 0.82, 0.62, 1.0),
			}
		"core_skill":
			return {
				"panel": Color(0.12, 0.20, 0.34, 0.94),
				"title": Color(0.82, 0.92, 1.0, 1.0),
				"subtitle": Color(0.96, 0.92, 0.72, 1.0),
				"detail": Color(0.78, 0.88, 1.0, 1.0),
			}
		_:
			return {
				"panel": Color(0.18, 0.22, 0.30, 0.92),
				"title": Color(0.94, 0.96, 1.0, 1.0),
				"subtitle": Color(0.88, 0.90, 0.94, 1.0),
				"detail": Color(0.76, 0.84, 0.94, 1.0),
			}


func _get_drop_toast_title(highlight: Dictionary) -> String:
	if bool(highlight.get("is_tracked_target", false)):
		return "追踪目标达成"
	if bool(highlight.get("has_legendary_affix", false)):
		return "传奇掉落"
	return "高价值掉落"


func _get_drop_toast_color(highlight: Dictionary) -> Color:
	if bool(highlight.get("is_tracked_target", false)):
		return Color(1.0, 0.50, 0.36, 0.98)
	if bool(highlight.get("has_legendary_affix", false)):
		return Color(1.0, 0.84, 0.48, 0.95)
	return Color(0.76, 0.9, 1.0, 0.92)


func _load_runtime_texture(resource_path: String) -> Texture2D:
	return RuntimeTextureLoader.load_texture(resource_path)


func get_resource_collect_target() -> Vector2:
	return resource_label.get_global_rect().get_center()
