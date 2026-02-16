extends Node3D
class_name IceCreamTruckAI

@onready var brake_audio: AudioStreamPlayer3D = $BrakeStreamPlayer
@onready var spawner: EnemySpawnerComponent = $EnemySpawnerComponent

@export_group("Movement")
@export var speed := 5.0
@export var acceleration := 2.0
@export var steering_speed := 3.0
@export var arrival_threshold := 1.0

@export_group("Pathfinding")
@export var starting_marker: RoadMarker
@export var pause_at_markers := 0.0
@export var avoid_backtracking := true

@export_group("Player Detection")
@export var raycast_check_interval := 0.2  # Check every 0.2 seconds
@export var player_layer := 1  # Physics layer the player is on
@export var brake_swerve_angle := 6.0  # Degrees to rotate during brake swerve
@export var brake_swerve_speed := 10.0  # How fast the swerve rotations happen
@export var brake_tilt_angle := -3.0  # Degrees to tilt forward when braking
@export var brake_tilt_speed := 10.0  # How fast the tilt happens

var current_speed := 0.0
var current_target: RoadMarker = null
var previous_marker: RoadMarker = null
var marker_before_previous: RoadMarker = null
var pause_timer := 0.0
var is_paused := false

# Detection variables
var player_in_area := false
var player_detected := false
var player_node: Node3D = null
var raycast_timer := 0.0
var player_seen_location: Vector3 = Vector3.ZERO
var closest_point_reached := false
var is_braking := false
var brake_swerve_state := 0  # 0 = not braking, 1 = left, 2 = right, 3 = center, 4 = done
var original_rotation: Vector3 = Vector3.ZERO
var target_brake_rotation: float = 0.0
var original_tilt: float = 0.0
var is_tilting := false

@onready var trigger_area: Area3D = $ObservationSystem/TriggerArea
@onready var right_raycast: RayCast3D = $ObservationSystem/RightRaycast
@onready var left_raycast: RayCast3D = $ObservationSystem/LeftRaycast

func _ready() -> void:
	# Connect area signals
	#if trigger_area:
	#	trigger_area.body_entered.connect(_on_player_entered_area)
	#	trigger_area.body_exited.connect(_on_player_exited_area)
	
	# Setup raycasts
	if right_raycast:
		right_raycast.enabled = true
		right_raycast.collision_mask = player_layer
	if left_raycast:
		left_raycast.enabled = true
		left_raycast.collision_mask = player_layer
	
	if starting_marker:
		global_position = starting_marker.global_position
		previous_marker = starting_marker
		_choose_next_marker()
	else:
		push_warning("IceCreamTruck: No starting_marker assigned!")

	spawner.enemy_despawned.connect(_on_enemy_hunt_finished)

func _physics_process(delta: float) -> void:
	# Update raycast timer
	raycast_timer += delta
	
	# Check for player if they're in the area
	if player_in_area and player_node and raycast_timer >= raycast_check_interval:
		raycast_timer = 0.0
		_check_player_visibility()
	
	# If player is detected, check if we've reached the closest point
	if player_detected:
		if not closest_point_reached and _is_at_closest_point_to_player():
			closest_point_reached = true
			is_braking = true
			brake_audio.play()
			brake_swerve_state = 1
			original_rotation = rotation
			original_tilt = rotation.x
			is_tilting = true
			target_brake_rotation = original_rotation.y - deg_to_rad(brake_swerve_angle)  # Start with left
			print("Reached closest point to player, initiating braking sequence...")
		
		if closest_point_reached:
			# 1. Apply brake tilt (visual juice)
			if is_tilting:
				if current_speed > 0.5:
					var target_tilt = original_tilt + deg_to_rad(brake_tilt_angle)
					rotation.x = lerp_angle(rotation.x, target_tilt, brake_tilt_speed * delta)
				else:
					rotation.x = lerp_angle(rotation.x, original_tilt, brake_tilt_speed * delta)
					if abs(rotation.x - original_tilt) < 0.01:
						is_tilting = false
			
			# 2. Apply brake swerve rotation sequence
			if is_braking and brake_swerve_state > 0 and brake_swerve_state < 4:
				var current_y = rotation.y
				var rotation_diff = target_brake_rotation - current_y
				
				if abs(rotation_diff) < 0.01:
					brake_swerve_state += 1
					if brake_swerve_state == 2:
						target_brake_rotation = original_rotation.y + deg_to_rad(brake_swerve_angle)
					elif brake_swerve_state == 3:
						target_brake_rotation = original_rotation.y
					elif brake_swerve_state == 4:
						is_braking = false # Swerve finished
				else:
					rotation.y = lerp_angle(current_y, target_brake_rotation, brake_swerve_speed * delta)
			
			# 3. Handle Deceleration
			current_speed = lerp(current_speed, 0.0, acceleration * delta)
			
			# 4. Trigger Spawn only when speed is near zero
			if current_speed <= 0.1:
				current_speed = 0.0
				if not spawner.is_processing_spawn and not spawner.current_enemy:
					print("Truck stopped. Triggering NPC spawn.")
					spawner.start_spawn_sequence()
			
			# 5. Apply movement if still sliding/braking
			if current_speed > 0.0:
				var forward = -global_transform.basis.z
				var velocity = forward * current_speed
				global_position += velocity * delta
			
			return # Exit process while interacting with player
	
	if not current_target:
		return
	
	# Handle pause at intersections
	if is_paused:
		pause_timer -= delta
		current_speed = lerp(current_speed, 0.0, acceleration * delta)
		if pause_timer <= 0:
			is_paused = false
		return
	
	# Normal Movement toward target
	var direction = (current_target.global_position - global_position)
	direction.y = 0
	var distance = direction.length()
	
	if distance < arrival_threshold:
		_arrive_at_marker()
		return
	
	var forward = -global_transform.basis.z
	var angle_to_target = forward.angle_to(direction.normalized())
	var turn_factor = 1.0 - clamp(angle_to_target / PI, 0.0, 0.7)
	var target_speed = speed * turn_factor
	
	current_speed = lerp(current_speed, target_speed, acceleration * delta)
	
	var velocity = direction.normalized() * current_speed
	global_position += velocity * delta
	
	_smooth_look_at(current_target.global_position, delta)
	
func _is_at_closest_point_to_player() -> bool:
	if player_seen_location == Vector3.ZERO or not current_target:
		return false
	
	# Flatten positions to 2D for distance calculation
	var truck_pos_2d = Vector2(global_position.x, global_position.z)
	var player_pos_2d = Vector2(player_seen_location.x, player_seen_location.z)
	var target_pos_2d = Vector2(current_target.global_position.x, current_target.global_position.z)
	
	# Calculate current distance to player
	var current_distance = truck_pos_2d.distance_to(player_pos_2d)
	
	# Calculate what the distance would be if we moved forward a bit
	var direction_to_target = (target_pos_2d - truck_pos_2d).normalized()
	var future_pos = truck_pos_2d + direction_to_target * (current_speed * 0.2)  # Look ahead 0.2 seconds
	var future_distance = future_pos.distance_to(player_pos_2d)
	
	# If future distance is greater, we've passed the closest point
	return future_distance > current_distance

func _smooth_look_at(target_pos: Vector3, delta: float) -> void:
	var flat_target = target_pos
	flat_target.y = global_position.y
	
	if global_position.distance_to(flat_target) > 0.1:
		var look_transform = global_transform.looking_at(flat_target, Vector3.UP)
		global_transform.basis = global_transform.basis.slerp(
			look_transform.basis, 
			steering_speed * delta
		)

func _check_player_visibility() -> void:
	if not player_node:
		return
	
	# Point both raycasts at the player
	var player_pos = player_node.global_position
	
	# Try right raycast
	right_raycast.target_position = right_raycast.to_local(player_pos)
	right_raycast.force_raycast_update()
	
	if right_raycast.is_colliding():
		var collider = right_raycast.get_collider()
		if collider == player_node or (collider.get_parent() == player_node if collider.get_parent() else false):
			_player_spotted()
			return
	
	# Try left raycast
	left_raycast.target_position = left_raycast.to_local(player_pos)
	left_raycast.force_raycast_update()
	
	if left_raycast.is_colliding():
		var collider = left_raycast.get_collider()
		if collider == player_node or (collider.get_parent() == player_node if collider.get_parent() else false):
			_player_spotted()
			return

func _player_spotted() -> void:
	if not player_detected:
		player_detected = true
		player_seen_location = player_node.global_position
		print("Player spotted at location: %s" % player_seen_location)
		# You can emit a signal here or trigger other events

func _on_player_entered_area(body: Node3D) -> void:
	# Check if it's the player (adjust this check based on your player setup)
	if body.is_in_group("player") or body.name == "Player":
		player_in_area = true
		player_node = body
		print("Player entered detection area")

func _on_player_exited_area(body: Node3D) -> void:
	if body == player_node:
		player_in_area = false
		player_node = null
		# Don't reset detection flags - truck should stay stopped
		print("Player left detection area")

func _arrive_at_marker() -> void:
	print("Arrived at marker: %s" % current_target.name)
	
	marker_before_previous = previous_marker
	previous_marker = current_target
	
	if pause_at_markers > 0:
		is_paused = true
		pause_timer = pause_at_markers
	
	_choose_next_marker()

func _choose_next_marker() -> void:
	if not current_target and not previous_marker:
		return
	
	var from_marker = current_target if current_target else previous_marker
	
	if avoid_backtracking:
		var all_connected = from_marker.get_connected_markers()
		var forward_options = all_connected.filter(func(m): return m != marker_before_previous)
		
		if forward_options.size() > 0:
			current_target = forward_options[randi() % forward_options.size()]
			print("Next destination: %s (avoiding backtrack)" % current_target.name)
		else:
			print("Dead end reached, backtracking...")
			current_target = from_marker.get_random_connected()
			if current_target:
				print("Next destination: %s (forced backtrack)" % current_target.name)
			else:
				push_warning("No valid next marker from: %s" % from_marker.name)
	else:
		var next = from_marker.get_random_connected(previous_marker)
		
		if next:
			current_target = next
			print("Next destination: %s" % current_target.name)
		else:
			push_warning("No valid next marker from: %s" % from_marker.name)
			current_target = from_marker.get_random_connected()

func set_destination(marker: RoadMarker) -> void:
	if marker:
		current_target = marker
		is_paused = false

func _on_trigger_area_body_entered(body: Node3D) -> void:
	_on_player_entered_area(body)

func _on_trigger_area_body_exited(body: Node3D) -> void:
	_on_player_exited_area(body)	


func _on_enemy_hunt_finished() -> void:
	# Reset truck variables so it can drive and look for the player again
	player_detected = false
	closest_point_reached = false
	is_braking = false
	brake_swerve_state = 0
	_choose_next_marker() 
	print("Enemy gone. Truck resuming patrol.")
