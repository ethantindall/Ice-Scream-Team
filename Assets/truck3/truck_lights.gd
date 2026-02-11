extends Node3D
class_name VehicleLights

@export var lights_on: bool = false:
	set(value):
		lights_on = value
		if is_inside_tree():
			_update_lights()

@export var auto_toggle_by_time: bool = true

func _ready() -> void:
	if auto_toggle_by_time:
		# Automatically set lights based on time of day
		lights_on = (GameSettings.time_of_day != "DAY")
	_update_lights()

func toggle_lights() -> void:
	lights_on = !lights_on

func set_lights(state: bool) -> void:
	lights_on = state

func _update_lights() -> void:
	# Toggle visibility of all direct children
	for child in get_children():
		if child is Node3D:
			child.visible = lights_on
