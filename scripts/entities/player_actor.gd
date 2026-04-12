class_name PlayerActor
extends CharacterBody2D

const DamageResolverScript = preload("res://scripts/combat/damage_resolver.gd")
const HERO_ANIMATION_PATHS := {
	"idle": ["res://assets/generated/afk_rpg_formal/characters/hero_idle_v2.png"],
	"move": [
		"res://assets/generated/afk_rpg_formal/characters/hero_move_anim_01.png",
		"res://assets/generated/afk_rpg_formal/characters/hero_move_anim_02.png",
		"res://assets/generated/afk_rpg_formal/characters/hero_move_anim_03.png",
		"res://assets/generated/afk_rpg_formal/characters/hero_move_anim_04.png",
		"res://assets/generated/afk_rpg_formal/characters/hero_move_anim_05.png",
		"res://assets/generated/afk_rpg_formal/characters/hero_move_anim_06.png",
	],
	"combat": ["res://assets/generated/afk_rpg_formal/characters/hero_combat_pose_v2.png"],
	"attack": [
		"res://assets/generated/afk_rpg_formal/characters/hero_attack_anim_01.png",
		"res://assets/generated/afk_rpg_formal/characters/hero_attack_anim_02.png",
		"res://assets/generated/afk_rpg_formal/characters/hero_attack_anim_03.png",
		"res://assets/generated/afk_rpg_formal/characters/hero_attack_anim_04.png",
	],
}
const HERO_ANIMATION_FPS := {
	"idle": 1.0,
	"move": 2.8,
	"combat": 1.0,
	"attack": 3.6,
}
const HERO_ANIMATION_LOOP := {
	"idle": true,
	"move": true,
	"combat": true,
	"attack": false,
}
const PLAYER_PORTRAIT_SCALE := Vector2(0.22, 0.22)
const PLAYER_BODY_SCALE := Vector2(2.2, 2.2)
const PLAYER_PORTRAIT_POSITION := Vector2(0.0, -20.0)
const PLAYER_HEALTH_MARKER_POSITION := Vector2(0.0, -104.0)
const PLAYER_HEALTH_MARKER_MIN_SCALE := 0.36
const PLAYER_HP_BAR_OFFSETS := {
	"left": -40.0,
	"top": -102.0,
	"right": 40.0,
	"bottom": -90.0,
}
const PLAYER_CAST_LABEL_OFFSETS := {
	"left": -84.0,
	"top": -146.0,
	"right": 84.0,
	"bottom": -118.0,
}
const PLAYER_CAST_LABEL_POSITION := Vector2(-84.0, -146.0)
const ACTIVE_SLOT_ORDER := ["basic", "core", "tactic", "burst"]
const MAX_RESOURCE := 100.0
const BASE_RESOURCE_REGEN := 4.0
const BASE_ATTACK_RANGE := 72.0
const MELEE_ATTACK_RANGE := 84.0
const CAST_FEEDBACK_TEXT := {
	"basic": "起手",
	"core": "核心",
	"tactic": "战术",
	"burst": "爆发",
}
const SCHOOL_COLORS := {
	"yufeng": Color(0.28, 0.66, 1.0, 1.0),
	"xuejie": Color(0.9, 0.25, 0.32, 1.0),
	"wulei": Color(0.68, 0.45, 1.0, 1.0),
}
const IDLE_RETURN_THRESHOLD := 4.0
const IDLE_RETURN_SPEED_MULTIPLIER := 0.75

signal died()

@onready var body_visual: Polygon2D = $BodyVisual
@onready var portrait_visual: AnimatedSprite2D = $PortraitVisual
@onready var hp_bar: ProgressBar = $HpBar
@onready var health_marker_back: Polygon2D = $HealthMarkerBack
@onready var health_marker_fill: Polygon2D = $HealthMarkerFill
@onready var cast_label: Label = $CastLabel

var max_hp: float = 160.0
var current_hp: float = 160.0
var attack: float = 18.0
var defense: float = 8.0
var move_speed: float = 120.0
var attack_interval: float = 0.65
var attack_range: float = 72.0
var current_resource: float = 40.0
var max_resource: float = MAX_RESOURCE
var resource_regen_per_second: float = BASE_RESOURCE_REGEN
var resource_cost_reduction: float = 0.0
var core_bonus_percent: float = 0.0
var core_damage_bonus_percent: float = 0.0
var whirlwind_radius: float = 120.0
var bleed_dot_bonus_percent: float = 0.0
var execute_threshold: float = 0.0
var chain_count_bonus: int = 0
var chain_damage_bonus_percent: float = 0.0
var core_cooldown_reduction: float = 0.0
var combat_params: Dictionary = {}
var combat_bonuses: Dictionary = {}
var active_skill_defs: Dictionary = {}
var passive_skill_defs: Array[Dictionary] = []
var skill_timers: Dictionary = {
	"basic": 0.0,
	"core": 1.5,
	"tactic": 0.8,
	"burst": 1.8,
}
var active_buffs: Dictionary = {}

var school_id: String = "yufeng"
var core_skill_id: String = "core_whirlwind"
var core_skill_name: String = "御风回斩"
var base_attack_value: float = 18.0
var base_defense_value: float = 8.0
var base_move_speed_value: float = 120.0
var base_attack_interval: float = 0.65
var target: Node2D
var should_move: bool = true
var status_text: String = "推进中"
var cast_tween: Tween
var idle_anchor_x: float = 0.0
var movement_left_bound: float = 426.0
var movement_right_bound: float = 854.0
var portrait_state: String = "idle"
var attack_animation_locked: bool = false
var portrait_frames: SpriteFrames
var forward_run_in_place: bool = false
var last_emitted_resource_value: int = -1


func _ready() -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp
	idle_anchor_x = global_position.x
	_apply_visual_layout()
	_build_portrait_frames()
	portrait_visual.animation_finished.connect(_on_portrait_animation_finished)
	_apply_portrait_visual(true)
	_emit_hp_state()
	_emit_resource_state(true)


func setup_from_skill(skill_data: Dictionary) -> void:
	var build_state: Dictionary = GameManager.get_combat_loadout_state()
	if build_state.is_empty():
		setup_from_build({
			"school_id": String(skill_data.get("school_id", "yufeng")),
			"hero_summary": GameManager.get_hero_progression_summary(),
			"active_skills": {
				"basic": {},
				"core": skill_data,
				"tactic": {},
				"burst": {},
			},
			"passives": [],
		})
		return
	setup_from_build(build_state)


func setup_from_build(build_data: Dictionary) -> void:
	_reset_base_stats()
	school_id = String(build_data.get("school_id", "yufeng"))
	active_skill_defs = {}
	for slot_type_variant in ACTIVE_SLOT_ORDER:
		var slot_type: String = String(slot_type_variant)
		active_skill_defs[slot_type] = Dictionary(build_data.get("active_skills", {}).get(slot_type, {})).duplicate(true)
	passive_skill_defs.clear()
	for passive_variant in build_data.get("passives", []):
		passive_skill_defs.append(Dictionary(passive_variant).duplicate(true))

	var core_skill_data: Dictionary = active_skill_defs.get("core", {})
	core_skill_id = String(core_skill_data.get("id", "core_whirlwind"))
	core_skill_name = String(core_skill_data.get("name", "御风回斩"))
	body_visual.color = SCHOOL_COLORS.get(school_id, SCHOOL_COLORS["yufeng"])
	_apply_portrait_tint()

	var hero_summary: Dictionary = Dictionary(build_data.get("hero_summary", {}))
	var hero_level: int = int(hero_summary.get("level", 1))
	var level_entry: Dictionary = ConfigDB.get_hero_level_entry(hero_level)
	var stat_growth: Dictionary = Dictionary(level_entry.get("base_stat_growth", {}))
	attack = float(stat_growth.get("attack_flat", 18.0))
	max_hp = float(stat_growth.get("hp_flat", 160.0))
	current_hp = max_hp
	defense = float(stat_growth.get("defense_flat", 8.0))
	move_speed = 120.0
	attack_interval = _get_skill_base_cooldown("basic", 0.65)
	attack_range = _calculate_base_attack_range()
	current_resource = 42.0
	max_resource = MAX_RESOURCE
	resource_regen_per_second = BASE_RESOURCE_REGEN
	resource_cost_reduction = 0.0
	core_bonus_percent = 0.0
	core_damage_bonus_percent = 0.0
	whirlwind_radius = 120.0
	bleed_dot_bonus_percent = 0.0
	execute_threshold = 0.0
	chain_count_bonus = 0
	chain_damage_bonus_percent = 0.0
	core_cooldown_reduction = 0.0

	combat_bonuses = GameManager.get_total_combat_bonuses()
	_apply_build_bonuses(combat_bonuses)

	base_attack_value = attack
	base_defense_value = defense
	base_move_speed_value = move_speed
	base_attack_interval = attack_interval
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp
	_update_health_marker()
	_reset_skill_runtime()
	_emit_hp_state()
	_emit_resource_state(true)


func _physics_process(delta: float) -> void:
	if current_hp <= 0.0:
		return

	_process_active_buffs(delta)
	_process_resource_regen(delta)
	_process_movement(delta)

	if target == null or not is_instance_valid(target):
		return

	_tick_skill_timers(delta)

	if _try_cast_tactic():
		return
	if _try_cast_burst():
		return
	if global_position.distance_to(target.global_position) > attack_range:
		return
	if _try_cast_core():
		return
	_try_cast_basic()


func _process_movement(delta: float) -> void:
	var current_move_speed: float = _get_current_move_speed()
	if should_move:
		var target_x: float = global_position.x
		if target != null and is_instance_valid(target):
			target_x = target.global_position.x
		else:
			target_x = idle_anchor_x
		global_position.x = move_toward(global_position.x, clampf(target_x, movement_left_bound, movement_right_bound), current_move_speed * delta)
		status_text = "追击中"
	elif forward_run_in_place:
		status_text = "推进中"
	elif target == null or not is_instance_valid(target):
		var distance_to_anchor: float = idle_anchor_x - global_position.x
		if absf(distance_to_anchor) > IDLE_RETURN_THRESHOLD:
			global_position.x = move_toward(global_position.x, idle_anchor_x, current_move_speed * IDLE_RETURN_SPEED_MULTIPLIER * delta)
			status_text = "归位中"
		else:
			status_text = "待机中"
	else:
		status_text = "战斗中"

	global_position.x = clampf(global_position.x, movement_left_bound, movement_right_bound)
	_update_portrait_state()


func _tick_skill_timers(delta: float) -> void:
	for slot_type_variant in ACTIVE_SLOT_ORDER:
		var slot_type: String = String(slot_type_variant)
		skill_timers[slot_type] = maxf(0.0, float(skill_timers.get(slot_type, 0.0)) - delta)


func _process_active_buffs(delta: float) -> void:
	var expired_ids: Array[String] = []
	for buff_id_variant in active_buffs.keys():
		var buff_id: String = String(buff_id_variant)
		var buff_state: Dictionary = active_buffs.get(buff_id, {})
		buff_state["time_left"] = maxf(0.0, float(buff_state.get("time_left", 0.0)) - delta)
		active_buffs[buff_id] = buff_state
		if float(buff_state.get("time_left", 0.0)) <= 0.0:
			expired_ids.append(buff_id)
	for buff_id in expired_ids:
		active_buffs.erase(buff_id)


func _process_resource_regen(delta: float) -> void:
	if max_resource <= 0.0:
		return
	var next_resource: float = minf(max_resource, current_resource + resource_regen_per_second * delta)
	if is_equal_approx(next_resource, current_resource):
		return
	current_resource = next_resource
	_emit_resource_state()


func _try_cast_basic() -> bool:
	var skill_data: Dictionary = active_skill_defs.get("basic", {})
	if skill_data.is_empty() or float(skill_timers.get("basic", 0.0)) > 0.0:
		return false
	if target == null or not is_instance_valid(target):
		return false
	var effect: Dictionary = _build_effect_profile(skill_data)
	var hit_summary: Dictionary = _apply_skill_effect(skill_data, effect, target, "basic")
	if int(hit_summary.get("hit_count", 0)) <= 0:
		return false
	_trigger_attack_animation()
	_show_cast_feedback(String(skill_data.get("name", CAST_FEEDBACK_TEXT["basic"])))
	_gain_resource(float(effect.get("resource_generate", 0.0)))
	skill_timers["basic"] = _get_skill_cooldown("basic", skill_data)
	return true


func _try_cast_core() -> bool:
	var skill_data: Dictionary = active_skill_defs.get("core", {})
	if skill_data.is_empty() or float(skill_timers.get("core", 0.0)) > 0.0:
		return false
	if target == null or not is_instance_valid(target):
		return false
	var effect: Dictionary = _build_effect_profile(skill_data)
	if not _can_afford_skill(effect):
		return false
	_consume_resource(float(effect.get("resource_cost", 0.0)))
	var hit_summary: Dictionary = _apply_skill_effect(skill_data, effect, target, "core")
	if int(hit_summary.get("hit_count", 0)) <= 0:
		return false
	_trigger_attack_animation()
	_show_cast_feedback(String(skill_data.get("name", CAST_FEEDBACK_TEXT["core"])))
	_emit_skill_highlight(skill_data, effect, hit_summary, "core_skill")
	skill_timers["core"] = _get_skill_cooldown("core", skill_data)
	return true


func _try_cast_tactic() -> bool:
	var skill_data: Dictionary = active_skill_defs.get("tactic", {})
	if skill_data.is_empty() or float(skill_timers.get("tactic", 0.0)) > 0.0:
		return false
	if target == null or not is_instance_valid(target):
		return false
	var effect: Dictionary = _build_effect_profile(skill_data)
	var ai_rule: String = String(skill_data.get("ai_rule", "missing_buff"))
	if ai_rule == "missing_buff" and _is_buff_active(String(effect.get("buff_id", ""))):
		return false
	if ai_rule == "enemy_cluster" and _count_nearby_enemies(160.0) < 3:
		return false
	if ai_rule == "low_health" and _get_hp_percent() > 0.55:
		return false
	if not _can_afford_skill(effect):
		return false
	_consume_resource(float(effect.get("resource_cost", 0.0)))
	var hit_summary: Dictionary = _apply_skill_effect(skill_data, effect, target, "tactic")
	_trigger_attack_animation()
	_show_cast_feedback(String(skill_data.get("name", CAST_FEEDBACK_TEXT["tactic"])))
	_emit_skill_highlight(skill_data, effect, hit_summary, "utility")
	skill_timers["tactic"] = _get_skill_cooldown("tactic", skill_data)
	return true


func _try_cast_burst() -> bool:
	var skill_data: Dictionary = active_skill_defs.get("burst", {})
	if skill_data.is_empty() or float(skill_timers.get("burst", 0.0)) > 0.0:
		return false
	if target == null or not is_instance_valid(target):
		return false
	var effect: Dictionary = _build_effect_profile(skill_data)
	var target_is_elite: bool = bool(target.get("enemy_type") in ["elite", "boss"])
	var cluster_size: int = _count_nearby_enemies(172.0)
	if not target_is_elite and cluster_size < 3:
		return false
	if not _can_afford_skill(effect):
		return false
	_consume_resource(float(effect.get("resource_cost", 0.0)))
	var hit_summary: Dictionary = _apply_skill_effect(skill_data, effect, target, "burst")
	if int(hit_summary.get("hit_count", 0)) <= 0:
		return false
	_trigger_attack_animation()
	_show_cast_feedback(String(skill_data.get("name", CAST_FEEDBACK_TEXT["burst"])))
	_emit_skill_highlight(skill_data, effect, hit_summary, "burst")
	skill_timers["burst"] = _get_skill_cooldown("burst", skill_data)
	return true


func _apply_skill_effect(skill_data: Dictionary, effect: Dictionary, primary_target: Node, slot_type: String) -> Dictionary:
	var kind: String = String(effect.get("kind", "single"))
	var hit_count: int = 0
	var kill_count: int = 0
	match kind:
		"aoe":
			var radius: float = float(effect.get("radius", whirlwind_radius))
			if String(skill_data.get("id", "")) in ["core_whirlwind", "burst_yufeng_tempest"]:
				radius += maxf(0.0, whirlwind_radius - 120.0)
			for enemy_variant in get_tree().get_nodes_in_group("enemy_actor"):
				var enemy: Node = enemy_variant
				if not is_instance_valid(enemy):
					continue
				if global_position.distance_to(enemy.global_position) > radius:
					continue
				var result: Dictionary = _damage_enemy_with_skill(enemy, skill_data, effect, slot_type, 1.0)
				hit_count += int(result.get("hit_count", 0))
				kill_count += int(result.get("kill_count", 0))
		"chain":
			var enemies: Array = _get_sorted_enemies()
			var chain_total: int = int(effect.get("chain_count", 3)) + chain_count_bonus + int(round(_get_buff_bonus("chain_count_bonus")))
			var falloff: float = float(effect.get("falloff", 0.0))
			for enemy_index in range(mini(chain_total, enemies.size())):
				var enemy: Node = enemies[enemy_index]
				var step_mult: float = maxf(0.35, 1.0 - float(enemy_index) * falloff)
				var result: Dictionary = _damage_enemy_with_skill(enemy, skill_data, effect, slot_type, step_mult)
				hit_count += int(result.get("hit_count", 0))
				kill_count += int(result.get("kill_count", 0))
		"buff":
			_apply_runtime_buff(effect)
			hit_count = 1
			kill_count = 0
		_:
			var single_result: Dictionary = _damage_enemy_with_skill(primary_target, skill_data, effect, slot_type, 1.0)
			hit_count = int(single_result.get("hit_count", 0))
			kill_count = int(single_result.get("kill_count", 0))

	if float(effect.get("resource_gain_on_cast", 0.0)) > 0.0:
		_gain_resource(float(effect.get("resource_gain_on_cast", 0.0)))
	if float(effect.get("resource_refund_on_hit", 0.0)) > 0.0 and hit_count > 0:
		_gain_resource(float(effect.get("resource_refund_on_hit", 0.0)) * hit_count)
	if float(effect.get("resource_refund_on_kill", 0.0)) > 0.0 and kill_count > 0:
		_gain_resource(float(effect.get("resource_refund_on_kill", 0.0)) * kill_count)
	return {
		"hit_count": hit_count,
		"kill_count": kill_count,
	}


func _damage_enemy_with_skill(enemy: Node, skill_data: Dictionary, effect: Dictionary, slot_type: String, step_multiplier: float) -> Dictionary:
	if enemy == null or not is_instance_valid(enemy):
		return {"hit_count": 0, "kill_count": 0}
	var pre_hp_variant: Variant = enemy.get("current_hp")
	var pre_hp: float = -1.0 if pre_hp_variant == null else float(pre_hp_variant)
	var damage: float = _calculate_skill_damage(skill_data, effect, slot_type, enemy, step_multiplier)
	var payload: Dictionary = _build_damage_payload(skill_data, effect, slot_type)
	var tags: Array = []
	if float(payload.get("bleed_dot_percent", 0.0)) > 0.0:
		tags.append("bleed")
	enemy.take_damage(damage, tags, payload)
	var hit_count: int = 1
	var post_hp_variant: Variant = enemy.get("current_hp")
	var post_hp: float = -1.0 if post_hp_variant == null else float(post_hp_variant)
	var kill_count: int = 1 if pre_hp > 0.0 and (post_hp <= 0.0 or not is_instance_valid(enemy)) else 0
	var splash_radius: float = float(effect.get("splash_radius", 0.0))
	if splash_radius > 0.0:
		for splash_target_variant in get_tree().get_nodes_in_group("enemy_actor"):
			var splash_target: Node = splash_target_variant
			if splash_target == enemy or not is_instance_valid(splash_target):
				continue
			if enemy.global_position.distance_to(splash_target.global_position) > splash_radius:
				continue
			var splash_payload: Dictionary = payload.duplicate(true)
			splash_payload["source"] = "basic"
			splash_target.take_damage(damage * 0.55, tags, splash_payload)
			hit_count += 1
	return {
		"hit_count": hit_count,
		"kill_count": kill_count,
	}


func _calculate_skill_damage(skill_data: Dictionary, effect: Dictionary, slot_type: String, enemy: Node, step_multiplier: float) -> float:
	var multiplier: float = float(effect.get("multiplier", 1.0)) * step_multiplier
	var elite_multiplier: float = float(effect.get("elite_multiplier", 1.0))
	var enemy_type: String = String(enemy.get("enemy_type"))
	if enemy_type in ["elite", "boss"]:
		multiplier *= elite_multiplier
	var params: Dictionary = combat_params.duplicate()
	params["weapon_damage"] = _get_current_attack_power() * multiplier
	params["crit_rate"] = float(params.get("crit_rate", 0.0)) + _get_buff_bonus("crit_rate")
	params["crit_damage"] = float(params.get("crit_damage", 0.5)) + _get_buff_bonus("crit_damage")
	params["skill_damage_percent"] = float(params.get("skill_damage_percent", 0.0)) + _get_buff_bonus("skill_damage_percent")
	if slot_type in ["core", "burst"]:
		params["weapon_damage"] *= 1.0 + core_bonus_percent + core_damage_bonus_percent + _get_buff_bonus("core_damage_percent")
	if slot_type in ["core", "burst"] and String(skill_data.get("id", "")) in ["core_chain_lightning", "burst_wulei_heavenfall"]:
		params["weapon_damage"] *= 1.0 + chain_damage_bonus_percent + _get_buff_bonus("chain_damage_percent") + float(effect.get("chain_damage_percent", 0.0))
	return DamageResolverScript.calculate_damage(params)


func _build_damage_payload(skill_data: Dictionary, effect: Dictionary, slot_type: String) -> Dictionary:
	var source: String = slot_type
	match String(skill_data.get("id", "")):
		"core_whirlwind", "burst_yufeng_tempest":
			source = "whirlwind"
		"core_chain_lightning", "burst_wulei_heavenfall":
			source = "chain_lightning"
		"core_deep_wound", "burst_xuejie_execution":
			source = "bleed"
		_:
			if slot_type == "core":
				source = "core"
	var payload := {
		"source": source,
	}
	var bleed_value: float = float(effect.get("bleed_dot_percent", 0.0)) + bleed_dot_bonus_percent + _get_buff_bonus("bleed_dot_percent")
	if bleed_value > 0.0:
		payload["bleed_dot_percent"] = bleed_value
	var execute_value: float = execute_threshold + float(effect.get("execute_threshold_bonus", 0.0)) + _get_buff_bonus("execute_threshold")
	if execute_value > 0.0:
		payload["execute_threshold"] = execute_value
	return payload


func _apply_runtime_buff(effect: Dictionary) -> void:
	var buff_id: String = String(effect.get("buff_id", "runtime_buff"))
	var stats := {}
	for key_variant in effect.keys():
		var key: String = String(key_variant)
		if key in ["kind", "buff_id", "duration", "resource_cost", "resource_generate", "cooldown", "selected_rune_id"]:
			continue
		var value: Variant = effect.get(key_variant)
		if value is float or value is int:
			stats[key] = float(value)
	active_buffs[buff_id] = {
		"time_left": float(effect.get("duration", 4.0)),
		"stats": stats,
	}


func _build_effect_profile(skill_data: Dictionary) -> Dictionary:
	var effect: Dictionary = Dictionary(skill_data.get("base_effect", {})).duplicate(true)
	var selected_rune: Dictionary = Dictionary(skill_data.get("selected_rune", {}))
	var modifiers: Dictionary = Dictionary(selected_rune.get("modifiers", {}))
	effect["resource_cost"] = maxf(0.0, float(skill_data.get("resource_cost", 0.0)) + float(modifiers.get("resource_cost_delta", 0.0)))
	effect["resource_cost"] *= maxf(0.0, 1.0 - resource_cost_reduction)
	effect["resource_generate"] = maxf(0.0, float(skill_data.get("resource_generate", 0.0)) + float(modifiers.get("resource_generate_delta", 0.0)))
	effect["cooldown"] = float(skill_data.get("cooldown", 0.0))
	effect["multiplier"] = float(effect.get("multiplier", 1.0)) + float(modifiers.get("multiplier_bonus", 0.0))
	if effect.has("radius") or modifiers.has("radius_bonus"):
		effect["radius"] = float(effect.get("radius", 0.0)) + float(modifiers.get("radius_bonus", 0.0))
	if effect.has("bleed_dot_percent") or modifiers.has("bleed_dot_percent_bonus"):
		effect["bleed_dot_percent"] = float(effect.get("bleed_dot_percent", 0.0)) + float(modifiers.get("bleed_dot_percent_bonus", 0.0))
	if effect.has("execute_threshold_bonus") or modifiers.has("execute_threshold_bonus"):
		effect["execute_threshold_bonus"] = float(effect.get("execute_threshold_bonus", 0.0)) + float(modifiers.get("execute_threshold_bonus", 0.0))
	if effect.has("chain_count") or modifiers.has("chain_count_bonus"):
		effect["chain_count"] = int(effect.get("chain_count", 0)) + int(modifiers.get("chain_count_bonus", 0))
	if effect.has("elite_multiplier") or modifiers.has("elite_multiplier_bonus"):
		effect["elite_multiplier"] = float(effect.get("elite_multiplier", 1.0)) + float(modifiers.get("elite_multiplier_bonus", 0.0))
	if modifiers.has("splash_radius"):
		effect["splash_radius"] = float(modifiers.get("splash_radius", 0.0))
	if modifiers.has("resource_gain_on_cast"):
		effect["resource_gain_on_cast"] = float(modifiers.get("resource_gain_on_cast", 0.0))
	if modifiers.has("resource_refund_on_hit"):
		effect["resource_refund_on_hit"] = float(modifiers.get("resource_refund_on_hit", 0.0))
	if modifiers.has("resource_refund_on_kill"):
		effect["resource_refund_on_kill"] = float(modifiers.get("resource_refund_on_kill", 0.0))
	if effect.has("attack_speed_percent") or modifiers.has("attack_speed_percent_bonus"):
		effect["attack_speed_percent"] = float(effect.get("attack_speed_percent", 0.0)) + float(modifiers.get("attack_speed_percent_bonus", 0.0))
	if effect.has("attack_percent") or modifiers.has("attack_percent_bonus"):
		effect["attack_percent"] = float(effect.get("attack_percent", 0.0)) + float(modifiers.get("attack_percent_bonus", 0.0))
	if effect.has("defense_flat") or modifiers.has("defense_flat_bonus"):
		effect["defense_flat"] = float(effect.get("defense_flat", 0.0)) + float(modifiers.get("defense_flat_bonus", 0.0))
	if effect.has("crit_rate") or modifiers.has("crit_rate_bonus"):
		effect["crit_rate"] = float(effect.get("crit_rate", 0.0)) + float(modifiers.get("crit_rate_bonus", 0.0))
	if effect.has("chain_damage_percent_bonus") or modifiers.has("chain_damage_percent_bonus"):
		effect["chain_damage_percent"] = float(effect.get("chain_damage_percent_bonus", 0.0)) + float(modifiers.get("chain_damage_percent_bonus", 0.0))
	return effect


func _apply_build_bonuses(bonuses: Dictionary) -> void:
	attack += float(bonuses.get("attack_flat", 0.0))
	max_hp += float(bonuses.get("hp_flat", 0.0))
	defense += float(bonuses.get("defense_flat", 0.0))
	attack *= 1.0 + float(bonuses.get("attack_percent", 0.0))
	move_speed *= 1.0 + float(bonuses.get("move_speed_percent", 0.0))
	attack_interval = maxf(0.18, attack_interval / (1.0 + float(bonuses.get("attack_speed_percent", 0.0))))
	resource_regen_per_second += float(bonuses.get("resource_regen_flat", 0.0))
	resource_cost_reduction = float(bonuses.get("resource_cost_reduction", 0.0))
	core_damage_bonus_percent = float(bonuses.get("core_damage_percent", 0.0))
	core_cooldown_reduction = float(bonuses.get("core_cooldown_reduction", 0.0))
	whirlwind_radius *= 1.0 + float(bonuses.get("whirlwind_radius_percent", 0.0))
	bleed_dot_bonus_percent = float(bonuses.get("bleed_dot_percent", 0.0))
	execute_threshold = float(bonuses.get("execute_threshold", 0.0))
	chain_count_bonus = int(round(float(bonuses.get("chain_count_bonus", 0.0))))
	chain_damage_bonus_percent = float(bonuses.get("chain_damage_percent", 0.0))

	combat_params = {
		"weapon_damage": maxf(attack, float(bonuses.get("weapon_damage", 0.0)) + attack),
		"primary_stat": float(bonuses.get("primary_stat", 0.0)),
		"crit_rate": float(bonuses.get("crit_rate", 0.0)),
		"crit_damage": float(bonuses.get("crit_damage", 0.5)),
		"skill_damage_percent": float(bonuses.get("skill_damage_percent", 0.0)),
		"elemental_damage_percent": float(bonuses.get("elemental_damage_percent", 0.0)),
		"set_bonus_percent": float(bonuses.get("set_bonus_percent", 0.0)),
		"legendary_effect_percent": float(bonuses.get("legendary_effect_percent", 0.0)),
		"elite_damage_percent": float(bonuses.get("elite_damage_percent", 0.0)),
	}


func _calculate_base_attack_range() -> float:
	var resolved_range: float = MELEE_ATTACK_RANGE
	for slot_type_variant in ["basic", "core", "burst"]:
		var skill_data: Dictionary = active_skill_defs.get(String(slot_type_variant), {})
		if skill_data.is_empty():
			continue
		var base_effect: Dictionary = Dictionary(skill_data.get("base_effect", {}))
		var range_bonus: float = float(base_effect.get("range_bonus", 0.0))
		resolved_range = maxf(resolved_range, BASE_ATTACK_RANGE + range_bonus)
	return resolved_range


func _get_skill_base_cooldown(slot_type: String, fallback_value: float) -> float:
	var skill_data: Dictionary = active_skill_defs.get(slot_type, {})
	if skill_data.is_empty():
		return fallback_value
	return float(skill_data.get("cooldown", fallback_value))


func _get_skill_cooldown(slot_type: String, skill_data: Dictionary) -> float:
	var base_cooldown: float = float(skill_data.get("cooldown", 0.5))
	match slot_type:
		"basic":
			return maxf(0.18, base_cooldown / (1.0 + _get_buff_bonus("attack_speed_percent")))
		"core", "burst":
			return maxf(0.65, base_cooldown * (1.0 - core_cooldown_reduction))
		_:
			return maxf(0.4, base_cooldown)


func _can_afford_skill(effect: Dictionary) -> bool:
	return current_resource >= float(effect.get("resource_cost", 0.0))


func _consume_resource(amount: float) -> void:
	if amount <= 0.0:
		return
	current_resource = maxf(0.0, current_resource - amount)
	_emit_resource_state()


func _gain_resource(amount: float) -> void:
	if amount <= 0.0:
		return
	current_resource = minf(max_resource, current_resource + amount)
	_emit_resource_state()


func _get_hp_percent() -> float:
	if max_hp <= 0.0:
		return 0.0
	return clampf(current_hp / max_hp, 0.0, 1.0)


func _get_current_attack_power() -> float:
	return base_attack_value * (1.0 + _get_buff_bonus("attack_percent"))


func _get_current_move_speed() -> float:
	return base_move_speed_value * (1.0 + _get_buff_bonus("move_speed_percent"))


func _get_current_defense() -> float:
	return base_defense_value + _get_buff_bonus("defense_flat")


func _get_buff_bonus(stat_key: String) -> float:
	var total: float = 0.0
	for buff_state_variant in active_buffs.values():
		var buff_state: Dictionary = buff_state_variant
		var stats: Dictionary = Dictionary(buff_state.get("stats", {}))
		total += float(stats.get(stat_key, 0.0))
	return total


func _is_buff_active(buff_id: String) -> bool:
	if buff_id.is_empty():
		return false
	return active_buffs.has(buff_id) and float(Dictionary(active_buffs.get(buff_id, {})).get("time_left", 0.0)) > 0.0


func _count_nearby_enemies(radius: float) -> int:
	var count: int = 0
	for enemy_variant in get_tree().get_nodes_in_group("enemy_actor"):
		var enemy: Node = enemy_variant
		if is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) <= radius:
			count += 1
	return count


func _get_sorted_enemies() -> Array:
	var enemies: Array = []
	for node in get_tree().get_nodes_in_group("enemy_actor"):
		if is_instance_valid(node):
			enemies.append(node)
	enemies.sort_custom(func(a, b) -> bool:
		return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position)
	)
	return enemies


func take_damage(raw_damage: float, attacker_defense: float = 0.0) -> void:
	var adjusted_raw: float = maxf(1.0, raw_damage - attacker_defense * 0.2)
	var actual_damage: float = DamageResolverScript.apply_defense(adjusted_raw, _get_current_defense())
	current_hp = maxf(0.0, current_hp - actual_damage)
	hp_bar.value = current_hp
	_update_health_marker()
	_emit_hp_state()
	if current_hp <= 0.0:
		died.emit()


func reset_state() -> void:
	current_hp = max_hp
	current_resource = 42.0
	_reset_skill_runtime()
	target = null
	should_move = false
	hp_bar.value = current_hp
	_update_health_marker()
	_emit_hp_state()
	_emit_resource_state(true)
	forward_run_in_place = false
	active_buffs.clear()


func set_idle_anchor_x(value: float) -> void:
	idle_anchor_x = value


func set_movement_bounds(left_bound: float, right_bound: float) -> void:
	movement_left_bound = left_bound
	movement_right_bound = right_bound


func set_forward_run_in_place(enabled: bool) -> void:
	forward_run_in_place = enabled
	if not attack_animation_locked:
		_update_portrait_state()


func is_advancing_visual() -> bool:
	if attack_animation_locked:
		return false
	return should_move or forward_run_in_place or portrait_state == "move"


func _show_cast_feedback(text: String) -> void:
	cast_label.text = text
	cast_label.modulate = Color(1, 0.95, 0.4, 1)
	cast_label.position = PLAYER_CAST_LABEL_POSITION
	if cast_tween:
		cast_tween.kill()
	cast_tween = create_tween()
	cast_tween.tween_property(cast_label, "position:y", cast_label.position.y - 16.0, 0.42)
	cast_tween.parallel().tween_property(cast_label, "modulate:a", 0.0, 0.42)
	cast_tween.finished.connect(func() -> void:
		cast_label.text = ""
		cast_label.modulate = Color(1, 0.95, 0.4, 1)
	)


func _emit_core_highlight(title: String, subtitle: String, detail: String) -> void:
	EventBus.combat_highlight_requested.emit({
		"highlight_type": "core_skill",
		"title": title,
		"subtitle": subtitle,
		"detail": detail,
	})


func _emit_skill_highlight(skill_data: Dictionary, effect: Dictionary, hit_summary: Dictionary, highlight_type: String) -> void:
	var subtitle: String = String(skill_data.get("description", ""))
	if String(effect.get("kind", "")) == "buff":
		subtitle = "持续 %.1f 秒" % float(effect.get("duration", 0.0))
	elif int(hit_summary.get("hit_count", 0)) > 0:
		subtitle = "命中 %d 个目标" % int(hit_summary.get("hit_count", 0))
	var detail: String = "真气 %d/%d" % [int(round(current_resource)), int(round(max_resource))]
	EventBus.combat_highlight_requested.emit({
		"highlight_type": highlight_type,
		"title": String(skill_data.get("name", "技能")),
		"subtitle": subtitle,
		"detail": detail,
	})


func _emit_hp_state() -> void:
	EventBus.player_hp_changed.emit(current_hp, max_hp)


func _emit_resource_state(force: bool = false) -> void:
	var rounded_value: int = int(round(current_resource))
	if not force and rounded_value == last_emitted_resource_value:
		return
	last_emitted_resource_value = rounded_value
	EventBus.player_resource_changed.emit(current_resource, max_resource)


func _reset_base_stats() -> void:
	max_hp = 160.0
	current_hp = 160.0
	attack = 18.0
	defense = 8.0
	move_speed = 120.0
	attack_interval = 0.65
	attack_range = MELEE_ATTACK_RANGE
	current_resource = 42.0
	max_resource = MAX_RESOURCE
	resource_regen_per_second = BASE_RESOURCE_REGEN
	resource_cost_reduction = 0.0
	core_bonus_percent = 0.0
	core_damage_bonus_percent = 0.0
	whirlwind_radius = 120.0
	bleed_dot_bonus_percent = 0.0
	execute_threshold = 0.0
	chain_count_bonus = 0
	chain_damage_bonus_percent = 0.0
	core_cooldown_reduction = 0.0
	combat_params = {}
	combat_bonuses = {}
	active_buffs.clear()


func _reset_skill_runtime() -> void:
	skill_timers = {
		"basic": 0.0,
		"core": 1.5,
		"tactic": 0.6,
		"burst": 1.2,
	}


func _apply_portrait_visual(force_restart: bool = false) -> void:
	if portrait_frames == null:
		_build_portrait_frames()
	portrait_visual.sprite_frames = portrait_frames
	if not portrait_frames.has_animation(portrait_state):
		portrait_state = "idle"
	var frame_count: int = portrait_frames.get_frame_count(portrait_state)
	portrait_visual.visible = frame_count > 0
	body_visual.visible = frame_count == 0
	if frame_count <= 0:
		return
	var should_restart: bool = force_restart or portrait_visual.animation != portrait_state
	if should_restart:
		portrait_visual.play(portrait_state)
	portrait_visual.speed_scale = float(HERO_ANIMATION_FPS.get(portrait_state, 1.0))
	if should_restart and portrait_visual.animation == portrait_state:
		portrait_visual.frame = 0
	_apply_portrait_tint()


func _apply_portrait_tint() -> void:
	if portrait_visual.sprite_frames == null or portrait_visual.sprite_frames.get_frame_count(portrait_state) <= 0:
		return
	match school_id:
		"xuejie":
			portrait_visual.modulate = Color(1.0, 0.9, 0.9, 1.0)
		"wulei":
			portrait_visual.modulate = Color(0.92, 0.94, 1.0, 1.0)
		_:
			portrait_visual.modulate = Color(1, 1, 1, 1)


func _update_portrait_state() -> void:
	if attack_animation_locked:
		return
	var next_state: String = "idle"
	if should_move or forward_run_in_place:
		next_state = "move"
	elif target != null and is_instance_valid(target):
		next_state = "combat"
	if next_state == portrait_state:
		return
	portrait_state = next_state
	_apply_portrait_visual(true)


func _trigger_attack_animation() -> void:
	if attack_animation_locked:
		return
	attack_animation_locked = true
	portrait_state = "attack"
	_apply_portrait_visual(true)


func _on_portrait_animation_finished() -> void:
	if portrait_visual.animation != "attack":
		return
	attack_animation_locked = false
	_update_portrait_state()


func _load_runtime_texture(resource_path: String) -> Texture2D:
	return RuntimeTextureLoader.load_texture(resource_path)


func _build_portrait_frames() -> void:
	portrait_frames = SpriteFrames.new()
	for animation_name in HERO_ANIMATION_PATHS.keys():
		portrait_frames.add_animation(animation_name)
		var resolved_paths: Array[String] = _resolve_animation_paths(animation_name)
		var animation_fps: float = _resolve_animation_fps(animation_name, resolved_paths.size())
		portrait_frames.set_animation_speed(animation_name, animation_fps)
		portrait_frames.set_animation_loop(animation_name, bool(HERO_ANIMATION_LOOP.get(animation_name, true)))
		for resource_path in resolved_paths:
			var texture: Texture2D = _load_runtime_texture(String(resource_path))
			if texture != null:
				portrait_frames.add_frame(animation_name, texture)


func _resolve_animation_paths(animation_name: String) -> Array[String]:
	var resolved: Array[String] = []
	for resource_path in HERO_ANIMATION_PATHS.get(animation_name, []):
		var texture: Texture2D = _load_runtime_texture(String(resource_path))
		if texture != null:
			resolved.append(String(resource_path))
	if animation_name == "move" and resolved.size() < 4:
		resolved.clear()
		for fallback_path in HERO_ANIMATION_PATHS["move"].slice(0, 4):
			if _load_runtime_texture(String(fallback_path)) != null:
				resolved.append(String(fallback_path))
	return resolved


func _resolve_animation_fps(animation_name: String, frame_count: int) -> float:
	if animation_name == "move":
		if frame_count >= 6:
			return 2.1
		return 1.4
	return float(HERO_ANIMATION_FPS.get(animation_name, 1.0))


func _apply_visual_layout() -> void:
	portrait_visual.scale = PLAYER_PORTRAIT_SCALE
	portrait_visual.position = PLAYER_PORTRAIT_POSITION
	body_visual.scale = PLAYER_BODY_SCALE
	health_marker_back.position = PLAYER_HEALTH_MARKER_POSITION
	health_marker_fill.position = PLAYER_HEALTH_MARKER_POSITION
	hp_bar.offset_left = PLAYER_HP_BAR_OFFSETS["left"]
	hp_bar.offset_top = PLAYER_HP_BAR_OFFSETS["top"]
	hp_bar.offset_right = PLAYER_HP_BAR_OFFSETS["right"]
	hp_bar.offset_bottom = PLAYER_HP_BAR_OFFSETS["bottom"]
	hp_bar.visible = false
	cast_label.offset_left = PLAYER_CAST_LABEL_OFFSETS["left"]
	cast_label.offset_top = PLAYER_CAST_LABEL_OFFSETS["top"]
	cast_label.offset_right = PLAYER_CAST_LABEL_OFFSETS["right"]
	cast_label.offset_bottom = PLAYER_CAST_LABEL_OFFSETS["bottom"]
	_update_health_marker()


func _update_health_marker() -> void:
	var ratio: float = 1.0 if max_hp <= 0.0 else clampf(current_hp / max_hp, 0.0, 1.0)
	var x_scale: float = PLAYER_HEALTH_MARKER_MIN_SCALE + (1.0 - PLAYER_HEALTH_MARKER_MIN_SCALE) * ratio
	health_marker_fill.scale = Vector2(x_scale, 1.0)
	health_marker_fill.visible = current_hp > 0.0
