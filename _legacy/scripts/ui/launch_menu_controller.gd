extends Control

const UI_STYLE = preload("res://scripts/ui/ui_style.gd")

@onready var dimmer: ColorRect = $Dimmer
@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/TitleLabel
@onready var subtitle_label: Label = $Panel/SubtitleLabel
@onready var slot_option: OptionButton = $Panel/SlotOption
@onready var slot_summary_label: Label = $Panel/SlotSummaryLabel
@onready var slot_meta_label: Label = $Panel/SlotMetaLabel
@onready var status_label: Label = $Panel/StatusLabel
@onready var guide_text: RichTextLabel = $Panel/GuideText
@onready var known_issues_text: RichTextLabel = $Panel/KnownIssuesText
@onready var continue_button: Button = $Panel/ContinueButton
@onready var new_game_button: Button = $Panel/NewGameButton
@onready var reset_button: Button = $Panel/ResetButton
@onready var settings_button: Button = $Panel/SettingsButton
@onready var feedback_button: Button = $Panel/FeedbackButton
@onready var settings_panel: Control = $SettingsPanel

var selected_slot: int = SaveManager.DEFAULT_SAVE_SLOT


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_set_descendants_process_mode(self, Node.PROCESS_MODE_WHEN_PAUSED)
	slot_option.item_selected.connect(_on_slot_selected)
	continue_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(_on_new_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	feedback_button.pressed.connect(DemoManager.open_feedback_page)
	if settings_panel.has_signal("panel_closed"):
		settings_panel.panel_closed.connect(_refresh)
	_apply_style()
	_populate_slots()
	_show_menu()


func _show_menu() -> void:
	get_tree().paused = true
	visible = true
	_refresh()


func _refresh() -> void:
	selected_slot = clampi(selected_slot, 1, SaveManager.get_save_slot_count())
	SaveManager.set_active_save_slot(selected_slot)
	var summary: Dictionary = SaveManager.get_save_slot_summary(selected_slot)
	title_label.text = "AFK-RPG 公开试玩版"
	subtitle_label.text = DemoManager.get_version_text()
	slot_summary_label.text = String(summary.get("title", "空档位"))
	var saved_unix_time: int = int(summary.get("saved_unix_time", 0))
	var time_text: String = "尚未创建存档"
	if saved_unix_time > 0:
		time_text = "最近保存：%s" % Time.get_datetime_string_from_unix_time(saved_unix_time, true)
	slot_meta_label.text = "%s\n%s" % [String(summary.get("subtitle", "")), time_text]
	continue_button.disabled = not bool(summary.get("has_save", false))
	reset_button.disabled = not bool(summary.get("has_save", false))
	status_label.text = "选择一个档位开始试玩。"
	guide_text.text = "[b]2 分钟上手[/b]\n1. 自动战斗会自己推进，但请先看右上角任务目标。\n2. [b]K[/b] 打开技能，确认四技能位、符文和被动已经装配。\n3. [b]I[/b] 打开背包，优先更换高品质装备；[b]U[/b] 查看参悟与宗师修为。\n4. [b]F5[/b] 快速存档，[b]F8[/b] 快速读档。"
	known_issues_text.text = "[b]试玩说明[/b]\n- 当前为公开试玩版，重点验证核心循环。\n- 建议使用桌面 Chrome 浏览器体验。\n- 若看到异常表现，请通过“反馈”按钮提交问题。"
	_style_action_buttons()


func _populate_slots() -> void:
	slot_option.clear()
	for slot in range(1, SaveManager.get_save_slot_count() + 1):
		slot_option.add_item("档位 %d" % slot)
		slot_option.set_item_metadata(slot_option.item_count - 1, slot)
	slot_option.select(selected_slot - 1)


func _on_slot_selected(index: int) -> void:
	selected_slot = int(slot_option.get_item_metadata(index))
	_refresh()


func _on_continue_pressed() -> void:
	if not SaveManager.load_game(selected_slot):
		status_label.text = "当前档位没有可读取的存档。"
		return
	DemoManager.mark_quick_start_seen()
	_enter_game("继续试玩")


func _on_new_pressed() -> void:
	if not SaveManager.start_new_game(selected_slot):
		status_label.text = "新建进度失败。"
		return
	DemoManager.mark_quick_start_seen()
	_enter_game("开始试玩")


func _on_reset_pressed() -> void:
	if not SaveManager.delete_save_slot(selected_slot):
		status_label.text = "删除档位失败。"
		return
	_refresh()
	status_label.text = "已清空档位 %d。" % selected_slot


func _on_settings_pressed() -> void:
	if settings_panel.has_method("open_panel"):
		settings_panel.open_panel()


func _enter_game(state_text: String) -> void:
	get_tree().paused = false
	if settings_panel.has_method("close_panel"):
		settings_panel.close_panel()
	visible = false
	EventBus.combat_state_changed.emit(state_text)


func _apply_style() -> void:
	dimmer.color = Color(0.02, 0.03, 0.05, 0.82)
	UI_STYLE.style_panel(panel, "Panel")
	UI_STYLE.style_label(title_label, "title")
	UI_STYLE.style_label(subtitle_label, "muted")
	UI_STYLE.style_label(slot_summary_label, "accent")
	UI_STYLE.style_label(slot_meta_label, "body")
	UI_STYLE.style_label(status_label, "muted")
	UI_STYLE.style_button(continue_button, UI_STYLE.COLOR_GREEN, continue_button.disabled)
	UI_STYLE.style_button(new_game_button, UI_STYLE.COLOR_GOLD, false)
	UI_STYLE.style_button(reset_button, UI_STYLE.COLOR_RED, reset_button.disabled)
	UI_STYLE.style_button(settings_button, UI_STYLE.COLOR_BLUE, false)
	UI_STYLE.style_button(feedback_button, UI_STYLE.COLOR_BLUE, false)
	UI_STYLE.style_option_button(slot_option, UI_STYLE.COLOR_BLUE)
	UI_STYLE.style_rich_text(guide_text)
	UI_STYLE.style_rich_text(known_issues_text)


func _style_action_buttons() -> void:
	UI_STYLE.style_button(continue_button, UI_STYLE.COLOR_GREEN, continue_button.disabled)
	UI_STYLE.style_button(new_game_button, UI_STYLE.COLOR_GOLD, false)
	UI_STYLE.style_button(reset_button, UI_STYLE.COLOR_RED, reset_button.disabled)
	UI_STYLE.style_button(settings_button, UI_STYLE.COLOR_BLUE, false)
	UI_STYLE.style_button(feedback_button, UI_STYLE.COLOR_BLUE, false)


func _set_descendants_process_mode(node: Node, mode: Node.ProcessMode) -> void:
	node.process_mode = mode
	for child in node.get_children():
		_set_descendants_process_mode(child, mode)
