extends Node3D

@export var lamp_mesh_path: NodePath = "LAMP" # Path to your MeshInstance3D
@export var spotlight_path: NodePath = "SpotLight3D" # Path to the spotlight

# Flicker settings
@export var flicker_chance_per_second: float = 0.05 
@export var flicker_count_min: int = 2
@export var flicker_count_max: int = 5
@export var flicker_interval_min: float = 0.05
@export var flicker_interval_max: float = 0.2

# Internal
var _spotlight: Light3D
var _lamp_material: StandardMaterial3D
var _flicker_times: int = 0
var _flicker_timer := 0.0
var _flicker_interval := 0.0
var _flicker_active := false

# Time of Day logic
var last_sky_state: String = ""
var _is_night: bool = false
var lamp_color := Color.html("#ffb826")

# -------------------------------
func _ready():
	_setup_nodes()
	_update_lamp_for_time() # Initial check

func _setup_nodes():
	_spotlight = get_node_or_null(spotlight_path)
	var lamp_mesh: MeshInstance3D = get_node_or_null(lamp_mesh_path)
	
	if lamp_mesh:
		# Note: Using surface 1 as per your original streetlight script
		var mat := lamp_mesh.get_active_material(1)
		if mat and mat is StandardMaterial3D:
			_lamp_material = mat.duplicate()
			lamp_mesh.set_surface_override_material(1, _lamp_material)
	else:
		push_warning("Streetlight: Lamp mesh not found")

func _process(delta: float):
	# 1. Update check: Only run if the time of day has actually changed
	if GameSettings.time_of_day != last_sky_state:
		_update_lamp_for_time()

	# 2. Early exit if it's day or nodes are missing
	if not _is_night or not _spotlight or not _lamp_material:
		return

	# 3. Flicker Logic (Only runs at night)
	_handle_flicker(delta)

func _update_lamp_for_time():
	last_sky_state = GameSettings.time_of_day
	_is_night = (last_sky_state != "DAY")
	
	if not _lamp_material or not _spotlight:
		return

	if not _is_night:
		# --- Day State ---
		_spotlight.visible = false
		_lamp_material.albedo_color = Color.WHITE
		_lamp_material.emission_enabled = false
		_flicker_active = false # Reset flicker if it turns day
	else:
		# --- Night State ---
		_spotlight.visible = true
		_lamp_material.albedo_color = lamp_color
		_lamp_material.emission_enabled = true
		_lamp_material.emission = lamp_color * 1.5

func _handle_flicker(delta: float):
	# Randomly decide to start a flicker
	if not _flicker_active and randf() < flicker_chance_per_second * delta:
		_flicker_active = true
		_flicker_times = randi_range(flicker_count_min, flicker_count_max)
		_flicker_interval = randf_range(flicker_interval_min, flicker_interval_max)
		_flicker_timer = 0.0

	# Handle active flicker
	if _flicker_active:
		_flicker_timer -= delta
		if _flicker_timer <= 0.0:
			# Toggle light and emission
			_spotlight.visible = not _spotlight.visible
			_lamp_material.emission_enabled = _spotlight.visible
			
			if _spotlight.visible:
				_lamp_material.emission = lamp_color * 1.5
			else:
				_lamp_material.emission = Color.BLACK

			_flicker_times -= 1
			if _flicker_times <= 0:
				# Restore normal ON state
				_spotlight.visible = true
				_lamp_material.emission_enabled = true
				_lamp_material.emission = lamp_color * 1.5
				_flicker_active = false
			else:
				# Set next interval
				_flicker_interval = randf_range(flicker_interval_min, flicker_interval_max)
				_flicker_timer = _flicker_interval
