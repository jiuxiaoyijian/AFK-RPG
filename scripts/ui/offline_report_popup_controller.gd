extends Control

const RESULT_CARD_PATH := "res://assets/generated/ui/result_card_bg.png"
const RESULT_BOSS_PATH := "res://assets/generated/ui/result_boss_bg.png"

@onready var panel: Panel = $Panel
@onready var card_art: TextureRect = $Panel/CardArt
@onready var boss_banner: TextureRect = $Panel/BossBanner
@onready var title_label: Label = $Panel/TitleLabel
@onready var highlight_label: Label = $Panel/HighlightLabel
@onready var content_label: Label = $Panel/ContentLabel
@onready var close_button: Button = $Panel/CloseButton


func _ready() -> void:
	visible = false
	close_button.pressed.connect(_on_close_pressed)
	card_art.texture = _load_runtime_texture(RESULT_CARD_PATH)
	boss_banner.texture = _load_runtime_texture(RESULT_BOSS_PATH)
	card_art.modulate = Color(0.94, 0.95, 0.98, 1.0)


func show_report(report_text: String) -> void:
	var is_boss_style: bool = _should_use_boss_style(report_text)
	title_label.text = "Boss 高光结算" if is_boss_style else "离线收益报告"
	title_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.5, 1.0) if is_boss_style else Color(0.92, 0.95, 1.0, 1.0))
	highlight_label.text = _build_highlight_text(report_text)
	highlight_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.42, 1.0) if is_boss_style else Color(0.82, 0.9, 1.0, 1.0))
	boss_banner.visible = is_boss_style
	card_art.modulate = Color(1.0, 0.88, 0.62, 1.0) if is_boss_style else Color(0.94, 0.95, 0.98, 1.0)
	content_label.text = report_text
	visible = true


func _on_close_pressed() -> void:
	EventBus.ui_close_requested.emit()


func hide_popup() -> void:
	visible = false


func _build_highlight_text(report_text: String) -> String:
	var lines: PackedStringArray = report_text.split("\n", false)
	for line_variant in lines:
		var line: String = String(line_variant)
		if line.contains("传奇") or line.contains("碎片") or line.contains("核心 +") or line.contains("离线装备"):
			return "高光收益: %s" % line
	if lines.size() > 0:
		return "高光收益: %s" % String(lines[0])
	return "高光收益: 本次平稳结算"


func _should_use_boss_style(report_text: String) -> bool:
	if report_text.contains("传奇") or report_text.contains("碎片"):
		return true
	var node_id: String = GameManager.stable_node_id if not GameManager.stable_node_id.is_empty() else GameManager.current_node_id
	var node_data: Dictionary = ConfigDB.get_chapter_node(node_id)
	return String(node_data.get("node_type", "")) == "boss"


func _load_runtime_texture(resource_path: String) -> Texture2D:
	if resource_path.is_empty() or not FileAccess.file_exists(resource_path):
		return null

	var image: Image = Image.new()
	var err: Error = image.load(ProjectSettings.globalize_path(resource_path))
	if err != OK:
		return null

	return ImageTexture.create_from_image(image)
