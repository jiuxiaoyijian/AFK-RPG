extends Control

signal panel_closed

const UI_STYLE = preload("res://scripts/ui/ui_style.gd")

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/TitleLabel
@onready var version_label: Label = $Panel/VersionLabel
@onready var master_label: Label = $Panel/MasterValueLabel
@onready var music_label: Label = $Panel/MusicValueLabel
@onready var sfx_label: Label = $Panel/SfxValueLabel
@onready var slot_label: Label = $Panel/SlotLabel
@onready var hint_label: Label = $Panel/HintLabel
@onready var status_label: Label = $Panel/StatusLabel
@onready var guide_text: RichTextLabel = $Panel/GuideText
@onready var master_slider: HSlider = $Panel/MasterSlider
@onready var music_slider: HSlider = $Panel/MusicSlider
@onready var sfx_slider: HSlider = $Panel/SfxSlider
@onready var save_button: Button = $Panel/SaveButton
@onready var load_button: Button = $Panel/LoadButton
@onready var reset_button: Button = $Panel/ResetButton
@onready var feedback_button: Button = $Panel/FeedbackButton
@onready var repo_button: Button = $Panel/RepoButton
@onready var close_button: Button = $Panel/CloseButton
@onready var debug_button: Button = $Panel/DebugButton


func _ready() -> void:
	master_slider.value_changed.connect(_on_volume_changed.bind("master"))
	music_slider.value_changed.connect(_on_volume_changed.bind("music"))
	sfx_slider.value_changed.connect(_on_volume_changed.bind("sfx"))
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	feedback_button.pressed.connect(DemoManager.open_feedback_page)
	repo_button.pressed.connect(DemoManager.open_repo_page)
	close_button.pressed.connect(_on_close_pressed)
	debug_button.pressed.connect(_on_debug_pressed)
	_apply_style()
	_refresh()
	visible = false


func open_panel() -> void:
	_refresh()
	visible = true


func close_panel() -> void:
	visible = false
	panel_closed.emit()


func _refresh() -> void:
	title_label.text = "试玩版设置"
	version_label.text = DemoManager.get_version_text()
	hint_label.text = "当前档位 %d | F5 快速存档 | F8 快速读档" % SaveManager.get_active_save_slot()
	slot_label.text = "当前存档位：%d" % SaveManager.get_active_save_slot()
	guide_text.text = "[b]2 分钟上手[/b]\n1. 先看右上角任务目标。\n2. 背包看装备，成长中心看参悟。\n3. 推演与秘境会告诉你下一步刷哪里。"
	master_slider.value = DemoManager.get_volume("master")
	music_slider.value = DemoManager.get_volume("music")
	sfx_slider.value = DemoManager.get_volume("sfx")
	_update_volume_labels()
	debug_button.visible = DemoManager.is_debug_tools_enabled()
	debug_button.disabled = not DemoManager.is_debug_tools_enabled()
	status_label.text = "调整设置后会自动保存。"


func _on_volume_changed(_value: float, bus_id: String) -> void:
	var slider: HSlider = _get_slider(bus_id)
	DemoManager.set_volume(bus_id, slider.value)
	_update_volume_labels()
	status_label.text = "已保存音量设置。"


func _get_slider(bus_id: String) -> HSlider:
	match bus_id:
		"master":
			return master_slider
		"music":
			return music_slider
		"sfx":
			return sfx_slider
		_:
			return master_slider


func _update_volume_labels() -> void:
	master_label.text = "%d%%" % int(round(master_slider.value * 100.0))
	music_label.text = "%d%%" % int(round(music_slider.value * 100.0))
	sfx_label.text = "%d%%" % int(round(sfx_slider.value * 100.0))


func _on_save_pressed() -> void:
	var ok: bool = SaveManager.save_game(SaveManager.get_active_save_slot())
	status_label.text = "已保存到档位 %d。" % SaveManager.get_active_save_slot() if ok else "保存失败。"


func _on_load_pressed() -> void:
	var ok: bool = SaveManager.load_game(SaveManager.get_active_save_slot())
	status_label.text = "已读取档位 %d。" % SaveManager.get_active_save_slot() if ok else "读取失败。"


func _on_reset_pressed() -> void:
	var ok: bool = SaveManager.start_new_game(SaveManager.get_active_save_slot())
	status_label.text = "已重置并重建当前档位。" if ok else "重置失败。"


func _on_debug_pressed() -> void:
	if not DemoManager.is_debug_tools_enabled():
		return
	close_panel()
	EventBus.ui_panel_requested.emit("gm")


func _on_close_pressed() -> void:
	close_panel()


func _apply_style() -> void:
	UI_STYLE.style_panel(panel, "Panel")
	UI_STYLE.style_label(title_label, "title")
	UI_STYLE.style_label(version_label, "muted")
	UI_STYLE.style_label(slot_label, "accent")
	UI_STYLE.style_label(hint_label, "muted")
	UI_STYLE.style_label(status_label, "muted")
	for label_node in [master_label, music_label, sfx_label]:
		UI_STYLE.style_label(label_node, "body")
	for button_node in [save_button, load_button, feedback_button, repo_button, close_button]:
		UI_STYLE.style_button(button_node, UI_STYLE.COLOR_BLUE, false)
	UI_STYLE.style_button(reset_button, UI_STYLE.COLOR_RED, false)
	UI_STYLE.style_button(debug_button, UI_STYLE.COLOR_TEXT_DIM, false)
	UI_STYLE.style_rich_text(guide_text)
