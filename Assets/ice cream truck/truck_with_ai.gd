extends Node3D
class_name IceCreamTruckAI

@onready var brake_audio: AudioStreamPlayer3D = $BrakeStreamPlayer
@onready var spawner: EnemySpawnerComponent = $EnemySpawnerComponent

@export var badguy_navigation_region: NavigationRegion3D
@export_group("Movement")
@export var speed := 15.0
@export var acceleration := 3.0
@export var steering_speed := 3.0
@export var arrival_threshold := 1.0

@export_group("Pathfinding")
@export var starting_marker: RoadMarker
@export var pause_at_markers := 0.0
@export var avoid_backtracking := true

@export_group("Player Detection")
@export var raycast_check_interval := 0.2
@export var player_layer := 1
@export var brake_swerve_angle := 6.0
@export var brake_swerve_speed := 10.0
@export var brake_tilt_angle := -3.0
@export var brake_tilt_speed := 10.0

@export var zone_handler: PlayerZoneHandler
var current_player_zone: String = ""


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
var brake_swerve_state := 0
var original_rotation: Vector3 = Vector3.ZERO
var target_brake_rotation: float = 0.0
var original_tilt: float = 0.0
var is_tilting := false


@onready var trigger_area: Area3D = $ObservationSystem/TriggerArea
@onready var right_raycast: RayCast3D = $ObservationSystem/RightRaycast
@onready var left_raycast: RayCast3D = $ObservationSystem/LeftRaycast

func _ready() -> void:
	# 1. Setup the spawner component immediately
	if spawner and badguy_navigation_region:
		spawner.setup_spawner(badguy_navigation_region)
	else:
		push_error("IceCreamTruck: Missing Spawner component or NavRegion reference!")

	# 2. Setup raycasts
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

	if zone_handler:
		zone_handler.player_zone_changed.connect(_on_player_zone_changed)
		current_player_zone = zone_handler.PLAYER_ZONE


	spawner.enemy_despawned.connect(_on_enemy_hunt_finished)

func _physics_process(delta: float) -> void:
	raycast_timer += delta
	
	if player_in_area and player_node and raycast_timer >= raycast_check_interval:
		raycast_timer = 0.0
		_check_player_visibility()
	
	if player_detected:
		if not closest_point_reached and _is_at_closest_point_to_player():
			closest_point_reached = true
			is_braking = true
			brake_audio.play()
			brake_swerve_state = 1
			original_rotation = rotation
			original_tilt = rotation.x
			is_tilting = true
			target_brake_rotation = original_rotation.y - deg_to_rad(brake_swerve_angle)
			print("Reached closest point to player, initiating braking sequence...")
		
		if closest_point_reached:
			if is_tilting:
				if current_speed > 0.5:
					var target_tilt = original_tilt + deg_to_rad(brake_tilt_angle)
					rotation.x = lerp_angle(rotation.x, target_tilt, brake_tilt_speed * delta)
				else:
					rotation.x = lerp_angle(rotation.x, original_tilt, brake_tilt_speed * delta)
					if abs(rotation.x - original_tilt) < 0.01:
						is_tilting = false
			
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
						is_braking = false
				else:
					rotation.y = lerp_angle(current_y, target_brake_rotation, brake_swerve_speed * delta)
			
			current_speed = lerp(current_speed, 0.0, acceleration * delta)
			
			if current_speed <= 0.1:
				current_speed = 0.0
				if not spawner.is_processing_spawn and not spawner.current_enemy:
					print("Truck stopped. Triggering NPC spawn.")
					spawner.start_spawn_sequence()
			
			if current_speed > 0.0:
				var forward = -global_transform.basis.z
				var velocity = forward * current_speed
				global_position += velocity * delta
			
			return
	
	if not current_target:
		return
	
	if is_paused:
		pause_timer -= delta
		current_speed = lerp(current_speed, 0.0, acceleration * delta)
		if pause_timer <= 0:
			is_paused = false
		return
	
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
	var truck_pos_2d = Vector2(global_position.x, global_position.z)
	var player_pos_2d = Vector2(player_seen_location.x, player_seen_location.z)
	var target_pos_2d = Vector2(current_target.global_position.x, current_target.global_position.z)
	var current_distance = truck_pos_2d.distance_to(player_pos_2d)
	var direction_to_target = (target_pos_2d - truck_pos_2d).normalized()
	var future_pos = truck_pos_2d + direction_to_target * (current_speed * 0.2)
	var future_distance = future_pos.distance_to(player_pos_2d)
	return future_distance > current_distance

func _smooth_look_at(target_pos: Vector3, delta: float) -> void:
	var flat_target = target_pos
	flat_target.y = global_position.y
	if global_position.distance_to(flat_target) > 0.1:
		var look_transform = global_transform.looking_at(flat_target, Vector3.UP)
		global_transform.basis = global_transform.basis.slerp(look_transform.basis, steering_speed * delta)

func _check_player_visibility() -> void:
	if not player_node: return
	var player_pos = player_node.global_position
	
	right_raycast.target_position = right_raycast.to_local(player_pos)
	right_raycast.force_raycast_update()
	if right_raycast.is_colliding():
		var collider = right_raycast.get_collider()
		if collider == player_node or (collider.get_parent() == player_node if collider.get_parent() else false):
			_player_spotted()
			return
	
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

func _on_player_entered_area(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		player_in_area = true
		player_node = body

func _on_player_exited_area(body: Node3D) -> void:
	if body == player_node:
		player_in_area = false
		player_node = null

func _arrive_at_marker() -> void:
	marker_before_previous = previous_marker
	previous_marker = current_target
	if pause_at_markers > 0:
		is_paused = true
		pause_timer = pause_at_markers
	_choose_next_marker()

func _choose_next_marker() -> void:
	if not current_target and not previous_marker: return
	var from_marker = current_target if current_target else previous_marker
	if avoid_backtracking:
		var all_connected = from_marker.get_connected_markers()
		var forward_options = all_connected.filter(func(m): return m != marker_before_previous)
		if forward_options.size() > 0:
			current_target = forward_options[randi() % forward_options.size()]
		else:
			current_target = from_marker.get_random_connected()
	else:
		current_target = from_marker.get_random_connected(previous_marker)

func set_destination(marker: RoadMarker) -> void:
	if marker:
		current_target = marker
		is_paused = false

func _on_trigger_area_body_entered(body: Node3D) -> void:
	_on_player_entered_area(body)

func _on_trigger_area_body_exited(body: Node3D) -> void:
	_on_player_exited_area(body)

func _on_enemy_hunt_finished() -> void:
	player_detected = false
	closest_point_reached = false
	is_braking = false
	brake_swerve_state = 0
	
	if player_seen_location == Vector3.ZERO:
		_choose_next_marker()
		return

	var direction_to_player = (player_seen_location - global_position).normalized()
	direction_to_player.y = 0
	var from_marker = current_target if current_target else previous_marker
	var options = from_marker.get_connected_markers()
	
	var best_marker: RoadMarker = null
	var best_score: float = -1.0
	
	for marker in options:
		var direction_to_marker = (marker.global_position - global_position).normalized()
		direction_to_marker.y = 0
		var score = direction_to_player.dot(direction_to_marker)
		if score > best_score:
			best_score = score
			best_marker = marker

	if best_marker:
		current_target = best_marker
	else:
		_choose_next_marker()


func _on_player_zone_changed(new_zone: String) -> void:
    current_player_zone = new_zone