extends Control

var target_scene_path: String = "res://main_map.tscn"

@onready var progress_bar: ProgressBar = $ProgressBar

func _ready() -> void:
	# 1. Start the background loading process
	ResourceLoader.load_threaded_request(target_scene_path)

func _process(_delta: float) -> void:
	var progress = []
	# 2. Check the status of the load
	var status = ResourceLoader.load_threaded_get_status(target_scene_path, progress)
	
	# Update the UI (progress[0] is a value from 0.0 to 1.0)
	progress_bar.value = progress[0] * 100
	
	# 3. When finished, swap the scenes
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var new_scene = ResourceLoader.load_threaded_get(target_scene_path)
		get_tree().change_scene_to_packed(new_scene)
	elif status == ResourceLoader.THREAD_LOAD_FAILED:
		print("Error: Could not load the scene!")
