# StaminaUI.gd
extends Control

@onready var stamina_bar: ProgressBar = $Label/ProgressBar
@onready var player: CharacterBody3D = get_tree().get_first_node_in_group("player")

func _ready():
	# Wait for the scene tree to be ready
	await get_tree().process_frame
	
	# Re-fetch player in case it wasn't ready
	if not player:
		player = get_tree().get_first_node_in_group("player")
	
	if player:
		player.stamina_changed.connect(_on_stamina_changed)
		print("DEBUG: Connected to player stamina signal")
		
		# Initialize the bar
		if stamina_bar:
			stamina_bar.max_value = player.max_stamina
			stamina_bar.value = player.current_stamina
			stamina_bar.show_percentage = false  # Optional: hide the % text
			print("DEBUG: Stamina bar initialized - Max:", stamina_bar.max_value, "Current:", stamina_bar.value)
	else:
		push_error("StaminaUI: Could not find player in 'player' group!")

func _on_stamina_changed(current: float, maximum: float):
	if stamina_bar:
		stamina_bar.max_value = maximum
		stamina_bar.value = current
