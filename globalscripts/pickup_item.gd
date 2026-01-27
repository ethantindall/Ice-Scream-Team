# pickup_item.gd
extends RigidBody3D

@export var item_name := "Pickupable Item"

var _player: Node3D = null
var _following: bool = false
var _holder: Node3D = null

func get_display_text():
	return item_name

func pickup():
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	_player = player
	_holder = player.get_node_or_null("Camera/ItemHolder")
	if not _holder:
		return

	# Freeze physics so it doesn't fall while held
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

	# Ignore collisions with the player
	add_collision_exception_with(_player)

	# Start following holder
	_following = true

func _physics_process(delta):
	if _following and _holder:
		global_transform.origin = _holder.global_transform.origin
		global_transform.basis = _holder.global_transform.basis

func drop(drop_position: Vector3):
	_following = false
	global_position = drop_position
	rotation = Vector3.ZERO
	call_deferred("_enable_physics")

func _enable_physics():
	freeze = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

	if _player:
		remove_collision_exception_with(_player)
		_player = null

# ---- NEW: apply throw AFTER physics is enabled ----
func _apply_throw(direction: Vector3, force: float):
	linear_velocity = direction * force
