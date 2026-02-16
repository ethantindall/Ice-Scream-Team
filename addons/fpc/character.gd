extends CharacterBody3D

# --- ENUMS ---
enum PlayerState {
	IDLE,
	WALKING,
	SPRINTING,
	CROUCHING,
	CROUCHWALK,
	DRAGGED,
	DIALOG
}

# --- CONFIG ---
@export var base_speed: float = 6.0
@export var sprint_speed: float = 10.0
@export var acceleration: float = 10.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.1
@export var drag_look_limit := 30.0

const CAM_STAND_HEIGHT := 1.4
const COLLISION_STAND_HEIGHT := 1.4
const COLLISION_CROUCH_HEIGHT := 1.0
var is_hidden := false

# --- STATE ---
var current_state: PlayerState = PlayerState.IDLE
var immobile: bool = false

@onready var player_raycast: RayCast3D = $Camera/RayCast3D
@onready var item_holder: Node3D = $Camera/ItemHolder
@onready var step_climb_component: StepClimbComponent = $StepClimbComponent

var _is_dragging := false
var is_dragging: bool:
	get:
		return _is_dragging
	set(v):
		_is_dragging = v
		current_state = PlayerState.DRAGGED if v else PlayerState.IDLE
		if player_raycast:
			player_raycast.enabled = not v

var _force_look := false
var force_look: bool:
	get:
		return _force_look
	set(v):
		_force_look = v
		current_state = PlayerState.DIALOG if v else PlayerState.IDLE

# --- MISC ---
var gravity := ProjectSettings.get_setting("physics/3d/default_gravity")
var forced_look_target: Vector3
var forced_look_speed := 3.0
var PAUSE := "ui_cancel"

# --- NODES ---
@onready var CAMERA: Camera3D = $Camera
@onready var COLLISION_MESH: CollisionShape3D = $Collision
@onready var ANIMATIONPLAYER: AnimationPlayer = $AnimationPlayer


func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	CAMERA.position.y = CAM_STAND_HEIGHT
	floor_snap_length = 0.2


func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta

	handle_jumping()

	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	handle_state_logic(input_dir.length() > 0)
	handle_movement(delta, direction)
	update_camera_fov()
	update_animations()


# --- INPUT ---

func _unhandled_input(event):
	if event.is_action_pressed(PAUSE):
		Input.mouse_mode = (
			Input.MOUSE_MODE_VISIBLE
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
			else Input.MOUSE_MODE_CAPTURED
		)

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if current_state == PlayerState.DRAGGED:
			CAMERA.rotation_degrees.y = clamp(
				CAMERA.rotation_degrees.y - event.relative.x * mouse_sensitivity,
				-drag_look_limit,
				drag_look_limit
			)
			var pitch = CAMERA.rotation_degrees.x - event.relative.y * mouse_sensitivity
			CAMERA.rotation_degrees.x = clamp(pitch, -110, -70)
		else:
			rotation_degrees.y -= event.relative.x * mouse_sensitivity
			CAMERA.rotation_degrees.x = clamp(
				CAMERA.rotation_degrees.x - event.relative.y * mouse_sensitivity,
				-60,
				90
			)


# --- MOVEMENT ---

func handle_movement(delta, direction: Vector3):
	var speed := base_speed
	if current_state == PlayerState.SPRINTING:
		speed = sprint_speed
	elif current_state in [PlayerState.CROUCHING, PlayerState.CROUCHWALK]:
		speed = base_speed * 0.4

	var target_velocity = direction * speed

	if is_on_floor():
		if direction.length() > 0.0:
			step_climb_component.check_step_climb(direction)
		velocity.x = target_velocity.x
		velocity.z = target_velocity.z
	else:
		velocity.x = lerp(velocity.x, target_velocity.x, 0.35)
		velocity.z = lerp(velocity.z, target_velocity.z, 0.35)

	move_and_slide()


func handle_jumping():
	if Input.is_action_pressed("ui_jump") and is_on_floor() and current_state != PlayerState.CROUCHING:
		velocity.y = jump_velocity
		floor_snap_length = 0.0
	else:
		floor_snap_length = 0.2


# --- STATE LOGIC ---

func handle_state_logic(moving: bool):
	if Input.is_action_pressed("ui_crouch"):
		current_state = PlayerState.CROUCHWALK if moving else PlayerState.CROUCHING
		_set_crouch(true)
		return
	else:
		_set_crouch(false)

	if moving and Input.is_action_pressed("ui_sprint"):
		current_state = PlayerState.SPRINTING
	elif moving:
		current_state = PlayerState.WALKING
	else:
		current_state = PlayerState.IDLE


func _set_crouch(active: bool):
	var target_cam_height = 0.8 if active else CAM_STAND_HEIGHT
	var target_h = COLLISION_CROUCH_HEIGHT if active else COLLISION_STAND_HEIGHT

	var tween = create_tween().set_parallel(true)
	tween.tween_property(CAMERA, "position:y", target_cam_height, 0.15)

	var capsule = COLLISION_MESH.shape as CapsuleShape3D
	if capsule:
		tween.tween_property(capsule, "height", target_h, 0.15)
		tween.tween_property(COLLISION_MESH, "position:y", target_h / 2.0, 0.15)


# --- VISUALS ---

func update_animations():
	if not ANIMATIONPLAYER:
		return

	match current_state:
		PlayerState.WALKING:
			ANIMATIONPLAYER.play("Walk")
		PlayerState.SPRINTING:
			ANIMATIONPLAYER.play("Running")
		PlayerState.CROUCHWALK:
			ANIMATIONPLAYER.play("CrouchWalk")
		PlayerState.CROUCHING:
			ANIMATIONPLAYER.play("CrouchIdle")
		_:
			ANIMATIONPLAYER.play("idle3")


func update_camera_fov():
	var target_fov = 65.0 if current_state == PlayerState.SPRINTING else 55.0
	CAMERA.fov = lerp(CAMERA.fov, target_fov, 0.1)

func get_current_state() -> PlayerState:
	return current_state
