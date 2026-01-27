extends Node3D 

# Drag and drop the Marker3D-MikeHouse into this slot in the Inspector
@export var target_node: Node3D 

func _process(_delta: float) -> void:
	if target_node:
		# Points the arrow's -Z axis (forward) directly at the marker
		# We use global_position because the arrow is nested under the camera
		look_at(target_node.global_position, Vector3.UP)
		
		# OPTIONAL: If your arrow model points the wrong way, 
		# uncomment the line below and change '90' to 180 or -90 
		# rotate_object_local(Vector3.UP, deg_to_rad(0))
	else:
		# Optional: Search for the node by name if not assigned in Inspector
		target_node = get_tree().current_scene.find_child("Marker3D-MikeHouse", true, false)
