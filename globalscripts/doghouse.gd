extends Node3D

enum HideType { DOGHOUSE, TRASHCAN }

# Use the enum as an export so you can pick it in the inspector
@export var type: HideType = HideType.DOGHOUSE
@export var mouse_sensitivity := 0.05
@export var max_pitch := 15.0
@export var max_yaw := 15.0
@export var exit_key := "ui_drop"
@export var peek_distance := 0.2
@export var peek_speed := 0.3

var item_name := ""
var pitch = 0.0
var yaw = 0.0
var base_rotation = Vector3.ZERO
var camera_center_position: Vector3
var camera_target_offset: float = 0.0
var camera_forward_offset: float = 0.0
var player_hidden_here: bool = false
var _camera_ready: bool = false
var sfx_hide: AudioStream = null

@onready var player: CharacterBody3D = get_tree().get_first_node_in_group("player") as CharacterBody3D
@onready var collision_shape = player.get_node_or_null("Collision") if player else null
@onready var badguy: CharacterBody3D = get_tree().get_first_node_in_group("badguy") as CharacterBody3D

# SFX Assets
var sfx_trashcan = preload("res://Assets/sounds/trashcan.mp3")
var sfx_steps: Array[AudioStream] = [
	preload("res://Assets/sounds/FreeSteps/Dirt/Steps_dirt-001.ogg"),
	preload("res://Assets/sounds/FreeSteps/Dirt/Steps_dirt-002.ogg"),
	preload("res://Assets/sounds/FreeSteps/Dirt/Steps_dirt-003.ogg")
]



func _ready():
	match type:
		HideType.TRASHCAN:
			sfx_hide = sfx_trashcan
			item_name = "Trashcan - Click to Hide"
		HideType.DOGHOUSE:
			#sfx_hide = sfx_steps[randi() % sfx_steps.size()]
			item_name = "Dog House - Click to Hide"


## Helper function to spawn and play 3D sounds 
func play_sfx(stream: AudioStream):
	if not stream: return # Safety check
	var sound = AudioStreamPlayer3D.new()
	sound.stream = stream
	add_child(sound)
	sound.play()
	sound.finished.connect(func(): sound.queue_free())


func get_display_text():
	return item_name


func hide_enter():
	if not player:
		push_warning("Player not found")
		return

	player.visible = false
	player.set_physics_process(false)
	if collision_shape:
		collision_shape.disabled = true
		push_warning("Player Collision node found, disabling it to prevent raycast issues")
	else:
		push_warning("Player Collision node not found, raycast may still hit player")

	player.is_hidden = true
	player_hidden_here = true
	_camera_ready = false

	var doghouse_camera = $Camera3D
	if doghouse_camera:
		if $Roofnode:
			$Roofnode.visible = true
		doghouse_camera.make_current()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		base_rotation = doghouse_camera.rotation_degrees
		await get_tree().physics_frame
		camera_center_position = doghouse_camera.global_transform.origin
		_camera_ready = true
	else:
		push_warning("Doghouse Camera3D not found")

	if type == HideType.TRASHCAN:
		play_sfx(sfx_hide) # Play the hide sound immediately
	else:
		#for the doghouse play all sounds in sfx_steps in sequence, no delay in between
		for sound in sfx_steps:
			play_sfx(sound)
			await get_tree().create_timer(sound.get_length()).timeout

			
func _physics_process(delta):
	if player.is_hidden and $Camera3D and _camera_ready:
		if Input.is_action_pressed("ui_left"):
			camera_target_offset = clamp(camera_target_offset - peek_speed * delta, -peek_distance, peek_distance)
		elif Input.is_action_pressed("ui_right"):
			camera_target_offset = clamp(camera_target_offset + peek_speed * delta, -peek_distance, peek_distance)
		else:
			camera_target_offset = lerp(camera_target_offset, 0.0, 5.0 * delta)

		if Input.is_action_pressed("ui_up"):
			camera_forward_offset = clamp(camera_forward_offset + peek_speed * delta, -peek_distance, peek_distance)
		elif Input.is_action_pressed("ui_down"):
			camera_forward_offset = clamp(camera_forward_offset - peek_speed * delta, -peek_distance, peek_distance)
		else:
			camera_forward_offset = lerp(camera_forward_offset, 0.0, 5.0 * delta)

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
		if event is InputEventMouseMotion:
			yaw -= event.relative.x * mouse_sensitivity
			pitch -= event.relative.y * mouse_sensitivity
			pitch = clamp(pitch, -max_pitch, max_pitch)
			yaw = clamp(yaw, -max_yaw, max_yaw)
			$Camera3D.rotation_degrees = Vector3(base_rotation.x + pitch, base_rotation.y + yaw, base_rotation.z)

		if Input.is_action_just_pressed(exit_key):
			hide_exit()


func hide_exit():
	if not player:
		return

	_camera_ready = false
			
	if collision_shape:
		collision_shape.disabled = false
	else:
		push_warning("Player Collision node not found, cannot re-enable it")

	var exit_marker = $ExitPoint
	if exit_marker:
		player.global_position = exit_marker.global_position + Vector3.UP * 0.25
		player.velocity = Vector3.ZERO
		if player:
			var marker_yaw = exit_marker.global_rotation.y
			var head_rot = player.rotation
			head_rot.y = marker_yaw + deg_to_rad(90)
			player.rotation = head_rot
	else:
		push_warning("ExitPoint not found, player will appear in same place")

	player.visible = true
	player.is_hidden = false
	player_hidden_here = false

	await get_tree().physics_frame

	player.set_physics_process(true)
	if not player.is_on_floor():
		player.move_and_slide()

	var raycast_node = player.get_node_or_null("Camera/RayCast3D")
	if raycast_node:
		raycast_node.is_hidden = false

	if player.CAMERA:
		player.CAMERA.make_current()
	else:
		push_warning("Player CAMERA not found")
	if $Roofnode:
		$Roofnode.visible = false
	player.is_hidden = false



	if type == HideType.TRASHCAN:
		play_sfx(sfx_hide) # Play the hide sound immediately
	else:
		#for the doghouse play all sounds in sfx_steps in sequence, no delay in between
		for sound in sfx_steps:
			play_sfx(sound)
			await get_tree().create_timer(sound.get_length()).timeout


	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _on_badguy_area_body_entered(body: Node3D) -> void:
	if body == badguy and player_hidden_here and player.is_hidden and badguy.get_em_anyway:
		print("THE BADGUY IS IN THE AREA")
		hide_exit()
		badguy.call_deferred("start_dragging")
	else:
		print("not the badguy")
