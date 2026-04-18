extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main/game_root.tscn"
const REQUIRED_PATHS := [
	"UILayer/LaunchMenu",
	"UILayer/SettingsPanel",
	"UILayer/MainNavBar",
]
const REQUIRED_RESOURCES := [
	"res://assets/generated/afk_rpg_formal/backgrounds/chapter1_town_road_single_native_v1.png",
]


func _init() -> void:
	call_deferred("_run_check")


func _run_check() -> void:
	for resource_path in REQUIRED_RESOURCES:
		if not ResourceLoader.exists(resource_path):
			push_error("Missing required resource: %s" % resource_path)
			quit(1)
			return
	var packed_scene := load(MAIN_SCENE_PATH)
	if packed_scene == null:
		push_error("Failed to load main scene: %s" % MAIN_SCENE_PATH)
		quit(1)
		return
	var root_node: Node = packed_scene.instantiate()
	get_root().add_child(root_node)
	await process_frame
	await process_frame
	for node_path in REQUIRED_PATHS:
		if root_node.get_node_or_null(node_path) == null:
			push_error("Missing required node: %s" % node_path)
			quit(1)
			return
	if not InputMap.has_action("ui_gm_panel") or not InputMap.action_get_events("ui_gm_panel").is_empty():
		push_error("Public demo should not expose a GM hotkey.")
		quit(1)
		return
	var launch_menu: Control = root_node.get_node_or_null("UILayer/LaunchMenu")
	if launch_menu == null or not launch_menu.visible:
		push_error("Launch menu should be visible on startup.")
		quit(1)
		return
	var gm_panel: Control = root_node.get_node_or_null("UILayer/GMPanel")
	if gm_panel != null and gm_panel.visible:
		push_error("GM panel should be hidden in the public demo.")
		quit(1)
		return
	quit(0)
