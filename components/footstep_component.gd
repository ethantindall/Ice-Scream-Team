extends Node3D
class_name FootstepComponent

# --- CONFIG ---
@export var footstep_sounds = {
	"grass": [
		preload("res://Assets/sounds/FreeSteps/Dirt/Steps_dirt-001.ogg"),
		preload("res://Assets/sounds/FreeSteps/Dirt/Steps_dirt-002.ogg"),
		preload("res://Assets/sounds/FreeSteps/Dirt/Steps_dirt-003.ogg"),
		preload("res://Assets/sounds/FreeSteps/Dirt/Steps_dirt-004.ogg")
	],
	"gravel": [
		preload("res://Assets/sounds/FreeSteps/Gravel/Steps_gravel-001.ogg"),
		preload("res://Assets/sounds/FreeSteps/Gravel/Steps_gravel-002.ogg"),
		preload("res://Assets/sounds/FreeSteps/Gravel/Steps_gravel-003.ogg"),
		preload("res://Assets/sounds/FreeSteps/Gravel/Steps_gravel-004.ogg")
	],
	"concrete": [
		preload("res://Assets/sounds/FreeSteps/Tiles/Steps_tiles-001.ogg"),
		preload("res://Assets/sounds/FreeSteps/Tiles/Steps_tiles-002.ogg"),
		preload("res://Assets/sounds/FreeSteps/Tiles/Steps_tiles-003.ogg"),
		preload("res://Assets/sounds/FreeSteps/Tiles/Steps_tiles-004.ogg")
	],
	"wood": [
		preload("res://Assets/sounds/FreeSteps/Wood/Steps_wood-001.ogg"),
		preload("res://Assets/sounds/FreeSteps/Wood/Steps_wood-002.ogg"),
		preload("res://Assets/sounds/FreeSteps/Wood/Steps_wood-003.ogg"),
		preload("res://Assets/sounds/FreeSteps/Wood/Steps_wood-004.ogg")        
	]
}

@export var base_volume_db := -8.0 
@export var sprint_volume_db := 3.0  
@export var pitch_variation := 0.2  # How much to randomize pitch (0.0 - 1.0)
@export var disable_sounds := false
var concrete_sound_reduction = 20.0  # Reduce volume for concrete surfaces

# --- NODES ---
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var parent_body: CharacterBody3D = get_parent()

func _ready():
	# Auto-create audio player if it doesn't exist
	if not has_node("AudioStreamPlayer3D"):
		audio_player = AudioStreamPlayer3D.new()
		audio_player.name = "AudioStreamPlayer3D"
		add_child(audio_player)

# Call this from animation
func play_footstep():
	if disable_sounds:
		return
	if not parent_body or not parent_body.is_on_floor():
		return
			
	var state = parent_body.get_current_state() if parent_body.has_method("get_current_state") else "WALKING"
	
	# Apply volume based on state
	var volume = base_volume_db
	match state:
		0:  # PlayerState.SPRINTING enum value
			volume = sprint_volume_db
		_:
			volume = base_volume_db
	
	# Detect surface and get appropriate sounds
	var surface_type = detect_surface_type()
	var sounds = footstep_sounds.get(surface_type, footstep_sounds["grass"])
	
	if surface_type == "concrete":
		volume -= concrete_sound_reduction  # Reduce volume for concrete surfaces
		
	if sounds.is_empty():
		push_warning("No footstep sounds configured for FootstepComponent on " + parent_body.name)
		return
	
	audio_player.stream = sounds[randi() % sounds.size()]
	audio_player.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	audio_player.volume_db = volume
	audio_player.play()

func detect_surface_type() -> String:
	if not parent_body:
		return "grass"
		
	var space_state = parent_body.get_world_3d().direct_space_state
	var ray_start = parent_body.global_position
	var ray_end = parent_body.global_position + Vector3.DOWN * 0.5
	
	var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.exclude = [parent_body.get_rid()]
	
	var result = space_state.intersect_ray(query)
	
	if result and result.has("collider"):
		var collider = result.collider
		
		# Check groups
		if collider.is_in_group("terrain_grass"):
			return "grass"
		elif collider.is_in_group("terrain_concrete"):
			return "concrete"
		elif collider.is_in_group("terrain_metal"):
			return "metal"
		elif collider.is_in_group("terrain_wood"):
			return "wood"
		
		# Check metadata as fallback
		if collider.has_meta("surface_type"):
			return collider.get_meta("surface_type")
	
	return "grass"  # default fallback
