extends Node

var player: CharacterBody3D
var is_running: bool = false 
var arrow: Node3D # Assuming Arrow is a 3D node, change type if it's 2D
var arrow_original_visible: bool = false

func _ready() -> void:
	# Connect signals once
	Dialogic.timeline_ended.connect(_on_timeline_ended)

func run(timeline_name: String, force_look = true):
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
	
	# Handle the Arrow visibility safely
	if player:
		arrow = player.get_node_or_null("Camera/Arrow")
		if arrow:
			arrow_original_visible = arrow.visible
			arrow.visible = false

		# --- UPDATED: Use force_look instead of immobile ---
		# This automatically sets state to DIALOG and shows the mouse
		player.force_look = force_look 

	# 4. Start the dialogue
	Dialogic.start(timeline_name)

func _on_timeline_ended() -> void:
	if player:
		# --- UPDATED: Use force_look instead of immobile ---
		# This automatically sets state back to IDLE and captures the mouse
		player.force_look = false
		
		# Restore Arrow visibility
		if arrow:
			arrow.visible = arrow_original_visible
	
	# Small delay to ensure inputs don't bleed through to the game frame
	await get_tree().process_frame
	is_running = false
