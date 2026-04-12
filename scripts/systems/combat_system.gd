extends Node

const PLAYER_SCENE := preload("res://scenes/entities/player.tscn")
const ENEMY_SCENE := preload("res://scenes/entities/enemy.tscn")
const LOOT_DROP_VISUAL_SCENE := preload("res://scenes/effects/loot_drop_visual.tscn")
const PARALLAX_LAYER_IDS: Array[String] = ["sky", "far", "mid", "near_back", "near_front"]
const CHAPTER_BACKGROUND_COLORS := {
	"chapter_1": Color(0.12, 0.11, 0.14, 1.0),
	"chapter_2": Color(0.17, 0.2, 0.18, 1.0),
}
const CHAPTER_GROUND_COLORS := {
	"chapter_1": Color(0.19, 0.18, 0.2, 1.0),
	"chapter_2": Color(0.21, 0.23, 0.17, 1.0),
}
const HERO_LEFT_BOUND := 426.0
const HERO_RIGHT_BOUND := 854.0
const LEFT_SPAWN_X := 112.0
const RIGHT_SPAWN_X := 1168.0

@onready var background_fill: Polygon2D = $"../../WorldLayer/Background"
@onready var ground_fill: Polygon2D = $"../../WorldLayer/Ground"
@onready var sky_layer: Parallax2D = $"../../WorldLayer/SkyLayer"
@onready var far_layer: Parallax2D = $"../../WorldLayer/FarLayer"
@onready var mid_layer: Parallax2D = $"../../WorldLayer/MidLayer"
@onready var near_back_layer: Parallax2D = $"../../WorldLayer/NearBackLayer"
@onready var near_front_layer: Parallax2D = $"../../WorldLayer/NearFrontLayer"
@onready var sky_sprite: Sprite2D = $"../../WorldLayer/SkyLayer/SkySprite"
@onready var far_sprite: Sprite2D = $"../../WorldLayer/FarLayer/FarSprite"
@onready var mid_sprite: Sprite2D = $"../../WorldLayer/MidLayer/MidSprite"
@onready var near_back_sprite: Sprite2D = $"../../WorldLayer/NearBackLayer/NearBackSprite"
@onready var near_front_sprite: Sprite2D = $"../../WorldLayer/NearFrontLayer/NearFrontSprite"
@onready var combat_runner: Node2D = $"../../WorldLayer/CombatRunner"
@onready var collect_effects: Node2D = $"../../UILayer/CollectEffects"
@onready var player_spawn: Marker2D = $"../../WorldLayer/CombatRunner/PlayerSpawn"
@onready var enemy_container: Node2D = $"../../WorldLayer/CombatRunner/EnemyContainer"
@onready var loot_container: Node2D = $"../../WorldLayer/CombatRunner/LootContainer"
@onready var hud: Control = $"../../UILayer/HUD"
@onready var main_nav_bar: Control = $"../../UILayer/MainNavBar"
@onready var loot_system: Node = $"../LootSystem"

const BASE_SCROLL_SPEED := 20.0
const VIEWPORT_WIDTH := 1280.0
const VIEWPORT_HEIGHT := 720.0

var player: Node2D
var current_node_data: Dictionary = {}
var current_wave_index: int = 0
var wave_wait_timer: float = 0.0
var finish_wait_timer: float = 0.0
var battle_state: String = "loading"
var last_enemy_death_position: Vector2 = Vector2.ZERO
var parallax_layers: Dictionary = {}
var parallax_sprites: Dictionary = {}
var current_parallax_scene: Dictionary = {}
var parallax_scroll_accumulator: float = 0.0


func _ready() -> void:
	_setup_parallax_runtime()
	EventBus.config_loaded.connect(_start_current_node)
	EventBus.node_changed.connect(_on_node_changed)
	if not ConfigDB.chapter_nodes.is_empty():
		_start_current_node()


func _physics_process(delta: float) -> void:
	_update_background_parallax(delta)
	_process_loot_pickups()
	if player == null or not is_instance_valid(player):
		return

	match battle_state:
		"waiting_next_wave":
			wave_wait_timer -= delta
			if wave_wait_timer <= 0.0:
				_spawn_wave()
		"node_success":
			finish_wait_timer -= delta
			if finish_wait_timer <= 0.0:
				GameManager.complete_node(String(current_node_data.get("id", "")))
				_start_current_node()
		"node_failed":
			finish_wait_timer -= delta
			if finish_wait_timer <= 0.0:
				GameManager.fallback_to_stable_node()
				_start_current_node()
		"combat", "moving":
			_update_player_targeting()
			_check_wave_progress()
		_:
			pass


func _input(event: InputEvent) -> void:
	if EventBus.ui_blocking_input:
		return
	if event.is_action_pressed("ui_skill_1"):
		GameManager.select_core_skill("core_whirlwind")
		_restart_current_node()
	elif event.is_action_pressed("ui_skill_2"):
		GameManager.select_core_skill("core_deep_wound")
		_restart_current_node()
	elif event.is_action_pressed("ui_skill_3"):
		GameManager.select_core_skill("core_chain_lightning")
		_restart_current_node()
	elif event.is_action_pressed("ui_restart_run"):
		_restart_current_node()


func _on_node_changed(_node_id: String) -> void:
	_start_current_node()


func _start_current_node() -> void:
	if ConfigDB.chapter_nodes.is_empty():
		return

	current_node_data = ConfigDB.get_chapter_node(GameManager.current_node_id)
	if current_node_data.is_empty():
		return

	_apply_chapter_visuals(
		String(current_node_data.get("chapter_id", GameManager.current_chapter_id)),
		String(current_node_data.get("id", GameManager.current_node_id))
	)
	_clear_enemies()
	_spawn_player()
	last_enemy_death_position = Vector2(760.0, player_spawn.global_position.y)
	current_wave_index = 0
	battle_state = "waiting_next_wave"
	wave_wait_timer = 0.3
	player.target = null
	player.should_move = false
	EventBus.battle_started.emit(String(current_node_data.get("id", "")))
	EventBus.combat_state_changed.emit("进入节点 %s" % String(current_node_data.get("id", "")))


func _spawn_player() -> void:
	if player and is_instance_valid(player):
		player.queue_free()

	player = PLAYER_SCENE.instantiate() as Node2D
	combat_runner.add_child(player)
	player.global_position = player_spawn.global_position
	player.setup_from_skill(GameManager.get_selected_core_skill())
	player.died.connect(_on_player_died)
	player.reset_state()
	if player.has_method("set_idle_anchor_x"):
		player.set_idle_anchor_x(player_spawn.global_position.x)
	if player.has_method("set_movement_bounds"):
		player.set_movement_bounds(HERO_LEFT_BOUND, HERO_RIGHT_BOUND)


func _spawn_wave() -> void:
	var pool_id: String = String(current_node_data.get("enemy_pool_id", ""))
	var pool_data: Dictionary = ConfigDB.get_enemy_pool(pool_id)
	var enemy_ids: Array = pool_data.get("enemy_ids", [])
	if enemy_ids.is_empty():
		return

	var count: int = int(pool_data.get("enemies_per_wave", 1))
	if String(current_node_data.get("node_type", "")) == "boss":
		count = 1

	for i in count:
		var enemy_id: String = String(enemy_ids[min(i, enemy_ids.size() - 1)])
		var enemy_data: Dictionary = ConfigDB.get_enemy(enemy_id)
		var enemy: Node2D = ENEMY_SCENE.instantiate() as Node2D
		enemy_container.add_child(enemy)
		var spawn_side: int = -1 if randi() % 2 == 0 else 1
		enemy.global_position = _get_enemy_spawn_position(i, count, spawn_side)
		enemy.setup_from_config(enemy_data)
		if enemy.has_method("set_spawn_side"):
			enemy.set_spawn_side(spawn_side)
		enemy.target = player
		enemy.died.connect(_on_enemy_died)

	current_wave_index += 1
	battle_state = "moving"
	_emit_wave_highlight(enemy_ids)
	EventBus.combat_state_changed.emit("第 %d 波战斗中" % current_wave_index)


func _update_player_targeting() -> void:
	var living_enemies: Array = []
	for child in enemy_container.get_children():
		if is_instance_valid(child):
			living_enemies.append(child)

	if living_enemies.is_empty():
		player.target = null
		player.should_move = false
		return

	living_enemies.sort_custom(func(a, b) -> bool:
		return player.global_position.distance_to(a.global_position) < player.global_position.distance_to(b.global_position)
	)

	player.target = living_enemies[0]
	player.should_move = player.global_position.distance_to(player.target.global_position) > player.attack_range * 0.92
	battle_state = "combat" if not player.should_move else "moving"


func _check_wave_progress() -> void:
	if enemy_container.get_child_count() > 0:
		return

	var total_waves: int = int(current_node_data.get("wave_count", 1))
	if current_wave_index < total_waves:
		battle_state = "waiting_next_wave"
		wave_wait_timer = 1.2
		player.target = null
		player.should_move = false
		EventBus.combat_state_changed.emit("波次清空，准备下一波")
		return

	var rewards: Array = current_node_data.get("first_clear_rewards", [])
	MetaProgressionSystem.grant_rewards(rewards)
	if loot_system and loot_system.has_method("process_node_loot"):
		var loot_result: Dictionary = loot_system.process_node_loot(current_node_data)
		_spawn_reward_drop_visuals(loot_result, last_enemy_death_position)
	battle_state = "node_success"
	finish_wait_timer = 2.0
	player.target = null
	player.should_move = false
	EventBus.battle_finished.emit(String(current_node_data.get("id", "")), true)
	EventBus.combat_state_changed.emit("节点完成，结算奖励中")


func _on_enemy_died(enemy_id: String, world_position: Vector2, enemy_type: String) -> void:
	GameManager.record_kill()
	last_enemy_death_position = world_position
	_spawn_enemy_death_visuals(world_position, enemy_type)
	_emit_enemy_death_highlight(enemy_id, enemy_type)
	EventBus.enemy_killed.emit(enemy_id)


func _on_player_died() -> void:
	battle_state = "node_failed"
	finish_wait_timer = 2.0
	player.target = null
	player.should_move = false
	EventBus.battle_finished.emit(String(current_node_data.get("id", "")), false)
	EventBus.combat_state_changed.emit("挑战失败，回退到稳定节点")


func _restart_current_node() -> void:
	_start_current_node()


func _emit_wave_highlight(enemy_ids: Array) -> void:
	if enemy_ids.is_empty():
		return
	var primary_enemy_id: String = String(enemy_ids[0])
	var enemy_data: Dictionary = ConfigDB.get_enemy(primary_enemy_id)
	var enemy_type: String = String(enemy_data.get("enemy_type", "normal"))
	if enemy_type == "normal":
		return
	var chapter_data: Dictionary = ConfigDB.get_chapter(String(current_node_data.get("chapter_id", GameManager.current_chapter_id)))
	var enemy_name: String = String(enemy_data.get("name", primary_enemy_id))
	var node_name: String = String(current_node_data.get("id", GameManager.current_node_id))
	var highlight_title: String = "精英来袭" if enemy_type == "elite" else "Boss 降临"
	var highlight_subtitle: String = "%s · %s" % [String(chapter_data.get("name", GameManager.current_chapter_id)), node_name]
	EventBus.combat_highlight_requested.emit({
		"highlight_type": enemy_type,
		"title": highlight_title,
		"subtitle": enemy_name,
		"detail": highlight_subtitle,
	})


func _emit_enemy_death_highlight(enemy_id: String, enemy_type: String) -> void:
	if not ["elite", "boss"].has(enemy_type):
		return
	var enemy_data: Dictionary = ConfigDB.get_enemy(enemy_id)
	var title: String = "强敌已除" if enemy_type == "elite" else "一战成名"
	var detail: String = "从强者身上，总能学到些什么。" if enemy_type == "elite" else "江湖路远，这不过是起点。"
	EventBus.combat_highlight_requested.emit({
		"highlight_type": "%s_kill" % enemy_type,
		"title": title,
		"subtitle": String(enemy_data.get("name", enemy_id)),
		"detail": detail,
	})


func _clear_enemies() -> void:
	for child in enemy_container.get_children():
		child.queue_free()


func _apply_chapter_visuals(chapter_id: String, node_id: String = "") -> void:
	background_fill.color = CHAPTER_BACKGROUND_COLORS.get(chapter_id, Color(0.1, 0.11, 0.16, 1.0))
	ground_fill.color = CHAPTER_GROUND_COLORS.get(chapter_id, Color(0.16, 0.18, 0.24, 1.0))
	current_parallax_scene = _resolve_parallax_scene(chapter_id, node_id)
	if current_parallax_scene.is_empty():
		_clear_parallax_layers()
		return
	parallax_scroll_accumulator = 0.0
	_apply_parallax_scene(current_parallax_scene)


func _load_runtime_texture(resource_path: String) -> Texture2D:
	return RuntimeTextureLoader.load_texture(resource_path)


func _spawn_enemy_death_visuals(world_position: Vector2, enemy_type: String) -> void:
	if loot_system == null or not loot_system.has_method("build_death_drop_visuals"):
		return
	var visual_entries: Array = loot_system.build_death_drop_visuals(current_node_data, enemy_type)
	_spawn_loot_visual_entries(visual_entries, world_position)


func _spawn_reward_drop_visuals(loot_result: Dictionary, world_position: Vector2) -> void:
	if loot_result.is_empty():
		return
	if loot_system == null or not loot_system.has_method("build_reward_drop_visuals"):
		return
	var visual_entries: Array = loot_system.build_reward_drop_visuals(loot_result, current_node_data)
	_spawn_loot_visual_entries(visual_entries, world_position)


func _spawn_loot_visual_entries(visual_entries: Array, world_position: Vector2) -> void:
	var index: int = 0
	for entry_variant in visual_entries:
		var entry: Dictionary = entry_variant
		var drop_visual: Node2D = LOOT_DROP_VISUAL_SCENE.instantiate() as Node2D
		loot_container.add_child(drop_visual)
		drop_visual.global_position = world_position + Vector2(float(index * 14 - visual_entries.size() * 6), 12.0)
		if drop_visual.has_method("set_collect_overlay_parent"):
			drop_visual.set_collect_overlay_parent(collect_effects)
		if drop_visual.has_method("setup"):
			drop_visual.setup(entry)
		index += 1


func _get_enemy_spawn_position(index: int, total: int, spawn_side: int) -> Vector2:
	var spread_offset: float = (float(index) - floor(float(total) * 0.5)) * 58.0
	var x_position: float = LEFT_SPAWN_X + absf(spread_offset) if spawn_side < 0 else RIGHT_SPAWN_X - absf(spread_offset)
	return Vector2(x_position, player_spawn.global_position.y)


func _process_loot_pickups() -> void:
	var has_player: bool = player != null and is_instance_valid(player)
	var player_position: Vector2 = player.global_position if has_player else Vector2.ZERO
	for child in loot_container.get_children():
		if child == null or not is_instance_valid(child):
			continue
		if not child.has_method("can_active_pickup") or not child.has_method("should_auto_pickup"):
			continue
		var should_collect: bool = false
		if child.can_active_pickup() and has_player:
			should_collect = player_position.distance_to(child.global_position) <= 86.0
		if not should_collect and child.should_auto_pickup():
			should_collect = true
		if not should_collect:
			continue
		if child.has_method("begin_collect"):
			child.begin_collect(_get_pickup_target_position(String(child.get_pickup_target_id())))


func _get_pickup_target_position(target_id: String) -> Vector2:
	match target_id:
		"inventory":
			if main_nav_bar and main_nav_bar.has_method("get_inventory_collect_target"):
				return main_nav_bar.get_inventory_collect_target()
			return Vector2(136.0, 628.0)
		_:
			if hud and hud.has_method("get_resource_collect_target"):
				return hud.get_resource_collect_target()
			return Vector2(240.0, 40.0)


func _setup_parallax_runtime() -> void:
	parallax_layers = {
		"sky": sky_layer,
		"far": far_layer,
		"mid": mid_layer,
		"near_back": near_back_layer,
		"near_front": near_front_layer,
	}
	parallax_sprites = {
		"sky": sky_sprite,
		"far": far_sprite,
		"mid": mid_sprite,
		"near_back": near_back_sprite,
		"near_front": near_front_sprite,
	}
	parallax_scroll_accumulator = 0.0
	for layer_id in PARALLAX_LAYER_IDS:
		var p_layer: Parallax2D = parallax_layers.get(layer_id)
		var sprite: Sprite2D = parallax_sprites.get(layer_id)
		if p_layer == null or sprite == null:
			continue
		p_layer.position = Vector2.ZERO
		p_layer.scroll_scale = Vector2.ONE
		p_layer.ignore_camera_scroll = true
		p_layer.scroll_offset = Vector2.ZERO
		sprite.scale = Vector2.ONE


func _resolve_parallax_scene(chapter_id: String, node_id: String) -> Dictionary:
	var scene_key: String = ConfigDB.get_parallax_scene_key(chapter_id, node_id)
	if not scene_key.is_empty():
		var configured_scene: Dictionary = ConfigDB.get_parallax_scene(scene_key).duplicate(true)
		if not configured_scene.is_empty():
			return configured_scene
	return {
		"scroll_speed_multipliers": {
			"sky": 0.05, "far": 0.15, "mid": 0.35,
			"near_back": 0.65, "near_front": 0.85
		},
		"layer_paths": {}
	}


func _apply_parallax_scene(scene_def: Dictionary) -> void:
	var layer_paths: Dictionary = scene_def.get("layer_paths", {})
	for layer_id in PARALLAX_LAYER_IDS:
		var texture_path: String = String(layer_paths.get(layer_id, ""))
		if texture_path.is_empty():
			_apply_parallax_layer(layer_id, null)
		else:
			_apply_parallax_layer(layer_id, _load_runtime_texture(texture_path))


func _apply_parallax_layer(layer_id: String, texture: Texture2D) -> void:
	var p_layer: Parallax2D = parallax_layers.get(layer_id)
	var sprite: Sprite2D = parallax_sprites.get(layer_id)
	if p_layer == null or sprite == null:
		return
	if texture == null:
		sprite.texture = null
		sprite.scale = Vector2.ONE
		p_layer.scroll_offset = Vector2.ZERO
		return
	sprite.texture = texture
	sprite.centered = false
	var tex_w := float(texture.get_width())
	var tex_h := float(texture.get_height())
	var scale_y := VIEWPORT_HEIGHT / maxf(1.0, tex_h)
	sprite.scale = Vector2(scale_y, scale_y)
	var scaled_w := tex_w * scale_y
	p_layer.repeat_size = Vector2(scaled_w, VIEWPORT_HEIGHT)
	p_layer.scroll_offset = Vector2.ZERO


func _clear_parallax_layers() -> void:
	parallax_scroll_accumulator = 0.0
	for layer_id in PARALLAX_LAYER_IDS:
		var p_layer: Parallax2D = parallax_layers.get(layer_id)
		var sprite: Sprite2D = parallax_sprites.get(layer_id)
		if sprite != null:
			sprite.texture = null
			sprite.scale = Vector2.ONE
		if p_layer != null:
			p_layer.scroll_offset = Vector2.ZERO


func _update_background_parallax(delta: float) -> void:
	if current_parallax_scene.is_empty():
		return
	parallax_scroll_accumulator += delta * BASE_SCROLL_SPEED
	var speed_mults: Dictionary = current_parallax_scene.get("scroll_speed_multipliers", {})
	for layer_id in PARALLAX_LAYER_IDS:
		var p_layer: Parallax2D = parallax_layers.get(layer_id)
		var sprite: Sprite2D = parallax_sprites.get(layer_id)
		if p_layer == null or sprite == null or sprite.texture == null:
			continue
		var speed_mult: float = float(speed_mults.get(layer_id, 0.5))
		var scroll_px: float = parallax_scroll_accumulator * speed_mult
		var repeat_w: float = maxf(1.0, p_layer.repeat_size.x)
		p_layer.scroll_offset = Vector2(-fmod(scroll_px, repeat_w), 0.0)
