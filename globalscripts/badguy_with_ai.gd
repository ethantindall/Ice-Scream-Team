extends CharacterBody3D

# --- ENUMS AND STATES ---
enum State { IDLE, WALKING, RUNNING, SEARCHING }

# --- NODES ---
@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hand_marker: Marker3D = $HandMarker
@onready var flashlight: Node3D = $GeneralSkeleton/BoneAttachment3D/Flashlight
@onready var eye_cast: RayCast3D = $EyeCast

# --- REFERENCES ---
@onready var player: CharacterBody3D = get_tree().get_first_node_in_group("player") as CharacterBody3D
@onready var dump_marker: Marker3D = _get_dump_marker()

# --- SETTINGS ---
@export var walking_speed: float = 1.5
@export var running_speed: float = 7.0
@export var rotation_speed: float = 10.0
@export var path_update_interval: float = 0.25 
@export var force_run: bool = true 
@export var search_wait_time: float = 10.0 # How long to wait at last known pos

# --- INTERNAL VARIABLES ---
var drag_timer: float = 0.0
var current_state: State = State.IDLE
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var update_timer: float = 0.0
var wait_timer: float = 0.0

var is_dragging: bool = false
var player_spotted: bool = false
var is_searching: bool = false
var is_waiting: bool = false
var last_known_position: Vector3 = Vector3.ZERO
var has_finished_game: bool = false 
var is_player_in_light_area: bool = false 

var cached_player_cam: Camera3D
var cached_player_anim: AnimationPlayer
var cached_player_collision: CollisionShape3D

func _ready() -> void:
	await get_tree().process_frame 
	
	if eye_cast:
		eye_cast.enabled = true
		eye_cast.exclude_parent = true
	
	if flashlight:
		if flashlight.has_signal("player_in_flashlight_area"):
			flashlight.player_in_flashlight_area.connect(_on_flashlight_player_in_area)
		if flashlight.has_signal("player_left_flashlight_area"):
			flashlight.player_left_flashlight_area.connect(_on_flashlight_player_left_area)

func _get_dump_marker() -> Marker3D:
	var truck = get_tree().get_first_node_in_group("ice_cream_truck")
	if truck:
		return truck.find_child("DumpMarker", true, false) as Marker3D
	return null

func _physics_process(delta: float) -> void:
	if has_finished_game: return

	if not is_on_floor():
		velocity.y -= gravity * delta

	update_timer += delta
	if update_timer >= path_update_interval:
		_process_vision_logic()
		update_pathfinding_target()
		update_timer = 0.0

	_handle_logic(delta)
	move_and_slide()

func _process_vision_logic() -> void:
    if is_dragging: return

    var can_see_now = _perform_vision_check()
    
    if can_see_now:
        last_known_position = player.global_position
        player_spotted = true
        is_searching = false
        is_waiting = false 
    else:
        # If we lost sight, but the player is NOT idle, keep searching
        if player_spotted:
            player_spotted = false
            is_searching = true
        
        # KEY CHANGE: If we are searching, check if we should stop based on player state
        if is_searching:
            # Assuming your Player script has a 'current_state' or 'state' enum
            # Replace 'State.IDLE' with the actual path to your player's Idle state
            if player.current_state == player.State.IDLE:
                # Optional: Only stop searching if we also reached the last known position
                if navigation_agent_3d.is_navigation_finished():
                    is_searching = false
                    is_waiting = true # Transition to the wait/look-around timer

func _perform_vision_check() -> bool:
	if not eye_cast or not player: return false
	if not is_player_in_light_area: return false

	var target_pos = player.global_position + Vector3(0, 0.6, 0)
	eye_cast.look_at(target_pos, Vector3.UP)
	var dist = global_position.distance_to(player.global_position)
	eye_cast.target_position = Vector3(0, 0, -(dist + 1.0))
	
	eye_cast.force_raycast_update() 

	if eye_cast.is_colliding():
		var hit = eye_cast.get_collider()
		if hit and (hit == player or hit.is_in_group("player")):
			return true
	return false

func _handle_logic(delta: float) -> void:
	var reached_destination = navigation_agent_3d.is_navigation_finished()
	
	if is_dragging:
		_drag_player_logic(delta)
		if reached_destination and global_position.distance_to(dump_marker.global_position) < 2.0:
			finish_drag()
		else:
			move_along_path(delta)
			
	elif player_spotted:
		current_state = State.RUNNING if force_run else State.WALKING
		move_along_path(delta)
		
	elif is_searching:
		current_state = State.WALKING
		move_along_path(delta)
		if reached_destination:
			# Switch from moving to waiting
			is_searching = false
			is_waiting = true
			wait_timer = 0.0
			print("NPC: Arrived at last known spot. Searching...")
	
	elif is_waiting:
			stop_moving()
			
			# Continue to look for the player even while standing still
			if _perform_vision_check():
				is_waiting = false
				player_spotted = true
				return # Immediately jump back to pursuit

			wait_timer += delta
			if wait_timer >= search_wait_time:
				# Final check: is the player still out there moving?
				if player.current_state != player.State.IDLE:
					# Keep waiting or return to search if player is still making noise/moving
					wait_timer = 0.0 
				else:
					is_waiting = false
					current_state = State.IDLE
					print("NPC: Player is quiet and hidden. Returning to idle.")
			

	else:
		current_state = State.IDLE
		stop_moving()

func _drag_player_logic(delta: float) -> void:
	if player:
		drag_timer += delta
		player.global_position = hand_marker.global_position
		player.rotation_degrees.x = 90
		player.rotation_degrees.y = rotation_degrees.y + 180
		if cached_player_cam:
			cached_player_cam.position = Vector3(0, 1.09, -0.35)

func update_pathfinding_target() -> void:
	if is_dragging and dump_marker:
		navigation_agent_3d.target_position = dump_marker.global_position
	elif player_spotted:
		navigation_agent_3d.target_position = player.global_position
	elif is_searching:
		navigation_agent_3d.target_position = last_known_position

func move_along_path(delta: float) -> void:
	var next_path_pos = navigation_agent_3d.get_next_path_position()
	var direction = global_position.direction_to(next_path_pos)
	
	var target_speed = walking_speed
	if current_state == State.RUNNING and not is_dragging:
		target_speed = running_speed
	
	if is_dragging:
		var cycle_time = fmod(drag_timer, 1.5)
		if cycle_time > 1.0:
			target_speed = 0.0
			animation_player.speed_scale = 0.0
		else:
			animation_player.speed_scale = 1.0
	else:
		animation_player.speed_scale = 1.0

	if direction.length() > 0.1:
		var target_angle = atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, rotation_speed * delta)

	velocity.x = direction.x * target_speed
	velocity.z = direction.z * target_speed
	
	var anim_name = "animations/Drag" if is_dragging else ("animations/Running" if target_speed > 2.0 else "animations/Walk")
	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name)

func stop_moving() -> void:
	velocity.x = move_toward(velocity.x, 0, 0.5)
	velocity.z = move_toward(velocity.z, 0, 0.5)
	if animation_player.has_animation("animations/idle3"):
		animation_player.play("animations/idle3")

func start_dragging():
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
	if cached_player_anim: cached_player_anim.play("Crawling Back")
	if cached_player_cam:
		var t = create_tween().set_parallel(true)
		t.tween_property(cached_player_cam, "rotation_degrees:x", -90.0, 0.5)
		t.tween_property(cached_player_cam, "position", Vector3(0, 1.09, -0.35), 0.5)

func finish_drag():
	has_finished_game = true 
	is_dragging = false
	velocity = Vector3.ZERO
	player.is_dragging = false
	player.rotation_degrees.x = 0
	if cached_player_collision: cached_player_collision.disabled = false
	print("GAME OVER")

# --- SIGNAL HANDLERS ---
func _on_flashlight_player_in_area() -> void:
	is_player_in_light_area = true

func _on_flashlight_player_left_area() -> void:
	is_player_in_light_area = false

func _on_insta_catch_area_body_entered(body: Node3D) -> void:
	if body == player and not is_dragging and not has_finished_game:
		start_dragging()

func _on_proximity_alert_area_body_entered(body: Node3D) -> void:
	if body == player and not is_dragging:
		player_spotted = true
		is_searching = false
		is_waiting = false
		last_known_position = player.global_position
