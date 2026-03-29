class_name LootDropVisual
extends Node2D

@onready var shadow: Polygon2D = $Shadow
@onready var beam_glow: Polygon2D = $BeamGlow
@onready var beam: Polygon2D = $Beam
@onready var backdrop: Polygon2D = $Backdrop
@onready var icon_sprite: Sprite2D = $IconSprite
@onready var name_label: Label = $NameLabel

var life_tween: Tween
var pulse_tween: Tween
var collect_tween: Tween
var drop_state: String = "spawning"
var start_position: Vector2 = Vector2.ZERO
var ground_position: Vector2 = Vector2.ZERO
var drop_duration: float = 0.45
var drop_elapsed: float = 0.0
var arc_height: float = 40.0
var grounded_time: float = 0.0
var auto_pickup_delay: float = 3.0
var pickup_target_id: String = "resources"
var collect_particles: Array[Polygon2D] = []
var collect_overlay_parent: Node


func setup(drop_data: Dictionary) -> void:
	var tint: Color = drop_data.get("tint", Color(1, 1, 1, 1))
	var beam_color: Color = drop_data.get("beam_color", tint)
	var show_beam: bool = bool(drop_data.get("show_beam", false))
	var show_label: bool = bool(drop_data.get("show_label", true))
	var icon_path: String = String(drop_data.get("icon_path", ""))
	var visual_scale: float = float(drop_data.get("visual_scale", 1.0))
	var spread: float = float(drop_data.get("spread", 32.0))
	auto_pickup_delay = float(drop_data.get("auto_pickup_delay", 3.0))
	pickup_target_id = String(drop_data.get("pickup_target", "resources"))
	drop_duration = float(drop_data.get("drop_duration", 0.42))
	arc_height = float(drop_data.get("arc_height", 42.0))
	z_index = int(drop_data.get("z_index", 20))

	scale = Vector2.ONE * visual_scale
	shadow.color = Color(0, 0, 0, 0.28)
	backdrop.color = Color(tint.r, tint.g, tint.b, 0.22)
	icon_sprite.texture = _load_runtime_texture(icon_path)
	icon_sprite.modulate = tint
	name_label.text = String(drop_data.get("label", ""))
	name_label.visible = show_label and not name_label.text.is_empty()
	name_label.add_theme_color_override("font_color", tint.lightened(0.18))

	beam.visible = show_beam
	beam_glow.visible = show_beam
	beam.color = Color(beam_color.r, beam_color.g, beam_color.b, 0.46)
	beam_glow.color = Color(beam_color.r, beam_color.g, beam_color.b, 0.20)
	beam.modulate = Color(1, 1, 1, 0)
	beam_glow.modulate = Color(1, 1, 1, 0)

	_start_drop_arc(spread, show_beam)


func _process(delta: float) -> void:
	match drop_state:
		"dropping":
			_update_drop_arc(delta)
		"grounded":
			grounded_time += delta
		_:
			pass


func _exit_tree() -> void:
	if life_tween:
		life_tween.kill()
	if pulse_tween:
		pulse_tween.kill()
	if collect_tween:
		collect_tween.kill()


func can_active_pickup() -> bool:
	return drop_state == "grounded"


func should_auto_pickup() -> bool:
	return drop_state == "grounded" and grounded_time >= auto_pickup_delay


func get_pickup_target_id() -> String:
	return pickup_target_id


func set_collect_overlay_parent(parent_node: Node) -> void:
	collect_overlay_parent = parent_node


func begin_collect(target_position: Vector2) -> void:
	if drop_state == "collecting" or drop_state == "finished":
		return

	drop_state = "collecting"
	name_label.visible = false
	if pulse_tween:
		pulse_tween.kill()

	_spawn_collect_particles(icon_sprite.modulate)
	shadow.visible = false
	backdrop.visible = false
	icon_sprite.visible = false
	beam.visible = false
	beam_glow.visible = false

	if collect_overlay_parent != null and is_instance_valid(collect_overlay_parent) and get_parent() != collect_overlay_parent:
		var preserved_global_position: Vector2 = global_position
		reparent(collect_overlay_parent)
		global_position = preserved_global_position
		z_index = 8

	collect_tween = create_tween()
	collect_tween.parallel().tween_property(self, "global_position", target_position, 1.05).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	collect_tween.parallel().tween_property(self, "scale", Vector2.ONE * 0.58, 1.05)
	collect_tween.parallel().tween_property(self, "modulate:a", 0.0, 0.96)
	collect_tween.finished.connect(func() -> void:
		drop_state = "finished"
		queue_free()
	)


func _start_drop_arc(spread: float, show_beam: bool) -> void:
	start_position = global_position + Vector2(randf_range(-8.0, 8.0), randf_range(-10.0, -2.0))
	ground_position = global_position + Vector2(randf_range(-spread, spread), randf_range(-2.0, 6.0))
	global_position = start_position
	modulate = Color(1, 1, 1, 1)
	drop_elapsed = 0.0
	drop_state = "dropping"

	if show_beam:
		beam.visible = true
		beam_glow.visible = true
		beam.modulate.a = 0.0
		beam_glow.modulate.a = 0.0


func _update_drop_arc(delta: float) -> void:
	drop_elapsed += delta
	var t: float = clampf(drop_elapsed / maxf(drop_duration, 0.01), 0.0, 1.0)
	var next_position: Vector2 = start_position.lerp(ground_position, t)
	next_position.y -= sin(t * PI) * arc_height
	global_position = next_position
	modulate.a = clampf(0.25 + t, 0.0, 1.0)

	if beam.visible:
		beam.modulate.a = t
		beam_glow.modulate.a = t

	if t >= 1.0:
		drop_state = "grounded"
		global_position = ground_position
		grounded_time = 0.0
		if beam.visible:
			pulse_tween = create_tween().set_loops()
			pulse_tween.tween_property(beam, "scale:x", 1.08, 0.45)
			pulse_tween.parallel().tween_property(beam_glow, "scale:x", 1.16, 0.45)
			pulse_tween.tween_property(beam, "scale:x", 0.94, 0.45)
			pulse_tween.parallel().tween_property(beam_glow, "scale:x", 0.88, 0.45)


func _spawn_collect_particles(tint: Color) -> void:
	if not collect_particles.is_empty():
		return

	for index in range(10):
		var particle := Polygon2D.new()
		particle.polygon = PackedVector2Array([
			Vector2(-35, 0),
			Vector2(0, -50),
			Vector2(35, 0),
			Vector2(0, 50),
		])
		particle.color = Color(tint.r, tint.g, tint.b, 1.0)
		particle.position = Vector2.from_angle((TAU / 10.0) * float(index)) * randf_range(80.0, 140.0)
		particle.scale = Vector2.ONE
		particle.z_index = 9
		add_child(particle)
		collect_particles.append(particle)

	var particle_tween := create_tween()
	for particle in collect_particles:
		particle_tween.parallel().tween_property(particle, "position", Vector2.ZERO, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		particle_tween.parallel().tween_property(particle, "scale", Vector2.ONE * 0.78, 0.55)
		particle_tween.parallel().tween_property(particle, "color:a", 0.95, 0.55)


func _load_runtime_texture(resource_path: String) -> Texture2D:
	return RuntimeTextureLoader.load_texture(resource_path)
