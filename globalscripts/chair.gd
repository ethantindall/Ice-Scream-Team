extends Node3D

@export var item_name = "Beanbag - Click to sit"
@export var mouse_sensitivity := 0.1
@export var max_look_yaw := 60.0   # How far left/right they can look
@export var max_look_pitch := 50.0 # How far up/down they can look
var original_collision_height: float = 0.0
var current_yaw_offset: float = 0.0

@export var disabled: bool = false

var is_sitting = false
var player: CharacterBody3D = null
var initial_yaw: float = 0.0



func get_display_text():
	if disabled:
		return ""
	return item_name

func sit_down():
	if disabled:
		return
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if not player: return

	is_sitting = true
	get_node("StaticBody3D/CollisionShape3D").disabled = true

	# Position & rotation logic...
	player.global_position = global_transform.origin + Vector3(0, 0.5, 0)
	player.global_rotation.y = global_rotation.y + PI
	#initial_yaw = rad_to_deg(player.global_rotation.y)

	# Store the base rotatiowdn
	initial_yaw = player.rotation_degrees.y 
	# Reset our tracking offset
	current_yaw_offset = 0.0


	player.immobile = true
	player.get_node("CanvasLayer/Control/InteractionLabel").text = "Press E to stand up"
	player.get_node("AnimationPlayer").play("Gaming")

	# ↓ Collision height fix with backup ↓
	var collision = player.get_node("Collision") as CollisionShape3D
	if collision and collision.shape is CapsuleShape3D:
		var cap = collision.shape as CapsuleShape3D

		# Store original height before changing
		original_collision_height = cap.height
		
		# Apply sitting size
		cap.height = 0.5



func _unhandled_input(event):
	if is_sitting and event is InputEventMouseMotion:
		# 1. Update the offset based on mouse movement
		var yaw_change = -event.relative.x * mouse_sensitivity
		current_yaw_offset += yaw_change
		
		# 2. Clamp the offset (e.g., -60 to +60)
		current_yaw_offset = clamp(current_yaw_offset, -max_look_yaw, max_look_yaw)

		# 3. Apply the clamped offset to the initial rotation
		player.rotation_degrees.y = initial_yaw + current_yaw_offset

		# Handle Vertical (Pitch) - this usually doesn't snap because it's limited to 90
		var camera = player.get_node_or_null("Camera")
		if camera:
			camera.rotation_degrees.x -= event.relative.y * mouse_sensitivity
			camera.rotation_degrees.x = clamp(camera.rotation_degrees.x, -max_look_pitch, max_look_pitch)
	if is_sitting and Input.is_action_just_pressed("ui_drop"): # Jump/Space
		stand_up()



func stand_up():
	is_sitting = false
	player.immobile = false
	player.get_node("CanvasLayer/Control/InteractionLabel").text = ""
	get_node("StaticBody3D/CollisionShape3D").disabled = false

	# Move player slightly forward from the chair before restoring collision
	var forward = -global_transform.basis.z.normalized()
	var stand_offset := -1  # tweak this number (0.5-1.0 usually feels good)
	player.global_position = global_transform.origin + forward * stand_offset

	# Restore collision height
	var collision = player.get_node("Collision") as CollisionShape3D
	if collision and collision.shape is CapsuleShape3D:
		var cap = collision.shape as CapsuleShape3D
		cap.height = original_collision_height

	player = null
