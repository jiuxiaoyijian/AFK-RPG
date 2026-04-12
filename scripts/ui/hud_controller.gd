extends Control

const UI_STYLE = preload("res://scripts/ui/ui_style.gd")

const PORTRAIT_FALLBACK_PATH := "res://assets/generated/afk_rpg_formal/characters/disciple_male_portrait.png"
const CORE_SKILL_ICON_PATHS := {
	"core_whirlwind": "res://assets/generated/afk_rpg_formal/icons/school_yufengdao_highlight.png",
	"core_deep_wound": "res://assets/generated/afk_rpg_formal/icons/school_xuejiedao_highlight.png",
	"core_chain_lightning": "res://assets/generated/afk_rpg_formal/icons/school_wuleidao_highlight.png",
}
const ORB_TEXTURE_PATHS := {
	"life": "res://assets/generated/afk_rpg_formal/icons/icon_orb_epic.png",
	"spirit": "res://assets/generated/afk_rpg_formal/icons/icon_orb_rare.png",
}
const SKILL_SLOT_FRAME_PATH := "res://assets/generated/afk_rpg_formal/ui/skill_slot_base.png"
const SKILL_SLOT_ICON_PATHS := {
	"basic": "res://assets/generated/afk_rpg_formal/icons/drop_equipment.png",
	"core": "res://assets/generated/afk_rpg_formal/icons/drop_rare.png",
	"tactic": "res://assets/generated/afk_rpg_formal/icons/system_wudao.png",
	"burst": "res://assets/generated/afk_rpg_formal/icons/system_jiyuantuiyan.png",
	"locked": "res://assets/generated/afk_rpg_formal/icons/icon_orb_common.png",
}
const LOOT_ICON_PATHS := {
	"legendary": "res://assets/generated/afk_rpg_formal/icons/drop_rare.png",
	"equip": "res://assets/generated/afk_rpg_formal/icons/drop_equipment.png",
	"store": "res://assets/generated/afk_rpg_formal/icons/drop_equipment.png",
	"salvage": "res://assets/generated/icons/drop_salvage.png",
}
const CLEAN_HUD_TEXTURE_PATHS := {
	"bar": "res://assets/generated/afk_rpg_formal/ui/hud/combat_plate_frame.png",
	"left_orb": "res://assets/generated/afk_rpg_formal/ui/hud/left_orb_shell.png",
	"right_orb": "res://assets/generated/afk_rpg_formal/ui/hud/right_orb_shell.png",
}
const HUD_PANEL_TEXTURE_PATHS := {
	"player": "res://assets/generated/afk_rpg_formal/ui/hud/player_header_frame.png",
	"portrait_ring": "res://assets/generated/afk_rpg_formal/ui/hud/portrait_ring_frame.png",
	"stage": "res://assets/generated/afk_rpg_formal/ui/hud/stage_header_frame.png",
	"objective": "res://assets/generated/afk_rpg_formal/ui/hud/objective_card_frame.png",
	"loot": "res://assets/generated/afk_rpg_formal/ui/hud/loot_card_frame.png",
	"drop_toast": "res://assets/generated/afk_rpg_formal/ui/hud/drop_toast_frame.png",
}
const COMBAT_BAR_WIDTH := 600.0
const COMBAT_BAR_HEIGHT := 168.0
const COMBAT_BAR_BOTTOM_GAP := 10.0
const COMBAT_PLATE_BOTTOM_GAP := 2.0
const ORB_SIDE_OVERHANG := 18.0
const ORB_BOTTOM_GAP := -2.0

@onready var player_header: Panel = $PlayerHeader
@onready var portrait_ring: Panel = $PlayerHeader/PortraitRing
@onready var portrait_texture: TextureRect = $PlayerHeader/PortraitRing/PortraitTexture
@onready var name_label: Label = $PlayerHeader/NameLabel
@onready var archetype_label: Label = $PlayerHeader/ArchetypeLabel
@onready var player_hp_label: Label = $PlayerHeader/PlayerHpLabel
@onready var resource_label: Label = $PlayerHeader/ResourceLabel

@onready var stage_header: Panel = $StageHeader
@onready var stage_title_label: Label = $StageHeader/StageTitleLabel
@onready var stage_progress_label: Label = $StageHeader/StageProgressLabel
@onready var stage_run_label: Label = $StageHeader/StageRunLabel
@onready var stage_dots_label: Label = $StageHeader/StageDotsLabel

@onready var combat_highlight_panel: Panel = $CombatHighlightPanel
@onready var combat_highlight_title: Label = $CombatHighlightPanel/CombatHighlightTitle
@onready var combat_highlight_subtitle: Label = $CombatHighlightPanel/CombatHighlightSubtitle
@onready var combat_highlight_detail: Label = $CombatHighlightPanel/CombatHighlightDetail

@onready var objective_card: Panel = $ObjectiveCard
@onready var objective_title_label: Label = $ObjectiveCard/ObjectiveTitleLabel
@onready var objective_main_label: Label = $ObjectiveCard/ObjectiveMainLabel
@onready var objective_reward_label: Label = $ObjectiveCard/ObjectiveRewardLabel
@onready var objective_next_label: Label = $ObjectiveCard/ObjectiveNextLabel

@onready var loot_card: Panel = $LootCard
@onready var loot_title_label: Label = $LootCard/LootTitleLabel
@onready var loot_icon: TextureRect = $LootCard/LootIcon
@onready var highlight_label: Label = $LootCard/HighlightLabel
@onready var loot_label: Label = $LootCard/LootLabel

@onready var combat_bar: Panel = $BattleSafeFrame
@onready var combat_plate_texture: TextureRect = $BattleSafeFrame/CombatPlateTexture
@onready var combat_plate: Panel = $BattleSafeFrame/CombatPlate
@onready var left_orb_mount: Panel = $BattleSafeFrame/LeftOrbMount
@onready var left_orb: Panel = $BattleSafeFrame/LeftOrb
@onready var left_orb_texture: TextureRect = $BattleSafeFrame/LeftOrb/LeftOrbTexture
@onready var left_orb_value_label: Label = $BattleSafeFrame/LeftOrb/LeftOrbValueLabel
@onready var left_orb_caption_label: Label = $BattleSafeFrame/LeftOrb/LeftOrbCaptionLabel
@onready var right_orb_mount: Panel = $BattleSafeFrame/RightOrbMount
@onready var right_orb: Panel = $BattleSafeFrame/RightOrb
@onready var right_orb_texture: TextureRect = $BattleSafeFrame/RightOrb/RightOrbTexture
@onready var right_orb_value_label: Label = $BattleSafeFrame/RightOrb/RightOrbValueLabel
@onready var right_orb_caption_label: Label = $BattleSafeFrame/RightOrb/RightOrbCaptionLabel
@onready var buff_strip: Panel = $BattleSafeFrame/BuffStrip
@onready var buff_a_label: Label = $BattleSafeFrame/BuffStrip/BuffALabel
@onready var buff_b_label: Label = $BattleSafeFrame/BuffStrip/BuffBLabel
@onready var buff_c_label: Label = $BattleSafeFrame/BuffStrip/BuffCLabel
@onready var skill_icons: Array = [
	$BattleSafeFrame/SkillStrip/SkillSlot1/Icon,
	$BattleSafeFrame/SkillStrip/SkillSlot2/Icon,
	$BattleSafeFrame/SkillStrip/SkillSlot3/Icon,
	$BattleSafeFrame/SkillStrip/SkillSlot4/Icon,
	$BattleSafeFrame/SkillStrip/SkillSlot5/Icon,
]
@onready var skill_frames: Array = [
	$BattleSafeFrame/SkillStrip/SkillSlot1/Frame,
	$BattleSafeFrame/SkillStrip/SkillSlot2/Frame,
	$BattleSafeFrame/SkillStrip/SkillSlot3/Frame,
	$BattleSafeFrame/SkillStrip/SkillSlot4/Frame,
	$BattleSafeFrame/SkillStrip/SkillSlot5/Frame,
]
@onready var skill_key_labels: Array = [
	$BattleSafeFrame/SkillStrip/SkillSlot1/KeyLabel,
	$BattleSafeFrame/SkillStrip/SkillSlot2/KeyLabel,
	$BattleSafeFrame/SkillStrip/SkillSlot3/KeyLabel,
	$BattleSafeFrame/SkillStrip/SkillSlot4/KeyLabel,
	$BattleSafeFrame/SkillStrip/SkillSlot5/KeyLabel,
]

@onready var drop_toast: Panel = $DropToast
@onready var toast_icon: TextureRect = $DropToast/ToastIcon
@onready var toast_title: Label = $DropToast/ToastTitle
@onready var toast_label: Label = $DropToast/ToastLabel

var current_state_text: String = "准备中"
var current_hp: float = 0.0
var current_hp_max: float = 0.0
var current_resource: float = 0.0
var current_resource_max: float = 100.0
var current_slot_entries: Array = []
var drop_toast_tween: Tween
var drop_toast_base_position: Vector2 = Vector2.ZERO
var combat_highlight_tween: Tween


func _ready() -> void:
	_wire_interactions()
	_apply_visual_style()
	get_viewport().size_changed.connect(_apply_hud_layout)
	EventBus.node_changed.connect(_on_node_changed)
	EventBus.player_hp_changed.connect(_on_hp_changed)
	EventBus.combat_state_changed.connect(_on_state_changed)
	EventBus.resources_changed.connect(_on_resources_changed)
	EventBus.inventory_changed.connect(_on_inventory_changed)
	EventBus.core_skill_changed.connect(_on_skill_changed)
	EventBus.skill_loadout_changed.connect(_on_skill_loadout_changed)
	EventBus.player_resource_changed.connect(_on_player_resource_changed)
	EventBus.hero_level_changed.connect(_on_progression_changed)
	EventBus.loot_summary_changed.connect(_on_loot_summary_changed)
	EventBus.daily_goals_changed.connect(_on_daily_goals_changed)
	EventBus.set_bonus_changed.connect(_on_build_relevant_state_changed)
	EventBus.martial_codex_changed.connect(_on_build_relevant_state_changed)
	EventBus.combat_highlight_requested.connect(_on_combat_highlight_requested)

	_on_node_changed(GameManager.current_node_id)
	_on_state_changed("准备中")
	_on_hp_changed(current_hp, current_hp_max)
	_on_resources_changed()
	_on_inventory_changed()
	_on_skill_loadout_changed(GameManager.get_skill_screen_state())
	_on_daily_goals_changed()
	_on_loot_summary_changed(GameManager.last_loot_summary)
	call_deferred("_apply_hud_layout")


func _wire_interactions() -> void:
	objective_card.mouse_filter = Control.MOUSE_FILTER_STOP
	objective_card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	objective_card.gui_input.connect(_on_objective_card_input)
	loot_card.mouse_filter = Control.MOUSE_FILTER_STOP
	loot_card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	loot_card.gui_input.connect(_on_loot_card_input)


func _apply_visual_style() -> void:
	_apply_panel_tint(player_header, Color(0.08, 0.10, 0.14, 0.30))
	_apply_panel_tint(stage_header, Color(0.08, 0.10, 0.14, 0.26))
	_apply_panel_tint(objective_card, Color(0.08, 0.10, 0.14, 0.24))
	_apply_panel_tint(loot_card, Color(0.08, 0.10, 0.14, 0.24))
	_apply_panel_tint(drop_toast, Color(0.10, 0.12, 0.16, 0.26))
	_apply_battle_safe_frame_style()
	_apply_combat_plate_style()
	_apply_orb_mount_style(left_orb_mount)
	_apply_orb_mount_style(right_orb_mount)
	_apply_orb_style(left_orb, Color(0.36, 0.09, 0.10, 0.96), Color(0.84, 0.54, 0.44, 0.92))
	_apply_orb_style(right_orb, Color(0.12, 0.20, 0.46, 0.96), Color(0.54, 0.70, 0.98, 0.92))
	_apply_panel_tint(buff_strip, Color(0.06, 0.08, 0.11, 0.78))
	_apply_panel_tint(combat_highlight_panel, Color(0.18, 0.22, 0.30, 0.92))
	_apply_portrait_ring_style()
	_apply_panel_texture_overlay(player_header, HUD_PANEL_TEXTURE_PATHS["player"], Color(1, 1, 1, 0.98), "FrameTexture")
	_apply_panel_texture_overlay(portrait_ring, HUD_PANEL_TEXTURE_PATHS["portrait_ring"], Color(1, 1, 1, 0.98), "RingTexture")
	_apply_panel_texture_overlay(stage_header, HUD_PANEL_TEXTURE_PATHS["stage"], Color(1, 1, 1, 0.98), "FrameTexture")
	_apply_panel_texture_overlay(objective_card, HUD_PANEL_TEXTURE_PATHS["objective"], Color(1, 1, 1, 0.96), "FrameTexture")
	_apply_panel_texture_overlay(loot_card, HUD_PANEL_TEXTURE_PATHS["loot"], Color(1, 1, 1, 0.96), "FrameTexture")
	_apply_panel_texture_overlay(drop_toast, HUD_PANEL_TEXTURE_PATHS["drop_toast"], Color(1, 1, 1, 0.96), "FrameTexture")

	combat_plate_texture.texture = _load_runtime_texture(CLEAN_HUD_TEXTURE_PATHS["bar"])
	left_orb_texture.texture = _load_runtime_texture(CLEAN_HUD_TEXTURE_PATHS["left_orb"])
	right_orb_texture.texture = _load_runtime_texture(CLEAN_HUD_TEXTURE_PATHS["right_orb"])
	combat_plate_texture.visible = true
	left_orb_mount.visible = false
	right_orb_mount.visible = false
	combat_plate.visible = false
	left_orb_texture.visible = true
	right_orb_texture.visible = true
	_apply_clean_texture_layout()
	var slot_frame_texture: Texture2D = _load_runtime_texture(SKILL_SLOT_FRAME_PATH)
	for frame in skill_frames:
		frame.texture = slot_frame_texture
	for label in [name_label, objective_title_label, loot_title_label]:
		label.add_theme_font_size_override("font_size", 18)
	for label in [archetype_label, player_hp_label, stage_title_label, objective_main_label, highlight_label]:
		label.add_theme_font_size_override("font_size", 14)
	for label in [resource_label, stage_progress_label, stage_run_label, stage_dots_label, objective_reward_label, objective_next_label, loot_label]:
		label.add_theme_font_size_override("font_size", 12)
	for label in [buff_a_label, buff_b_label, buff_c_label]:
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", Color(0.90, 0.92, 0.98, 1.0))
	for key_label in skill_key_labels:
		key_label.add_theme_font_size_override("font_size", 10)
		key_label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.92, 1.0))

	name_label.add_theme_color_override("font_color", UI_STYLE.COLOR_GOLD)
	archetype_label.add_theme_color_override("font_color", UI_STYLE.COLOR_BLUE)
	player_hp_label.add_theme_color_override("font_color", UI_STYLE.COLOR_TEXT)
	resource_label.add_theme_color_override("font_color", UI_STYLE.COLOR_TEXT_DIM)
	stage_title_label.add_theme_color_override("font_color", UI_STYLE.COLOR_TEXT)
	stage_progress_label.add_theme_color_override("font_color", UI_STYLE.COLOR_BLUE)
	stage_run_label.add_theme_color_override("font_color", UI_STYLE.COLOR_GOLD)
	stage_dots_label.add_theme_color_override("font_color", UI_STYLE.COLOR_TEXT_DIM)
	objective_title_label.add_theme_color_override("font_color", UI_STYLE.COLOR_GOLD)
	objective_main_label.add_theme_color_override("font_color", UI_STYLE.COLOR_TEXT)
	objective_reward_label.add_theme_color_override("font_color", UI_STYLE.COLOR_BLUE)
	objective_next_label.add_theme_color_override("font_color", UI_STYLE.COLOR_GOLD)
	loot_title_label.add_theme_color_override("font_color", UI_STYLE.COLOR_GOLD)
	loot_label.add_theme_color_override("font_color", UI_STYLE.COLOR_TEXT_DIM)
	left_orb_value_label.add_theme_font_size_override("font_size", 16)
	right_orb_value_label.add_theme_font_size_override("font_size", 16)
	left_orb_caption_label.add_theme_font_size_override("font_size", 11)
	right_orb_caption_label.add_theme_font_size_override("font_size", 11)
	left_orb_value_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.96, 1.0))
	right_orb_value_label.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0, 1.0))
	left_orb_caption_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.82, 1.0))
	right_orb_caption_label.add_theme_color_override("font_color", Color(0.82, 0.92, 1.0, 1.0))

	combat_highlight_panel.visible = false
	drop_toast.visible = false


func _on_node_changed(_node_id: String) -> void:
	_refresh_player_header()
	_refresh_stage_header()
	_refresh_combat_bar()


func _on_hp_changed(new_current_hp: float, new_max_hp: float) -> void:
	current_hp = new_current_hp
	current_hp_max = new_max_hp
	_refresh_player_header()
	_refresh_combat_bar()


func _on_state_changed(state_text: String) -> void:
	current_state_text = state_text
	_refresh_stage_header()
	_refresh_combat_bar()


func _on_resources_changed() -> void:
	_refresh_player_header()
	_refresh_stage_header()


func _on_inventory_changed() -> void:
	_refresh_player_header()


func _on_skill_changed(_skill_id: String) -> void:
	_refresh_player_header()
	_refresh_combat_bar()


func _on_skill_loadout_changed(loadout: Dictionary) -> void:
	current_slot_entries = loadout.get("slot_entries", []).duplicate(true)
	_refresh_player_header()
	_refresh_combat_bar()


func _on_player_resource_changed(new_current_resource: float, new_max_resource: float) -> void:
	current_resource = new_current_resource
	current_resource_max = new_max_resource
	_refresh_combat_bar()


func _on_progression_changed(_summary: Dictionary) -> void:
	_refresh_player_header()
	_refresh_combat_bar()


func _on_build_relevant_state_changed(_payload: Variant = null) -> void:
	_refresh_combat_bar()


func _on_daily_goals_changed() -> void:
	var summary: Dictionary = GameManager.get_main_hud_state().get("objective_summary", {})
	objective_title_label.text = String(summary.get("title", "任务目标"))
	objective_main_label.text = "目标: %s" % _truncate_ui_text(String(summary.get("goal_text", "暂无目标")), 18)
	objective_reward_label.text = "进度: %s | 建议: %s" % [
		_truncate_ui_text(String(summary.get("progress_text", "--")), 8),
		_truncate_ui_text(String(summary.get("cta_text", "继续推进主目标")), 10),
	]
	objective_next_label.text = "下一步: %s" % _truncate_ui_text(String(summary.get("next_step_text", "继续推进当前目标")), 18)
	objective_card.tooltip_text = "点击打开成长中心，继续推进当前目标。"


func _on_loot_summary_changed(summary_text: String) -> void:
	var summary: Dictionary = GameManager.get_main_hud_state().get("loot_feed", {})
	var summary_lines: Array[String] = []
	for line_variant in summary.get("lines", []):
		summary_lines.append(String(line_variant))

	var highlight_line: String = "高价值掉落: 暂无"
	for line in summary_lines:
		if line.contains("传奇"):
			highlight_line = "高价值掉落: %s" % line
			break
	if highlight_line == "高价值掉落: 暂无" and not summary_lines.is_empty():
		highlight_line = "高价值掉落: %s" % summary_lines[0]

	loot_title_label.text = "掉落信息"
	highlight_label.text = _truncate_ui_text(highlight_line, 22)
	highlight_label.add_theme_color_override("font_color", _get_loot_highlight_color(highlight_line))
	_apply_loot_icon()
	if summary_lines.size() <= 1:
		loot_label.text = _truncate_ui_text(summary_text, 34)
	else:
		var compact_lines: Array[String] = []
		for line_variant in summary_lines.slice(1, min(summary_lines.size(), 4)):
			compact_lines.append(_truncate_ui_text(String(line_variant), 18))
		loot_label.text = "\n".join(compact_lines)
	loot_card.tooltip_text = _build_loot_card_tooltip()
	_maybe_show_drop_toast(highlight_line)


func _on_combat_highlight_requested(highlight_data: Dictionary) -> void:
	var highlight_type: String = String(highlight_data.get("highlight_type", "generic"))
	combat_highlight_title.text = String(highlight_data.get("title", "战斗高光"))
	combat_highlight_subtitle.text = String(highlight_data.get("subtitle", ""))
	combat_highlight_detail.text = String(highlight_data.get("detail", ""))
	var colors: Dictionary = _get_combat_highlight_colors(highlight_type)
	combat_highlight_title.add_theme_color_override("font_color", colors.get("title", Color.WHITE))
	combat_highlight_subtitle.add_theme_color_override("font_color", colors.get("subtitle", Color.WHITE))
	combat_highlight_detail.add_theme_color_override("font_color", colors.get("detail", Color.WHITE))
	_apply_panel_tint(combat_highlight_panel, colors.get("panel", Color(0.18, 0.22, 0.30, 0.92)))
	_show_combat_highlight_banner()


func _refresh_player_header() -> void:
	var summary: Dictionary = GameManager.get_main_hud_state().get("player_header", {})
	name_label.text = String(summary.get("name", "无名侠客"))
	archetype_label.text = String(summary.get("archetype", "流派: --"))
	player_hp_label.text = _build_hp_text()
	resource_label.text = _truncate_ui_text(String(summary.get("resource_text", "香火钱 0")), 52)
	portrait_texture.texture = _load_runtime_texture(String(summary.get("portrait_path", PORTRAIT_FALLBACK_PATH)))
	player_header.tooltip_text = "当前角色状态与资源概览"


func _refresh_stage_header() -> void:
	var summary: Dictionary = GameManager.get_main_hud_state().get("stage_header", {})
	stage_title_label.text = _truncate_ui_text(String(summary.get("title", "当前节点")), 22)
	stage_progress_label.text = _truncate_ui_text("%s | %s" % [
		String(summary.get("subtitle", "节点推进中")),
		current_state_text,
	], 28)
	stage_run_label.text = String(summary.get("run_text", "击杀 0 | 清图 0"))
	stage_dots_label.text = _build_stage_dots(current_state_text)
	stage_header.tooltip_text = "当前章节、节点与推进进度"


func _refresh_combat_bar() -> void:
	var summary: Dictionary = GameManager.get_main_hud_state().get("combat_bar", {})
	if current_hp_max > 0.0:
		left_orb_value_label.text = "%d%%" % int(_get_hp_percent() * 100.0)
	else:
		left_orb_value_label.text = "--"
	left_orb_caption_label.text = "生命"
	right_orb_value_label.text = "%d/%d" % [int(round(current_resource)), int(round(current_resource_max))]
	right_orb_caption_label.text = "真气"
	_update_skill_slots(summary.get("active_slots", current_slot_entries))
	buff_a_label.text = _truncate_ui_text(String(summary.get("core_skill_name", "核心技能")), 12)
	buff_b_label.text = _truncate_ui_text(String(summary.get("focus_text", "技能循环运行中")), 16)
	buff_c_label.text = _truncate_ui_text(String(summary.get("set_summary_text", "传承未激活")), 16)


func _update_skill_slots(slot_entries: Array) -> void:
	for i in range(skill_icons.size()):
		if i >= slot_entries.size() or i >= 4:
			skill_icons[i].visible = false
			skill_frames[i].visible = false
			skill_key_labels[i].visible = false
			continue
		var slot_entry: Dictionary = slot_entries[i]
		var slot_type: String = String(slot_entry.get("slot_type", "basic"))
		var is_unlocked: bool = bool(slot_entry.get("is_unlocked", false))
		var icon_path: String = String(slot_entry.get("icon_path", ""))
		if icon_path.is_empty():
			icon_path = String(SKILL_SLOT_ICON_PATHS.get(slot_type, SKILL_SLOT_ICON_PATHS["locked"]))
		skill_icons[i].texture = _load_runtime_texture(icon_path)
		skill_icons[i].visible = true
		skill_frames[i].visible = true
		skill_key_labels[i].visible = true
		skill_key_labels[i].text = String(slot_entry.get("slot_label", slot_type)) if is_unlocked else "未解锁"
		skill_icons[i].modulate = Color(1, 1, 1, 1) if is_unlocked else Color(0.46, 0.48, 0.54, 0.9)


func _build_hp_text() -> String:
	if current_hp_max <= 0.0:
		return "生命 --"
	return "生命 %d / %d" % [int(current_hp), int(current_hp_max)]


func _get_hp_percent() -> float:
	if current_hp_max <= 0.0:
		return 0.0
	return clampf(current_hp / current_hp_max, 0.0, 1.0)


func _build_stage_dots(state_text: String) -> String:
	var filled: int = clampi(_extract_wave_index(state_text), 0, 5)
	var empty: int = maxi(0, 5 - filled)
	return "%s%s" % ["●".repeat(filled), "○".repeat(empty)]


func _extract_wave_index(state_text: String) -> int:
	var start_index: int = state_text.find("第 ")
	if start_index == -1:
		start_index = state_text.find("第")
	if start_index == -1:
		return 1 if state_text.contains("战斗") else 0
	start_index += 1
	var number_text: String = ""
	while start_index < state_text.length():
		var digit_char: String = state_text.substr(start_index, 1)
		if digit_char >= "0" and digit_char <= "9":
			number_text += digit_char
		elif not number_text.is_empty():
			break
		start_index += 1
	if number_text.is_empty():
		return 1
	return mini(5, int(number_text))


func _apply_hud_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	player_header.position = Vector2(18.0, 18.0)
	player_header.size = Vector2(436.0, 122.0)
	stage_header.position = Vector2(viewport_size.x - 338.0, 18.0)
	stage_header.size = Vector2(320.0, 90.0)
	combat_highlight_panel.position = Vector2((viewport_size.x - combat_highlight_panel.size.x) * 0.5, 86.0)
	objective_card.position = Vector2(viewport_size.x - 338.0, 148.0)
	objective_card.size = Vector2(320.0, 122.0)
	loot_card.position = Vector2(18.0, 244.0)
	loot_card.size = Vector2(304.0, 114.0)
	combat_bar.position = Vector2(
		(viewport_size.x - COMBAT_BAR_WIDTH) * 0.5,
		viewport_size.y - COMBAT_BAR_HEIGHT - COMBAT_BAR_BOTTOM_GAP
	)
	combat_bar.size = Vector2(COMBAT_BAR_WIDTH, COMBAT_BAR_HEIGHT)
	_apply_clean_texture_layout()
	drop_toast_base_position = Vector2((viewport_size.x - drop_toast.size.x) * 0.5, 72.0)
	if not drop_toast.visible:
		drop_toast.position = drop_toast_base_position


func _apply_clean_texture_layout() -> void:
	_layout_plate_texture()
	_layout_orb(left_orb, left_orb_texture, left_orb_value_label, left_orb_caption_label, true)
	_layout_orb(right_orb, right_orb_texture, right_orb_value_label, right_orb_caption_label, false)


func _layout_plate_texture() -> void:
	if combat_plate_texture.texture == null:
		return
	var texture_size: Vector2 = combat_plate_texture.texture.get_size()
	combat_plate_texture.size = texture_size
	combat_plate_texture.position = Vector2(
		(combat_bar.size.x - texture_size.x) * 0.5,
		combat_bar.size.y - texture_size.y - COMBAT_PLATE_BOTTOM_GAP
	)


func _layout_orb(
	orb_panel: Panel,
	orb_texture: TextureRect,
	value_label: Label,
	caption_label: Label,
	is_left: bool
) -> void:
	if orb_texture.texture == null:
		return
	var texture_size: Vector2 = orb_texture.texture.get_size()
	orb_panel.size = texture_size
	orb_panel.position = Vector2(
		-ORB_SIDE_OVERHANG if is_left else combat_bar.size.x - texture_size.x + ORB_SIDE_OVERHANG,
		combat_bar.size.y - texture_size.y - ORB_BOTTOM_GAP
	)
	orb_texture.position = Vector2.ZERO
	orb_texture.size = texture_size
	value_label.position = Vector2(0.0, texture_size.y * 0.42 - 16.0)
	value_label.size = Vector2(texture_size.x, 28.0)
	caption_label.position = Vector2(0.0, texture_size.y * 0.67 - 10.0)
	caption_label.size = Vector2(texture_size.x, 20.0)


func _on_objective_card_input(event: InputEvent) -> void:
	if _is_primary_click(event):
		EventBus.ui_panel_requested.emit("research")


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
	drop_toast_tween.tween_property(drop_toast, "position:y", drop_toast_base_position.y - 10.0, 0.2)
	drop_toast_tween.parallel().tween_property(drop_toast, "modulate:a", 1.0, 0.12)
	drop_toast_tween.tween_interval(1.8)
	drop_toast_tween.tween_property(drop_toast, "modulate:a", 0.0, 0.28)
	drop_toast_tween.finished.connect(func() -> void:
		drop_toast.visible = false
		drop_toast.modulate.a = 1.0
		drop_toast.position = drop_toast_base_position
	)


func _build_loot_card_tooltip() -> String:
	var highlight: Dictionary = GameManager.get_loot_highlight()
	if highlight.is_empty():
		return "点击打开背包，检查最近掉落。"
	if bool(highlight.get("has_legendary_affix", false)) and String(highlight.get("action", "")) != "equip":
		return "点击直达百炼坊的萃取页，处理这件武学装备。"
	if String(highlight.get("action", "")) == "equip":
		return "点击打开背包，并聚焦刚刚替换上的装备槽位。"
	return "点击打开背包，并聚焦最近这件高价值掉落。"


func _apply_loot_icon() -> void:
	var highlight: Dictionary = GameManager.get_loot_highlight()
	var texture_path: String = ""
	if bool(highlight.get("has_legendary_affix", false)):
		texture_path = LOOT_ICON_PATHS["legendary"]
	else:
		texture_path = String(LOOT_ICON_PATHS.get(String(highlight.get("action", "store")), LOOT_ICON_PATHS["store"]))
	loot_icon.texture = _load_runtime_texture(texture_path)


func _show_combat_highlight_banner() -> void:
	combat_highlight_panel.visible = true
	combat_highlight_panel.modulate = Color(1, 1, 1, 0.0)
	combat_highlight_panel.scale = Vector2.ONE * 0.96
	if combat_highlight_tween:
		combat_highlight_tween.kill()
	combat_highlight_tween = create_tween()
	combat_highlight_tween.tween_property(combat_highlight_panel, "modulate:a", 1.0, 0.12)
	combat_highlight_tween.parallel().tween_property(combat_highlight_panel, "scale", Vector2.ONE, 0.18)
	combat_highlight_tween.tween_interval(1.4)
	combat_highlight_tween.tween_property(combat_highlight_panel, "modulate:a", 0.0, 0.3)
	combat_highlight_tween.finished.connect(func() -> void:
		combat_highlight_panel.visible = false
		combat_highlight_panel.modulate.a = 1.0
		combat_highlight_panel.scale = Vector2.ONE
	)


func _apply_battle_safe_frame_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.11, 0.82)
	style.border_color = Color(0.34, 0.30, 0.24, 0.86)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 24
	style.corner_radius_top_right = 24
	style.corner_radius_bottom_left = 24
	style.corner_radius_bottom_right = 24
	style.shadow_size = 8
	style.shadow_color = Color(0, 0, 0, 0.18)
	combat_bar.add_theme_stylebox_override("panel", style)


func _apply_combat_plate_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.10, 0.12, 0.82)
	style.border_color = Color(0.58, 0.48, 0.30, 0.74)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.shadow_size = 4
	style.shadow_color = Color(0, 0, 0, 0.12)
	combat_plate.add_theme_stylebox_override("panel", style)


func _apply_orb_mount_style(panel: Panel) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.11, 0.10, 0.54)
	style.border_color = Color(0.62, 0.50, 0.28, 0.72)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 3
	style.corner_radius_top_left = 999
	style.corner_radius_top_right = 999
	style.corner_radius_bottom_left = 28
	style.corner_radius_bottom_right = 28
	style.shadow_size = 3
	style.shadow_color = Color(0, 0, 0, 0.10)
	panel.add_theme_stylebox_override("panel", style)


func _apply_orb_style(panel: Panel, bg_color: Color, border_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.corner_radius_top_left = 999
	style.corner_radius_top_right = 999
	style.corner_radius_bottom_left = 999
	style.corner_radius_bottom_right = 999
	style.shadow_size = 4
	style.shadow_color = Color(0, 0, 0, 0.10)
	panel.add_theme_stylebox_override("panel", style)


func _apply_portrait_ring_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.12, 0.16, 0.94)
	style.border_color = Color(0.82, 0.68, 0.38, 0.92)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 999
	style.corner_radius_top_right = 999
	style.corner_radius_bottom_left = 999
	style.corner_radius_bottom_right = 999
	portrait_ring.add_theme_stylebox_override("panel", style)


func _apply_panel_tint(panel: Panel, bg_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = Color(minf(bg_color.r + 0.18, 1.0), minf(bg_color.g + 0.18, 1.0), minf(bg_color.b + 0.18, 1.0), 0.72)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.shadow_size = 6
	style.shadow_color = Color(0, 0, 0, 0.14)
	panel.add_theme_stylebox_override("panel", style)


func _apply_panel_texture_overlay(panel: Control, texture_path: String, tint: Color, overlay_name: String) -> void:
	var overlay := panel.get_node_or_null(overlay_name) as TextureRect
	if overlay == null:
		overlay = TextureRect.new()
		overlay.name = overlay_name
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.z_index = 0
		overlay.show_behind_parent = false
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.add_child(overlay)
		panel.move_child(overlay, 0)
	overlay.texture = _load_runtime_texture(texture_path)
	overlay.expand_mode = 1
	overlay.stretch_mode = 6
	overlay.modulate = tint


func _get_loot_highlight_color(text: String) -> Color:
	if text.contains("传奇"):
		return Color(1.0, 0.78, 0.32, 1.0)
	if text.contains("装备"):
		return Color(0.8, 0.9, 1.0, 1.0)
	if text.contains("分解"):
		return Color(0.92, 0.64, 0.48, 1.0)
	return Color(0.86, 0.9, 0.96, 1.0)


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
		_:
			return {
				"panel": Color(0.18, 0.22, 0.30, 0.92),
				"title": Color(0.94, 0.96, 1.0, 1.0),
				"subtitle": Color(0.88, 0.90, 0.94, 1.0),
				"detail": Color(0.76, 0.84, 0.94, 1.0),
			}


func _truncate_ui_text(text: String, max_chars: int) -> String:
	var single_line: String = text.replace("\n", " ").strip_edges()
	if single_line.length() <= max_chars:
		return single_line
	return "%s…" % single_line.substr(0, max_chars)


func _is_primary_click(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT


func _load_runtime_texture(resource_path: String) -> Texture2D:
	return RuntimeTextureLoader.load_texture(resource_path)


func get_resource_collect_target() -> Vector2:
	return resource_label.get_global_rect().get_center()
