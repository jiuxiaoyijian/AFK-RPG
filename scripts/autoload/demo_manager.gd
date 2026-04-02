extends Node

const SETTINGS_PATH := "user://public_demo_settings.cfg"
const PUBLIC_DEMO_VERSION := "Public Demo 0.1.0"
const FEEDBACK_URL := "https://github.com/jiuxiaoyijian/AFK-RPG/issues"
const REPO_URL := "https://github.com/jiuxiaoyijian/AFK-RPG"
const MASTER_BUS_NAME := "Master"
const MUSIC_BUS_NAME := "Music"
const SFX_BUS_NAME := "SFX"
const MIN_DB := -40.0

var master_volume: float = 0.92
var music_volume: float = 0.70
var sfx_volume: float = 0.84
var has_seen_quick_start: bool = false


func _ready() -> void:
	_ensure_audio_bus(MUSIC_BUS_NAME)
	_ensure_audio_bus(SFX_BUS_NAME)
	_load_settings()
	_apply_audio_levels()


func is_debug_tools_enabled() -> bool:
	return OS.is_debug_build()


func get_version_text() -> String:
	return "%s | %s" % [PUBLIC_DEMO_VERSION, ProjectSettings.get_setting("application/config/name", "AFK-RPG")]


func get_feedback_url() -> String:
	return FEEDBACK_URL


func get_repo_url() -> String:
	return REPO_URL


func open_feedback_page() -> void:
	OS.shell_open(FEEDBACK_URL)


func open_repo_page() -> void:
	OS.shell_open(REPO_URL)


func get_volume(bus_id: String) -> float:
	match bus_id:
		"master":
			return master_volume
		"music":
			return music_volume
		"sfx":
			return sfx_volume
		_:
			return 1.0


func set_volume(bus_id: String, normalized: float) -> void:
	var clamped_value: float = clampf(normalized, 0.0, 1.0)
	match bus_id:
		"master":
			master_volume = clamped_value
			_set_bus_volume(MASTER_BUS_NAME, clamped_value)
		"music":
			music_volume = clamped_value
			_set_bus_volume(MUSIC_BUS_NAME, clamped_value)
		"sfx":
			sfx_volume = clamped_value
			_set_bus_volume(SFX_BUS_NAME, clamped_value)
		_:
			return
	_save_settings()


func mark_quick_start_seen() -> void:
	if has_seen_quick_start:
		return
	has_seen_quick_start = true
	_save_settings()


func should_show_quick_start() -> bool:
	return not has_seen_quick_start


func _ensure_audio_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	var target_index: int = AudioServer.bus_count
	AudioServer.add_bus(target_index)
	AudioServer.set_bus_name(target_index, bus_name)


func _set_bus_volume(bus_name: String, normalized: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		return
	var db_value: float = linear_to_db(maxf(normalized, 0.001))
	db_value = clampf(db_value, MIN_DB, 6.0)
	AudioServer.set_bus_volume_db(bus_index, db_value)
	AudioServer.set_bus_mute(bus_index, normalized <= 0.001)


func _apply_audio_levels() -> void:
	_set_bus_volume(MASTER_BUS_NAME, master_volume)
	_set_bus_volume(MUSIC_BUS_NAME, music_volume)
	_set_bus_volume(SFX_BUS_NAME, sfx_volume)


func _load_settings() -> void:
	var config := ConfigFile.new()
	var err: int = config.load(SETTINGS_PATH)
	if err != OK:
		return
	master_volume = float(config.get_value("audio", "master", master_volume))
	music_volume = float(config.get_value("audio", "music", music_volume))
	sfx_volume = float(config.get_value("audio", "sfx", sfx_volume))
	has_seen_quick_start = bool(config.get_value("ui", "has_seen_quick_start", has_seen_quick_start))


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("ui", "has_seen_quick_start", has_seen_quick_start)
	config.save(SETTINGS_PATH)
