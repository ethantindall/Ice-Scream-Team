extends CharacterBody3D

# --- ENUMS ---
enum PlayerState { NORMAL, SPRINTING, CROUCHING, DRAGGED, DIALOG }

# --- CONFIG ---
@export var base_speed: float = 6
@export var sprint_speed: float = 10
@export var acceleration: float = 10.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.1
@export var drag_look_limit := 30.0

var CAM_STAND_HEIGHT := 1.4
var COLLISION_STAND_HEIGHT := 1.4
var COLLISION_CROUCH_HEIGHT := 1.0

# --- STATE ---
var current_state: PlayerState = PlayerState.NORMAL
var immobile: bool = false
var is_hidden: bool = false
var is_dragging: bool = false: 
	set(v): 
		is_dragging = v
		if v: 
			current_state = PlayerState.DRAGGED
		else:
			current_state = PlayerState.NORMAL
			# Ensure camera returns to normal when drag ends
			if CAMERA: 
				CAMERA.position.y = CAM_STAND_HEIGHT
				CAMERA.rotation_degrees.y = 0

# --- STEP CLIMB CONFIG ---
var max_step_height: float = 0.25 
var min_step_height: float = 0.05 
var step_check_dist: float = 0.4 

# --- MISC ---
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var force_look: bool = false:
	set(v):
		force_look = v
		current_state = PlayerState.DIALOG if v else PlayerState.NORMAL

var forced_look_target: Vector3
var forced_look_speed: float = 3.0
var PAUSE: String = "ui_cancel"

# --- NODES ---
@onready var CAMERA: Camera3D = $Camera
@onready var COLLISION_MESH: CollisionShape3D = $Collision
@onready var ANIMATIONPLAYER: AnimationPlayer = $AnimationPlayer

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	CAMERA.transform.origin.y = CAM_STAND_HEIGHT 
	floor_snap_length = 0.2

func _physics_process(delta):
	match current_state:
		PlayerState.DRAGGED:
			_handle_dragged_physics(delta)
			return
		PlayerState.DIALOG:
			_handle_dialog_physics(delta)
			return

	if not is_on_floor():
		velocity.y -= gravity * delta
	
	handle_jumping()

	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	handle_movement(delta, direction)
	handle_state_logic(input_dir.length() > 0)
	update_camera_fov()
	update_animations(direction)

func _handle_dragged_physics(delta):
	velocity = Vector3.ZERO
	move_and_slide()

func _handle_dialog_physics(delta):
	var dir = global_position.direction_to(forced_look_target)
	var target_yaw = atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, forced_look_speed * delta)
	velocity.x = lerp(velocity.x, 0.0, acceleration * delta)
	velocity.z = lerp(velocity.z, 0.0, acceleration * delta)
	move_and_slide()

func _unhandled_input(event):
	if event.is_action_pressed(PAUSE):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if current_state == PlayerState.DRAGGED:
			CAMERA.rotation_degrees.y = clamp(CAMERA.rotation_degrees.y - event.relative.x * mouse_sensitivity, -drag_look_limit, drag_look_limit)
			var pitch = CAMERA.rotation_degrees.x - event.relative.y * mouse_sensitivity
			CAMERA.rotation_degrees.x = clamp(pitch, -110, -70)
		else:
			rotation_degrees.y -= event.relative.x * mouse_sensitivity
			CAMERA.rotation_degrees.x = clamp(CAMERA.rotation_degrees.x - event.relative.y * mouse_sensitivity, -60, 90)

func handle_movement(delta, direction: Vector3):
	var speed = base_speed
	if current_state == PlayerState.SPRINTING: speed = sprint_speed
	elif current_state == PlayerState.CROUCHING: speed = base_speed * 0.4
	
	var target_velocity = direction * speed
	if is_on_floor():
		if direction.length() > 0: _check_step_climb(direction)
		velocity.x = target_velocity.x
		velocity.z = target_velocity.z
	else:
		velocity.x = lerp(velocity.x, target_velocity.x, 0.35)
		velocity.z = lerp(velocity.z, target_velocity.z, 0.35)
	move_and_slide()

func handle_state_logic(moving: bool):
	if current_state == PlayerState.DRAGGED or current_state == PlayerState.DIALOG:
		return

	if Input.is_action_pressed("ui_crouch"):
		if current_state != PlayerState.CROUCHING: set_crouch_logic(true)
	elif current_state == PlayerState.CROUCHING:
		set_crouch_logic(false)
	
	if current_state != PlayerState.CROUCHING and moving and Input.is_action_pressed("ui_sprint"):
		current_state = PlayerState.SPRINTING
	elif current_state == PlayerState.SPRINTING:
		current_state = PlayerState.NORMAL

func set_crouch_logic(active: bool):
	current_state = PlayerState.CROUCHING if active else PlayerState.NORMAL
	var target_cam_height = 0.8 if active else CAM_STAND_HEIGHT 
	var target_h = COLLISION_CROUCH_HEIGHT if active else COLLISION_STAND_HEIGHT
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(CAMERA, "position:y", target_cam_height, 0.15)
	var capsule = COLLISION_MESH.shape as CapsuleShape3D
	if capsule:
		tween.tween_property(capsule, "height", target_h, 0.15)
		tween.tween_property(COLLISION_MESH, "position:y", target_h / 2.0, 0.15)

func update_animations(direction: Vector3):
	if not ANIMATIONPLAYER: return
	if direction.length() > 0:
		match current_state:
			PlayerState.NORMAL: ANIMATIONPLAYER.play("Walk")
			PlayerState.SPRINTING: ANIMATIONPLAYER.play("Running")
			PlayerState.CROUCHING: ANIMATIONPLAYER.play("CrouchWalk")
	else:
		match current_state:
			PlayerState.CROUCHING: ANIMATIONPLAYER.play("CrouchIdle")
			_: ANIMATIONPLAYER.play("idle3")

func update_camera_fov():
	var target_fov = 65.0 if current_state == PlayerState.SPRINTING else 55.0
	CAMERA.fov = lerp(CAMERA.fov, target_fov, 0.1)

func handle_jumping():
	if Input.is_action_pressed("ui_jump") and is_on_floor() and current_state != PlayerState.CROUCHING:
		velocity.y = jump_velocity
		floor_snap_length = 0.0
	else:
		floor_snap_length = 0.2

func _check_step_climb(direction: Vector3):
	var space_state = get_world_3d().direct_space_state
	var ray_start = global_position + (direction * step_check_dist) + Vector3(0, max_step_height, 0)
	var ray_end = ray_start + Vector3(0, -max_step_height * 1.5, 0)
	var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.exclude = [get_rid()]
	var result = space_state.intersect_ray(query)
	if result:
		var step_height = result.position.y - global_position.y
		if step_height > min_step_height and step_height <= max_step_height:
			global_position.y += step_height + 0.02
			global_position += direction * 0.05
