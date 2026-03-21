extends Control

const RESULT_CARD_PATH := "res://assets/generated/ui/result_card_bg.png"
const RESULT_BOSS_PATH := "res://assets/generated/ui/result_boss_bg.png"

@onready var panel: Panel = $Panel
@onready var card_art: TextureRect = $Panel/CardArt
@onready var boss_banner: TextureRect = $Panel/BossBanner
@onready var title_label: Label = $Panel/TitleLabel
@onready var highlight_label: Label = $Panel/HighlightLabel
@onready var content_title_label: Label = $Panel/EarningsTitleLabel
@onready var content_label: RichTextLabel = $Panel/ContentLabel
@onready var goal_title_label: Label = $Panel/GoalTitleLabel
@onready var goal_label: RichTextLabel = $Panel/GoalLabel
@onready var close_button: Button = $Panel/CloseButton

var popup_mode: String = "offline_report"


func _ready() -> void:
	visible = false
	close_button.pressed.connect(_on_close_pressed)
	card_art.texture = _load_runtime_texture(RESULT_CARD_PATH)
	boss_banner.texture = _load_runtime_texture(RESULT_BOSS_PATH)
	card_art.modulate = Color(0.94, 0.95, 0.98, 1.0)


func show_report(report_text: String) -> void:
	var is_boss_style: bool = _should_use_boss_style(report_text)
	_show_popup(
		"首领高光结算" if is_boss_style else "闭关所得",
		_build_highlight_text(report_text),
		report_text,
		_build_goal_section_text(),
		is_boss_style,
		"本次闭关所得",
		"回来先做什么",
		"关闭",
		"offline_report"
	)


func show_stage_event(event_data: Dictionary) -> void:
	var content_lines: Array = event_data.get("content_lines", [])
	var goal_lines: Array = event_data.get("goal_lines", [])
	_show_popup(
		String(event_data.get("title", "破局要闻")),
		String(event_data.get("highlight", "关键阶段已达成")),
		_join_lines(content_lines),
		_join_lines(goal_lines),
		bool(event_data.get("boss_style", false)),
		"事件内容",
		"接下来",
		"继续",
		"stage_event"
	)


func _on_close_pressed() -> void:
	EventBus.ui_close_requested.emit()


func hide_popup() -> void:
	visible = false
	popup_mode = "offline_report"


func _build_highlight_text(report_text: String) -> String:
	var lines: PackedStringArray = report_text.split("\n", false)
	for line_variant in lines:
		var line: String = String(line_variant)
		if line.contains("传奇") or line.contains("异宝") or line.contains("真意残片") or line.contains("灵核 +") or line.contains("闭关装备"):
			return "高光收益: %s" % line
	if lines.size() > 0:
		return "高光收益: %s" % String(lines[0])
	return "高光收益: 本次平稳结算"


func _should_use_boss_style(report_text: String) -> bool:
	if report_text.contains("传奇") or report_text.contains("异宝") or report_text.contains("真意残片"):
		return true
	var node_id: String = GameManager.stable_node_id if not GameManager.stable_node_id.is_empty() else GameManager.current_node_id
	var node_data: Dictionary = ConfigDB.get_chapter_node(node_id)
	return String(node_data.get("node_type", "")) == "boss"


func _build_goal_section_text() -> String:
	var build_advice: Dictionary = GameManager.get_build_advice_data()
	var lines: Array[String] = []
	lines.append(String(DailyGoalSystem.get_next_step_summary()))
	lines.append(String(DailyGoalSystem.get_primary_goal_summary()))
	lines.append("最接近完成: %s" % String(DailyGoalSystem.get_nearest_side_goal_summary()))
	lines.append("道统缺口: %s" % String(build_advice.get("gap_summary", "继续补当前道统核心属性")))
	lines.append("下一件: %s" % String(build_advice.get("next_target_line", "下一件: 继续刷当前核心件")))
	return "\n".join(lines)


func _show_popup(
	popup_title: String,
	highlight_text: String,
	content_text: String,
	goal_text: String,
	use_boss_style: bool,
	content_title: String,
	goal_title: String,
	close_text: String,
	mode: String
) -> void:
	popup_mode = mode
	title_label.text = popup_title
	title_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.5, 1.0) if use_boss_style else Color(0.92, 0.95, 1.0, 1.0))
	highlight_label.text = highlight_text
	highlight_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.42, 1.0) if use_boss_style else Color(0.82, 0.9, 1.0, 1.0))
	content_title_label.text = content_title
	goal_title_label.text = goal_title
	close_button.text = close_text
	boss_banner.visible = use_boss_style
	card_art.modulate = Color(1.0, 0.88, 0.62, 1.0) if use_boss_style else Color(0.94, 0.95, 0.98, 1.0)
	content_label.text = content_text
	content_label.scroll_to_line(0)
	goal_label.text = goal_text
	goal_label.scroll_to_line(0)
	visible = true


func _join_lines(lines: Array) -> String:
	var text_lines: Array[String] = []
	for line_variant in lines:
		var line: String = String(line_variant).strip_edges()
		if line.is_empty():
			continue
		text_lines.append(line)
	return "\n".join(text_lines)


func _load_runtime_texture(resource_path: String) -> Texture2D:
	return RuntimeTextureLoader.load_texture(resource_path)
