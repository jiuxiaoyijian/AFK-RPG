class_name EnemyActor
extends CharacterBody2D

const DamageResolverScript = preload("res://scripts/combat/damage_resolver.gd")
const ENEMY_PORTRAIT_PATHS := {
	"normal": "res://assets/generated/portraits/enemy_normal_placeholder.png",
	"elite": "res://assets/generated/portraits/enemy_elite_placeholder.png",
	"boss": "res://assets/generated/afk_rpg_formal/bosses/boss_fuci_shanjun_battle_stance.png",
}
const ENEMY_PORTRAIT_PATHS_BY_ID := {
	"boss_iron_beast": "res://assets/generated/afk_rpg_formal/bosses/boss_fuci_shanjun_battle_stance.png",
	"boss_magma_overseer": "res://assets/generated/afk_rpg_formal/bosses/boss_jilu_jianyuan_staff_standing.png",
}

signal died(enemy_id: String, world_position: Vector2, enemy_type: String)

@onready var body_visual: Polygon2D = $BodyVisual
@onready var portrait_visual: Sprite2D = $PortraitVisual
@onready var hp_bar: ProgressBar = $HpBar
@onready var status_label: Label = $StatusLabel
@onready var feedback_label: Label = $FeedbackLabel

var enemy_id: String = ""
var enemy_name: String = ""
var enemy_type: String = "normal"
var max_hp: float = 10.0
var current_hp: float = 10.0
var attack: float = 1.0
var defense: float = 0.0
var move_speed: float = 40.0
var attack_interval: float = 1.2
var attack_range: float = 52.0
var spawn_side: int = 1

var target: Node2D
var attack_timer: float = 0.0
var bleed_ticks: Array[Dictionary] = []
var feedback_tween: Tween


func _ready() -> void:
	add_to_group("enemy_actor")


func setup_from_config(data: Dictionary) -> void:
	enemy_id = String(data.get("id", "enemy"))
	enemy_name = String(data.get("name", enemy_id))
	enemy_type = String(data.get("enemy_type", "normal"))
	max_hp = float(data.get("hp", 10.0))
	current_hp = max_hp
	attack = float(data.get("attack", 1.0))
	defense = float(data.get("defense", 0.0))
	move_speed = float(data.get("move_speed", 40.0))
	attack_interval = float(data.get("attack_interval", 1.2))
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp

	match enemy_type:
		"elite":
			body_visual.color = Color(0.82, 0.45, 0.18, 1.0)
			portrait_visual.scale = Vector2(0.1, 0.1)
		"boss":
			body_visual.color = Color(0.75, 0.18, 0.18, 1.0)
			scale = Vector2(1.3, 1.3)
			attack_range = 68.0
			portrait_visual.scale = Vector2(0.12, 0.12)
		_:
			body_visual.color = Color(0.32, 0.75, 0.36, 1.0)
			portrait_visual.scale = Vector2(0.09, 0.09)

	_apply_portrait_visual()


func _physics_process(delta: float) -> void:
	if current_hp <= 0.0:
		return

	_process_bleed(delta)

	if target == null or not is_instance_valid(target):
		return

	var distance: float = global_position.distance_to(target.global_position)
	if distance > attack_range:
		var direction: float = signf(target.global_position.x - global_position.x)
		if is_zero_approx(direction):
			direction = float(spawn_side) * -1.0
		global_position.x += direction * move_speed * delta
	else:
		attack_timer -= delta
		if attack_timer <= 0.0:
			attack_timer = attack_interval
			if target.has_method("take_damage"):
				target.take_damage(attack, defense)


func take_damage(raw_damage: float, attacker_tags: Array = [], attacker_payload: Dictionary = {}) -> void:
	var actual_damage: float = DamageResolverScript.apply_defense(raw_damage, defense)
	current_hp = maxf(0.0, current_hp - actual_damage)
	hp_bar.value = current_hp
	var emphasis: float = 1.0
	if enemy_type == "elite":
		emphasis = 1.12
	elif enemy_type == "boss":
		emphasis = 1.28
	if String(attacker_payload.get("source", "")) in ["whirlwind", "bleed", "chain_lightning", "core"]:
		emphasis += 0.12
	_show_feedback("-%d" % int(actual_damage), _get_hit_color(attacker_payload), emphasis)
	_flash_body(_get_hit_color(attacker_payload))
	if current_hp <= 0.0:
		died.emit(enemy_id, global_position, enemy_type)
		queue_free()
		return

	if attacker_tags.has("bleed"):
		var bleed_multiplier: float = 0.22 * (1.0 + float(attacker_payload.get("bleed_dot_percent", 0.0)))
		_apply_bleed(2.8, maxf(1.0, raw_damage * bleed_multiplier))
		var execute_threshold: float = float(attacker_payload.get("execute_threshold", 0.0))
		if execute_threshold > 0.0 and current_hp <= max_hp * execute_threshold:
			_show_feedback("处决", Color(1.0, 0.2, 0.2, 1.0), 1.36)
			current_hp = 0.0
			hp_bar.value = current_hp
			died.emit(enemy_id, global_position, enemy_type)
			queue_free()
	update_status_label(attacker_payload)


func _apply_bleed(duration: float, tick_damage: float) -> void:
	bleed_ticks.append({
		"time_left": duration,
		"tick_damage": tick_damage,
		"tick_timer": 1.0,
	})


func _process_bleed(delta: float) -> void:
	if bleed_ticks.is_empty():
		return

	for effect in bleed_ticks:
		effect["time_left"] = float(effect["time_left"]) - delta
		effect["tick_timer"] = float(effect["tick_timer"]) - delta
		if float(effect["tick_timer"]) <= 0.0:
			effect["tick_timer"] = 1.0
			var actual_damage: float = DamageResolverScript.apply_defense(float(effect["tick_damage"]), defense * 0.5)
			current_hp = maxf(0.0, current_hp - actual_damage)
			hp_bar.value = current_hp
			_show_feedback("流血 %d" % int(actual_damage), Color(1.0, 0.35, 0.35, 1.0), 1.08)

	for index in range(bleed_ticks.size() - 1, -1, -1):
		if float(bleed_ticks[index]["time_left"]) <= 0.0:
			bleed_ticks.remove_at(index)

	if current_hp <= 0.0:
		died.emit(enemy_id, global_position, enemy_type)
		queue_free()

	update_status_label({})


func update_status_label(attacker_payload: Dictionary) -> void:
	var tags: Array[String] = []
	if not bleed_ticks.is_empty():
		tags.append("流血")
	var execute_threshold: float = float(attacker_payload.get("execute_threshold", 0.0))
	if execute_threshold > 0.0 and current_hp <= max_hp * execute_threshold:
		tags.append("斩杀线")
	if enemy_type == "boss":
		tags.append("Boss")
	status_label.text = " ".join(tags)


func _show_feedback(text: String, color: Color, emphasis: float = 1.0) -> void:
	feedback_label.text = text
	feedback_label.modulate = color
	feedback_label.position = Vector2(-40.0, -74.0)
	feedback_label.scale = Vector2.ONE * emphasis
	if feedback_tween:
		feedback_tween.kill()
	feedback_tween = create_tween()
	feedback_tween.tween_property(feedback_label, "position:y", feedback_label.position.y - 14.0, 0.35)
	feedback_tween.parallel().tween_property(feedback_label, "scale", Vector2.ONE * 0.92, 0.35)
	feedback_tween.parallel().tween_property(feedback_label, "modulate:a", 0.0, 0.35)
	feedback_tween.finished.connect(func() -> void:
		feedback_label.text = ""
		feedback_label.modulate = Color(1, 1, 1, 1)
		feedback_label.scale = Vector2.ONE
	)


func _flash_body(color: Color) -> void:
	body_visual.color = color
	var tween := create_tween()
	tween.tween_property(body_visual, "color", _get_base_color(), 0.15)


func _get_hit_color(attacker_payload: Dictionary) -> Color:
	match String(attacker_payload.get("source", "")):
		"whirlwind":
			return Color(0.3, 0.72, 1.0, 1.0)
		"bleed":
			return Color(1.0, 0.35, 0.35, 1.0)
		"chain_lightning":
			return Color(0.72, 0.5, 1.0, 1.0)
		_:
			return Color(1.0, 1.0, 1.0, 1.0)


func _get_base_color() -> Color:
	match enemy_type:
		"elite":
			return Color(0.82, 0.45, 0.18, 1.0)
		"boss":
			return Color(0.75, 0.18, 0.18, 1.0)
		_:
			return Color(0.32, 0.75, 0.36, 1.0)


func _apply_portrait_visual() -> void:
	var texture_path: String = String(ENEMY_PORTRAIT_PATHS_BY_ID.get(enemy_id, ""))
	if texture_path.is_empty():
		texture_path = String(ENEMY_PORTRAIT_PATHS.get(enemy_type, ENEMY_PORTRAIT_PATHS["normal"]))
	var portrait_texture: Texture2D = _load_runtime_texture(texture_path)
	portrait_visual.texture = portrait_texture
	portrait_visual.visible = portrait_texture != null
	body_visual.visible = portrait_texture == null
	if portrait_texture != null:
		portrait_visual.modulate = Color(1, 1, 1, 1)


func _load_runtime_texture(resource_path: String) -> Texture2D:
	return RuntimeTextureLoader.load_texture(resource_path)


func set_spawn_side(value: int) -> void:
	spawn_side = value
