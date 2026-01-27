extends Node3D

@export var lamp_mesh_path := "LAMP"
@export var porchlight_path := "OmniLight3D"
var lamp_color := Color.html("#ffb826")
var lights_on:bool = true
var last_sky_state: String = ""

func _ready():
	toggle_lights()
	

func _process(delta: float) -> void:
	if GameSettings.time_of_day != last_sky_state:
		toggle_lights()


func toggle_lights():	
	last_sky_state = GameSettings.time_of_day
	lights_on = (GameSettings.time_of_day == "DAY")
	var lamp_mesh: MeshInstance3D = get_node_or_null(lamp_mesh_path)
	var porchlight: Light3D = get_node_or_null(porchlight_path)
	
	if not lamp_mesh or not porchlight:
		push_warning("Lamp mesh or porchlight not found")
		return

	var mat := lamp_mesh.get_active_material(0)
	if lights_on:
		# --- Day ---
		if porchlight:
			porchlight.visible = false
			mat.albedo_color = Color.WHITE
			mat.emission_enabled = false

	else:
		# --- Night ---
		if porchlight:
			porchlight.visible = true
			mat.albedo_color = lamp_color
			mat.emission_enabled = true
			mat.emission = lamp_color * 1 # adjust intensity
