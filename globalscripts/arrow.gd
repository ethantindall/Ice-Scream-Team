extends Node3D 

var active = false

@onready var daytime_target: Marker3D = get_tree().current_scene.find_child("Marker3D-MikeHouse", true, false)
@onready var nighttime_target: Marker3D = get_tree().current_scene.find_child("Marker3D-TimmyHouse", true, false)

func _process(_delta: float) -> void:
	if not active: 
		return
	
	var target_node: Marker3D
	if GameSettings.time_of_day == "DAY":
		target_node = daytime_target	
	else:
		target_node = nighttime_target

	# Points the arrow's -Z axis (forward) directly at the marker
	look_at(target_node.global_position, Vector3.UP)
		

func set_active(is_active: bool) -> void:
	active = is_active
	visible = is_active
	set_process(is_active)
	set_physics_process(is_active)
