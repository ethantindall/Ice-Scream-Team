extends Area3D

func _on_body_entered(body: Node3D) -> void:
	# Check if the body that entered belongs to the "player" group
	if body.is_in_group("player"):
		# 1. Trigger the fade-in on the sister node
		var ambiance = get_node("../NighttimeAmbiance")
		if ambiance.has_method("turn_on"):
			ambiance.turn_on()
		
		# 2. Print for debugging
		print("Player triggered ambiance. Deleting trigger zone.")
		
		# 3. Delete this Area3D so it never triggers again
		queue_free()
