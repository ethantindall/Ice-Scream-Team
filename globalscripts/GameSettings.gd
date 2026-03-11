extends Node

# Preload the .tres files (much faster than instantiating scenes)
const DAY_ENV = preload("res://Assets/envs/day_env_pack.tres")
const NIGHT_ENV = preload("res://Assets/envs/night_env_pack.tres")

@export_group("Lights & Objects")
@export var SUN_LIGHT :DirectionalLight3D
@export var MOON_LIGHT :DirectionalLight3D
@export var MOON: Node3D

@export_group("Video & Camera")
@export var max_fps: int = 120
@export var vsync_enabled: bool = true
@export var base_fov: float = 60.0
@export var render_distance: float = 400.0

@export_group("Time State")
@export_enum("DAY", "NIGHT") var time_of_day: String = "DAY"


var world_env: WorldEnvironment = null

func _ready():
	apply_video_settings()
	apply_render_distance()
	apply_fov()
	
	# Grab the existing WorldEnvironment node
	world_env = get_tree().get_first_node_in_group("world_environment") as WorldEnvironment
	
	if not world_env:
		print("Warning: Ensure your WorldEnvironment node is in the 'world_environment' group.")
	
	update_environment()

# ---------------------
# DAY / NIGHT LOGIC
# ---------------------

func set_time_of_day(new_time: String):
	if time_of_day != new_time:
		time_of_day = new_time
		update_environment()

func update_environment():
	var is_day = (time_of_day == "DAY")
	
	# 1. Swap Environment Resource
	if world_env:
		world_env.environment = DAY_ENV if is_day else NIGHT_ENV

	# 2. Toggle Light Visibility
	if SUN_LIGHT: SUN_LIGHT.visible = is_day
	if MOON_LIGHT: MOON_LIGHT.visible = !is_day
	if MOON: MOON.visible = !is_day

	var day_folder = get_tree().get_first_node_in_group("daytime_folder")
	var night_folder = get_tree().get_first_node_in_group("nighttime_folder")
	day_folder.queue_free()
	night_folder.visible = true


# ---------------------
# VIDEO & CAMERA
# ---------------------

func apply_video_settings():
	Engine.max_fps = max_fps
	var vsync_mode = DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vsync_mode)

func apply_fov():
	# Ensure your Camera3D nodes are in the "cameras" group
	get_tree().call_group("cameras", "set_fov", base_fov)

func apply_render_distance():
	for camera in get_tree().get_nodes_in_group("cameras"):
		if camera is Camera3D:
			camera.far = render_distance
