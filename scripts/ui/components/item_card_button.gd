extends Button
class_name ItemCardButton

const UI_STYLE = preload("res://scripts/ui/ui_style.gd")
const RuntimeTextureLoaderScript = preload("res://scripts/utils/runtime_texture_loader.gd")

const SLOT_ICON_PATHS := {
	"weapon": "res://assets/generated/icons/equip_weapon.png",
	"helmet": "res://assets/generated/icons/equip_helmet.png",
	"armor": "res://assets/generated/icons/equip_armor.png",
	"gloves": "res://assets/generated/icons/equip_gloves.png",
	"legs": "res://assets/generated/icons/equip_armor.png",
	"boots": "res://assets/generated/icons/equip_gloves.png",
	"accessory": "res://assets/generated/icons/equip_weapon.png",
	"accessory1": "res://assets/generated/icons/equip_weapon.png",
	"accessory2": "res://assets/generated/icons/equip_weapon.png",
	"belt": "res://assets/generated/icons/equip_armor.png",
}

const RARITY_FRAME_PATHS := {
	"common": "res://assets/generated/ui/frame_common.png",
	"uncommon": "res://assets/generated/ui/frame_common.png",
	"rare": "res://assets/generated/ui/frame_rare.png",
	"epic": "res://assets/generated/ui/frame_epic.png",
	"set": "res://assets/generated/ui/frame_epic.png",
	"legendary": "res://assets/generated/ui/frame_legendary.png",
	"ancient": "res://assets/generated/ui/frame_ancient.png",
}

const CORNER_BADGE_PRIORITY := ["传承", "武学", "高价值", "已精炼", "已锁定"]

@onready var frame_texture: TextureRect = $FrameTexture
@onready var icon_panel: PanelContainer = $InnerPadding/CardRow/IconPanel
@onready var icon_texture: TextureRect = $InnerPadding/CardRow/IconPanel/IconTexture
@onready var content_box: VBoxContainer = $InnerPadding/CardRow/ContentBox
@onready var title_label: Label = $InnerPadding/CardRow/ContentBox/TitleLabel
@onready var subtitle_label: Label = $InnerPadding/CardRow/ContentBox/SubtitleLabel
@onready var badge_label: Label = $InnerPadding/CardRow/ContentBox/BadgeLabel
@onready var corner_badge: PanelContainer = $CornerBadge
@onready var corner_badge_label: Label = $CornerBadge/CornerBadgeLabel

var _pending_data: Dictionary = {}


func _ready() -> void:
	flat = false
	text = ""
	clip_text = true
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	frame_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_panel.clip_contents = true
	content_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corner_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corner_badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.clip_text = true
	subtitle_label.clip_text = true
	badge_label.clip_text = true
	_apply_text_style()
	_apply_panel_styles()
	if not _pending_data.is_empty():
		configure(_pending_data)


func configure(card_data: Dictionary) -> void:
	_pending_data = card_data.duplicate(true)
	if not is_node_ready():
		return

	var accent: Color = card_data.get("accent_color", UI_STYLE.COLOR_BLUE)
	var card_disabled: bool = bool(card_data.get("disabled", false))
	var is_selected: bool = bool(card_data.get("selected", false))
	var is_placeholder: bool = bool(card_data.get("is_placeholder", false))
	var compact_mode: String = String(card_data.get("compact_mode", "default"))

	custom_minimum_size = card_data.get("min_size", Vector2(72, 72))
	disabled = card_disabled
	tooltip_text = String(card_data.get("tooltip_text", ""))

	title_label.text = String(card_data.get("title", ""))
	subtitle_label.text = String(card_data.get("subtitle", ""))
	var badges: Array = card_data.get("badges", [])
	badge_label.text = "" if badges.is_empty() else " | ".join(badges)
	badge_label.visible = not badges.is_empty()
	var has_frame_texture: bool = _apply_frame(String(card_data.get("rarity", "common")), is_placeholder, card_data)
	_apply_icon(card_data)
	_apply_corner_badge(card_data, badges, accent, is_placeholder)

	_apply_compact_mode(compact_mode, is_placeholder, has_frame_texture)
	UI_STYLE.style_button(self, accent, card_disabled)

	modulate = card_data.get(
		"modulate",
		Color(1, 1, 1, 1) if not is_placeholder else Color(0.64, 0.68, 0.76, 0.34)
	)
	scale = Vector2.ONE * 1.02 if is_selected else Vector2.ONE


func _apply_text_style() -> void:
	UI_STYLE.style_label(title_label, "heading")
	UI_STYLE.style_label(subtitle_label, "muted")
	UI_STYLE.style_label(badge_label, "warning")
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	badge_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI_STYLE.style_label(corner_badge_label, "tiny")
	corner_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _apply_panel_styles() -> void:
	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = Color(0.10, 0.13, 0.18, 0.82)
	icon_style.border_color = Color(0.34, 0.42, 0.56, 0.24)
	icon_style.border_width_left = 1
	icon_style.border_width_top = 1
	icon_style.border_width_right = 1
	icon_style.border_width_bottom = 1
	icon_style.corner_radius_top_left = 7
	icon_style.corner_radius_top_right = 7
	icon_style.corner_radius_bottom_right = 7
	icon_style.corner_radius_bottom_left = 7
	icon_style.content_margin_left = 4
	icon_style.content_margin_right = 4
	icon_style.content_margin_top = 4
	icon_style.content_margin_bottom = 4
	icon_panel.add_theme_stylebox_override("panel", icon_style)

	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0.20, 0.24, 0.30, 0.88)
	badge_style.corner_radius_top_left = 8
	badge_style.corner_radius_top_right = 8
	badge_style.corner_radius_bottom_right = 8
	badge_style.corner_radius_bottom_left = 8
	badge_style.content_margin_left = 5
	badge_style.content_margin_right = 5
	badge_style.content_margin_top = 1
	badge_style.content_margin_bottom = 1
	corner_badge.add_theme_stylebox_override("panel", badge_style)


func _apply_compact_mode(compact_mode: String, is_placeholder: bool, has_frame_texture: bool) -> void:
	subtitle_label.visible = true
	badge_label.visible = not badge_label.text.is_empty()
	frame_texture.visible = has_frame_texture
	match compact_mode:
		"grid":
			title_label.add_theme_font_size_override("font_size", 9)
			subtitle_label.add_theme_font_size_override("font_size", 8)
			badge_label.add_theme_font_size_override("font_size", 7)
			icon_panel.custom_minimum_size = Vector2(14, 14)
			icon_texture.custom_minimum_size = Vector2(10, 10)
			subtitle_label.visible = false
			badge_label.visible = false
		"equipment":
			title_label.add_theme_font_size_override("font_size", 9)
			subtitle_label.add_theme_font_size_override("font_size", 9)
			badge_label.add_theme_font_size_override("font_size", 7)
			icon_panel.custom_minimum_size = Vector2(16, 16)
			icon_texture.custom_minimum_size = Vector2(12, 12)
			badge_label.visible = false
		"candidate":
			title_label.add_theme_font_size_override("font_size", 12)
			subtitle_label.add_theme_font_size_override("font_size", 10)
			badge_label.add_theme_font_size_override("font_size", 9)
			icon_panel.custom_minimum_size = Vector2(18, 18)
			icon_texture.custom_minimum_size = Vector2(12, 12)
		_:
			title_label.add_theme_font_size_override("font_size", 11)
			subtitle_label.add_theme_font_size_override("font_size", 10)
			badge_label.add_theme_font_size_override("font_size", 9)
			icon_panel.custom_minimum_size = Vector2(18, 18)
			icon_texture.custom_minimum_size = Vector2(12, 12)

	title_label.add_theme_color_override("font_color", UI_STYLE.COLOR_TEXT_MUTED if is_placeholder else UI_STYLE.COLOR_TEXT)
	subtitle_label.add_theme_color_override("font_color", UI_STYLE.COLOR_TEXT_MUTED if is_placeholder else UI_STYLE.COLOR_TEXT_DIM)
	badge_label.add_theme_color_override("font_color", UI_STYLE.COLOR_TEXT_MUTED if is_placeholder else UI_STYLE.COLOR_GOLD)
	icon_panel.modulate = Color(1, 1, 1, 0.35) if is_placeholder else Color(1, 1, 1, 0.9)


func _apply_frame(rarity: String, is_placeholder: bool, card_data: Dictionary) -> bool:
	var frame_path: String = String(card_data.get("frame_texture_path", ""))
	var should_show_frame: bool = bool(card_data.get("show_frame", false)) or not frame_path.is_empty()
	if frame_path.is_empty() and should_show_frame:
		frame_path = RARITY_FRAME_PATHS.get(rarity, RARITY_FRAME_PATHS["common"])
	if frame_path.is_empty():
		frame_texture.texture = null
		frame_texture.visible = false
		return false

	frame_texture.texture = RuntimeTextureLoaderScript.load_texture(frame_path)
	frame_texture.modulate = card_data.get(
		"frame_modulate",
		Color(1, 1, 1, 0.16) if is_placeholder else Color(1, 1, 1, 0.40)
	)
	frame_texture.visible = should_show_frame and frame_texture.texture != null
	return frame_texture.visible


func _apply_icon(card_data: Dictionary) -> void:
	var icon_path: String = String(card_data.get("icon_path", ""))
	var slot_id: String = String(card_data.get("slot_id", ""))
	if icon_path.is_empty():
		icon_path = SLOT_ICON_PATHS.get(slot_id, "")
	var icon_texture_resource: Texture2D = null
	if not icon_path.is_empty():
		icon_texture_resource = RuntimeTextureLoaderScript.load_texture(icon_path)
	icon_texture.texture = icon_texture_resource
	icon_panel.visible = icon_texture_resource != null


func _apply_corner_badge(card_data: Dictionary, badges: Array, accent: Color, is_placeholder: bool) -> void:
	var badge_text: String = String(card_data.get("corner_badge", ""))
	if badge_text.is_empty():
		badge_text = _pick_corner_badge(badges)
	corner_badge.visible = not badge_text.is_empty()
	corner_badge_label.text = badge_text
	corner_badge_label.add_theme_color_override(
		"font_color",
		UI_STYLE.COLOR_TEXT_MUTED if is_placeholder else UI_STYLE.COLOR_TEXT
	)
	corner_badge.self_modulate = accent.darkened(0.2) if not is_placeholder else Color(0.3, 0.33, 0.38, 0.55)


func _pick_corner_badge(badges: Array) -> String:
	if badges.is_empty():
		return ""
	for priority_badge in CORNER_BADGE_PRIORITY:
		if badges.has(priority_badge):
			return priority_badge
	return String(badges[0])
