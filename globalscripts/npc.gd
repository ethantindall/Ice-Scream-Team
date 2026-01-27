extends Node3D

@export_group("NPC Identity")
@export_enum(
	"Mom", 
	"Boone", 
	"OldManJenkins",
	"ICM",
	"Mike",
	"MikeMom",
	"Killer",
	"Neighborhood Kid",
	"HS Kid",
	"Mrs. Jenkins",
	"Neighborhood Dad",
	"Police Officer"
	) var npc_type: String = "Mom"

@export var item_name := "NPC"

@export_group("Animations")
@export var turn_speed := 3.0
@export var turn_right_anim := "animations/Turn Right"
@export var turn_left_anim := "animations/Turn Left"
@export var idle_animation := "animations/idle3"

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var npc_face: Marker3D = $Marker3D

var _player_ref: CharacterBody3D
var _original_yaw := 0.0
var _target_yaw := 0.0
var _turn_animation_name := ""
var _previous_animation := ""

var _is_turning_to_player := false
var _is_turning_back := false

func get_display_text():
	return item_name

func talk_to():
	# 1. Use the Handler's busy check
	if DialogicHandler.is_running:
		return

	# 2. Determine which dialog to play
	var dialog_to_play = _get_current_dialog_from_handler()
	if dialog_to_play == "":
		return

	# 3. Handle NPC-Specific Player Focus
	_player_ref = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if _player_ref:
		_player_ref.force_look = true
		_player_ref.forced_look_target = npc_face.global_position

	# 4. Save animation & rotation state
	_original_yaw = global_rotation.y
	_previous_animation = animation_player.current_animation
	if _previous_animation == "":
		_previous_animation = idle_animation

	# 5. Calculate yaw toward player in global/world space
	var dir_to_player := (_player_ref.global_position - global_position).normalized()
	_target_yaw = atan2(dir_to_player.x, dir_to_player.z)

	var delta_yaw := wrapf(_target_yaw - global_rotation.y, -PI, PI)
	_turn_animation_name = turn_right_anim if delta_yaw >= 0.0 else turn_left_anim

	_is_turning_to_player = true
	_is_turning_back = false

	if animation_player.has_animation(_turn_animation_name):
		animation_player.play(_turn_animation_name)

	# 6. Connect to end signal LOCALLY
	if not Dialogic.timeline_ended.is_connected(_on_timeline_ended):
		Dialogic.timeline_ended.connect(_on_timeline_ended)

	# 7. Run dialog
	DialogicHandler.run(dialog_to_play)

func _get_current_dialog_from_handler() -> String:
	var next_convo = ""
	match npc_type:
		"Mom": next_convo = MasterEventHandler.mom_next_convo
		"Boone": next_convo = MasterEventHandler.boone_next_convo
		"ICM": next_convo = MasterEventHandler.icm_next_convo
		"Mike": next_convo = MasterEventHandler.mike_next_convo
		"Killer": next_convo = MasterEventHandler.killer_next_convo
		"OldManJenkins": next_convo = MasterEventHandler.omj_next_convo
		"MikeMom": next_convo = MasterEventHandler.mike_mom_next_convo
		"Neighborhood Kid": next_convo = MasterEventHandler.neighborhood_kid_next_convo
		"HS Kid": next_convo = MasterEventHandler.hs_kid_next_convo
		"Mrs. Jenkins": next_convo = MasterEventHandler.mrs_jenkins_next_convo
		"Neighborhood Dad": next_convo = MasterEventHandler.neighborhood_dad_next_convo
		"Police Officer": next_convo = MasterEventHandler.police_officer_next_convo
	return next_convo

func _process(delta):
	if _is_turning_to_player or _is_turning_back:
		var new_yaw := lerp_angle(global_rotation.y, _target_yaw, turn_speed * delta)
		global_rotation.y = new_yaw

		if abs(wrapf(new_yaw - _target_yaw, -PI, PI)) < 0.01:
			global_rotation.y = _target_yaw

			var next_anim = idle_animation
			if _is_turning_back:
				next_anim = _previous_animation

			_is_turning_to_player = false
			_is_turning_back = false

			if animation_player.has_animation(next_anim):
				animation_player.play(next_anim)

func _on_timeline_ended():
	if _player_ref:
		_player_ref.force_look = false
		_player_ref = null

	_target_yaw = _original_yaw
	var delta_yaw := wrapf(_target_yaw - global_rotation.y, -PI, PI)
	_turn_animation_name = turn_right_anim if delta_yaw >= 0.0 else turn_left_anim

	_is_turning_back = true
	_is_turning_to_player = false

	if animation_player.has_animation(_turn_animation_name):
		animation_player.play(_turn_animation_name)

	if Dialogic.timeline_ended.is_connected(_on_timeline_ended):
		Dialogic.timeline_ended.disconnect(_on_timeline_ended)
