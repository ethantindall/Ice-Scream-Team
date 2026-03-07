extends Node

# Preload the scene files (.tscn)
const DAY_ENV_SCENE = preload("res://Assets/envs/day_environment.tscn")
const NIGHT_ENV_SCENE = preload("res://Assets/envs/night_environment.tscn")

@export var SUN_LIGHT :DirectionalLight3D
@export var MOON_LIGHT :DirectionalLight3D
@export var MOON: Node3D
var current_env_instance: Node = null



# =====================
# SETTINGS
# =====================
@export_group("Video & Camera")
@export var max_fps: int = 120
@export var vsync_enabled: bool = true
@export var base_fov: float = 60.0
@export var render_distance: float = 400.0

@export_group("Time State")
@export_enum("DAY", "NIGHT") var time_of_day: String = "DAY" # Default to DAY

@export_group("Folder References")
@export var day_folder: Node3D
@export var night_folder: Node3D

func _ready():
	apply_video_settings()
	apply_render_distance()
	apply_fov()
	
	# CRITICAL: Clean up any WorldEnvironment nodes already in the scene
	# so they don't override our spawned ones.
	for env in get_tree().get_nodes_in_group("world_environment"):
		if env.get_parent() != self: # Don't delete the one we just made
			env.queue_free()
			
	update_environment()

# ---------------------
# DAY / NIGHT LOGIC
# ---------------------
func set_time_of_day(new_time: String):
	var formatted = new_time
	if time_of_day != formatted:
		time_of_day = formatted
		update_environment()

func update_environment():
	var is_day = (time_of_day == "DAY")
	
	# 1. SAFETY CHECK: If lights aren't assigned, don't crash!
	if SUN_LIGHT:
		SUN_LIGHT.visible = is_day
	else:
		print("Warning: SUN_LIGHT is not assigned in the Inspector")

	if MOON_LIGHT:
		MOON_LIGHT.visible = !is_day
	else:
		print("Warning: MOON_LIGHT is not assigned in the Inspector")

	if MOON:
		MOON.visible = !is_day
	else:
		print("Warning: MOON is not assigned in the Inspector")

	# 2. Determine which scene to load
	var scene_to_load = DAY_ENV_SCENE if is_day else NIGHT_ENV_SCENE
	
	# Safety check for the scene files
	if not scene_to_load:
		print("Error: Environment scene failed to load!")
		return

	print("Switching to: ", time_of_day, " | Scene: ", scene_to_load.resource_path)

	# 3. Remove the old environment instance
	# We use 'is_instance_valid' to be extra safe during scene transitions
	if is_instance_valid(current_env_instance):
		current_env_instance.queue_free()
	
	# 4. Instantiate and add the new one
	current_env_instance = scene_to_load.instantiate()
	add_child(current_env_instance)

	# 5. Toggle Folders
	_activate_folder(day_folder, is_day)
	_activate_folder(night_folder, !is_day)
func _activate_folder(node: Node, active: bool):
	if not node: return
	node.visible = active
	node.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED

# ---------------------
# VIDEO & CAMERA (STAY THE SAME)
# ---------------------
func apply_video_settings():
	Engine.max_fps = max_fps
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED)

func apply_fov():
	get_tree().call_group("cameras", "set_fov", base_fov)

func apply_render_distance():
	for camera in get_tree().get_nodes_in_group("cameras"):
		if camera is Camera3D: camera.far = render_distance
