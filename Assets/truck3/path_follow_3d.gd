extends PathFollow3D

@export var speed := 10.0
@export var look_ahead := 2.0  # Distance ahead to look (higher = smoother/wider turns)
@export var steer_speed := 5.0 # Speed of rotation (lower = heavier feel)

func _physics_process(delta: float) -> void:
	# 1. Move the position along the path
	progress += speed * delta
	
	# 2. Get the position of a point further down the path
	var target_pos = get_parent().curve.sample_baked(progress + look_ahead)
	
	# 3. Calculate the target transform
	# We use the path's global position to transform the local baked point
	var global_target = get_parent().to_global(target_pos)
	
	# 4. Smoothly rotate towards that point
	_smooth_look_at(global_target, delta)

func _smooth_look_at(target: Vector3, delta: float) -> void:
	var origin = global_transform.origin
	
	# Avoid errors if the target is exactly where we are
	if origin.is_equal_approx(target):
		return
		
	# Create a temporary transform to find the "perfect" rotation
	var target_transform = global_transform.looking_at(target, Vector3.UP)
	
	# Slerp (Spherical Linear Interpolation) between current and target rotation
	global_transform.basis = global_transform.basis.slerp(
		target_transform.basis, 
		steer_speed * delta
	)
