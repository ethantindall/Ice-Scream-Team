extends Node3D

@export var is_open: bool = false
@export var open_angle: float = 90.0
@export var open_speed: float = 6.0
@export var item_name: String = "Door"
@export var locked: bool = false
@export var can_be_locked: bool = true
@export var click_to_knock: bool = false
@export var open_afer_knocking: bool = false
@export var run_timeline_after_knocking: String = ""
@export var npc_to_look_at: Node3D = null

var target_rotation: float = 0.0
var closed_rotation: float = 0.0
var _is_interacting: bool = false 

var sfx_knock = preload("res://Assets/sounds/doorknock.wav")
var sfx_rattle = preload("res://Assets/sounds/doorlocked.mp3")
var sfx_open = preload("res://Assets/sounds/dooropen.mp3")

func _ready():
	closed_rotation = rotation_degrees.y
	target_rotation = closed_rotation
	if name == "MikeFrontDoor":
		MasterEventHandler.mikeFrontDoor = self

## Helper function to spawn and play 3D sounds
func play_sfx(stream: AudioStream):
	var sound = AudioStreamPlayer3D.new()
	sound.stream = stream
	add_child(sound)
	sound.play()
	sound.finished.connect(func(): sound.queue_free())

func toggle():
	if _is_interacting or DialogicHandler.is_running: 
		return

	# 1. Handle Locked + Closed Door
	if locked and not is_open:
		perform_locked_sequence()
		return

	# 2. Handle Normal Open/Close
	if is_open:
		is_open = false
		target_rotation = closed_rotation
		play_sfx(sfx_open) # Play for closing
		print("closing")
	else:
		is_open = true
		target_rotation = closed_rotation + open_angle
		play_sfx(sfx_open) # Play for opening
		print("opening")

func perform_locked_sequence():
	_is_interacting = true
	
	# Path A: The "Knock and Open" Door
	if click_to_knock and open_afer_knocking:
		play_sfx(sfx_knock)

		DialogicHandler.run("knock knock")
		
		while DialogicHandler.is_running:
			await get_tree().process_frame
		
		await get_tree().create_timer(1.0).timeout
		
		locked = false
		is_open = true
		target_rotation = closed_rotation + open_angle
		play_sfx(sfx_open) # Play for opening after knock
		
		if npc_to_look_at and npc_to_look_at.has_method("talk_to"):
			npc_to_look_at.talk_to()

	# Path B: The "Normal Locked" Door (Rattle)
	else:
		play_sfx(sfx_rattle)
		
		# Physical feedback
		var original_target = target_rotation
		target_rotation += 2.0 
		await get_tree().create_timer(0.1).timeout
		target_rotation = original_target 
	
	_is_interacting = false

func _physics_process(delta: float):
	rotation_degrees.y = lerp(rotation_degrees.y, target_rotation, delta * open_speed)

func get_display_text() -> String:
	if is_open: return "Close Door"
	if locked:
		if click_to_knock and open_afer_knocking:
			return "Knock"
		return "Locked"
	return "Open Door"
