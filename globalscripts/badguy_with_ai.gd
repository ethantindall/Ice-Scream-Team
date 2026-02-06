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
@export var search_wait_time: float = 20.0 
@export var wander_radius: float = 11.0 # Distance the NPC will wander from the last seen spot

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
var wander_target: Vector3 = Vector3.ZERO # The current random point NPC is walking toward
var has_finished_game: bool = false 
var is_player_in_light_area: bool = false 

var cached_player_cam: Camera3D
var cached_player_anim: AnimationPlayer
var cached_player_collision: CollisionShape3D


var get_em_anyway: bool = false  # Tracks if the NPC has seen the player hide in the current hiding attempt


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
	if truck: return truck.find_child("DumpMarker", true, false) as Marker3D
	return null

func _physics_process(delta: float) -> void:
	if has_finished_game: return
	if not is_on_floor(): velocity.y -= gravity * delta

	update_timer += delta
	if update_timer >= path_update_interval:
		_process_vision_logic()
		update_pathfinding_target()
		update_timer = 0.0

	_handle_logic(delta)
	move_and_slide()

func _process_vision_logic() -> void:
	if is_dragging: return

	if is_player_in_light_area or player_spotted or is_searching or is_waiting:
		var can_see_now = _perform_vision_check()
		
		if can_see_now:
			last_known_position = player.global_position
			player_spotted = true
			is_searching = false
			is_waiting = false
			wait_timer = 0.0
		else:
			if player_spotted:
				player_spotted = false
				is_searching = true

				if player.is_hidden:
					get_em_anyway = true
					last_known_position = player.global_position
				else:
					print("The player is not hidden, but we lost sight of him, so we will search for him.")
					get_em_anyway = false
	else:
		eye_cast.rotation = Vector3.ZERO




func _perform_vision_check() -> bool:
	if not eye_cast or not player: return false
	eye_cast.clear_exceptions()
	eye_cast.add_exception(self)
	
	var item_holder = player.get_node_or_null("Camera/ItemHolder")
	if item_holder:
		for child in item_holder.get_children():
			if child is RigidBody3D:
				eye_cast.add_exception(child)
	
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
		# NPC actively sees the player
		current_state = State.RUNNING if force_run else State.WALKING
		move_along_path(delta)
		
	elif is_searching or get_em_anyway:
		# NPC lost sight, but is RUSHING to the last seen spot
		current_state = State.RUNNING # Change this from WALKING to RUNNING
		move_along_path(delta)
		
		if reached_destination:
			is_searching = false
			is_waiting = true
			wait_timer = 0.0
			_pick_next_wander_point()
			print("NPC: Reached last seen spot. Starting search...")
	
	elif is_waiting:
		# NPC is now at the spot and is WALKING around looking
		current_state = State.WALKING
		
		# Procedural head sweep (optional visual flair)
		if eye_cast:
			eye_cast.rotation.y = sin(Time.get_ticks_msec() * 0.005) * 0.8
			
		if reached_destination:
			_pick_next_wander_point()
			
		move_along_path(delta)
		
		wait_timer += delta
		if wait_timer >= search_wait_time:
			_stop_searching()
			
	else:
		current_state = State.IDLE
		stop_moving()


func _drag_player_logic(delta: float) -> void:
	if player:
		drag_timer += delta
		# Player automatically follows hand_marker as parent
		# Only update camera position if needed
		if cached_player_cam:
			cached_player_cam.position = Vector3(0, 1.09, -0.35)

func _pick_next_wander_point() -> void:
	# Pick a random spot within a circle around the last known position
	var angle = randf() * TAU
	var distance = randf_range(3.0, wander_radius) # Minimum 3m away so they actually move
	var offset = Vector3(cos(angle) * distance, 0, sin(angle) * distance)
	wander_target = last_known_position + offset

func _stop_searching() -> void:
	is_waiting = false
	player_spotted = false 
	is_searching = false
	get_em_anyway = false
	if eye_cast: eye_cast.rotation = Vector3.ZERO
	print("NPC: Gave up search.")

func update_pathfinding_target() -> void:
	if is_dragging and dump_marker:
		navigation_agent_3d.target_position = dump_marker.global_position
	elif player_spotted:
		navigation_agent_3d.target_position = player.global_position
	elif is_searching:
		# Priority 1: The exact spot the player vanished
		navigation_agent_3d.target_position = last_known_position
	elif is_waiting:
		# Priority 2: Random spots near that spot
		navigation_agent_3d.target_position = wander_target
	elif get_em_anyway and player.is_hidden:
		# If we know the player is hidden, we can still try to go to them
		navigation_agent_3d.target_position = last_known_position
		print("going to get em!")

func move_along_path(delta: float) -> void:
	var next_path_pos = navigation_agent_3d.get_next_path_position()
	var direction = global_position.direction_to(next_path_pos)
	var target_speed = running_speed if (current_state == State.RUNNING and not is_dragging) else walking_speed
	
	if is_dragging:
		var cycle_time = fmod(drag_timer, 1.5)
		animation_player.speed_scale = 0.0 if cycle_time > 1.0 else 1.0
		if cycle_time > 1.0: target_speed = 0.0
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
	player.velocity = Vector3.ZERO
	player.set_physics_process(false)

	is_dragging = true
	player_spotted = false
	is_searching = false
	is_waiting = false

	# Stop player physics
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	drag_timer = 0.0

	# Cache
	cached_player_cam = player.CAMERA
	cached_player_anim = player.ANIMATIONPLAYER
	cached_player_collision = player.COLLISION_MESH
	player.is_dragging = true

	# Disable collision
	if cached_player_collision:
		cached_player_collision.disabled = true
	player.collision_layer = 0
	player.collision_mask = 0

	# Play crawl animation
	if cached_player_anim:
		cached_player_anim.play("Crawling Back")

	# Parent to hand marker
	if player.get_parent() != hand_marker:
		player.get_parent().remove_child(player)
		hand_marker.add_child(player)

	# Reset local transform and rotation
	player.transform = Transform3D.IDENTITY
	player.rotation_degrees = Vector3(90, 0, 0) # lying down, feet away

	# Adjust camera
	if cached_player_cam:
		var t = create_tween().set_parallel(true)
		t.tween_property(cached_player_cam, "rotation_degrees:x", -90.0, 0.5)
		t.tween_property(cached_player_cam, "position", Vector3(0, 1.09, -0.35), 0.5)

func finish_drag():
	has_finished_game = true
	is_dragging = false
	velocity = Vector3.ZERO
	player.is_dragging = false

	# Restore collision
	if cached_player_collision:
		cached_player_collision.disabled = false
	player.collision_layer = 1 # or whatever it was before
	player.collision_mask = 1  # or whatever it was before

	# Restore player rotation
	player.rotation_degrees = Vector3.ZERO
	player.set_physics_process(true)

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
