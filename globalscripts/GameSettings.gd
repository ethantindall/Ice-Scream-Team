extends Node

# =====================
# VIDEO SETTINGS
# =====================
var max_fps: int = 120
var vsync_enabled: bool = true


# =====================
# CAMERA SETTINGS
# =====================
var base_fov: float = 60.0
var sprint_fov_bonus: float = 10.0

# Mouse sensitivity (degrees per pixel)
var mouse_sensitivity: float = 0.1
signal mouse_sensitivity_changed(value)

# Render distance (in meters / world units)
var render_distance: float = 400.0

signal fov_changed(value)

# =====================
# DAY / NIGHT SETTINGS
# =====================
var time_of_day = "DAY" # Change to "DAY" or "NIGHT" to test

# Day colors
static var DAY_SKY_TOP := Color.html("#598dcc")
static var DAY_SKY_HORIZON := Color.html("#c5a195")
static var DAY_GROUND_TOP := Color.html("#66594d")
static var DAY_GROUND_BOTTOM := Color.html("#33332a")
static var DAY_CURVE = 0.1
static var DAY_LIGHT_ENERGY = 1.0

# Night colors
static var NIGHT_SKY_TOP := Color.html("#000000")
static var NIGHT_SKY_HORIZON := Color.html("#130e0e")
static var NIGHT_GROUND_HORIZON := Color.html("#000000")
static var NIGHT_GROUND_BOTTOM := Color.html("#000000")
static var NIGHT_CURVE = 0.1
static var NIGHT_LIGHT_ENERGY = .2

func _ready():
	apply_video_settings()
	apply_render_distance()
	apply_fov()
	apply_time_of_day()

# ---------------------
# VIDEO
# ---------------------
func apply_video_settings():
	Engine.max_fps = max_fps
	#DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

# ---------------------
# CAMERA
# ---------------------
func apply_fov():
	for camera in get_tree().get_nodes_in_group("cameras"):
		camera.fov = base_fov
	fov_changed.emit(base_fov)

func set_base_fov(value: float):
	base_fov = clamp(value, 30.0, 120.0)
	apply_fov()

# ---------------------
# INPUT
# ---------------------
func set_mouse_sensitivity(value: float):
	mouse_sensitivity = clamp(value, 0.01, 1.0)
	mouse_sensitivity_changed.emit(mouse_sensitivity)

# ---------------------
# RENDER DISTANCE
# ---------------------
func apply_render_distance():
	for camera in get_tree().get_nodes_in_group("cameras"):
		camera.far = render_distance

# ---------------------
# DAY / NIGHT
# ---------------------

func apply_time_of_day():
	# --- Environment & Sky Logic ---
	for env_node in get_tree().get_nodes_in_group("world_environment"):
		var world_env := env_node as WorldEnvironment
		if not world_env or not world_env.environment:
			continue

		var env := world_env.environment.duplicate()
		world_env.environment = env

		if not env.sky:
			env.sky = Sky.new()
		if not env.sky.sky_material:
			env.sky.sky_material = ProceduralSkyMaterial.new()

		var sky := env.sky.sky_material as ProceduralSkyMaterial
		if not sky:
			continue

		if time_of_day == "DAY":
			sky.sky_top_color = DAY_SKY_TOP
			sky.sky_horizon_color = DAY_SKY_HORIZON
			sky.ground_bottom_color = DAY_GROUND_BOTTOM
			sky.ground_horizon_color = DAY_GROUND_TOP
			sky.sky_curve = DAY_CURVE
			env.volumetric_fog_enabled = false
			env.fog_enabled = true
			for star in get_tree().get_nodes_in_group("sunmoon"):
				star.light_energy = DAY_LIGHT_ENERGY
				star.rotation.x = deg_to_rad(-15) 
		else:
			for star in get_tree().get_nodes_in_group("sunmoon"):
				star.light_energy = NIGHT_LIGHT_ENERGY
				star.rotation.x = deg_to_rad(-60)
			sky.sky_top_color = NIGHT_SKY_TOP
			sky.sky_horizon_color = NIGHT_SKY_HORIZON
			sky.ground_bottom_color = NIGHT_GROUND_BOTTOM
			sky.ground_horizon_color = NIGHT_GROUND_HORIZON
			sky.sky_curve = NIGHT_CURVE
			env.volumetric_fog_enabled = true
			env.fog_enabled = false
			#for truck in get_tree().get_nodes_in_group("ice_cream_truck"):
			#	truck.get_node("Lights").lights_on = true
			#	truck.get_node("Lights")._update_lights()
			
	# --- Population (Folder) Logic ---
	print("Sky changed. Updating population groups: daytime_folder, nighttime_folder")
	
	var is_day = (time_of_day == "DAY")
	
	# Fetch the single master nodes from the groups
	var day_folder = get_tree().get_first_node_in_group("daytime_folder")
	var night_folder = get_tree().get_first_node_in_group("nighttime_folder")
	

	# Activate/Deactivate the folders
	if day_folder:
		_activate_group(day_folder, is_day)
		
	if night_folder:
		_activate_group(night_folder, !is_day)
		
	print("Population updated.")

func _activate_group(node: Node, active: bool):
	if node:
		# Toggle visibility if it's a 3D or 2D object
		if node is Node3D or node is CanvasItem:
			node.visible = active
		
		# Set process mode: INHERIT (Normal) or DISABLED (No physics, no scripts)
		node.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
