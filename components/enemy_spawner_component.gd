extends Node3D
class_name EnemySpawnerComponent

@export_group("References")
@export var nav_region_path: NodePath 

@onready var spawn_marker: Marker3D = $Marker3D
var enemy_scene: PackedScene = preload("res://Assets/chars/00_completed chars/badguyWithAI.tscn")

var nav_region: NavigationRegion3D
var current_enemy: Node3D = null
var is_processing_spawn := false

signal enemy_spawned(enemy_node)
signal enemy_despawned

func _ready() -> void:
	if nav_region_path:
		nav_region = get_node(nav_region_path)
	
	if not nav_region:
		push_error("DEBUG ERROR: NavRegion not found!")
		return
	
	# Configure the NavigationMesh for runtime baking
	_setup_navigation_mesh()

func _setup_navigation_mesh() -> void:
	if not nav_region.navigation_mesh:
		nav_region.navigation_mesh = NavigationMesh.new()
	
	var nav_mesh = nav_region.navigation_mesh
	
	# Agent properties
	nav_mesh.agent_radius = 0.5  # Adjust based on your character size
	nav_mesh.agent_height = 2.0
	nav_mesh.agent_max_climb = 0.5
	nav_mesh.agent_max_slope = 45.0
	
	# Cell size affects precision vs performance
	nav_mesh.cell_size = 0.25
	nav_mesh.cell_height = 0.2
	
	# CRITICAL: Set the geometry parsing
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	
	# Edge connection settings
	nav_mesh.edge_max_length = 12.0
	nav_mesh.edge_max_error = 1.3

func start_spawn_sequence() -> void:
	if is_processing_spawn or current_enemy: return
	is_processing_spawn = true
	
	print("DEBUG: Moving NavRegion and baking for new location...")
	
	# 1. Move the region to the spawn location
	nav_region.global_position = global_position
	
	# 2. Set the filter baking AABB to only bake a 50m radius around this point
	var bake_aabb = AABB(Vector3(-50, -5, -50), Vector3(100, 10, 100))
	nav_region.navigation_mesh.filter_baking_aabb = bake_aabb
	
	# 3. Ensure the region is enabled
	nav_region.enabled = true
	
	# 4. Bake on thread
	nav_region.bake_navigation_mesh(true)
	
	# 5. Wait for bake to finish
	await nav_region.bake_finished 
	
	# 6. IMPORTANT: Wait one more frame for the navigation server to sync
	await get_tree().process_frame
	
	print("DEBUG: Bake complete. Spawning Bad Guy...")
	_spawn_enemy()
	is_processing_spawn = false

func _spawn_enemy() -> void:
	if not enemy_scene: return
		
	current_enemy = enemy_scene.instantiate()
	
	# Add to scene tree
	get_tree().current_scene.add_child(current_enemy)
	current_enemy.global_transform = spawn_marker.global_transform
	
	# Debug: Verify navigation is working
	if current_enemy.has_node("NavigationAgent3D"):
		print("DEBUG: Navigation agent found and ready")
	
	enemy_spawned.emit(current_enemy)
	
	if current_enemy.has_signal("returned_to_truck"):
		current_enemy.returned_to_truck.connect(_on_enemy_returned)

func _on_enemy_returned() -> void:
	if current_enemy:
		current_enemy.queue_free()
		current_enemy = null
	
	# Disable the region instead of clearing (more reliable)
	if nav_region:
		nav_region.enabled = false
	
	enemy_despawned.emit()
