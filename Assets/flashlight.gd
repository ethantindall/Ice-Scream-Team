extends Node3D

@onready var lens: MeshInstance3D = $Lens
@onready var light: SpotLight3D = $SpotLight3D
@export var turned_on: bool = false
signal player_in_flashlight_area
signal player_left_flashlight_area

func _ready():
	_update_light()


func toggle_flashlight():
	turned_on = not turned_on
	_update_light()

func _update_light():
	light.visible = turned_on
	
	# Access the material on surface 0 (the first material slot)
	var mat = lens.get_surface_override_material(0)
	
	# If you haven't set an "Override", get the material from the mesh itself
	if not mat:
		mat = lens.mesh.surface_get_material(0)
	
	if mat:
		mat.emission_enabled = turned_on


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body	.is_in_group("player"):
		print("Trying to emit signal")
		player_in_flashlight_area.emit()


func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_left_flashlight_area.emit()	
