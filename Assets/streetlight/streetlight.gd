extends Node3D

@export var lamp_mesh_path: NodePath = "LAMP"
@export var spotlight_path: NodePath = "SpotLight3D"

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
var _is_night: bool = false

var LAMP_COLOR := Color.html("#ffb826")


func _ready():
	_setup_nodes()
	GameSettings.time_of_day_changed.connect(_on_time_of_day_changed)
	_update_lamp_for_time(GameSettings.time_of_day)


func _setup_nodes():
	_spotlight = get_node_or_null(spotlight_path)
	var lamp_mesh: MeshInstance3D = get_node_or_null(lamp_mesh_path)

	if lamp_mesh:
		var mat := lamp_mesh.get_active_material(1)
		if mat and mat is StandardMaterial3D:
			_lamp_material = mat.duplicate()
			lamp_mesh.set_surface_override_material(1, _lamp_material)
	else:
		push_warning("Streetlight: Lamp mesh not found")


func _on_time_of_day_changed(new_time: String) -> void:
	_update_lamp_for_time(new_time)


func _update_lamp_for_time(time: String) -> void:
	var is_night := (time != "DAY")
	if is_night == _is_night:  # Guard: no change, skip
		return

	_is_night = is_night

	if not _lamp_material or not _spotlight:
		return

	if not _is_night:
		_spotlight.visible = false
		_lamp_material.albedo_color = Color.WHITE
		_lamp_material.emission_enabled = false
		_flicker_active = false
	else:
		_spotlight.visible = true
		_lamp_material.albedo_color = LAMP_COLOR
		_lamp_material.emission_enabled = true
		_lamp_material.emission = LAMP_COLOR * 1.5


func _process(delta: float):
	if not _is_night or not _spotlight or not _lamp_material:
		return
	_handle_flicker(delta)


func _handle_flicker(delta: float):
	if not _flicker_active and randf() < flicker_chance_per_second * delta:
		_flicker_active = true
		_flicker_times = randi_range(flicker_count_min, flicker_count_max)
		_flicker_interval = randf_range(flicker_interval_min, flicker_interval_max)
		_flicker_timer = 0.0

	if _flicker_active:
		_flicker_timer -= delta
		if _flicker_timer <= 0.0:
			_spotlight.visible = not _spotlight.visible
			_lamp_material.emission_enabled = _spotlight.visible
			_lamp_material.emission = LAMP_COLOR * 1.5 if _spotlight.visible else Color.BLACK

			_flicker_times -= 1
			if _flicker_times <= 0:
				_spotlight.visible = true
				_lamp_material.emission_enabled = true
				_lamp_material.emission = LAMP_COLOR * 1.5
				_flicker_active = false
			else:
				_flicker_interval = randf_range(flicker_interval_min, flicker_interval_max)
				_flicker_timer = _flicker_interval
