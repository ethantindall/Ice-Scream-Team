extends Node

var player: CharacterBody3D
var is_running: bool = false 
var label_original_text: String = ""
var arrow
var arrow_original_visible: bool = false


func _ready() -> void:
	# Connect signals once
	Dialogic.timeline_ended.connect(_on_timeline_ended)

func run(timeline_name: String):
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D

	# 1. Busy check
	if is_running:
		return
		
	# 2. Simple empty string check
	if timeline_name == "":
		printerr("DialogicHandler: No timeline name provided.")
		return

	# 3. Setup State
	is_running = true
	
	arrow = player.get_node("Camera/Arrow")
	arrow_original_visible = arrow.visible
	arrow.visible = false

	if player:
		player.immobile = true 
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# 4. Start the dialogue
	# Dialogic 2 handles finding the .dtl file by name automatically
	Dialogic.start(timeline_name)

func _on_timeline_ended() -> void:
	if player:
		player.immobile = false
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	await get_tree().process_frame
	is_running = false
	# REMOVE OR COMMENT OUT THIS LINE:
	arrow.visible = arrow_original_visible
