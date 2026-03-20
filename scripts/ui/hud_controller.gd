extends Control

const CORE_SKILL_ICON_PATHS := {
	"core_whirlwind": "res://assets/generated/icons/core_whirlwind.png",
	"core_deep_wound": "res://assets/generated/icons/core_deep_wound.png",
	"core_chain_lightning": "res://assets/generated/icons/core_chain_lightning.png",
}
const EQUIPMENT_ICON_PATHS := {
	"weapon": "res://assets/generated/icons/equip_weapon.png",
	"helmet": "res://assets/generated/icons/equip_helmet.png",
	"armor": "res://assets/generated/icons/equip_armor.png",
	"gloves": "res://assets/generated/icons/equip_gloves.png",
}
const HUD_RESULT_CARD_PATH := "res://assets/generated/ui/result_card_bg.png"
const HUD_RARITY_FRAME_PATHS := {
	"common": "res://assets/generated/ui/frame_common.png",
	"uncommon": "res://assets/generated/ui/frame_common.png",
	"rare": "res://assets/generated/ui/frame_rare.png",
	"epic": "res://assets/generated/ui/frame_epic.png",
	"legendary": "res://assets/generated/ui/frame_legendary.png",
	"ancient": "res://assets/generated/ui/frame_ancient.png",
}
const LOOT_ICON_PATHS := {
	"legendary": "res://assets/generated/icons/drop_legendary.png",
	"store": "res://assets/generated/icons/drop_store.png",
	"salvage": "res://assets/generated/icons/drop_salvage.png",
}
const SAFE_FRAME_SIDE_MARGIN := 8.0
const SAFE_FRAME_BOTTOM_GAP := 18.0
const SAFE_FRAME_HEIGHT := 210.0
const CARD_TO_FRAME_GAP := 18.0
const CARD_SIDE_MARGIN := 16.0
const CARD_MIN_TOP_GAP := 18.0

@onready var resource_label: Label = $TopBar/ResourceLabel
@onready var run_label: Label = $TopBar/RunLabel
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
@onready var target_label: Label = $TargetCard/TargetLabel
@onready var codex_label: Label = $TargetCard/CodexLabel
@onready var equip_card: Panel = $EquipCard
@onready var equip_card_art: TextureRect = $EquipCard/CardArt
@onready var weapon_icon: TextureRect = $EquipCard/WeaponSlot/Icon
@onready var weapon_frame: TextureRect = $EquipCard/WeaponSlot/Frame
@onready var helmet_icon: TextureRect = $EquipCard/HelmetSlot/Icon
@onready var helmet_frame: TextureRect = $EquipCard/HelmetSlot/Frame
@onready var armor_icon: TextureRect = $EquipCard/ArmorSlot/Icon
@onready var armor_frame: TextureRect = $EquipCard/ArmorSlot/Frame
@onready var gloves_icon: TextureRect = $EquipCard/GlovesSlot/Icon
@onready var gloves_frame: TextureRect = $EquipCard/GlovesSlot/Frame
@onready var weapon_label: Label = $EquipCard/WeaponSlot/Value
@onready var helmet_label: Label = $EquipCard/HelmetSlot/Value
@onready var armor_label: Label = $EquipCard/ArmorSlot/Value
@onready var gloves_label: Label = $EquipCard/GlovesSlot/Value
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


func _ready() -> void:
	_apply_card_art()
	_apply_slot_icons()
	_apply_battle_safe_frame_style()
	_apply_compact_typography()
	get_viewport().size_changed.connect(_apply_hud_layout)
	EventBus.node_changed.connect(_on_node_changed)
	EventBus.combat_state_changed.connect(_on_state_changed)
	EventBus.player_hp_changed.connect(_on_hp_changed)
	EventBus.resources_changed.connect(_on_resources_changed)
	EventBus.core_skill_changed.connect(_on_skill_changed)
	EventBus.equipment_changed.connect(_on_equipment_changed)
	EventBus.loot_summary_changed.connect(_on_loot_summary_changed)
	EventBus.codex_changed.connect(_on_codex_changed)
	EventBus.loot_target_changed.connect(_on_target_changed)

	_on_node_changed(GameManager.current_node_id)
	_on_state_changed("准备中")
	_on_hp_changed(0.0, 0.0)
	_on_resources_changed()
	_on_skill_changed(GameManager.selected_core_skill_id)
	_on_focus_changed()
	_on_target_changed()
	_on_codex_changed()
	_on_equipment_changed()
	_on_loot_summary_changed(GameManager.last_loot_summary)
	call_deferred("_apply_hud_layout")


func _on_node_changed(node_id: String) -> void:
	var node_data: Dictionary = ConfigDB.get_chapter_node(node_id)
	var chapter_id: String = String(node_data.get("chapter_id", GameManager.current_chapter_id))
	var chapter_data: Dictionary = ConfigDB.get_chapter(chapter_id)
	node_label.text = "%s  ·  %s  ·  %s" % [
		String(chapter_data.get("name", chapter_id)),
		String(node_data.get("id", node_id)),
		String(node_data.get("node_type", "--")),
	]
	_on_focus_changed()
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
	resource_label.text = "金币 %d  |  铁屑 %d  |  核心 %d  |  碎片 %d  |  背包 %d" % [
		MetaProgressionSystem.gold,
		MetaProgressionSystem.scrap,
		MetaProgressionSystem.core,
		MetaProgressionSystem.legend_shard,
		GameManager.get_inventory_count(),
	]
	run_label.text = "击杀 %d  |  清图 %d  |  当前节点 %s" % [
		GameManager.current_run_kills,
		GameManager.current_run_clears,
		GameManager.current_node_id,
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
	target_label.text = LootCodexSystem.get_tracked_target_summary_text()
	target_label.add_theme_color_override("font_color", Color(0.92, 0.86, 1.0, 1.0))


func _on_codex_changed() -> void:
	codex_label.text = LootCodexSystem.get_codex_summary_text()
	codex_label.add_theme_color_override("font_color", Color(0.74, 0.82, 1.0, 1.0))


func _on_equipment_changed() -> void:
	_update_equipped_slot("weapon", weapon_label)
	_update_equipped_slot("helmet", helmet_label)
	_update_equipped_slot("armor", armor_label)
	_update_equipped_slot("gloves", gloves_label)


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
	highlight_label.text = highlight_line
	highlight_label.add_theme_color_override("font_color", _get_loot_highlight_color(highlight_line))
	loot_card_art.modulate = _get_loot_card_modulate(highlight_line)
	_apply_loot_icon()
	if summary_lines.size() <= 1:
		loot_label.text = summary_text
	else:
		loot_label.text = "\n".join(summary_lines.slice(1))
	loot_label.add_theme_color_override("font_color", Color(0.82, 0.86, 0.9, 1.0))
	_maybe_show_drop_toast(highlight_line)


func _update_equipped_slot(slot: String, label: Label) -> void:
	var item: Dictionary = GameManager.get_equipped_item(slot)
	var frame: TextureRect = _get_slot_frame(slot)
	if item.is_empty():
		label.text = "--"
		label.add_theme_color_override("font_color", Color(0.72, 0.74, 0.78, 1.0))
		if frame != null:
			frame.texture = _load_runtime_texture(HUD_RARITY_FRAME_PATHS["common"])
		return
	label.text = "%s\n%.1f" % [
		String(item.get("name", "--")),
		float(item.get("score", 0.0)),
	]
	var rarity: String = String(item.get("rarity", "common"))
	label.add_theme_color_override("font_color", _get_rarity_color(rarity))
	if frame != null:
		frame.texture = _load_runtime_texture(String(HUD_RARITY_FRAME_PATHS.get(rarity, HUD_RARITY_FRAME_PATHS["common"])))


func _get_rarity_color(rarity: String) -> Color:
	match rarity:
		"uncommon":
			return Color(0.48, 0.9, 0.46, 1.0)
		"rare":
			return Color(0.42, 0.7, 1.0, 1.0)
		"epic":
			return Color(0.8, 0.52, 1.0, 1.0)
		"legendary":
			return Color(1.0, 0.74, 0.28, 1.0)
		"ancient":
			return Color(1.0, 0.46, 0.3, 1.0)
		_:
			return Color(0.88, 0.88, 0.9, 1.0)


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
	var nav_top: float = main_nav_bar.position.y if main_nav_bar != null else viewport_size.y - 92.0
	var safe_frame_bottom: float = nav_top - SAFE_FRAME_BOTTOM_GAP
	var safe_frame_top: float = safe_frame_bottom - SAFE_FRAME_HEIGHT
	battle_safe_frame.position = Vector2(SAFE_FRAME_SIDE_MARGIN, safe_frame_top)
	battle_safe_frame.size = Vector2(viewport_size.x - SAFE_FRAME_SIDE_MARGIN * 2.0, SAFE_FRAME_HEIGHT)

	var reference_top: float = maxf(
		battle_card.position.y + battle_card.size.y,
		target_card.position.y + target_card.size.y
	) + CARD_MIN_TOP_GAP
	var desired_card_y: float = safe_frame_top - equip_card.size.y - CARD_TO_FRAME_GAP
	var card_y: float = maxf(reference_top, desired_card_y)

	equip_card.position = Vector2(CARD_SIDE_MARGIN, card_y)
	loot_card.position = Vector2(viewport_size.x - loot_card.size.x - CARD_SIDE_MARGIN, card_y)
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


func _apply_slot_icons() -> void:
	weapon_icon.texture = _load_runtime_texture(EQUIPMENT_ICON_PATHS["weapon"])
	helmet_icon.texture = _load_runtime_texture(EQUIPMENT_ICON_PATHS["helmet"])
	armor_icon.texture = _load_runtime_texture(EQUIPMENT_ICON_PATHS["armor"])
	gloves_icon.texture = _load_runtime_texture(EQUIPMENT_ICON_PATHS["gloves"])


func _get_slot_frame(slot: String) -> TextureRect:
	match slot:
		"weapon":
			return weapon_frame
		"helmet":
			return helmet_frame
		"armor":
			return armor_frame
		"gloves":
			return gloves_frame
		_:
			return null


func _apply_loot_icon() -> void:
	var highlight: Dictionary = GameManager.get_loot_highlight()
	var texture_path: String = ""
	if bool(highlight.get("has_legendary_affix", false)):
		texture_path = LOOT_ICON_PATHS["legendary"]
	else:
		texture_path = String(LOOT_ICON_PATHS.get(String(highlight.get("action", "store")), LOOT_ICON_PATHS["store"]))
	loot_icon.texture = _load_runtime_texture(texture_path)


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
	toast_title.text = "传奇掉落" if bool(highlight.get("has_legendary_affix", false)) else "高价值掉落"
	toast_label.text = String(highlight.get("item_name", highlight_line))
	drop_toast.modulate = Color(1.0, 0.84, 0.48, 0.95) if bool(highlight.get("has_legendary_affix", false)) else Color(0.76, 0.9, 1.0, 0.92)
	drop_toast.visible = true
	drop_toast.position = drop_toast_base_position
	if drop_toast_tween:
		drop_toast_tween.kill()
	drop_toast_tween = create_tween()
	drop_toast_tween.tween_property(drop_toast, "position:y", drop_toast_base_position.y - 10.0, 0.25)
	drop_toast_tween.parallel().tween_property(drop_toast, "modulate:a", 1.0, 0.15)
	drop_toast_tween.tween_interval(1.5)
	drop_toast_tween.tween_property(drop_toast, "modulate:a", 0.0, 0.35)
	drop_toast_tween.finished.connect(func() -> void:
		drop_toast.visible = false
		drop_toast.modulate.a = 1.0
		drop_toast.position = drop_toast_base_position
	)


func _get_loot_card_modulate(text: String) -> Color:
	if text.contains("传奇"):
		return Color(1.0, 0.82, 0.46, 0.62)
	if text.contains("装备"):
		return Color(0.72, 0.86, 1.0, 0.56)
	if text.contains("分解"):
		return Color(0.94, 0.72, 0.52, 0.52)
	return Color(0.9, 0.92, 0.98, 0.45)


func _load_runtime_texture(resource_path: String) -> Texture2D:
	return RuntimeTextureLoader.load_texture(resource_path)


func get_resource_collect_target() -> Vector2:
	return resource_label.get_global_rect().get_center()
