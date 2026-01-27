extends Node3D  # Root of the door

@export var is_open: bool = false
@export var open_angle: float = 90.0
@export var open_speed: float = 6.0
@export var item_name: String = "Door"
@export var locked: bool = false  # door can be locked
@export var can_be_locked: bool = true
@export var click_to_knock: bool = false
@export var open_afer_knocking: bool = false
@export var run_timeline_after_knocking: String = ""

var target_rotation: float = 0.0
var closed_rotation: float = 0.0

func _ready():
	closed_rotation = rotation_degrees.y
	target_rotation = closed_rotation
		
	if name == "MikeFrontDoor":
		MasterEventHandler.mikeFrontDoor = self

func toggle():
	if locked:
		if click_to_knock:
			print("knock knock")
			
			if not DialogicHandler.is_running:
				DialogicHandler.run("knock knock")
			if open_afer_knocking:
				#wait until dialogue ends
				while DialogicHandler.is_running:
					await get_tree().process_frame
				#wait a couple more seconds
				await get_tree().create_timer(1.0).timeout					
				is_open = true
				target_rotation = closed_rotation + open_angle
				print("opening after knocking")
				if run_timeline_after_knocking != "":
					DialogicHandler.run(run_timeline_after_knocking)
		return

	if is_open:
		is_open = false
		target_rotation = closed_rotation
		print("closing")
	else:
		is_open = true
		target_rotation = closed_rotation + open_angle
		print("opening")

func _physics_process(delta: float):
	rotation_degrees.y = lerp(rotation_degrees.y, target_rotation, delta * open_speed)

# Optional helper to get display text
func get_display_text() -> String:
	if can_be_locked:
		var status := "Unlocked"
		if locked:
			status = "Locked"
			if click_to_knock:
				status = "Click to knock"
		return "%s - %s" % [item_name, status]
	return item_name
