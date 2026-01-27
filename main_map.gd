extends Node3D

func _ready():
	_apply_time_of_day()

func _apply_time_of_day():
	var day_folder = get_node_or_null("DAYTIMESTUFF")
	var night_folder = get_node_or_null("NIGHTTIMESTUFF")
	
	if GameSettings.time_of_day == "DAY":
		_activate_group(day_folder, true)
		_activate_group(night_folder, false)
	else:
		_activate_group(day_folder, false)
		_activate_group(night_folder, true)

func _activate_group(node: Node, active: bool):
	if node:
		if active:
			node.visible = true
			node.process_mode = Node.PROCESS_MODE_INHERIT
		else:
			node.visible = false
			# This is the "Magic Switch" that kills collision and logic
			node.process_mode = Node.PROCESS_MODE_DISABLED
