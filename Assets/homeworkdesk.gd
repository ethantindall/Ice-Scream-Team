extends Node3D

@export var homework_scene: String = "res://2Dscenes/homework2dscreen.tscn"
var disabled = MasterEventHandler.homeworkEnabled



	
func get_display_text() -> String:
	# 1. If we finished the homework, show nothing
	if disabled:
		return ""
	
	# 2. Check if the Master says homework is ready
	if MasterEventHandler.homeworkEnabled:
		return MasterEventHandler.homeworkLabel
	
	# 3. If it's not time for homework yet, return something else or nothing
	return ""
	
func do_homework() -> void:
	if MasterEventHandler.homeworkEnabled == false:
		return
	MasterEventHandler.homeworkEnabled = false
	# 1️⃣ Load the 2D homework scene
	SceneManager.load_scene(homework_scene)

	# 2️⃣ Disable all nodes in the "player" group
	for player in get_tree().get_nodes_in_group("player"):

		# Optional: hide any CanvasLayer inside the player
		var canvas_layer = player.get_node_or_null("CanvasLayer")
		if canvas_layer:
			canvas_layer.visible = false
