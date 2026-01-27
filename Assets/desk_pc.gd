extends Node3D

@export var item_name: String = "PC - Click to use"

@export var powered_on: bool = false  # exported for UI or inspector
@export var screen_scene: String = "res://2Dscenes/asteroid/computerscreen.tscn"


@export var disabled = false

func _ready():
	if name == "TimmyBeanbag":
		MasterEventHandler.beanbagAtMikeHouse = self



# New method for UI display
func get_display_text() -> String:
	if disabled:
		return ""
	return item_name


func open_computer():
	if disabled:
		return
	SceneManager.load_scene(screen_scene)
	
	# 2️⃣ Disable all nodes in the "player" group
	for player in get_tree().get_nodes_in_group("player"):
		player.set_process(false)
		player.set_physics_process(false)

		# Optional: hide any CanvasLayer inside the player
		var canvas_layer = player.get_node_or_null("CanvasLayer")
		if canvas_layer:
			canvas_layer.visible = false
