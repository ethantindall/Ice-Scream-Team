extends CharacterBody3D

# Define our NPC states
enum State { IDLE, WALKING, RUNNING }

@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hand_marker: Marker3D = $HandMarker

# --- REFERENCES ---
@onready var player: CharacterBody3D = get_tree().get_first_node_in_group("player") as CharacterBody3D
@onready var dump_marker: Marker3D = _get_dump_marker()

@export var walking_speed: float = 1.5
@export var running_speed: float = 7.0
@export var rotation_speed: float = 10.0
@export var path_update_interval: float = 0.25 
@export var force_run: bool = false 

# --- RHYTHM VARIABLES ---
var drag_timer: float = 0.0 # Tracks the total time spent dragging

var current_state: State = State.WALKING
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var update_timer: float = 0.0
var is_dragging: bool = false
var has_finished_game: bool = false 

# Cache variables to store player components
var cached_player_cam: Camera3D
var cached_player_anim: AnimationPlayer
var cached_player_collision: CollisionShape3D

func _get_dump_marker() -> Marker3D:
	var truck = get_tree().get_first_node_in_group("ice_cream_truck")
	if truck:
		return truck.find_child("DumpMarker", true, false) as Marker3D
	return null

func _physics_process(delta: float) -> void:
	if has_finished_game: 
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	update_timer += delta
	if update_timer >= path_update_interval:
		update_pathfinding_target()
		update_timer = 0.0

	if is_dragging and player:
		# Update the rhythm timer
		drag_timer += delta
		
		player.global_position = hand_marker.global_position
		player.rotation_degrees.x = 90
		player.rotation_degrees.y = rotation_degrees.y + 180
		
		if cached_player_cam:
			cached_player_cam.position = Vector3(0, 1.09, -0.35)

	# --- THE REFINED GATE ---
	if navigation_agent_3d.is_navigation_finished() and is_dragging:
		finish_drag()
	elif not navigation_agent_3d.is_navigation_finished():
		if not is_dragging:
			current_state = State.RUNNING if force_run else State.WALKING
		move_along_path(delta)
	else:
		stop_moving()

	move_and_slide()

func update_pathfinding_target() -> void:
	if is_dragging:
		if dump_marker:
			navigation_agent_3d.target_position = dump_marker.global_position
	elif player:
		navigation_agent_3d.target_position = player.global_position

func move_along_path(delta: float) -> void:
	var next_path_pos = navigation_agent_3d.get_next_path_position()
	var direction = global_position.direction_to(next_path_pos)
	var target_speed = walking_speed
	
	if is_dragging:
		# --- RHYTHMIC PAUSE LOGIC ---
		# Cycle duration = 1.0s move + 0.5s pause = 1.5s total
		var cycle_time = fmod(drag_timer, 1.5)
		
		if cycle_time > 1.0:
			# We are in the 0.5s pause window
			target_speed = 0.0
			animation_player.speed_scale = 0.0 # Freeze the animation
		else:
			# We are in the 1.0s movement window
			target_speed = walking_speed
			animation_player.speed_scale = 1.0 # Resume animation
	else:
		# Normal non-dragging movement
		target_speed = running_speed if current_state == State.RUNNING else walking_speed
		animation_player.speed_scale = 1.0

	if direction.length() > 0.1:
		var target_angle = atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, rotation_speed * delta)

	velocity.x = direction.x * target_speed
	velocity.z = direction.z * target_speed
	
	# Handle Animations
	var anim_name = "animations/Drag" if is_dragging else ("animations/Running" if target_speed > 2.0 else "animations/Walk")
	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name)

func stop_moving() -> void:
	velocity.x = move_toward(velocity.x, 0, 0.5)
	velocity.z = move_toward(velocity.z, 0, 0.5)
	animation_player.speed_scale = 1.0
	if animation_player.has_animation("animations/idle3") and not is_dragging:
		animation_player.play("animations/idle3")

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body == player and not is_dragging and not has_finished_game:
		start_dragging()

func start_dragging():
	is_dragging = true
	drag_timer = 0.0 # Reset rhythm
	
	cached_player_cam = player.CAMERA
	cached_player_anim = player.ANIMATIONPLAYER
	cached_player_collision = player.COLLISION_MESH
	
	player.is_dragging = true 
	
	if cached_player_collision:
		cached_player_collision.disabled = true
	
	if cached_player_anim:
		cached_player_anim.play("Crawling Back")

	if cached_player_cam:
		var fall_tween = create_tween().set_parallel(true)
		fall_tween.tween_property(cached_player_cam, "rotation_degrees:x", -90.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		fall_tween.tween_property(cached_player_cam, "position", Vector3(0, 1.09, -0.35), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func finish_drag():
	has_finished_game = true 
	is_dragging = false
	velocity = Vector3.ZERO
	animation_player.speed_scale = 1.0
	
	player.is_dragging = false
	player.rotation_degrees.x = 0
	
	if cached_player_collision:
		cached_player_collision.disabled = false
	
	if animation_player.has_animation("animations/idle3"):
		animation_player.play("animations/idle3")
		
	print("GAME OVER: Player delivered!")
