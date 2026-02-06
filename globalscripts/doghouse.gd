extends Node3D

@export var item_name := "Dog House - Click to Hide"
@export var mouse_sensitivity := 0.05
@export var max_pitch := 15.0          # max up/down rotation in degrees
@export var max_yaw := 15.0            # max left/right rotation in degrees
@export var exit_key := "ui_drop"      # key to exit, e.g., "E"
@export var peek_distance := 0.2       # max lateral/forward peek
@export var peek_speed := 0.3          # speed to move to target peek

var pitch = 0.0
var yaw = 0.0
var base_rotation = Vector3.ZERO
@onready var player: CharacterBody3D = get_tree().get_first_node_in_group("player") as CharacterBody3D
@onready var collision_shape = player.get_node_or_null("Collision")
@onready var badguy: CharacterBody3D = get_tree().get_first_node_in_group("badguy") as CharacterBody3D

var camera_center_position: Vector3
var camera_target_offset: float = 0.0    # current lateral offset
var camera_forward_offset: float = 0.0   # current forward/back offset

var player_hidden_here: bool = false


func get_display_text():
	return item_name

func hide_enter():
	# --- Find player ---
	if not player:
		push_warning("Player not found")
		return

	# --- Hide player and disable physics ---
	player.visible = false
	player.set_physics_process(false)
	#also make collision shape invisible to prevent raycast from hitting it
	if collision_shape:
		collision_shape.disabled = true
		push_warning("Player Collision node found, disabling it to prevent raycast issues")
	else:
		push_warning("Player Collision node not found, raycast may still hit player")

	# --- Switch to doghouse camera ---
	var doghouse_camera = $Camera3D
	if doghouse_camera:
		if $Roofnode:
			$Roofnode.visible = true
		doghouse_camera.make_current()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		base_rotation = doghouse_camera.rotation_degrees
		camera_center_position = doghouse_camera.global_transform.origin
	else:
		push_warning("Doghouse Camera3D not found")
	
	player.is_hidden = true
	player_hidden_here = true

func _physics_process(delta):
	if player.is_hidden and $Camera3D:
		# --- Lateral peek (left/right) ---
		if Input.is_action_pressed("ui_left"):
			camera_target_offset = clamp(camera_target_offset - peek_speed * delta, -peek_distance, peek_distance)
		elif Input.is_action_pressed("ui_right"):
			camera_target_offset = clamp(camera_target_offset + peek_speed * delta, -peek_distance, peek_distance)
		else:
			camera_target_offset = lerp(camera_target_offset, 0.0, 5.0 * delta)

		# --- Forward/back peek (up/down) ---
		if Input.is_action_pressed("ui_up"):
			camera_forward_offset = clamp(camera_forward_offset + peek_speed * delta, -peek_distance, peek_distance)
		elif Input.is_action_pressed("ui_down"):
			camera_forward_offset = clamp(camera_forward_offset - peek_speed * delta, -peek_distance, peek_distance)
		else:
			camera_forward_offset = lerp(camera_forward_offset, 0.0, 5.0 * delta)

		# --- Calculate new camera position ---
		var basis = $Camera3D.global_transform.basis

		var forward_dir = -basis.z
		forward_dir.y = 0
		forward_dir = forward_dir.normalized()

		var right_dir = basis.x
		right_dir.y = 0
		right_dir = right_dir.normalized()


		var new_pos = camera_center_position + right_dir * camera_target_offset + forward_dir * camera_forward_offset
		$Camera3D.global_transform.origin = new_pos

func _unhandled_input(event):
	if player.is_hidden and $Camera3D.is_current():
		# --- Mouse pan ---
		if event is InputEventMouseMotion:
			yaw -= event.relative.x * mouse_sensitivity
			pitch -= event.relative.y * mouse_sensitivity
			pitch = clamp(pitch, -max_pitch, max_pitch)
			yaw = clamp(yaw, -max_yaw, max_yaw)
			$Camera3D.rotation_degrees = Vector3(base_rotation.x + pitch, base_rotation.y + yaw, base_rotation.z)

		# --- Exit doghouse ---
		if Input.is_action_just_pressed(exit_key):
			hide_exit()

func hide_exit():
	if not player:
		return

	if collision_shape:
		collision_shape.disabled = false
	else:
		push_warning("Player Collision node not found, cannot re-enable it")

	var exit_marker = $ExitPoint
	if exit_marker:
		# --- Move player to exit marker ---
		player.global_position = exit_marker.global_position

		# --- Rotate HEAD to match marker yaw + 90° right ---
		if player:
			var marker_yaw = exit_marker.global_rotation.y
			var head_rot = player.rotation
			head_rot.y = marker_yaw + deg_to_rad(90)
			player.rotation = head_rot
	else:
		push_warning("ExitPoint not found, player will appear in same place")

	# --- Show player and enable physics ---
	player.visible = true
	player.set_physics_process(true)
	player.is_hidden = false  # allow raycast to resume
	player_hidden_here = false

	# --- Reset RayCast3D is_hidden ---
	var raycast_node = player.get_node_or_null("Camera/RayCast3D")
	if raycast_node:
		raycast_node.is_hidden = false

	# --- Switch back to player camera ---
	if player.CAMERA:
		player.CAMERA.make_current()
	else:
		push_warning("Player CAMERA not found")
	if $Roofnode:
		$Roofnode.visible = false
	player.is_hidden = false

	# --- Re-capture mouse for player control ---
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _on_badguy_area_body_entered(body: Node3D) -> void:
	if body == badguy and player_hidden_here and player.is_hidden:
		print("THE BADGUY IS IN THE AREA")
		
	else:
		print("not the badguy")
