class_name PlayerActor
extends CharacterBody2D

const DamageResolverScript = preload("res://scripts/combat/damage_resolver.gd")
const HERO_PORTRAIT_PATH := "res://assets/generated/portraits/hero_placeholder.png"

signal died()

@onready var body_visual: Polygon2D = $BodyVisual
@onready var portrait_visual: Sprite2D = $PortraitVisual
@onready var hp_bar: ProgressBar = $HpBar
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

var core_skill_id: String = "core_whirlwind"
var core_skill_name: String = "旋风斩"
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


func _ready() -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp
	idle_anchor_x = global_position.x
	_apply_portrait_visual()


func setup_from_skill(skill_data: Dictionary) -> void:
	core_skill_id = String(skill_data.get("id", "core_whirlwind"))
	core_skill_name = String(skill_data.get("name", "旋风斩"))

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

	current_hp = max_hp
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp
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
	var raw_damage: float = DamageResolverScript.build_damage(attack, 1.0)
	enemy.take_damage(raw_damage, [], {"source": "basic"})


func _cast_core_skill() -> void:
	match core_skill_id:
		"core_whirlwind":
			_show_cast_feedback("旋风!")
			_cast_whirlwind()
		"core_deep_wound":
			if target and is_instance_valid(target):
				_show_cast_feedback("裂伤!")
				var raw_damage: float = DamageResolverScript.build_damage(attack, 1.6, core_bonus_percent + core_damage_bonus_percent)
				target.take_damage(raw_damage, ["bleed"], {
					"source": "bleed",
					"bleed_dot_percent": bleed_dot_bonus_percent,
					"execute_threshold": execute_threshold,
				})
		"core_chain_lightning":
			_show_cast_feedback("连锁!")
			_cast_chain_lightning()
		_:
			if target and is_instance_valid(target):
				var raw_damage: float = DamageResolverScript.build_damage(attack, 1.3, core_bonus_percent + core_damage_bonus_percent)
				target.take_damage(raw_damage, [], {"source": "core"})


func _cast_whirlwind() -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemy_actor")
	for node in enemies:
		if is_instance_valid(node):
			if global_position.distance_to(node.global_position) <= whirlwind_radius:
				var raw_damage: float = DamageResolverScript.build_damage(attack, 1.2, core_bonus_percent + core_damage_bonus_percent)
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
		var multiplier: float = (1.4 - (float(i) * 0.2)) * (1.0 + chain_damage_bonus_percent + core_damage_bonus_percent)
		var raw_damage: float = DamageResolverScript.build_damage(attack, multiplier, core_bonus_percent)
		enemy.take_damage(raw_damage, [], {"source": "chain_lightning"})


func take_damage(raw_damage: float, attacker_defense: float = 0.0) -> void:
	var adjusted_raw: float = maxf(1.0, raw_damage - attacker_defense * 0.2)
	var actual_damage: float = DamageResolverScript.apply_defense(adjusted_raw, defense)
	current_hp = maxf(0.0, current_hp - actual_damage)
	hp_bar.value = current_hp
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
	EventBus.player_hp_changed.emit(current_hp, max_hp)


func set_idle_anchor_x(value: float) -> void:
	idle_anchor_x = value


func set_movement_bounds(left_bound: float, right_bound: float) -> void:
	movement_left_bound = left_bound
	movement_right_bound = right_bound


func _show_cast_feedback(text: String) -> void:
	cast_label.text = text
	cast_label.modulate = Color(1, 0.95, 0.4, 1)
	cast_label.position = Vector2(-50.0, -62.0)
	if cast_tween:
		cast_tween.kill()
	cast_tween = create_tween()
	cast_tween.tween_property(cast_label, "position:y", cast_label.position.y - 12.0, 0.28)
	cast_tween.parallel().tween_property(cast_label, "modulate:a", 0.0, 0.28)
	cast_tween.finished.connect(func() -> void:
		cast_label.text = ""
		cast_label.modulate = Color(1, 0.95, 0.4, 1)
	)


func _apply_portrait_visual() -> void:
	var portrait_texture: Texture2D = _load_runtime_texture(HERO_PORTRAIT_PATH)
	portrait_visual.texture = portrait_texture
	portrait_visual.visible = portrait_texture != null
	body_visual.visible = portrait_texture == null
	_apply_portrait_tint()


func _apply_portrait_tint() -> void:
	if portrait_visual.texture == null:
		return

	match core_skill_id:
		"core_deep_wound":
			portrait_visual.modulate = Color(1.0, 0.9, 0.9, 1.0)
		"core_chain_lightning":
			portrait_visual.modulate = Color(0.92, 0.94, 1.0, 1.0)
		_:
			portrait_visual.modulate = Color(1, 1, 1, 1)


func _load_runtime_texture(resource_path: String) -> Texture2D:
	return RuntimeTextureLoader.load_texture(resource_path)
