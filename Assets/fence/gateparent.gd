extends Node3D

# Exposed variables, editable in the editor
@export var is_open: bool = false
@export var locked: bool = true
@export var open_angle: float = 90.0
@export var open_speed: float = 6.0
@export var item_name: String = "Gate"

@onready var pivot: Node3D = $PivotPoint
@onready var pivot_script = pivot.get_script()  # Reference to the pivot script

func _ready():
	# Pass the variables to the pivot script
	_apply_to_pivot()

func _apply_to_pivot():
	if pivot_script:
		pivot.is_open = is_open
		pivot.locked = locked
		pivot.open_angle = open_angle
		pivot.open_speed = open_speed
		pivot.item_name = item_name
		pivot._update_padlocks()  # Force padlocks to refresh
