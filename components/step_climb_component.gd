extends Node3D
class_name StepClimbComponent

## The maximum height the character can step up.
@export var max_step_height := 0.35
## The minimum height to be considered a "step" (prevents jitter).
@export var min_step_height := 0.05
## How far in front of the character to check for obstacles.
@export var step_check_dist := 0.5

@onready var body: CharacterBody3D = get_parent()

func check_step_climb(direction: Vector3):
	if direction.length() < 0.1 or not body.is_on_floor():
		return
	
	var space_state = body.get_world_3d().direct_space_state
	
	# We check the direction we are moving, plus any walls we are currently sliding against
	var collision_directions = [direction.normalized()]
	
	for i in body.get_slide_collision_count():
		var collision = body.get_slide_collision(i)
		var collision_normal = collision.get_normal()
		var push_dir = -Vector3(collision_normal.x, 0, collision_normal.z).normalized()
		if push_dir.length() > 0.1:
			collision_directions.append(push_dir)
	
	var step_found = false
	var best_step_height = 0.0
	
	for check_dir in collision_directions:
		# Ray 1: Check for a wall in front
		var forward_start = body.global_position + Vector3.UP * 0.1
		var forward_end = forward_start + check_dir * step_check_dist
		
		var forward_query = PhysicsRayQueryParameters3D.create(forward_start, forward_end)
		forward_query.exclude = [body.get_rid()]
		var forward_result = space_state.intersect_ray(forward_query)
		
		if not forward_result:
			continue
		
		# Ray 2: Check downward from above the obstacle
		var down_start = forward_result.position + Vector3.UP * (max_step_height + 0.1)
		var down_end = down_start + Vector3.DOWN * (max_step_height + 0.2)
		
		var down_query = PhysicsRayQueryParameters3D.create(down_start, down_end)
		down_query.exclude = [body.get_rid()]
		var down_result = space_state.intersect_ray(down_query)
		
		if down_result:
			var step_height = down_result.position.y - body.global_position.y
			
			if step_height > min_step_height and step_height <= max_step_height:
				if step_height > best_step_height:
					best_step_height = step_height
					step_found = true
	
	if step_found:
		body.global_position.y += best_step_height + 0.02
		# Add a tiny forward nudge to ensure we clear the lip of the ledge
		body.global_position += direction.normalized() * 0.05
