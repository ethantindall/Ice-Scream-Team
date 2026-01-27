extends Node
# Make this an Autoload (Project Settings → Autoload)

var cached_scenes := {}
var current_scene: Node = null

func load_scene(path: String) -> void:
	var scene: Node

	# If already loaded, reuse it
	if cached_scenes.has(path):
		scene = cached_scenes[path]
	else:
		var scene_res = load(path)
		if scene_res == null:
			push_error("Scene load failed: " + path)
			return
		scene = scene_res.instantiate()
		cached_scenes[path] = scene

	_switch_to(scene)

func _switch_to(scene: Node) -> void:
	# Hide current
	if current_scene:
		current_scene.visible = false

	# Add new scene under this manager (if not already)
	if not scene.is_inside_tree():
		add_child(scene)

	# Show the new one
	scene.visible = true
	current_scene = scene
	
	
func unload_scene(path: String) -> void:
	if cached_scenes.has(path):
		var scene = cached_scenes[path]
		if scene.is_inside_tree():
			scene.queue_free()
		cached_scenes.erase(path)
