extends Node3D
class_name VehicleLights

@export var lights_on: bool = false:
	set(value):
		if lights_on == value:  # Guard: skip if state unchanged
			return
		lights_on = value
		if is_inside_tree():
			_update_lights()

@export var auto_toggle_by_time: bool = true


func _ready() -> void:
	if auto_toggle_by_time:
		# Connect to a signal instead of polling in _process
		GameSettings.time_of_day_changed.connect(_on_time_of_day_changed)
		lights_on = (GameSettings.time_of_day != "DAY")
	else:
		_update_lights()


func _on_time_of_day_changed(new_time: String) -> void:
	if not auto_toggle_by_time:
		return
	lights_on = (new_time != "DAY")  # Setter handles _update_lights()


func toggle_lights() -> void:
	lights_on = !lights_on


func _update_lights() -> void:
	for child in get_children():
		if child is Node3D:
			child.visible = lights_on
