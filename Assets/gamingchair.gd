extends Node3D

## Configuration
@export var item_name = "Gaming Chair - Click to sit"

@export var screen_scene: String = "res://2Dscenes/asteroid/computerscreen.tscn"
@export var mouse_sensitivity := 0.1
@export var max_look_yaw := 60.0
@export var max_look_pitch := 50.0

## State
var is_sitting = false
var player: CharacterBody3D = null
var original_collision_height: float = 0.0
var initial_yaw: float = 0.0
var current_yaw_offset: float = 0.0

func get_display_text():
	return item_name

func sit_down():
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if not player: return

	is_sitting = true
	# Disable chair collision so it doesn't bump the player
	var chair_col = get_node_or_null("StaticBody3D/CollisionShape3D")
	if chair_col: chair_col.disabled = true

	# Position & Rotation Logic
	player.global_position = global_transform.origin + Vector3(0, 0.5, 0)
	player.global_rotation.y = global_rotation.y + PI
	
	initial_yaw = player.rotation_degrees.y 
	current_yaw_offset = 0.0

	player.immobile = true
	player.get_node("CanvasLayer/Control/InteractionLabel").text = ""
	
	if player.has_node("AnimationPlayer"):
		player.get_node("AnimationPlayer").play("Gaming")

	# Collision height fix
	var collision = player.get_node_or_null("Collision") as CollisionShape3D
	if collision and collision.shape is CapsuleShape3D:
		original_collision_height = collision.shape.height
		collision.shape.height = 0.5

	# --- NEW LOGIC: Wait 1 second then open computer ---
	await get_tree().create_timer(1.0).timeout
	open_computer()

func open_computer():
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if not player: return

	SceneManager.load_scene(screen_scene)
	
	# Disable player processing while in 2D game
	player.set_process(false)
	player.set_physics_process(false)
	
	var canvas_layer = player.get_node_or_null("CanvasLayer")
	if canvas_layer:
		canvas_layer.visible = false

func _unhandled_input(event):
	if is_sitting and event is InputEventMouseMotion:
		# Handle YAW (Left/Right)
		var yaw_change = -event.relative.x * mouse_sensitivity
		current_yaw_offset = clamp(current_yaw_offset + yaw_change, -max_look_yaw, max_look_yaw)
		player.rotation_degrees.y = initial_yaw + current_yaw_offset

		# Handle PITCH (Up/Down)
		var camera = player.get_node_or_null("Camera")
		if camera:
			camera.rotation_degrees.x = clamp(camera.rotation_degrees.x - (event.relative.y * mouse_sensitivity), -max_look_pitch, max_look_pitch)

# Note: stand_up() is not called automatically anymore per your request 
# that they stay seated after the game.
func stand_up():
	is_sitting = false
	player.immobile = false
	
	var chair_col = get_node_or_null("StaticBody3D/CollisionShape3D")
	if chair_col: chair_col.disabled = false

	# Move player back
	var forward = -global_transform.basis.z.normalized()
	player.global_position = global_transform.origin + forward * -1.0

	var collision = player.get_node_or_null("Collision") as CollisionShape3D
	if collision and collision.shape is CapsuleShape3D:
		collision.shape.height = original_collision_height
	
	player = null
