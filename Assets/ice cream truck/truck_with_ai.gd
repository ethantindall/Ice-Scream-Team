extends Node3D
class_name IceCreamTruckAI

@export_group("Movement")
@export var speed := 5.0
@export var acceleration := 2.0
@export var steering_speed := 3.0
@export var arrival_threshold := 1.0

@export_group("Pathfinding")
@export var starting_marker: RoadMarker  # Set this to where truck starts
@export var pause_at_markers := 0.5
@export var avoid_backtracking := true  # Try to avoid immediate U-turns

var current_speed := 0.0
var current_target: RoadMarker = null
var previous_marker: RoadMarker = null  # Track where we came from
var marker_before_previous: RoadMarker = null  # Track 2 steps back for better backtrack avoidance
var pause_timer := 0.0
var is_paused := false

func _ready() -> void:
	if starting_marker:
		# Position truck at starting marker
		global_position = starting_marker.global_position
		previous_marker = starting_marker
		_choose_next_marker()
	else:
		push_warning("IceCreamTruck: No starting_marker assigned!")

func _physics_process(delta: float) -> void:
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
	direction.y = 0  # Keep movement on XZ plane
	var distance = direction.length()
	
	# Check if we've arrived
	if distance < arrival_threshold:
		_arrive_at_marker()
		return
	
	# Accelerate
	current_speed = lerp(current_speed, speed, acceleration * delta)
	
	# Move forward
	var velocity = direction.normalized() * current_speed
	global_position += velocity * delta
	
	# Smooth rotation toward target
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

func _arrive_at_marker() -> void:
	print("Arrived at marker: %s" % current_target.name)
	
	# Update marker history (shift the chain back)
	marker_before_previous = previous_marker
	previous_marker = current_target
	
	# Pause at intersection
	if pause_at_markers > 0:
		is_paused = true
		pause_timer = pause_at_markers
	
	# Choose next marker
	_choose_next_marker()

func _choose_next_marker() -> void:
	if not current_target and not previous_marker:
		return
	
	var from_marker = current_target if current_target else previous_marker
	
	if avoid_backtracking:
		# Get all connected markers
		var all_connected = from_marker.get_connected_markers()
		
		# Filter out the marker we just came from
		var forward_options = all_connected.filter(func(m): return m != marker_before_previous)
		
		if forward_options.size() > 0:
			# Pick randomly from forward options
			current_target = forward_options[randi() % forward_options.size()]
			print("Next destination: %s (avoiding backtrack)" % current_target.name)
		else:
			# Dead end - we have to backtrack
			print("Dead end reached, backtracking...")
			current_target = from_marker.get_random_connected()
			if current_target:
				print("Next destination: %s (forced backtrack)" % current_target.name)
			else:
				push_warning("No valid next marker from: %s" % from_marker.name)
	else:
		# Original behavior: exclude only immediate previous
		var next = from_marker.get_random_connected(previous_marker)
		
		if next:
			current_target = next
			print("Next destination: %s" % current_target.name)
		else:
			# No valid next marker - this shouldn't happen if markers are set up correctly
			push_warning("No valid next marker from: %s" % from_marker.name)
			# As fallback, allow backtracking
			current_target = from_marker.get_random_connected()

# Optional: Force truck to go to a specific marker
func set_destination(marker: RoadMarker) -> void:
	if marker:
		current_target = marker
		is_paused = false
