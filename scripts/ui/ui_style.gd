extends RefCounted
class_name UIStyle

const COLOR_PANEL := Color(0.08, 0.10, 0.14, 0.94)
const COLOR_PANEL_SOFT := Color(0.11, 0.13, 0.18, 0.92)
const COLOR_PANEL_STRONG := Color(0.06, 0.08, 0.12, 0.97)
const COLOR_TITLE := Color(0.12, 0.16, 0.22, 0.96)
const COLOR_TITLE_SOFT := Color(0.14, 0.18, 0.25, 0.9)
const COLOR_BORDER := Color(0.34, 0.42, 0.56, 0.92)
const COLOR_BORDER_SOFT := Color(0.34, 0.42, 0.56, 0.35)
const COLOR_TEXT := Color(0.94, 0.96, 1.0, 1.0)
const COLOR_TEXT_DIM := Color(0.78, 0.82, 0.9, 1.0)
const COLOR_TEXT_MUTED := Color(0.50, 0.56, 0.66, 1.0)
const COLOR_GOLD := Color(0.98, 0.84, 0.54, 1.0)
const COLOR_PEACH := Color(0.96, 0.78, 0.80, 1.0)
const COLOR_TEAL := Color(0.50, 0.90, 0.92, 1.0)
const COLOR_BLUE := Color(0.52, 0.76, 1.0, 1.0)
const COLOR_GREEN := Color(0.56, 0.88, 0.62, 1.0)
const COLOR_RED := Color(0.98, 0.56, 0.48, 1.0)
const COLOR_SHADOW := Color(0.0, 0.0, 0.0, 0.18)


static func style_panel(panel: Panel, panel_name: String) -> void:
	panel.add_theme_stylebox_override("panel", build_panel_style(panel_name))


static func build_panel_style(panel_name: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = COLOR_BORDER
	style.shadow_color = COLOR_SHADOW
	style.shadow_size = 10
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8

	match panel_name:
		"TopBar":
			style.bg_color = Color(0.11, 0.13, 0.18, 0.84)
			style.corner_radius_top_left = 8
			style.corner_radius_top_right = 8
			style.corner_radius_bottom_right = 8
			style.corner_radius_bottom_left = 8
		"CombatHighlightPanel":
			style.bg_color = Color(0.14, 0.18, 0.26, 0.92)
		"BattleSafeFrame":
			style.bg_color = Color(0.07, 0.12, 0.16, 0.08)
			style.border_color = Color(0.30, 0.82, 0.84, 0.26)
			style.content_margin_left = 14
			style.content_margin_top = 14
			style.content_margin_right = 14
			style.content_margin_bottom = 14
		"TargetCard", "DailyGoalCard", "BattleCard", "EquipCard", "LootCard", "DropToast":
			style.bg_color = COLOR_PANEL
		"HeaderBar":
			style.bg_color = COLOR_TITLE
			style.content_margin_left = 12
			style.content_margin_right = 12
		"SummarySection", "FilterSection", "ListSection", "DetailSection", "ActionSection", "QuickSection", "RateSection", "RecentSection":
			style.bg_color = COLOR_PANEL_SOFT
			style.border_color = COLOR_BORDER_SOFT
		"ResourceSection", "ItemSection", "NodeSection", "ProgressSection":
			style.bg_color = COLOR_PANEL_SOFT
			style.border_color = COLOR_BORDER_SOFT
		"WeaponSlot", "HelmetSlot", "ArmorSlot", "GlovesSlot", "SkillIconPanel":
			style.bg_color = Color(0.12, 0.15, 0.22, 0.86)
			style.border_color = Color(0.34, 0.42, 0.56, 0.26)
			style.border_width_left = 1
			style.border_width_top = 1
			style.border_width_right = 1
			style.border_width_bottom = 1
			style.shadow_size = 0
		"Panel":
			style.bg_color = COLOR_PANEL_STRONG
			style.content_margin_left = 16
			style.content_margin_top = 12
			style.content_margin_right = 16
			style.content_margin_bottom = 12
		_:
			style.bg_color = COLOR_PANEL_SOFT
			style.border_color = COLOR_BORDER_SOFT
			style.shadow_size = 0

	return style


static func style_button(button: BaseButton, accent: Color, disabled: bool = false) -> void:
	var normal := _build_button_style(accent, 0.14 if not disabled else 0.05, 0.34 if not disabled else 0.14)
	var hover := _build_button_style(accent.lightened(0.06), 0.20 if not disabled else 0.06, 0.46 if not disabled else 0.14)
	var pressed := _build_button_style(accent.darkened(0.10), 0.28 if not disabled else 0.08, 0.52 if not disabled else 0.14)
	var disabled_style := _build_button_style(Color(0.40, 0.44, 0.50, 1.0), 0.06, 0.16)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled", disabled_style)
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", COLOR_TEXT)
	button.add_theme_color_override("font_pressed_color", COLOR_TEXT)
	button.add_theme_color_override("font_disabled_color", Color(0.58, 0.62, 0.70, 1.0))
	button.add_theme_font_size_override("font_size", 13)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.self_modulate = Color(1, 1, 1, 1)


static func style_option_button(option_button: OptionButton, accent: Color) -> void:
	style_button(option_button, accent, false)
	option_button.add_theme_color_override("modulate_arrow", accent.lightened(0.3))


static func style_check_box(check_box: CheckBox, accent: Color) -> void:
	check_box.add_theme_color_override("font_color", COLOR_TEXT)
	check_box.add_theme_color_override("font_hover_color", COLOR_TEXT)
	check_box.add_theme_color_override("font_pressed_color", COLOR_TEXT)
	check_box.add_theme_color_override("font_disabled_color", Color(0.58, 0.62, 0.70, 1.0))
	check_box.add_theme_color_override("checkbox_checked_color", accent)
	check_box.add_theme_color_override("checkbox_unchecked_color", COLOR_TEXT_DIM)
	check_box.add_theme_font_size_override("font_size", 13)


static func style_item_list(item_list: ItemList) -> void:
	var base := StyleBoxFlat.new()
	base.bg_color = Color(0.07, 0.09, 0.13, 0.92)
	base.border_color = COLOR_BORDER_SOFT
	base.border_width_left = 1
	base.border_width_top = 1
	base.border_width_right = 1
	base.border_width_bottom = 1
	base.corner_radius_top_left = 10
	base.corner_radius_top_right = 10
	base.corner_radius_bottom_right = 10
	base.corner_radius_bottom_left = 10

	var selected := base.duplicate()
	selected.bg_color = Color(0.15, 0.19, 0.27, 0.98)
	selected.border_color = Color(0.32, 0.58, 0.92, 0.48)

	item_list.add_theme_stylebox_override("panel", base)
	item_list.add_theme_stylebox_override("focus", selected)
	item_list.add_theme_color_override("font_color", COLOR_TEXT)
	item_list.add_theme_color_override("font_selected_color", COLOR_TEXT)
	item_list.add_theme_color_override("guide_color", Color(0.20, 0.24, 0.32, 1.0))
	item_list.add_theme_font_size_override("font_size", 13)


static func style_rich_text(rich_text: RichTextLabel) -> void:
	var base := StyleBoxFlat.new()
	base.bg_color = Color(0.06, 0.08, 0.11, 0.64)
	base.border_color = Color(0.18, 0.22, 0.28, 0.0)
	base.corner_radius_top_left = 8
	base.corner_radius_top_right = 8
	base.corner_radius_bottom_right = 8
	base.corner_radius_bottom_left = 8
	rich_text.add_theme_stylebox_override("normal", base)
	rich_text.add_theme_color_override("default_color", COLOR_TEXT)
	rich_text.add_theme_font_size_override("normal_font_size", 13)
	rich_text.scroll_active = true


static func style_progress_bar(progress_bar: ProgressBar, fill_color: Color) -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.14, 0.18, 0.25, 0.92)
	background.corner_radius_top_left = 999
	background.corner_radius_top_right = 999
	background.corner_radius_bottom_left = 999
	background.corner_radius_bottom_right = 999

	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.corner_radius_top_left = 999
	fill.corner_radius_top_right = 999
	fill.corner_radius_bottom_left = 999
	fill.corner_radius_bottom_right = 999

	progress_bar.add_theme_stylebox_override("background", background)
	progress_bar.add_theme_stylebox_override("fill", fill)
	progress_bar.add_theme_color_override("font_color", COLOR_TEXT)


static func style_label(label: Label, role: String = "body") -> void:
	label.add_theme_font_size_override("font_size", 14 if role != "tiny" else 11)
	match role:
		"title":
			label.add_theme_color_override("font_color", COLOR_GOLD)
		"heading":
			label.add_theme_color_override("font_color", COLOR_TEXT)
		"accent":
			label.add_theme_color_override("font_color", COLOR_BLUE)
		"muted":
			label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
		"tiny":
			label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
		"success":
			label.add_theme_color_override("font_color", COLOR_GREEN)
		"warning":
			label.add_theme_color_override("font_color", COLOR_GOLD)
		"danger":
			label.add_theme_color_override("font_color", COLOR_RED)
		_:
			label.add_theme_color_override("font_color", COLOR_TEXT)


static func _build_button_style(accent: Color, fill_alpha: float, border_alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r, accent.g, accent.b, fill_alpha)
	style.border_color = Color(accent.r, accent.g, accent.b, border_alpha)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style
