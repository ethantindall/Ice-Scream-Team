extends RigidBody3D
# Boone's car

@export var drive_speed: float = 5.0
@export var target_distance: float = 10.0

var is_backing_up: bool = false
var start_position: Vector3 = Vector3.ZERO

func _ready() -> void:
	# 1. Start FROZEN so it doesn't jitter on the ramps at game start
	freeze = true 

func _physics_process(_delta: float) -> void:
	if is_backing_up:
		var current_distance = global_position.distance_to(start_position)
		
		if current_distance < target_distance:
			# Move the car
			linear_velocity = transform.basis.z * drive_speed
		else:
			# 2. We've reached the destination!
			is_backing_up = false
			linear_velocity = Vector3.ZERO
			
			# 3. Optional: Wait a split second for the car to "settle" 
			# on its suspension before freezing it again.
			await get_tree().create_timer(0.5).timeout
			freeze = true

# Drives the car 10 meters back when called by the MasterEventHandler
func follow_path():
	# 4. Unfreeze so the physics engine can move it
	freeze = false
	
	# Small delay to mimic the car "starting up" or the chocks being pulled
	await get_tree().create_timer(1.0).timeout
	
	start_position = global_position
	is_backing_up = true
