extends Node3D

var is_open: bool = false
var locked: bool = false
var open_angle: float = 90.0
var open_speed: float = 6.0
var item_name: String = "Gate"

@onready var pivot: Node3D = self
@onready var padlocks: Node3D = $Padlocks
@onready var player = get_tree().get_first_node_in_group("player") as CharacterBody3D

# These are already preloaded, so we'll use these variables instead of path strings
var sfx_knock = preload("res://Assets/sounds/doorknock.mp3")
var sfx_rattle = preload("res://Assets/sounds/doorlocked.mp3")
var sfx_open = preload("res://Assets/sounds/dooropen.mp3")
var sfx_unlock = preload("res://Assets/sounds/doorunlock.mp3")

var closed_rotation: float
var target_rotation: float

func _ready():
	closed_rotation = pivot.rotation_degrees.y
	# This is the correct GDScript ternary syntax:
	target_rotation = (closed_rotation + open_angle) if is_open else closed_rotation
	_update_padlocks()

## Helper function to spawn and play 3D sounds 
func play_sfx(stream: AudioStream):
	if not stream: return # Safety check
	var sound = AudioStreamPlayer3D.new()
	sound.stream = stream
	add_child(sound)
	sound.play()
	sound.finished.connect(func(): sound.queue_free())

func toggle():
	# CASE 1: Player has the key and unlocks the gate
	if locked and player.holding_item and player.holding_key:
		print("unlocking and opening!")
		set_locked(false)
		play_sfx(sfx_unlock) # Use helper function
		open()
		
		# Key deletion logic
		var all_keys = get_tree().get_nodes_in_group("keys")
		for key in all_keys:
			if key.get("_following") == true:
				key.queue_free()
		
		player.holding_item = false
		player.holding_key = false

	# CASE 2: Gate is locked and clicked, but no key is held (RATTLE)
	elif locked:
		print(item_name + " is locked! (Rattle)")
		play_sfx(sfx_rattle) # Played the rattle sound here
		# Optional: you could add a small camera shake or gate jitter here too
		return
		
	# CASE 3: Normal open/close
	else:
		if is_open:
			close()
		else:
			open()

func open():
	if locked: return
	is_open = true
	target_rotation = closed_rotation + open_angle
	play_sfx(sfx_open) 

func close():
	if locked: return
	is_open = false
	target_rotation = closed_rotation
	play_sfx(sfx_open) # Using open sound for close, or you can add sfx_close

func set_locked(value: bool):
	locked = value
	if locked:
		target_rotation = pivot.rotation_degrees.y
		is_open = false
	_update_padlocks()

func _update_padlocks():
	if padlocks:
		padlocks.visible = locked

func _physics_process(delta: float):
	if locked: return
	pivot.rotation_degrees.y = lerp(
		pivot.rotation_degrees.y,
		target_rotation,
		delta * open_speed
	)

func get_display_text() -> String:
	if player.holding_item and player.holding_key and locked:
		return "%s - Unlock with key" % [item_name]
	return "%s - %s" % [item_name, ("Locked" if locked else "Unlocked")]
