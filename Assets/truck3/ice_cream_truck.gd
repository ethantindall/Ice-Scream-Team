extends Node3D

@export var is_active_truck: bool

@export_group("Movement Physics")
@export_subgroup("Speeds")
@export var speed := 3.0
@export var acceleration := 3.0

@export_subgroup("Steering")
@export var look_ahead_distance := 4.0 
@export var steering_speed := 5.0      

@export_subgroup("Audio")
@export var is_playing: bool = false
@export var audio_speed: float = 0.8

var current_speed := 0.0
var is_driving = false

@onready var path_follower: PathFollow3D = get_parent() as PathFollow3D
@onready var path_node: Path3D = get_parent().get_parent() as Path3D

func _ready() -> void:
	if is_active_truck:
		add_to_group("active_truck")
		print("added to active truck group")
		self.visible = false
		
		$AudioStreamPlayer3D.pitch_scale = audio_speed
		$AudioStreamPlayer3D.playing = is_playing

func _physics_process(delta: float) -> void:
	if not path_follower or not path_node:
		return
	if not is_driving:
		return

	# 1. Move the PathFollower parent
	current_speed = lerp(current_speed, speed, acceleration * delta)
	path_follower.progress += current_speed * delta
	
	# 2. Smoothly rotate this node (the car container)
	_smooth_rotate(delta)

func _smooth_rotate(delta: float) -> void:
	var curve = path_node.curve
	var path_length = curve.get_baked_length()
	
	# 1. Get current position and a point slightly ahead
	var target_progress = path_follower.progress + look_ahead_distance
	
	var current_pos = global_position
	var target_pos_local: Vector3
	
	if target_progress <= path_length:
		# We are still on the path, look at the future point
		target_pos_local = curve.sample_baked(target_progress)
	else:
		# We are at or past the end. 
		# Look at the very last point + the direction of the final segment
		var end_pos = curve.sample_baked(path_length)
		var pre_end_pos = curve.sample_baked(path_length - 0.1)
		var exit_direction = (end_pos - pre_end_pos).normalized()
		
		# Create a virtual target point floating out in space past the end
		target_pos_local = end_pos + exit_direction * look_ahead_distance

	var target_pos_global = path_node.to_global(target_pos_local)
	
	# 2. Lock the Y axis
	target_pos_global.y = global_position.y 

	# 3. Apply the rotation
	if global_position.distance_to(target_pos_global) > 0.1:
		var look_transform = global_transform.looking_at(target_pos_global, Vector3.UP)
		global_transform.basis = global_transform.basis.slerp(look_transform.basis, steering_speed * delta)
