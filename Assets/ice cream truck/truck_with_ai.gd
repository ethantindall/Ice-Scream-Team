extends Node3D
class_name IceCreamTruckAI

@onready var brake_audio: AudioStreamPlayer3D = $BrakeStreamPlayer
@onready var spawner: EnemySpawnerComponent = $EnemySpawnerComponent

@export var badguy_navigation_region: NavigationRegion3D
@export_group("Movement")
@export var movement_enabled: bool = false
@export var speed := 15.0
@export var acceleration := 3.0
@export var steering_speed := 3.0
@export var arrival_threshold := 1.0

@export_group("Pathfinding")
@export var starting_marker: RoadMarker
@export var pause_at_markers := 0.0
@export var avoid_backtracking := true

@export_group("Player Detection")
@export var searching_enabled: bool = true
@export var raycast_check_interval := 0.2
@export var player_layer := 1
@export var brake_swerve_angle := 6.0
@export var brake_swerve_speed := 10.0
@export var brake_tilt_angle := -3.0
@export var brake_tilt_speed := 10.0


var current_speed := 0.0
var current_target: RoadMarker = null
var previous_marker: RoadMarker = null
var visited_history: Array[RoadMarker] = []  # Stores last 4 visited markers
const HISTORY_SIZE := 4
var pause_timer := 0.0
var is_paused := false

# Detection variables
var player_in_area := false
var player_detected := false
var player_node: Node3D = null  # Set once in _ready, never cleared
var raycast_timer := 0.0
# Set only on confirmed raycast hit (used for braking closest-point logic)
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
	# 1. Grab the player node globally so we always have their current position.
	# We never null this out — the truck always knows where the player is.
	player_node = get_tree().get_first_node_in_group("player")
	if not player_node:
		push_warning("IceCreamTruck: Could not find a node in group 'player'!")

	# 2. Setup the spawner component immediately
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
		visited_history.push_back(starting_marker)
		_choose_next_marker()
	else:
		push_warning("IceCreamTruck: No starting_marker assigned!")


	spawner.enemy_despawned.connect(_on_enemy_hunt_finished)

func _physics_process(delta: float) -> void:
	if not movement_enabled:
		return
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
		# Do NOT null player_node — we keep the reference forever so the truck
		# always knows the player's current position when choosing the next marker.

func _arrive_at_marker() -> void:
	# Push the reached marker into visited history before choosing next
	if current_target:
		visited_history.push_back(current_target)
		if visited_history.size() > HISTORY_SIZE:
			visited_history.pop_front()
		previous_marker = current_target

	if pause_at_markers > 0:
		is_paused = true
		pause_timer = pause_at_markers
	MasterEventHandler._on_dialogic_signal("truck_arrived_at_point")
	
	_choose_next_marker()
	

func _choose_next_marker() -> void:
	var from_marker: RoadMarker = current_target if current_target else previous_marker
	if not from_marker:
		return

	var all_connected: Array = from_marker.get_connected_markers()
	if all_connected.is_empty():
		return

	# --- Step 1: Hard-exclude the immediately previous marker (strict no-backtrack) ---
	var last: RoadMarker = visited_history.back() if not visited_history.is_empty() else null
	var no_backtrack: Array = all_connected.filter(func(m): return m != last)

	# Dead end — allow backtracking as last resort
	if no_backtrack.is_empty():
		no_backtrack = all_connected

	# --- Step 2: Soft-exclude recently visited markers if fresh options exist ---
	var preferred: Array = no_backtrack.filter(func(m): return m not in visited_history)
	var candidates: Array = preferred if not preferred.is_empty() else no_backtrack

	# --- Step 3: Score candidates by closeness to player, weighted by forward alignment ---
	# Pure distance-to-player can pick a marker that's closer to the player but behind
	# the truck, causing wrong turns. We blend distance with a forward-facing bonus so
	# the truck always chooses a marker it can actually drive toward.
	if player_node != null:
		var player_pos: Vector3 = player_node.global_position
		var truck_forward: Vector3 = -global_transform.basis.z

		var best_marker: RoadMarker = null
		var best_score := -INF

		for marker in candidates:
			# How close does this marker get us to the player? (lower dist = better, so negate)
			var dist: float = marker.global_position.distance_to(player_pos)
			var dist_score: float = -dist

			# Is this marker roughly in front of us? dot product: 1.0 = straight ahead, -1.0 = behind
			var dir_to_marker: Vector3 = (marker.global_position - global_position).normalized()
			var alignment: float = truck_forward.dot(dir_to_marker)

			# Blend: distance matters most, but a strong backward penalty prevents U-turns.
			# Alignment weight of 30.0 means a marker must be ~30 units closer to the player
			# to overcome being directly behind the truck.
			var score: float = dist_score + alignment * 30.0

			if score > best_score:
				best_score = score
				best_marker = marker

		if best_marker:
			current_target = best_marker
			return

	# --- Step 4: Fallback — pick randomly (only before player node is found) ---
	current_target = candidates[randi() % candidates.size()]

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
	# current_target is still set to wherever the truck was heading before it braked.
	# Just let it continue — no need to recalculate anything.


func set_position_and_target(pos_marker: RoadMarker, target_marker: RoadMarker) -> void:
	global_position = pos_marker.global_position
	current_target = target_marker
