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
var core_cooldown: float = 5.0
var core_bonus_percent: float = 0.0
var core_damage_bonus_percent: float = 0.0
var whirlwind_radius: float = 120.0
var bleed_dot_bonus_percent: float = 0.0
var execute_threshold: float = 0.0
var chain_count_bonus: int = 0
var chain_damage_bonus_percent: float = 0.0
var combat_params: Dictionary = {}

var core_skill_id: String = "core_whirlwind"
var core_skill_name: String = "御风道"
const IDLE_RETURN_THRESHOLD := 4.0
const IDLE_RETURN_SPEED_MULTIPLIER := 0.75

var basic_attack_timer: float = 0.0
var core_attack_timer: float = 1.5
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


func _ready() -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp
	idle_anchor_x = global_position.x
	_apply_visual_layout()
	_build_portrait_frames()
	portrait_visual.animation_finished.connect(_on_portrait_animation_finished)
	_apply_portrait_visual(true)


func setup_from_skill(skill_data: Dictionary) -> void:
	core_skill_id = String(skill_data.get("id", "core_whirlwind"))
	core_skill_name = String(skill_data.get("name", "御风道"))

	max_hp = 160.0
	current_hp = max_hp
	attack = 18.0
	defense = 8.0
	move_speed = 120.0
	attack_interval = 0.65
	attack_range = 72.0
	core_cooldown = float(skill_data.get("cooldown", 5.0))
	core_bonus_percent = 0.0
	core_damage_bonus_percent = 0.0
	whirlwind_radius = 120.0
	bleed_dot_bonus_percent = 0.0
	execute_threshold = 0.0
	chain_count_bonus = 0
	chain_damage_bonus_percent = 0.0

	match core_skill_id:
		"core_whirlwind":
			attack = 16.0
			attack_interval = 0.45
			attack_range = 84.0
			core_bonus_percent = 0.15
			body_visual.color = Color(0.28, 0.66, 1.0, 1.0)
		"core_deep_wound":
			attack = 21.0
			attack_interval = 0.72
			attack_range = 80.0
			core_bonus_percent = 0.20
			body_visual.color = Color(0.9, 0.25, 0.32, 1.0)
		"core_chain_lightning":
			attack = 17.0
			attack_interval = 0.62
			attack_range = 180.0
			core_bonus_percent = 0.10
			body_visual.color = Color(0.68, 0.45, 1.0, 1.0)
		_:
			body_visual.color = Color(0.28, 0.66, 1.0, 1.0)

	_apply_portrait_tint()

	var bonuses: Dictionary = GameManager.get_total_combat_bonuses()
	attack += float(bonuses.get("attack_flat", 0.0))
	max_hp += float(bonuses.get("hp_flat", 0.0))
	defense += float(bonuses.get("defense_flat", 0.0))
	attack *= 1.0 + float(bonuses.get("attack_percent", 0.0))
	attack_interval = maxf(0.18, attack_interval / (1.0 + float(bonuses.get("attack_speed_percent", 0.0))))
	core_damage_bonus_percent = float(bonuses.get("core_damage_percent", 0.0))
	core_cooldown = maxf(0.8, core_cooldown * (1.0 - float(bonuses.get("core_cooldown_reduction", 0.0))))
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

	current_hp = max_hp
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp
	_update_health_marker()
	EventBus.player_hp_changed.emit(current_hp, max_hp)


func _physics_process(delta: float) -> void:
	if current_hp <= 0.0:
		return

	if should_move:
		var target_x: float = global_position.x
		if target != null and is_instance_valid(target):
			target_x = target.global_position.x
		else:
			target_x = idle_anchor_x
		global_position.x = move_toward(global_position.x, clampf(target_x, movement_left_bound, movement_right_bound), move_speed * delta)
		status_text = "追击中"
	elif forward_run_in_place:
		status_text = "推进中"
	elif target == null or not is_instance_valid(target):
		var distance_to_anchor: float = idle_anchor_x - global_position.x
		if absf(distance_to_anchor) > IDLE_RETURN_THRESHOLD:
			global_position.x = move_toward(global_position.x, idle_anchor_x, move_speed * IDLE_RETURN_SPEED_MULTIPLIER * delta)
			status_text = "归位中"
		else:
			status_text = "待机中"
	else:
		status_text = "战斗中"

	global_position.x = clampf(global_position.x, movement_left_bound, movement_right_bound)
	_update_portrait_state()

	if target == null or not is_instance_valid(target):
		return

	basic_attack_timer -= delta
	core_attack_timer -= delta

	if global_position.distance_to(target.global_position) <= attack_range:
		if basic_attack_timer <= 0.0:
			basic_attack_timer = attack_interval
			_basic_attack(target)

		if core_attack_timer <= 0.0:
			core_attack_timer = core_cooldown
			_cast_core_skill()


func _basic_attack(enemy: Node) -> void:
	_trigger_attack_animation()
	var params: Dictionary = combat_params.duplicate()
	params["weapon_damage"] = attack
	var is_crit: bool = DamageResolverScript.is_critical_hit(params.get("crit_rate", 0.0))
	var raw_damage: float
	if is_crit:
		raw_damage = DamageResolverScript.build_damage(attack, 1.0) * (1.0 + float(params.get("crit_damage", 0.5)))
	else:
		raw_damage = DamageResolverScript.build_damage(attack, 1.0)
	enemy.take_damage(raw_damage, [], {"source": "basic", "is_crit": is_crit})


func _cast_core_skill() -> void:
	_trigger_attack_animation()
	match core_skill_id:
		"core_whirlwind":
			_show_cast_feedback("旋风!")
			_emit_core_highlight("御风回斩", "风痕已成阵", "保持贴近敌群，吃满风刃回环收益")
			_cast_whirlwind()
		"core_deep_wound":
			if target and is_instance_valid(target):
				_show_cast_feedback("裂伤!")
				_emit_core_highlight("血劫断命", "血线与断命线同步抬升", "观察目标是否已经进入断命时机")
				var raw_damage: float = _calc_core_damage(1.6)
				target.take_damage(raw_damage, ["bleed"], {
					"source": "bleed",
					"bleed_dot_percent": bleed_dot_bonus_percent,
					"execute_threshold": execute_threshold,
				})
		"core_chain_lightning":
			_show_cast_feedback("连锁!")
			_emit_core_highlight(
				"五雷连引",
				"本次引雷 %d 段" % mini(3 + chain_count_bonus, get_tree().get_nodes_in_group("enemy_actor").size()),
				"优先观察攻速、引雷次数和雷痕伤害反馈"
			)
			_cast_chain_lightning()
		_:
			if target and is_instance_valid(target):
				var raw_damage: float = _calc_core_damage(1.3)
				target.take_damage(raw_damage, [], {"source": "core"})


func _cast_whirlwind() -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemy_actor")
	for node in enemies:
		if is_instance_valid(node):
			if global_position.distance_to(node.global_position) <= whirlwind_radius:
				var raw_damage: float = _calc_core_damage(1.2)
				node.take_damage(raw_damage, [], {"source": "whirlwind"})


func _cast_chain_lightning() -> void:
	var enemies: Array = []
	for node in get_tree().get_nodes_in_group("enemy_actor"):
		if is_instance_valid(node):
			enemies.append(node)

	enemies.sort_custom(func(a, b) -> bool:
		return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position)
	)

	var remaining_hits: int = mini(3 + chain_count_bonus, enemies.size())
	for i in remaining_hits:
		var enemy: Node = enemies[i]
		var chain_mult: float = 1.4 - (float(i) * 0.2)
		var raw_damage: float = _calc_core_damage(chain_mult * (1.0 + chain_damage_bonus_percent))
		enemy.take_damage(raw_damage, [], {"source": "chain_lightning"})


func _calc_core_damage(skill_multiplier: float) -> float:
	var params: Dictionary = combat_params.duplicate()
	params["weapon_damage"] = attack * skill_multiplier * (1.0 + core_bonus_percent + core_damage_bonus_percent)
	return DamageResolverScript.calculate_damage(params)


func take_damage(raw_damage: float, attacker_defense: float = 0.0) -> void:
	var adjusted_raw: float = maxf(1.0, raw_damage - attacker_defense * 0.2)
	var actual_damage: float = DamageResolverScript.apply_defense(adjusted_raw, defense)
	current_hp = maxf(0.0, current_hp - actual_damage)
	hp_bar.value = current_hp
	_update_health_marker()
	EventBus.player_hp_changed.emit(current_hp, max_hp)
	if current_hp <= 0.0:
		died.emit()


func reset_state() -> void:
	current_hp = max_hp
	basic_attack_timer = 0.0
	core_attack_timer = 1.5
	target = null
	should_move = false
	hp_bar.value = current_hp
	_update_health_marker()
	EventBus.player_hp_changed.emit(current_hp, max_hp)
	forward_run_in_place = false


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

	match core_skill_id:
		"core_deep_wound":
			portrait_visual.modulate = Color(1.0, 0.9, 0.9, 1.0)
		"core_chain_lightning":
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
