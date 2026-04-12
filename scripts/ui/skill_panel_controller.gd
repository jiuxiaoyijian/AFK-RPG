extends Control

signal panel_closed

const UI_STYLE = preload("res://scripts/ui/ui_style.gd")

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/TitleLabel
@onready var summary_label: Label = $Panel/SummaryLabel
@onready var school_option: OptionButton = $Panel/SchoolOption
@onready var hero_status_label: Label = $Panel/HeroStatusLabel
@onready var current_slot_label: Label = $Panel/CurrentSlotLabel
@onready var basic_slot_button: Button = $Panel/BasicSlotButton
@onready var core_slot_button: Button = $Panel/CoreSlotButton
@onready var tactic_slot_button: Button = $Panel/TacticSlotButton
@onready var burst_slot_button: Button = $Panel/BurstSlotButton
@onready var skill_list: ItemList = $Panel/SkillList
@onready var rune_list: ItemList = $Panel/RuneList
@onready var passive_list: ItemList = $Panel/PassiveList
@onready var passive_slot_1_button: Button = $Panel/PassiveSlot1Button
@onready var passive_slot_2_button: Button = $Panel/PassiveSlot2Button
@onready var passive_slot_3_button: Button = $Panel/PassiveSlot3Button
@onready var detail_text: RichTextLabel = $Panel/DetailText
@onready var equip_skill_button: Button = $Panel/EquipSkillButton
@onready var equip_rune_button: Button = $Panel/EquipRuneButton
@onready var equip_passive_button: Button = $Panel/EquipPassiveButton
@onready var close_button: Button = $Panel/CloseButton
@onready var status_label: Label = $Panel/StatusLabel

var selected_school_id: String = ""
var selected_slot_type: String = "core"
var selected_skill_id: String = ""
var selected_rune_id: String = ""
var selected_passive_id: String = ""
var selected_passive_slot: int = 0
var selected_detail_type: String = "skill"


func _ready() -> void:
	visible = false
	school_option.item_selected.connect(_on_school_selected)
	skill_list.item_selected.connect(_on_skill_selected)
	rune_list.item_selected.connect(_on_rune_selected)
	passive_list.item_selected.connect(_on_passive_selected)
	basic_slot_button.pressed.connect(_on_slot_pressed.bind("basic"))
	core_slot_button.pressed.connect(_on_slot_pressed.bind("core"))
	tactic_slot_button.pressed.connect(_on_slot_pressed.bind("tactic"))
	burst_slot_button.pressed.connect(_on_slot_pressed.bind("burst"))
	passive_slot_1_button.pressed.connect(_on_passive_slot_pressed.bind(0))
	passive_slot_2_button.pressed.connect(_on_passive_slot_pressed.bind(1))
	passive_slot_3_button.pressed.connect(_on_passive_slot_pressed.bind(2))
	equip_skill_button.pressed.connect(_on_equip_skill_pressed)
	equip_rune_button.pressed.connect(_on_equip_rune_pressed)
	equip_passive_button.pressed.connect(_on_equip_passive_pressed)
	close_button.pressed.connect(close_panel)
	EventBus.skill_loadout_changed.connect(_refresh)
	EventBus.hero_level_changed.connect(_refresh)
	EventBus.hero_experience_changed.connect(_refresh)
	_apply_style()
	_refresh()


func open_panel() -> void:
	visible = true
	_refresh()


func close_panel() -> void:
	visible = false
	panel_closed.emit()


func _refresh(_payload: Variant = null) -> void:
	var state: Dictionary = GameManager.get_skill_screen_state()
	if selected_school_id.is_empty():
		selected_school_id = String(state.get("selected_school_id", "yufeng"))
	title_label.text = "技能"
	var hero_summary: Dictionary = state.get("hero_summary", {})
	summary_label.text = "Lv.%d | %s | 宗师修为 %s" % [
		int(hero_summary.get("level", 1)),
		String(hero_summary.get("status_text", "初入江湖")),
		"已开启" if bool(hero_summary.get("paragon_unlocked", false)) else "未开启",
	]
	hero_status_label.text = "经验 %d / %d | 技能位 %d | 被动位 %d | 符文层 %d" % [
		int(round(float(hero_summary.get("experience", 0.0)))),
		int(hero_summary.get("experience_to_next", 0)),
		int(hero_summary.get("unlocked_skill_slots", 2)),
		int(hero_summary.get("unlocked_passive_slots", 0)),
		int(hero_summary.get("unlocked_rune_tiers", 0)),
	]
	current_slot_label.text = "当前技能位: %s" % _get_slot_display_name(selected_slot_type)
	_populate_school_option(state.get("schools", []))
	_refresh_slot_buttons(state.get("slot_entries", []))
	_refresh_skill_list(state.get("active_skills", []))
	_refresh_rune_list(state.get("active_skills", []))
	_refresh_passive_list(state.get("passive_skills", []), state.get("selected_passives", []))
	_refresh_detail_text(state)
	_refresh_action_buttons(state)


func _populate_school_option(schools: Array) -> void:
	var previous_school_id: String = selected_school_id
	school_option.clear()
	var selected_index: int = 0
	for school_index in range(schools.size()):
		var school_entry: Dictionary = schools[school_index]
		var school_id: String = String(school_entry.get("id", ""))
		school_option.add_item(String(school_entry.get("name", school_id)))
		school_option.set_item_metadata(school_index, school_id)
		if school_id == previous_school_id:
			selected_index = school_index
	if school_option.item_count > 0:
		school_option.select(selected_index)
		selected_school_id = String(school_option.get_item_metadata(selected_index))


func _refresh_slot_buttons(slot_entries: Array) -> void:
	var buttons: Array[Button] = [
		basic_slot_button,
		core_slot_button,
		tactic_slot_button,
		burst_slot_button,
	]
	for index in range(mini(slot_entries.size(), buttons.size())):
		var entry: Dictionary = slot_entries[index]
		var button: Button = buttons[index]
		var is_unlocked: bool = bool(entry.get("is_unlocked", false))
		button.disabled = not is_unlocked
		button.text = "%s\n%s" % [
			String(entry.get("slot_label", "")),
			String(entry.get("skill_name", "未解锁")) if is_unlocked else "未解锁",
		]
		var is_selected: bool = String(entry.get("slot_type", "")) == selected_slot_type
		_style_slot_button(button, is_selected)


func _refresh_skill_list(active_skills: Array) -> void:
	var previous_skill_id: String = selected_skill_id
	selected_skill_id = ""
	skill_list.clear()
	for skill_entry_variant in active_skills:
		var skill_entry: Dictionary = skill_entry_variant
		if String(skill_entry.get("school_id", selected_school_id)) != selected_school_id:
			continue
		if String(skill_entry.get("slot_type", "")) != selected_slot_type:
			continue
		var prefix: String = "[已装]" if bool(skill_entry.get("is_equipped", false)) else ("[可用]" if bool(skill_entry.get("is_unlocked", false)) else "[未解锁]")
		var line: String = "%s %s Lv.%d" % [
			prefix,
			String(skill_entry.get("name", "")),
			int(skill_entry.get("unlock_level", 1)),
		]
		skill_list.add_item(line)
		skill_list.set_item_metadata(skill_list.item_count - 1, String(skill_entry.get("id", "")))
		if String(skill_entry.get("id", "")) == previous_skill_id:
			selected_skill_id = previous_skill_id
			skill_list.select(skill_list.item_count - 1)

	if selected_skill_id.is_empty() and skill_list.item_count > 0:
		skill_list.select(0)
		selected_skill_id = String(skill_list.get_item_metadata(0))


func _refresh_rune_list(active_skills: Array) -> void:
	var selected_skill: Dictionary = _find_active_skill_entry(active_skills, selected_skill_id)
	if selected_skill.is_empty():
		selected_skill = _find_equipped_skill_for_slot(active_skills, selected_slot_type)
		selected_skill_id = String(selected_skill.get("id", selected_skill_id))

	var previous_rune_id: String = selected_rune_id
	selected_rune_id = ""
	rune_list.clear()
	for rune_entry_variant in selected_skill.get("runes", []):
		var rune_entry: Dictionary = rune_entry_variant
		var prefix: String = "[已装]" if bool(rune_entry.get("is_selected", false)) else ("[可用]" if bool(rune_entry.get("is_unlocked", false)) else "[未解锁]")
		var line: String = "%s %s" % [prefix, String(rune_entry.get("name", ""))]
		rune_list.add_item(line)
		rune_list.set_item_metadata(rune_list.item_count - 1, String(rune_entry.get("id", "")))
		if String(rune_entry.get("id", "")) == previous_rune_id or bool(rune_entry.get("is_selected", false)):
			selected_rune_id = String(rune_entry.get("id", ""))
			rune_list.select(rune_list.item_count - 1)

	if selected_rune_id.is_empty() and rune_list.item_count > 0:
		selected_rune_id = String(rune_list.get_item_metadata(0))
		rune_list.select(0)


func _refresh_passive_list(passive_skills: Array, selected_passives: Array) -> void:
	var previous_passive_id: String = selected_passive_id
	selected_passive_id = ""
	passive_list.clear()
	for passive_entry_variant in passive_skills:
		var passive_entry: Dictionary = passive_entry_variant
		if String(passive_entry.get("school_id", selected_school_id)) != selected_school_id:
			continue
		var prefix: String = "[已装]" if bool(passive_entry.get("is_equipped", false)) else ("[可用]" if bool(passive_entry.get("is_unlocked", false)) else "[未解锁]")
		var line: String = "%s %s Lv.%d" % [
			prefix,
			String(passive_entry.get("name", "")),
			int(passive_entry.get("unlock_level", 1)),
		]
		passive_list.add_item(line)
		passive_list.set_item_metadata(passive_list.item_count - 1, String(passive_entry.get("id", "")))
		if String(passive_entry.get("id", "")) == previous_passive_id:
			selected_passive_id = previous_passive_id
			passive_list.select(passive_list.item_count - 1)
	if selected_passive_id.is_empty() and passive_list.item_count > 0:
		selected_passive_id = String(passive_list.get_item_metadata(0))
		passive_list.select(0)

	var passive_buttons: Array[Button] = [passive_slot_1_button, passive_slot_2_button, passive_slot_3_button]
	for passive_index in range(passive_buttons.size()):
		var passive_button: Button = passive_buttons[passive_index]
		var passive_id: String = ""
		if passive_index < selected_passives.size():
			passive_id = String(selected_passives[passive_index])
		var passive_data: Dictionary = ConfigDB.get_passive_skill(passive_id)
		passive_button.text = "被动位 %d\n%s" % [
			passive_index + 1,
			String(passive_data.get("name", "未装配")) if not passive_id.is_empty() else "未装配",
		]
		_style_slot_button(passive_button, passive_index == selected_passive_slot)


func _refresh_detail_text(state: Dictionary) -> void:
	var detail_lines: Array[String] = []
	var selected_skill: Dictionary = _find_active_skill_entry(state.get("active_skills", []), selected_skill_id)
	if selected_detail_type == "passive" and not selected_passive_id.is_empty():
		var passive_data: Dictionary = ConfigDB.get_passive_skill(selected_passive_id)
		detail_lines.append("[b]%s[/b]" % String(passive_data.get("name", "")))
		detail_lines.append("解锁 Lv.%d" % int(passive_data.get("unlock_level", 1)))
		detail_lines.append(String(passive_data.get("description", "")))
	elif not selected_skill.is_empty():
		detail_lines.append("[b]%s[/b]" % String(selected_skill.get("name", "")))
		detail_lines.append("定位: %s | 解锁 Lv.%d" % [
			_get_slot_display_name(String(selected_skill.get("slot_type", ""))),
			int(selected_skill.get("unlock_level", 1)),
		])
		detail_lines.append(String(selected_skill.get("description", "")))
		detail_lines.append("")
		detail_lines.append("[b]符文[/b]")
		for rune_entry_variant in selected_skill.get("runes", []):
			var rune_entry: Dictionary = rune_entry_variant
			var rune_prefix: String = "• "
			if bool(rune_entry.get("is_selected", false)):
				rune_prefix = "• [已装] "
			elif not bool(rune_entry.get("is_unlocked", false)):
				rune_prefix = "• [未解锁] "
			detail_lines.append("%s%s: %s" % [
				rune_prefix,
				String(rune_entry.get("name", "")),
				String(rune_entry.get("description", "")),
			])
	else:
		detail_lines.append("选择一项技能、符文或被动后可查看详情。")
	detail_text.text = "\n".join(detail_lines)


func _refresh_action_buttons(state: Dictionary) -> void:
	var selected_skill: Dictionary = _find_active_skill_entry(state.get("active_skills", []), selected_skill_id)
	var selected_rune_unlocked: bool = false
	if not selected_skill.is_empty():
		for rune_entry_variant in selected_skill.get("runes", []):
			var rune_entry: Dictionary = rune_entry_variant
			if String(rune_entry.get("id", "")) == selected_rune_id:
				selected_rune_unlocked = bool(rune_entry.get("is_unlocked", false))
				break

	var selected_passive_data: Dictionary = ConfigDB.get_passive_skill(selected_passive_id)
	var hero_summary: Dictionary = state.get("hero_summary", {})
	equip_skill_button.disabled = selected_skill.is_empty() or not bool(selected_skill.get("is_unlocked", false))
	equip_rune_button.disabled = selected_skill.is_empty() or selected_rune_id.is_empty() or not selected_rune_unlocked
	equip_passive_button.disabled = selected_passive_id.is_empty() or int(selected_passive_data.get("unlock_level", 999)) > int(hero_summary.get("level", 1))
	equip_skill_button.text = "装配到%s" % _get_slot_display_name(selected_slot_type)
	equip_rune_button.text = "装配符文"
	equip_passive_button.text = "装配到被动位 %d" % (selected_passive_slot + 1)
	UI_STYLE.style_button(equip_skill_button, UI_STYLE.COLOR_BLUE, equip_skill_button.disabled)
	UI_STYLE.style_button(equip_rune_button, UI_STYLE.COLOR_GOLD, equip_rune_button.disabled)
	UI_STYLE.style_button(equip_passive_button, UI_STYLE.COLOR_GREEN, equip_passive_button.disabled)
	UI_STYLE.style_button(close_button, UI_STYLE.COLOR_TEXT_DIM, false)


func _on_school_selected(index: int) -> void:
	selected_school_id = String(school_option.get_item_metadata(index))
	selected_skill_id = ""
	selected_rune_id = ""
	selected_passive_id = ""
	selected_detail_type = "skill"
	_refresh()


func _on_slot_pressed(slot_type: String) -> void:
	selected_slot_type = slot_type
	selected_skill_id = ""
	selected_rune_id = ""
	selected_detail_type = "skill"
	_refresh()


func _on_passive_slot_pressed(slot_index: int) -> void:
	selected_passive_slot = slot_index
	_refresh()


func _on_skill_selected(index: int) -> void:
	selected_skill_id = String(skill_list.get_item_metadata(index))
	selected_rune_id = ""
	selected_detail_type = "skill"
	_refresh()


func _on_rune_selected(index: int) -> void:
	selected_rune_id = String(rune_list.get_item_metadata(index))
	selected_detail_type = "skill"
	_refresh_action_buttons(GameManager.get_skill_screen_state())


func _on_passive_selected(index: int) -> void:
	selected_passive_id = String(passive_list.get_item_metadata(index))
	selected_detail_type = "passive"
	_refresh()


func _on_equip_skill_pressed() -> void:
	var result: Dictionary = GameManager.equip_active_skill(selected_slot_type, selected_skill_id)
	status_label.text = "已装配 %s。" % selected_skill_id if bool(result.get("ok", false)) else String(result.get("reason", "装配失败"))
	_refresh()


func _on_equip_rune_pressed() -> void:
	var result: Dictionary = GameManager.equip_skill_rune(selected_skill_id, selected_rune_id)
	status_label.text = "已装配符文。" if bool(result.get("ok", false)) else String(result.get("reason", "符文装配失败"))
	_refresh()


func _on_equip_passive_pressed() -> void:
	var result: Dictionary = GameManager.equip_passive(selected_passive_slot, selected_passive_id)
	status_label.text = "已装配被动。" if bool(result.get("ok", false)) else String(result.get("reason", "被动装配失败"))
	_refresh()


func _find_active_skill_entry(active_skills: Array, skill_id: String) -> Dictionary:
	for skill_entry_variant in active_skills:
		var skill_entry: Dictionary = skill_entry_variant
		if String(skill_entry.get("id", "")) == skill_id:
			return skill_entry
	return {}


func _find_equipped_skill_for_slot(active_skills: Array, slot_type: String) -> Dictionary:
	for skill_entry_variant in active_skills:
		var skill_entry: Dictionary = skill_entry_variant
		if String(skill_entry.get("slot_type", "")) == slot_type and bool(skill_entry.get("is_equipped", false)):
			return skill_entry
	return {}


func _get_slot_display_name(slot_type: String) -> String:
	match slot_type:
		"basic":
			return "基础"
		"core":
			return "核心"
		"tactic":
			return "战术"
		"burst":
			return "爆发"
		_:
			return slot_type


func _style_slot_button(button: Button, is_selected: bool) -> void:
	UI_STYLE.style_button(
		button,
		UI_STYLE.COLOR_BLUE if is_selected else UI_STYLE.COLOR_TEXT_DIM,
		button.disabled
	)


func _apply_style() -> void:
	UI_STYLE.style_panel(panel, "Panel")
	UI_STYLE.style_label(title_label, "title")
	UI_STYLE.style_label(summary_label, "accent")
	UI_STYLE.style_label(hero_status_label, "body")
	UI_STYLE.style_label(current_slot_label, "muted")
	UI_STYLE.style_label(status_label, "muted")
	UI_STYLE.style_option_button(school_option, UI_STYLE.COLOR_BLUE)
	UI_STYLE.style_item_list(skill_list)
	UI_STYLE.style_item_list(rune_list)
	UI_STYLE.style_item_list(passive_list)
	UI_STYLE.style_rich_text(detail_text)
	for button in [
		basic_slot_button,
		core_slot_button,
		tactic_slot_button,
		burst_slot_button,
		passive_slot_1_button,
		passive_slot_2_button,
		passive_slot_3_button,
	]:
		_style_slot_button(button, false)
