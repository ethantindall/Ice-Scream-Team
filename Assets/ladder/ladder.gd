extends Node3D

@export var item_name := "Ladder - Click to climb"
@export var climb_speed := 3.0
@export var climb_duration := 2.5

var climbing := false

func get_display_text():
	return item_name


# Node structure is as follows
# Ladder (Node3D)
# - Box005 (MeshInstance3D)
# - StaticBody3D
# - - CollisionShape3D
# - Path3D
#when climb is called, the player should be somehow added to the path 3d and move along path
# when they reach the end of the path, remove them from path 3d


func climb():
	var player = get_tree().get_first_node_in_group("player")
	if not player or climbing:
		return
	
	climbing = true
	var path: Path3D = $Path3D
	var path_follow := PathFollow3D.new()
	path.add_child(path_follow)
	path_follow.rotation_mode = PathFollow3D.ROTATION_NONE
	
	if player is CharacterBody3D:
		player.set_physics_process(false)

	#play player animation player CrawlFront
	player.get_node("AnimationPlayer").play("Crawling Front")
	var tween = create_tween()

	# tween_method(method_to_call, start_value, end_value, duration)
	# This will call the 'lambda' function every frame
	tween.tween_method(
		func(ratio: float):
			# Update the helper node's position
			path_follow.progress_ratio = ratio
			# Move the player to match it immediately
			player.global_position = path_follow.global_position,
		0.0,            # Start ratio
		1.0,            # End ratio
		climb_duration  # Time in seconds (e.g., 2.0 or 3.0)
	).set_trans(Tween.TRANS_LINEAR) # Linear is best for ladders; SINE can feel 'floaty'

	tween.finished.connect(func():
		path_follow.queue_free()
		if player is CharacterBody3D:
			player.set_physics_process(true)
		climbing = false
	)
