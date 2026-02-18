extends CharacterBody3D

# --- ENUMS AND STATES ---
enum State { IDLE, WALKING, SPRINTING, SEARCHING, RETURNING_TO_SPAWN }

# --- NODES ---
@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hand_marker: Marker3D = $HandMarker
@onready var flashlight: Node3D = $GeneralSkeleton/BoneAttachment3D/Flashlight
@onready var eye_cast: RayCast3D = $EyeCast
@onready var step_climb_component: StepClimbComponent = $StepClimbComponent

# --- REFERENCES ---
@onready var player: CharacterBody3D = get_tree().get_first_node_in_group("player") as CharacterBody3D
@onready var dump_marker: Marker3D = _get_dump_marker()

# --- SETTINGS ---
@export var walking_speed: float = 3.0
@export var running_speed: float = 10.0
@export var rotation_speed: float = 10.0
@export var path_update_interval: float = 0.25 
@export var force_run: bool = true 
@export var search_wait_time: float = 20.0 
@export var wander_radius: float = 11.0 
@export var player_left_navmesh_wait_time: float = 2.0

# --- ANTI-STUCK SETTINGS ---
@export var stuck_threshold: float = 0.5
@export var recovery_duration: float = 0.6

# --- INTERNAL VARIABLES ---
var drag_timer: float = 0.0
var current_state: State = State.IDLE
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var update_timer: float = 0.0
var wait_timer: float = 0.0

var last_frame_position: Vector3 = Vector3.ZERO
var stuck_timer: float = 0.0
var recovery_timer: float = 0.0
var is_recovering: bool = false
var recovery_vector: Vector3 = Vector3.ZERO

var is_dragging: bool = false
var player_spotted: bool = false
var is_searching: bool = false
var is_waiting: bool = false
var last_known_position: Vector3 = Vector3.ZERO
var wander_target: Vector3 = Vector3.ZERO 
var has_finished_game: bool = false 
var is_player_in_light_area: bool = false 

var cached_player_cam: Camera3D
var cached_player_anim: AnimationPlayer
var cached_player_collision: CollisionShape3D

var get_em_anyway: bool = false

# --- RETURN TO SPAWN VARIABLES ---
var spawn_position: Vector3 = Vector3.ZERO
var is_returning_to_spawn: bool = false
var player_left_navmesh_timer: float = 0.0
var is_waiting_after_player_left: bool = false

signal returned_to_truck

func _ready() -> void:
	await get_tree().process_frame 
	spawn_position = global_position

	
	if eye_cast:
		eye_cast.enabled = true
		eye_cast.exclude_parent = true
	
	if flashlight:
		if flashlight.has_signal("player_in_flashlight_area"):
			flashlight.player_in_flashlight_area.connect(_on_flashlight_player_in_area)
		if flashlight.has_signal("player_left_flashlight_area"):
			flashlight.player_left_flashlight_area.connect(_on_flashlight_player_left_area)
	
	if player:
		player_spotted = true
		last_known_position = player.global_position

func _get_dump_marker() -> Marker3D:
	var marker = get_tree().get_first_node_in_group("dump_marker") as Marker3D
	if marker: return marker
	var truck = get_tree().get_first_node_in_group("ice_cream_truck")
	if truck: return truck.find_child("DumpMarker", true, false) as Marker3D
	return null

func _physics_process(delta: float) -> void:
	if has_finished_game: return
	if not is_on_floor(): velocity.y -= gravity * delta

	# 1. RECOVERY OVERRIDE
	if is_recovering:
		_handle_recovery(delta)
		move_and_slide()
		last_frame_position = global_position
		return

	# 2. PATHING UPDATES
	update_timer += delta
	if update_timer >= path_update_interval:
		_check_player_on_navmesh()
		_process_vision_logic()
		update_pathfinding_target()
		update_timer = 0.0

	# 3. NORMAL AI LOGIC
	_handle_logic(delta)

	# 4. STUCK DETECTION
	# Modified to only trigger if velocity intent is high but actual movement is low
	if velocity.length() > 0.5 and not is_dragging:
		if global_position.distance_to(last_frame_position) < 0.02:
			stuck_timer += delta
		else:
			stuck_timer = 0.0
		
		if stuck_timer >= stuck_threshold:
			_start_recovery()
	else:
		stuck_timer = 0.0
		
	last_frame_position = global_position
	move_and_slide()

# --- RECOVERY SYSTEM ---

func _start_recovery() -> void:
	is_recovering = true
	recovery_timer = 0.0
	stuck_timer = 0.0
	var back = -global_transform.basis.z
	var random_offset = Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
	recovery_vector = (back + random_offset).normalized()

func _handle_recovery(delta: float) -> void:
	recovery_timer += delta
	velocity.x = recovery_vector.x * walking_speed
	velocity.z = recovery_vector.z * walking_speed
	
	if animation_player.has_animation("animations/Walk"):
		animation_player.play("animations/Walk", -1, -1.0)

	if recovery_timer >= recovery_duration:
		is_recovering = false
		update_pathfinding_target()

# --- MOVEMENT AND LOGIC ---

func move_along_path(delta: float) -> void:
	# Don't move if we've arrived
	if navigation_agent_3d.is_navigation_finished():
		stop_moving()
		return

	var next_path_pos = navigation_agent_3d.get_next_path_position()
	var direction = global_position.direction_to(next_path_pos)
	direction.y = 0 
	direction = direction.normalized()

	var target_speed = running_speed if (current_state == State.SPRINTING and not is_dragging) else walking_speed
	
	if is_dragging:
		var cycle_time = fmod(drag_timer, 1.5)
		if cycle_time > 1.0: target_speed = 0.0
		animation_player.speed_scale = 0.0 if cycle_time > 1.0 else 1.0
	else:
		animation_player.speed_scale = 1.0

	# Rotation
	if direction.length() > 0.1:
		var target_angle = atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, rotation_speed * delta)
		if step_climb_component:
			step_climb_component.check_step_climb(direction)

	velocity.x = direction.x * target_speed
	velocity.z = direction.z * target_speed
	
	# Animations based on movement speed
	if velocity.length() > 0.2:
		var anim_name = "animations/Walk"
		if is_dragging: 
			anim_name = "animations/Drag"
		elif target_speed > walking_speed + 1.0: 
			anim_name = "animations/Running"
			
		if animation_player.has_animation(anim_name):
			if animation_player.current_animation != anim_name:
				animation_player.play(anim_name)
	else:
		stop_moving()

func _handle_logic(delta: float) -> void:
	var reached_destination = navigation_agent_3d.is_navigation_finished()
	
	if is_waiting_after_player_left and not is_returning_to_spawn:
		player_left_navmesh_timer += delta
		current_state = State.IDLE
		stop_moving()
		if player_left_navmesh_timer >= player_left_navmesh_wait_time:
			_start_return_to_spawn()
		return
	
	if is_returning_to_spawn:
		current_state = State.SPRINTING
		if reached_destination and global_position.distance_to(spawn_position) < 2.0:
			_despawn()
		else:
			move_along_path(delta)
		return
	
	if is_dragging:
		_drag_player_logic(delta)
		if dump_marker and reached_destination and global_position.distance_to(dump_marker.global_position) < 2.0:
			finish_drag()
		else:
			move_along_path(delta)
			
	elif player_spotted:
		current_state = State.SPRINTING if force_run else State.WALKING
		move_along_path(delta)
		
	elif is_searching or get_em_anyway:
		current_state = State.SPRINTING 
		if reached_destination:
			is_searching = false
			is_waiting = true
			wait_timer = 0.0
			_pick_next_wander_point()
		else:
			move_along_path(delta)
	
	elif is_waiting:
		current_state = State.WALKING
		wait_timer += delta
		if wait_timer >= search_wait_time: 
			_stop_searching()
		elif reached_destination: 
			_pick_next_wander_point()
		else:
			move_along_path(delta)
			
	else:
		current_state = State.IDLE
		stop_moving()

# --- UTILITIES ---

func _check_player_on_navmesh() -> void:
	if is_dragging or not player: return
	var nav_map = navigation_agent_3d.get_navigation_map()
	var closest_point = NavigationServer3D.map_get_closest_point(nav_map, player.global_position)
	
	if player.global_position.distance_to(closest_point) > 2.0:
		if not is_waiting_after_player_left and not is_returning_to_spawn:
			is_waiting_after_player_left = true
			player_left_navmesh_timer = 0.0
	else:
		if is_waiting_after_player_left or is_returning_to_spawn:
			_cancel_return_to_spawn()
			player_spotted = true
			last_known_position = player.global_position

func _cancel_return_to_spawn() -> void:
	is_waiting_after_player_left = false
	is_returning_to_spawn = false
	player_left_navmesh_timer = 0.0

func _process_vision_logic() -> void:
	if is_dragging or is_returning_to_spawn: return
	
	var can_see_now = _perform_vision_check()
	if can_see_now:
		last_known_position = player.global_position
		player_spotted = true
		is_searching = false
		is_waiting = false
		wait_timer = 0.0
	elif player_spotted:
		player_spotted = false
		is_searching = true
		get_em_anyway = player.is_hidden
	
	if not player_spotted and not is_searching and not is_waiting:
		if eye_cast: eye_cast.rotation = Vector3.ZERO

func _perform_vision_check() -> bool:
	if not eye_cast or not player: return false
	eye_cast.clear_exceptions()
	eye_cast.add_exception(self)
	var target_pos = player.global_position + Vector3(0, 0.6, 0)
	eye_cast.look_at(target_pos, Vector3.UP)
	eye_cast.target_position = Vector3(0, 0, -(global_position.distance_to(player.global_position) + 1.0))
	eye_cast.force_raycast_update() 
	if eye_cast.is_colliding():
		var hit = eye_cast.get_collider()
		return hit == player or hit.is_in_group("player")
	return false

func update_pathfinding_target() -> void:
	if is_returning_to_spawn: 
		navigation_agent_3d.target_position = spawn_position
	elif is_dragging:
		if dump_marker: navigation_agent_3d.target_position = dump_marker.global_position
	elif player_spotted: 
		navigation_agent_3d.target_position = player.global_position
	elif is_searching: 
		navigation_agent_3d.target_position = last_known_position
	elif is_waiting: 
		navigation_agent_3d.target_position = wander_target
	elif get_em_anyway and player.is_hidden: 
		navigation_agent_3d.target_position = last_known_position

func stop_moving() -> void:
	velocity.x = move_toward(velocity.x, 0, 0.5)
	velocity.z = move_toward(velocity.z, 0, 0.5)
	if animation_player.has_animation("animations/idle3"):
		if animation_player.current_animation != "animations/idle3":
			animation_player.play("animations/idle3")

func _start_return_to_spawn() -> void:
	is_returning_to_spawn = true
	player_spotted = false
	is_searching = false
	is_waiting = false
	is_waiting_after_player_left = false
	get_em_anyway = false

func _despawn() -> void:
	returned_to_truck.emit()
	queue_free()

func _drag_player_logic(delta: float) -> void:
	if player:
		drag_timer += delta
		if cached_player_cam: cached_player_cam.position = Vector3(0, 1.09, -0.35)

func _pick_next_wander_point() -> void:
	var angle = randf() * TAU
	var distance = randf_range(3.0, wander_radius)
	wander_target = last_known_position + Vector3(cos(angle) * distance, 0, sin(angle) * distance)
	navigation_agent_3d.target_position = wander_target

func _stop_searching() -> void:
	is_waiting = false; player_spotted = false; is_searching = false; get_em_anyway = false
	if eye_cast: eye_cast.rotation = Vector3.ZERO

func start_dragging():
	player.set_physics_process(false)
	is_dragging = true
	player_spotted = false
	is_searching = false
	is_waiting = false
	drag_timer = 0.0
	cached_player_cam = player.CAMERA
	cached_player_anim = player.ANIMATIONPLAYER
	cached_player_collision = player.COLLISION_MESH
	player.is_dragging = true
	if cached_player_collision: cached_player_collision.disabled = true
	player.collision_layer = 0; player.collision_mask = 0
	if cached_player_anim: cached_player_anim.play("Crawling Back")
	if player.get_parent() != hand_marker:
		player.get_parent().remove_child(player)
		hand_marker.add_child(player)
	player.transform = Transform3D.IDENTITY
	player.rotation_degrees = Vector3(90, 0, 0)
	if cached_player_cam:
		var t = create_tween().set_parallel(true)
		t.tween_property(cached_player_cam, "rotation_degrees:x", -90.0, 0.5)
		t.tween_property(cached_player_cam, "position", Vector3(0, 1.09, -0.35), 0.5)

func finish_drag():
	has_finished_game = true
	is_dragging = false
	velocity = Vector3.ZERO
	player.is_dragging = false
	if cached_player_collision: cached_player_collision.disabled = false
	player.collision_layer = 1; player.collision_mask = 1
	player.rotation_degrees = Vector3.ZERO
	player.set_physics_process(true)

func _on_flashlight_player_in_area() -> void: is_player_in_light_area = true
func _on_flashlight_player_left_area() -> void: is_player_in_light_area = false

func _on_insta_catch_area_body_entered(body: Node3D) -> void:
	if body == player and not is_dragging and not has_finished_game:
		start_dragging()

func _on_proximity_alert_area_body_entered(body: Node3D) -> void:
	if body == player and not is_dragging:
		player_spotted = true
		is_searching = false
		is_waiting = false
		last_known_position = player.global_position

func get_current_state() -> State: return current_state
