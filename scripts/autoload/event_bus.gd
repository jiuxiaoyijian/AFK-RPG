@warning_ignore("unused_signal")
extends Node

signal battle_started(node_id: String)
signal battle_finished(node_id: String, success: bool)
signal enemy_killed(enemy_id: String)
signal node_changed(node_id: String)
signal player_hp_changed(current_hp: float, max_hp: float)
signal combat_state_changed(state_text: String)
signal resources_changed()
signal core_skill_changed(skill_id: String)
signal config_loaded()
signal equipment_changed()
signal loot_summary_changed(summary_text: String)
signal inventory_changed()
signal offline_report_ready(report_text: String)
signal research_changed()
signal codex_changed()
signal loot_target_changed()
signal ui_panel_requested(panel_id: String)
signal ui_close_requested()
signal ui_state_changed(active_panel_id: String, blocking_input: bool)

var ui_blocking_input: bool = false
