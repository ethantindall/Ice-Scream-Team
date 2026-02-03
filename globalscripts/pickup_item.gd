# pickup_item.gd
extends RigidBody3D

@export var item_name := "Pickupable Item"

# --- INTERNAL STATE ---
var _player: Node3D = null
var _following: bool = false
var _holder: Node3D = null

# --- PUBLIC METHODS ---
func get_display_text() -> String:
	return item_name

func pickup():
	var player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if not player:
		return

	_player = player
	_holder = player.get_node_or_null("Camera/ItemHolder")
	if not _holder:
		return

	# --- TURN OFF PHYSICS ---
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

	# Disable collisions entirely while held
	collision_layer = 0
	collision_mask = 0

	# Ensure player is ignored
	add_collision_exception_with(_player)

	# Start following the holder
	_following = true


func _physics_process(delta: float) -> void:
	if _following and _holder:
		# Match holder position and rotation
		global_transform.origin = _holder.global_transform.origin
		global_transform.basis = _holder.global_transform.basis


func drop(drop_position: Vector3) -> void:
	_following = false
	global_position = drop_position
	rotation = Vector3.ZERO
	call_deferred("_enable_physics")


func _enable_physics() -> void:
	# Restore collision layers so item interacts normally
	collision_layer = 1
	collision_mask = 1

	# Re-enable physics simulation
	freeze = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

	# Remove collision exception with player
	if _player:
		remove_collision_exception_with(_player)
		_player = null


# --- THROW ITEM ---
func _apply_throw(direction: Vector3, force: float) -> void:
	# Apply throw after physics is enabled
	linear_velocity = direction * force
