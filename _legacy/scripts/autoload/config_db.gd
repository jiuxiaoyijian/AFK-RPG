extends Node

const CORE_SKILLS_PATH := "res://data/skills/core_skills.json"
const ACTIVE_SKILLS_PATH := "res://data/skills/active_skills.json"
const PASSIVE_SKILLS_PATH := "res://data/skills/passive_skills.json"
const ENEMIES_PATH := "res://data/enemies/enemy_defs.json"
const CHAPTERS_PATH := "res://data/chapters/chapter_defs.json"
const EQUIPMENT_BASES_PATH := "res://data/equipment/equipment_bases.json"
const AFFIXES_PATH := "res://data/equipment/affixes.json"
const LEGENDARY_AFFIXES_PATH := "res://data/equipment/legendary_affixes.json"
const SET_DEFS_PATH := "res://data/sets/set_defs.json"
const CUBE_RECIPES_PATH := "res://data/equipment/cube_recipes.json"
const GEMS_PATH := "res://data/equipment/gems.json"
const DROP_TABLES_PATH := "res://data/drops/drop_tables.json"
const RIFT_SCALING_PATH := "res://data/rift/rift_scaling.json"
const RIFT_KEYS_PATH := "res://data/rift/rift_keys.json"
const RESEARCH_TREE_PATH := "res://data/progression/research_tree.json"
const HERO_LEVELS_PATH := "res://data/progression/hero_levels.json"
const PARALLAX_SCENE_DEFS_PATH := "res://data/backgrounds/parallax_scene_defs.json"

var core_skills: Dictionary = {}
var active_skills: Dictionary = {}
var passive_skills: Dictionary = {}
var active_skills_by_school: Dictionary = {}
var passive_skills_by_school: Dictionary = {}
var hero_levels: Dictionary = {}
var enemies: Dictionary = {}
var chapters: Dictionary = {}
var chapter_nodes: Dictionary = {}
var enemy_pools: Dictionary = {}
var equipment_bases: Dictionary = {}
var affixes: Dictionary = {}
var legendary_affixes: Dictionary = {}
var set_defs: Dictionary = {}
var cube_recipes: Dictionary = {}
var gems: Dictionary = {}
var drop_profiles: Dictionary = {}
var rift_scaling_entries: Array = []
var rift_key_entries: Array = []
var research_nodes: Dictionary = {}
var parallax_scene_defs: Dictionary = {}
var parallax_scene_chapter_defaults: Dictionary = {}
var parallax_scene_node_overrides: Dictionary = {}


func _ready() -> void:
	load_all()


func load_all() -> void:
	core_skills.clear()
	active_skills.clear()
	passive_skills.clear()
	active_skills_by_school.clear()
	passive_skills_by_school.clear()
	hero_levels.clear()
	enemies.clear()
	chapters.clear()
	chapter_nodes.clear()
	enemy_pools.clear()
	equipment_bases.clear()
	affixes.clear()
	legendary_affixes.clear()
	set_defs.clear()
	cube_recipes.clear()
	gems.clear()
	drop_profiles.clear()
	rift_scaling_entries.clear()
	rift_key_entries.clear()
	research_nodes.clear()
	parallax_scene_defs.clear()
	parallax_scene_chapter_defaults.clear()
	parallax_scene_node_overrides.clear()

	for entry: Dictionary in _read_json_array(CORE_SKILLS_PATH):
		core_skills[entry["id"]] = entry

	for entry: Dictionary in _read_json_array(ACTIVE_SKILLS_PATH):
		active_skills[entry["id"]] = entry
		var school_id: String = String(entry.get("school_id", ""))
		if not active_skills_by_school.has(school_id):
			active_skills_by_school[school_id] = []
		active_skills_by_school[school_id].append(entry)

	for entry: Dictionary in _read_json_array(PASSIVE_SKILLS_PATH):
		passive_skills[entry["id"]] = entry
		var passive_school_id: String = String(entry.get("school_id", ""))
		if not passive_skills_by_school.has(passive_school_id):
			passive_skills_by_school[passive_school_id] = []
		passive_skills_by_school[passive_school_id].append(entry)

	for entry: Dictionary in _read_json_array(ENEMIES_PATH):
		enemies[entry["id"]] = entry

	for entry: Dictionary in _read_json_array(EQUIPMENT_BASES_PATH):
		equipment_bases[entry["id"]] = entry

	for entry: Dictionary in _read_json_array(AFFIXES_PATH):
		affixes[entry["id"]] = entry

	for entry: Dictionary in _read_json_array(LEGENDARY_AFFIXES_PATH):
		legendary_affixes[entry["id"]] = entry

	var set_payload: Dictionary = _read_json_dict(SET_DEFS_PATH)
	for entry: Dictionary in set_payload.get("set_defs", []):
		set_defs[entry["id"]] = entry

	var cube_payload: Dictionary = _read_json_dict(CUBE_RECIPES_PATH)
	for entry: Dictionary in cube_payload.get("cube_recipes", []):
		cube_recipes[entry["id"]] = entry

	var gem_payload: Dictionary = _read_json_dict(GEMS_PATH)
	for entry: Dictionary in gem_payload.get("gems", []):
		gems[entry["id"]] = entry

	var chapter_payload: Dictionary = _read_json_dict(CHAPTERS_PATH)
	for entry: Dictionary in chapter_payload.get("chapters", []):
		chapters[entry["id"]] = entry
	for entry: Dictionary in chapter_payload.get("chapter_nodes", []):
		chapter_nodes[entry["id"]] = entry
	for entry: Dictionary in chapter_payload.get("enemy_pools", []):
		enemy_pools[entry["id"]] = entry

	var drop_payload: Dictionary = _read_json_dict(DROP_TABLES_PATH)
	for entry: Dictionary in drop_payload.get("drop_profiles", []):
		drop_profiles[entry["id"]] = entry

	var rift_scaling_payload: Dictionary = _read_json_dict(RIFT_SCALING_PATH)
	rift_scaling_entries = rift_scaling_payload.get("rift_scaling", [])

	var rift_keys_payload: Dictionary = _read_json_dict(RIFT_KEYS_PATH)
	rift_key_entries = rift_keys_payload.get("rift_keys", [])

	var research_payload: Dictionary = _read_json_dict(RESEARCH_TREE_PATH)
	for entry: Dictionary in research_payload.get("research_nodes", []):
		research_nodes[entry["id"]] = entry

	var hero_level_payload: Dictionary = _read_json_dict(HERO_LEVELS_PATH)
	for entry: Dictionary in hero_level_payload.get("hero_levels", []):
		hero_levels[int(entry.get("level", 1))] = entry

	var parallax_scene_payload: Dictionary = _read_json_dict(PARALLAX_SCENE_DEFS_PATH)
	for entry: Dictionary in parallax_scene_payload.get("scene_defs", []):
		parallax_scene_defs[entry["id"]] = entry
	parallax_scene_chapter_defaults = parallax_scene_payload.get("chapter_defaults", {})
	parallax_scene_node_overrides = parallax_scene_payload.get("node_overrides", {})

	EventBus.config_loaded.emit()


func get_core_skill(skill_id: String) -> Dictionary:
	if active_skills.has(skill_id):
		return active_skills.get(skill_id, {})
	return core_skills.get(skill_id, {})


func get_active_skill(skill_id: String) -> Dictionary:
	return active_skills.get(skill_id, {})


func get_all_active_skills() -> Array:
	return active_skills.values()


func get_active_skills_by_school(school_id: String) -> Array:
	return active_skills_by_school.get(school_id, [])


func get_passive_skill(skill_id: String) -> Dictionary:
	return passive_skills.get(skill_id, {})


func get_all_passive_skills() -> Array:
	return passive_skills.values()


func get_passive_skills_by_school(school_id: String) -> Array:
	return passive_skills_by_school.get(school_id, [])


func get_hero_level_entry(level: int) -> Dictionary:
	return hero_levels.get(level, {})


func get_enemy(enemy_id: String) -> Dictionary:
	return enemies.get(enemy_id, {})


func get_chapter(chapter_id: String) -> Dictionary:
	return chapters.get(chapter_id, {})


func get_chapter_node(node_id: String) -> Dictionary:
	return chapter_nodes.get(node_id, {})


func get_node_type_display_name(node_type: String) -> String:
	match node_type:
		"elite":
			return "精英"
		"boss":
			return "首领"
		_:
			return "寻常"


func get_chapter_node_name(node_id: String) -> String:
	var node_data: Dictionary = get_chapter_node(node_id)
	if node_data.is_empty():
		return node_id
	var explicit_name: String = String(node_data.get("name", ""))
	if not explicit_name.is_empty():
		return explicit_name
	return String(node_data.get("id", node_id))


func get_chapter_node_short_label(node_id: String) -> String:
	var node_data: Dictionary = get_chapter_node(node_id)
	if node_data.is_empty():
		return node_id
	var chapter_data: Dictionary = get_chapter(String(node_data.get("chapter_id", "")))
	var chapter_name: String = String(chapter_data.get("name", ""))
	var node_name: String = get_chapter_node_name(node_id)
	if chapter_name.is_empty():
		return node_name
	return "%s/%s" % [chapter_name, node_name]


func get_chapter_node_full_label(node_id: String) -> String:
	var node_data: Dictionary = get_chapter_node(node_id)
	if node_data.is_empty():
		return node_id
	return "%s · %s · %s" % [
		String(get_chapter(String(node_data.get("chapter_id", ""))).get("name", String(node_data.get("chapter_id", "")))),
		get_chapter_node_name(node_id),
		get_node_type_display_name(String(node_data.get("node_type", "normal"))),
	]


func get_enemy_pool(pool_id: String) -> Dictionary:
	return enemy_pools.get(pool_id, {})


func get_drop_profile(profile_id: String) -> Dictionary:
	return drop_profiles.get(profile_id, {})


func get_all_equipment_bases() -> Array:
	return equipment_bases.values()


func get_all_affixes() -> Array:
	return affixes.values()


func get_all_legendary_affixes() -> Array:
	return legendary_affixes.values()


func get_set(set_id: String) -> Dictionary:
	return set_defs.get(set_id, {})


func get_all_sets() -> Array:
	return set_defs.values()


func get_cube_recipe(recipe_id: String) -> Dictionary:
	return cube_recipes.get(recipe_id, {})


func get_all_cube_recipes() -> Array:
	return cube_recipes.values()


func get_gem(gem_id: String) -> Dictionary:
	return gems.get(gem_id, {})


func get_all_gems() -> Array:
	return gems.values()


func get_rift_scaling_entries() -> Array:
	return rift_scaling_entries


func get_rift_key_entries() -> Array:
	return rift_key_entries


func get_research_node(node_id: String) -> Dictionary:
	return research_nodes.get(node_id, {})


func get_all_research_nodes() -> Array:
	return research_nodes.values()


func get_parallax_scene(scene_id: String) -> Dictionary:
	return parallax_scene_defs.get(scene_id, {})


func get_parallax_scene_key(chapter_id: String, node_id: String) -> String:
	var node_override: String = String(parallax_scene_node_overrides.get(node_id, ""))
	if not node_override.is_empty():
		return node_override
	return String(parallax_scene_chapter_defaults.get(chapter_id, ""))


func get_chapter_first_node(chapter_id: String) -> String:
	var chapter: Dictionary = get_chapter(chapter_id)
	var node_ids: Array = chapter.get("node_ids", [])
	if node_ids.is_empty():
		return ""
	return String(node_ids[0])


func _read_json_array(path: String) -> Array:
	var data: Variant = _read_json(path)
	if data is Array:
		return data
	return []


func _read_json_dict(path: String) -> Dictionary:
	var data: Variant = _read_json(path)
	if data is Dictionary:
		return data
	return {}


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_warning("JSON not found: %s" % path)
		return null

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Failed to open JSON: %s" % path)
		return null

	var json_text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(json_text)
	if parsed == null:
		push_warning("Failed to parse JSON: %s" % path)
	return parsed
