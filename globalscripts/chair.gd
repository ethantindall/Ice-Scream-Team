extends Node3D

@export var item_name = "Beanbag - Click to sit"
@export var mouse_sensitivity := 0.1
@export var max_look_yaw := 60.0   # Left/Right limit
@export var max_look_pitch := 50.0 # Up/Down limit
@export var disabled: bool = false

var original_collision_height: float = 0.0
var current_yaw_offset: float = 0.0
var current_pitch: float = 0.0
var is_sitting = false
var player: CharacterBody3D = null

@onready var sit_point: Marker3D = $SitPoint

func get_display_text():
	if disabled: return ""
	return item_name

func sit_down():
	if disabled: return
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if not player: return

	is_sitting = true
	var chair_col = get_node_or_null("StaticBody3D/CollisionShape3D")
	if chair_col: chair_col.disabled = true

	# 1. Snap player body to chair position and rotation
	player.global_position = sit_point.global_position + Vector3(0, 0.5, 0)
	player.global_rotation.y = global_rotation.y + PI
	
	# 2. Reset tracking offsets
	current_yaw_offset = 0.0
	current_pitch = 0.0

	# 3. Set state to SITTING (freezes physics movement)
	player.current_state = player.PlayerState.SITTING
	
	player.get_node("CanvasLayer/Control/InteractionLabel").text = "Press E to stand up"
	
	if player.has_node("AnimationPlayer"):
		player.get_node("AnimationPlayer").play("Gaming")

	# Collision height fix
	var collision = player.get_node_or_null("Collision") as CollisionShape3D
	if collision and collision.shape is CapsuleShape3D:
		original_collision_height = collision.shape.height
		collision.shape.height = 0.5

func _unhandled_input(event):
	if not is_sitting or not player:
		return

	# Handle Standing Up
	if Input.is_action_just_pressed("ui_drop"): 
		stand_up()
		return

	# Handle Independent Camera Look
	if event is InputEventMouseMotion:
		var camera = player.get_node_or_null("Camera")
		if camera:
			# Calculate Yaw (Horizontal)
			current_yaw_offset -= event.relative.x * mouse_sensitivity
			current_yaw_offset = clamp(current_yaw_offset, -max_look_yaw, max_look_yaw)
			
			# Calculate Pitch (Vertical)
			current_pitch -= event.relative.y * mouse_sensitivity
			current_pitch = clamp(current_pitch, -max_look_pitch, max_look_pitch)
			
			# Apply rotations ONLY to the camera node
			# The player body (parent) stays at global_rotation.y
			camera.rotation_degrees.y = current_yaw_offset
			camera.rotation_degrees.x = current_pitch

func stand_up():
	if not player: return
	
	var camera = player.get_node_or_null("Camera")
	
	# --- RESET CAMERA: Re-align with body ---
	if camera:
		camera.rotation = Vector3.ZERO
	
	is_sitting = false
	player.current_state = player.PlayerState.IDLE
	player.get_node("CanvasLayer/Control/InteractionLabel").text = ""
	
	var chair_col = get_node_or_null("StaticBody3D/CollisionShape3D")
	if chair_col: chair_col.disabled = false

	# Move player forward to avoid getting stuck in the chair
	var forward = -global_transform.basis.z.normalized()
	player.global_position = global_transform.origin + forward * -1.0

	# Restore collision height
	var collision = player.get_node_or_null("Collision") as CollisionShape3D
	if collision and collision.shape is CapsuleShape3D:
		collision.shape.height = original_collision_height

	player = null
