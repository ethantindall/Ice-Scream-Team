extends Node3D
class_name EnemySpawnerComponent

@onready var spawn_marker: Marker3D = $Marker3D
var enemy_scene: PackedScene = preload("res://Assets/chars/00_completed chars/badguyWithAI.tscn")

var nav_region: NavigationRegion3D
var current_enemy: Node3D = null
var is_processing_spawn := false
var navmesh_size = 100.0

var sfx_spawn = preload("res://Assets/sounds/cardoorslam.mp3")

signal enemy_spawned(enemy_node)
signal enemy_despawned

func _ready() -> void:
	# Ready is now empty because we wait for the parent to call setup_spawner
	pass

func setup_spawner(region: NavigationRegion3D) -> void:
	if not region:
		push_error("EnemySpawner: Received null NavigationRegion!")
		return
	
	nav_region = region
	_setup_navigation_mesh()
	print("EnemySpawner: NavRegion linked and mesh configured.")

func _setup_navigation_mesh() -> void:
	if not nav_region: return
	
	if not nav_region.navigation_mesh:
		nav_region.navigation_mesh = NavigationMesh.new()
	
	var nav_mesh = nav_region.navigation_mesh
	
	# Agent properties
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_height = 2.0
	nav_mesh.agent_max_climb = 0.5
	nav_mesh.agent_max_slope = 45.0
	
	# Precision settings
	nav_mesh.cell_size = 0.25
	nav_mesh.cell_height = 0.2
	
	# Geometry parsing
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	
	# Edge connection settings
	nav_mesh.edge_max_length = 12.0
	nav_mesh.edge_max_error = 1.3

func start_spawn_sequence() -> void:
	print("SPAWNING BADGUY")
	if is_processing_spawn or current_enemy or not nav_region: return
	is_processing_spawn = true
	
	print("DEBUG: Moving NavRegion and baking for new location...")
	
	# 1. Move the region to the truck's location
	nav_region.global_position = global_position
	
	# 2. Set the filter baking AABB
	var bake_aabb = AABB(Vector3(-navmesh_size/2, -5, -navmesh_size/2), Vector3(navmesh_size, 10, navmesh_size))
	nav_region.navigation_mesh.filter_baking_aabb = bake_aabb
	
	# 3. Ensure the region is active
	nav_region.enabled = true
	
	#play audio
	play_sfx(sfx_spawn)

	# 4. Bake (using thread is safer for performance)
	nav_region.bake_navigation_mesh(true)
	
	# 5. Wait for bake and sync
	await nav_region.bake_finished 
	await get_tree().process_frame
	
	print("DEBUG: Bake complete. Spawning Bad Guy...")
	_spawn_enemy()
	is_processing_spawn = false

func _spawn_enemy() -> void:
	if not enemy_scene: return
		
	current_enemy = enemy_scene.instantiate()
	get_tree().current_scene.add_child(current_enemy)
	current_enemy.global_transform = spawn_marker.global_transform
	
	enemy_spawned.emit(current_enemy)
	
	if current_enemy.has_signal("returned_to_truck"):
		current_enemy.returned_to_truck.connect(_on_enemy_returned)

func _on_enemy_returned() -> void:
	if current_enemy:
		current_enemy.queue_free()
		current_enemy = null
	
	if nav_region:
		nav_region.enabled = false
	
	MasterEventHandler.badguy = null
	enemy_despawned.emit()
	print("BADGUY DESPAWNED")
	play_sfx(sfx_spawn)

# Helper function to spawn and play 3D sounds 
func play_sfx(stream: AudioStream):
	if not stream: return # Safety check
	var sound = AudioStreamPlayer3D.new()
	sound.stream = stream
	add_child(sound)
	sound.play()
	sound.finished.connect(func(): sound.queue_free())
