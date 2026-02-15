extends Node3D
class_name IceCreamTruckAI

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

func _physics_process(delta: float) -> void:
	# Update raycast timer
	raycast_timer += delta
	
	# Check for player if they're in the area
	if player_in_area and player_node and raycast_timer >= raycast_check_interval:
		raycast_timer = 0.0
		_check_player_visibility()
	
	# If player is detected, stop the truck
	if player_detected:
		current_speed = lerp(current_speed, 0.0, acceleration * delta)
		return
	
	if not current_target:
		return
	
	# Handle pause at intersections
	if is_paused:
		pause_timer -= delta
		current_speed = lerp(current_speed, 0.0, acceleration * delta)
		if pause_timer <= 0:
			is_paused = false
		return
	
	# Move toward target
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
		print("Player spotted! Truck stopping.")
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
		player_detected = false  # Reset detection when player leaves
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
