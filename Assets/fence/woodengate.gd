extends Node3D

var is_open: bool = false
var locked: bool = false
var open_angle: float = 90.0
var open_speed: float = 6.0
var item_name: String = "Gate"

# Since Pivot is the root, we just use `self`
@onready var pivot: Node3D = self
@onready var padlocks: Node3D = $Padlocks  # Assuming Padlocks is direct child

var closed_rotation: float
var target_rotation: float

func _ready():
	print("LOCKED FROM SCENE:", locked)
	closed_rotation = pivot.rotation_degrees.y
	if is_open:
		target_rotation = closed_rotation + open_angle
	else:
		target_rotation = closed_rotation
	_update_padlocks()

func toggle():
	if locked:
		print(item_name + " is locked!")
		return

	if is_open:
		close()
	else:
		open()

func open():
	if locked:
		return
	is_open = true
	target_rotation = closed_rotation + open_angle
	print("opening")

func close():
	if locked:
		return
	is_open = false
	target_rotation = closed_rotation
	print("closing")

func set_locked(value: bool):
	locked = value
	if locked:
		# Stop any motion immediately when locking
		target_rotation = pivot.rotation_degrees.y
		is_open = false
	_update_padlocks()

func _update_padlocks():
	if padlocks:
		padlocks.visible = locked
		print("padlocks set to " + str(padlocks.visible))

func _physics_process(delta: float):
	if locked:
		return  # Prevent movement when locked
	pivot.rotation_degrees.y = lerp(
		pivot.rotation_degrees.y,
		target_rotation,
		delta * open_speed
	)

func get_display_text() -> String:
	return "%s - %s" % [
		item_name,
		("Locked" if locked else "Unlocked")
	]
