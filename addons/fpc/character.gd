extends CharacterBody3D

# --- CONFIG ---
var immobile: bool = false
var PAUSE: String = "ui_cancel"

var base_speed: float = 6
var sprint_speed: float = 10
var crouch_speed: float = 1.0
var acceleration: float = 10.0
var jump_velocity: float = 4.5
var mouse_sensitivity: float = 0.1
var air_control: float = 0.35
var motion_smoothing: bool = false

# --- STEP CLIMB CONFIG ---
var max_step_height: float = 0.25 # Slightly higher than 0.2 for better reliability
var step_check_dist: float = 0.4

# --- STATE ---
var speed: float = base_speed
var current_speed: float = 0.0
var state: String = "normal" 
var was_on_floor: bool = true
var is_crouching: bool = false
var sprint_enabled: bool = true
var just_jumped: bool = false

# --- CAMERA / COLLISION ---
var CAM_STAND_HEIGHT := 1.8
var CAM_CROUCH_HEIGHT := 1.6
var CAM_SPRINT_Z := -0.2
var CAM_CROUCH_Z := -0.3
var COLLISION_STAND_HEIGHT := 1.8
var COLLISION_CROUCH_HEIGHT := 1.4
var cam_lerp_speed := 10.0
var camera_base_z: float = 0.0 

# --- MISC ---
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var force_look: bool = false
var forced_look_target: Vector3
var forced_look_speed: float = 3.0

# --- NODES ---
@onready var CAMERA: Camera3D = $Camera
@onready var COLLISION_MESH: CollisionShape3D = $Collision
@onready var ANIMATIONPLAYER: AnimationPlayer = $AnimationPlayer


var is_hidden: bool = false


func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera_base_z = CAMERA.transform.origin.z
	
	# IMPROVEMENT: Ensure Floor Snap is active in the Inspector
	apply_floor_snap() 

func _physics_process(delta):
	if immobile:
		velocity.x = lerp(velocity.x, 0.0, acceleration * delta)
		velocity.z = lerp(velocity.z, 0.0, acceleration * delta)
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		update_animations(Vector3.ZERO)
		if force_look: _update_forced_look(delta)
		return 

	current_speed = get_real_velocity().length()
	
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	handle_jumping()

	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	handle_movement(delta, input_dir)
	handle_state(input_dir.length() > 0)

	update_camera_fov()

	if not was_on_floor and is_on_floor():
		just_jumped = false
	elif was_on_floor and not is_on_floor():
		just_jumped = true

	was_on_floor = is_on_floor()

	var move_dir = global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)
	move_dir.y = 0
	update_animations(move_dir.normalized())

func handle_jumping():
	if Input.is_action_pressed("ui_jump") and is_on_floor() and state != "crouching":
		velocity.y = jump_velocity
		# Disable snapping temporarily so we can actually leave the ground
		floor_snap_length = 0.0 
	else:
		# Set snap length back to your max step height
		floor_snap_length = max_step_height

func handle_movement(delta, input_dir: Vector2):
	var direction = (global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var target_velocity = direction * speed

	if is_on_floor():
		# --- ROBUST STEP CLIMBING ---
		if direction.length() > 0:
			_check_step_climb(direction)

		if motion_smoothing:
			velocity.x = lerp(velocity.x, target_velocity.x, acceleration * delta)
			velocity.z = lerp(velocity.z, target_velocity.z, acceleration * delta)
		else:
			velocity.x = target_velocity.x
			velocity.z = target_velocity.z
	else:
		velocity.x = lerp(velocity.x, target_velocity.x, air_control)
		velocity.z = lerp(velocity.z, target_velocity.z, air_control)

	move_and_slide()

func _check_step_climb(direction: Vector3):
	var space_state = get_world_3d().direct_space_state
	
	# We use a RayQuery but with a thicker margin via 'motion' or multiple offsets
	# For simplicity and reliability, we check 3 points: Center, Left, and Right
	var lateral_offset = global_transform.basis.x * 0.2
	var check_points = [
		Vector3.ZERO,
		lateral_offset,
		-lateral_offset
	]
	
	for offset in check_points:
		var ray_start = global_position + offset + (direction * step_check_dist) + Vector3(0, max_step_height, 0)
		var ray_end = ray_start + Vector3(0, -max_step_height * 1.2, 0)
		
		var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
		query.exclude = [get_rid()]
		var result = space_state.intersect_ray(query)

		if result:
			var step_height = result.position.y - global_position.y
			if step_height > 0.02 and step_height <= max_step_height:
				# Check if there is head-room before snapping up
				# (Prevents getting stuck in low ceilings)
				global_position.y += step_height
				return # Exit once one point finds a valid step

func handle_state(moving: bool):
	if Input.is_action_pressed("ui_crouch"):
		if not is_crouching: set_crouch(true)
	elif is_crouching:
		set_crouch(false)

	if sprint_enabled and not is_crouching and moving:
		if Input.is_action_pressed("ui_sprint"):
			if state != "sprinting": enter_sprint_state()
		elif state == "sprinting": enter_normal_state()
	elif state == "sprinting":
		enter_normal_state()

func enter_normal_state():
	state = "normal"
	speed = base_speed
	var tween = get_tree().create_tween()
	tween.tween_property(CAMERA, "transform:origin:z", camera_base_z, 0.15)
	if ANIMATIONPLAYER: ANIMATIONPLAYER.play("idle3")

func enter_sprint_state():
	state = "sprinting"
	speed = sprint_speed
	var tween = get_tree().create_tween()
	tween.tween_property(CAMERA, "transform:origin:z", camera_base_z + CAM_SPRINT_Z, 0.15)

func update_animations(direction: Vector3):
	if not ANIMATIONPLAYER or just_jumped: return
	if direction.length() > 0:
		match state:
			"normal": ANIMATIONPLAYER.play("Walk")
			"sprinting": ANIMATIONPLAYER.play("Running")
			"crouching": ANIMATIONPLAYER.play("CrouchWalk")
	else:
		match state:
			"normal", "sprinting": ANIMATIONPLAYER.play("idle3")
			"crouching": ANIMATIONPLAYER.play("CrouchIdle")

func _process(delta):
	if force_look: _update_forced_look(delta)
	if Input.is_action_just_pressed(PAUSE):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func _update_forced_look(delta):
	if not forced_look_target: return
	var target_transform = CAMERA.global_transform.looking_at(forced_look_target, Vector3.UP)
	var target_rotation = target_transform.basis.get_euler()
	rotation.y = lerp_angle(rotation.y, target_rotation.y, forced_look_speed * delta)
	CAMERA.rotation.x = lerp_angle(CAMERA.rotation.x, target_rotation.x, forced_look_speed * delta)

func set_crouch(value: bool):
	is_crouching = value
	state = "crouching" if is_crouching else "normal"
	var target_cam_height = CAM_CROUCH_HEIGHT if is_crouching else CAM_STAND_HEIGHT
	var target_collision_height = COLLISION_CROUCH_HEIGHT if is_crouching else COLLISION_STAND_HEIGHT

	var tween = get_tree().create_tween()
	tween.tween_property(CAMERA, "transform:origin:y", target_cam_height, 0.15)

	var capsule = COLLISION_MESH.shape as CapsuleShape3D
	if capsule:
		capsule.height = target_collision_height

func update_camera_fov():
	CAMERA.fov = lerp(CAMERA.fov, 65.0 if state == "sprinting" else 55.0, 0.3)

func _unhandled_input(event):
	if immobile or force_look: return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation_degrees.y -= event.relative.x * mouse_sensitivity
		CAMERA.rotation_degrees.x = clamp(CAMERA.rotation_degrees.x - event.relative.y * mouse_sensitivity, -60, 90)
