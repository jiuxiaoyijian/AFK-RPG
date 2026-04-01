class_name EnemyActor
extends CharacterBody2D

const DamageResolverScript = preload("res://scripts/combat/damage_resolver.gd")
const ENEMY_PORTRAIT_PATHS := {
	"normal": "res://assets/generated/portraits/enemy_normal_placeholder.png",
	"elite": "res://assets/generated/portraits/enemy_elite_placeholder.png",
	"boss": "res://assets/generated/afk_rpg_formal/bosses/boss_fuci_shanjun_v2.png",
}
const ENEMY_PORTRAIT_PATHS_BY_ID := {
	"boss_iron_beast": "res://assets/generated/afk_rpg_formal/bosses/boss_fuci_shanjun_v2.png",
	"boss_magma_overseer": "res://assets/generated/afk_rpg_formal/bosses/boss_jilu_jianyuan_v2.png",
	"boss_silver_hook_elder": "res://assets/generated/afk_rpg_formal/bosses/boss_yingou_laoren_v1.png",
}
const ENEMY_LAYOUTS := {
	"normal": {
		"portrait_scale": Vector2(0.22, 0.22),
		"portrait_position": Vector2(0.0, -18.0),
		"body_scale": Vector2(2.15, 2.15),
		"hp_left": -36.0,
		"hp_top": -94.0,
		"hp_right": 36.0,
		"hp_bottom": -82.0,
		"status_left": -46.0,
		"status_top": -120.0,
		"status_right": 46.0,
		"status_bottom": -100.0,
		"feedback_position": Vector2(-54.0, -136.0),
	},
	"elite": {
		"portrait_scale": Vector2(0.24, 0.24),
		"portrait_position": Vector2(0.0, -22.0),
		"body_scale": Vector2(2.35, 2.35),
		"hp_left": -40.0,
		"hp_top": -104.0,
		"hp_right": 40.0,
		"hp_bottom": -92.0,
		"status_left": -48.0,
		"status_top": -132.0,
		"status_right": 48.0,
		"status_bottom": -110.0,
		"feedback_position": Vector2(-58.0, -150.0),
	},
	"boss": {
		"portrait_scale": Vector2(0.3, 0.3),
		"portrait_position": Vector2(0.0, -30.0),
		"body_scale": Vector2(2.85, 2.85),
		"hp_left": -50.0,
		"hp_top": -126.0,
		"hp_right": 50.0,
		"hp_bottom": -112.0,
		"status_left": -58.0,
		"status_top": -158.0,
		"status_right": 58.0,
		"status_bottom": -134.0,
		"feedback_position": Vector2(-68.0, -178.0),
	},
}
const ENEMY_MOVE_SPEED_MULTIPLIER := 1.65
const ENEMY_HP_BAR_BACKGROUND := Color(0.15, 0.04, 0.04, 0.92)
const ENEMY_HP_BAR_FILL := Color(0.88, 0.18, 0.16, 0.98)
const ENEMY_HP_BAR_BORDER := Color(0.42, 0.10, 0.10, 1.0)

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
	_apply_hp_bar_theme()


func setup_from_config(data: Dictionary) -> void:
	enemy_id = String(data.get("id", "enemy"))
	enemy_name = String(data.get("name", enemy_id))
	enemy_type = String(data.get("enemy_type", "normal"))
	max_hp = float(data.get("hp", 10.0))
	current_hp = max_hp
	attack = float(data.get("attack", 1.0))
	defense = float(data.get("defense", 0.0))
	move_speed = float(data.get("move_speed", 40.0)) * ENEMY_MOVE_SPEED_MULTIPLIER
	attack_interval = float(data.get("attack_interval", 1.2))
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp

	match enemy_type:
		"elite":
			body_visual.color = Color(0.82, 0.45, 0.18, 1.0)
		"boss":
			body_visual.color = Color(0.75, 0.18, 0.18, 1.0)
			attack_range = 68.0
		_:
			body_visual.color = Color(0.32, 0.75, 0.36, 1.0)

	scale = Vector2.ONE
	_apply_visual_layout()
	_apply_portrait_visual()
	_apply_hp_bar_theme()


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
	feedback_label.position = _get_feedback_position()
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


func _apply_visual_layout() -> void:
	var layout: Dictionary = ENEMY_LAYOUTS.get(enemy_type, ENEMY_LAYOUTS["normal"])
	portrait_visual.scale = layout["portrait_scale"]
	portrait_visual.position = layout["portrait_position"]
	body_visual.scale = layout["body_scale"]
	hp_bar.offset_left = layout["hp_left"]
	hp_bar.offset_top = layout["hp_top"]
	hp_bar.offset_right = layout["hp_right"]
	hp_bar.offset_bottom = layout["hp_bottom"]
	status_label.offset_left = layout["status_left"]
	status_label.offset_top = layout["status_top"]
	status_label.offset_right = layout["status_right"]
	status_label.offset_bottom = layout["status_bottom"]


func _get_feedback_position() -> Vector2:
	var layout: Dictionary = ENEMY_LAYOUTS.get(enemy_type, ENEMY_LAYOUTS["normal"])
	return layout["feedback_position"]


func _apply_hp_bar_theme() -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = ENEMY_HP_BAR_BACKGROUND
	background.corner_radius_top_left = 999
	background.corner_radius_top_right = 999
	background.corner_radius_bottom_left = 999
	background.corner_radius_bottom_right = 999
	background.border_color = ENEMY_HP_BAR_BORDER
	background.border_width_left = 1
	background.border_width_top = 1
	background.border_width_right = 1
	background.border_width_bottom = 1

	var fill := StyleBoxFlat.new()
	fill.bg_color = ENEMY_HP_BAR_FILL
	fill.corner_radius_top_left = 999
	fill.corner_radius_top_right = 999
	fill.corner_radius_bottom_left = 999
	fill.corner_radius_bottom_right = 999

	hp_bar.add_theme_stylebox_override("background", background)
	hp_bar.add_theme_stylebox_override("fill", fill)
	hp_bar.modulate = Color(1, 1, 1, 1)
