@tool
extends Marker3D
class_name RoadMarker

# Use backing fields to avoid setter recursion
var _marker1: Marker3D
var _marker2: Marker3D
var _marker3: Marker3D
var _marker4: Marker3D

@export_category("Connected Nodes")
@export var marker1: Marker3D:
	get:
		return _marker1
	set(value):
		if _marker1 != value:
			_remove_bidirectional_link(_marker1)
			_marker1 = value
			_add_bidirectional_link(_marker1)
			_update_debug_lines()

@export var marker2: Marker3D:
	get:
		return _marker2
	set(value):
		if _marker2 != value:
			_remove_bidirectional_link(_marker2)
			_marker2 = value
			_add_bidirectional_link(_marker2)
			_update_debug_lines()

@export var marker3: Marker3D:
	get:
		return _marker3
	set(value):
		if _marker3 != value:
			_remove_bidirectional_link(_marker3)
			_marker3 = value
			_add_bidirectional_link(_marker3)
			_update_debug_lines()

@export var marker4: Marker3D:
	get:
		return _marker4
	set(value):
		if _marker4 != value:
			_remove_bidirectional_link(_marker4)
			_marker4 = value
			_add_bidirectional_link(_marker4)
			_update_debug_lines()

@export_category("Connection Settings")
@export var bidirectional := true

@export_category("Debug Visualization")
@export var show_connections := true:
	set(value):
		show_connections = value
		_update_debug_lines()
@export var connection_color := Color.YELLOW:
	set(value):
		connection_color = value
		_update_debug_lines()

# Add bidirectional link by directly setting backing field (NO setter called)
func _add_bidirectional_link(target: Marker3D) -> void:
	if not bidirectional or target == null:
		return
	if not is_instance_valid(target) or not target is RoadMarker:
		return
	
	var target_marker = target as RoadMarker
	
	# Check if target already has us linked
	if target_marker.is_connected_to(self):
		return
	
	# Find an empty slot and assign to BACKING FIELD directly
	if target_marker._marker1 == null:
		target_marker._marker1 = self
		target_marker._update_debug_lines()
	elif target_marker._marker2 == null:
		target_marker._marker2 = self
		target_marker._update_debug_lines()
	elif target_marker._marker3 == null:
		target_marker._marker3 = self
		target_marker._update_debug_lines()
	elif target_marker._marker4 == null:
		target_marker._marker4 = self
		target_marker._update_debug_lines()
	else:
		push_warning("RoadMarker '%s': All slots full, cannot auto-link from '%s'" % [target.name, name])

# Remove bidirectional link by directly setting backing field
func _remove_bidirectional_link(target: Marker3D) -> void:
	if not bidirectional or target == null:
		return
	if not is_instance_valid(target) or not target is RoadMarker:
		return
	
	var target_marker = target as RoadMarker
	
	# Remove us from target's slots by setting BACKING FIELD
	if target_marker._marker1 == self:
		target_marker._marker1 = null
		target_marker._update_debug_lines()
	if target_marker._marker2 == self:
		target_marker._marker2 = null
		target_marker._update_debug_lines()
	if target_marker._marker3 == self:
		target_marker._marker3 = null
		target_marker._update_debug_lines()
	if target_marker._marker4 == self:
		target_marker._marker4 = null
		target_marker._update_debug_lines()

# Returns array of all connected markers (non-null)
func get_connected_markers() -> Array[Marker3D]:
	var connected: Array[Marker3D] = []
	var seen = {}  # Use dictionary for fast lookup
	
	# Check each slot and only add if we haven't seen it yet
	if _marker1 != null and not _marker1 in seen:
		connected.append(_marker1)
		seen[_marker1] = true
	if _marker2 != null and not _marker2 in seen:
		connected.append(_marker2)
		seen[_marker2] = true
	if _marker3 != null and not _marker3 in seen:
		connected.append(_marker3)
		seen[_marker3] = true
	if _marker4 != null and not _marker4 in seen:
		connected.append(_marker4)
		seen[_marker4] = true
	
	return connected

# Get a random connected marker (excluding the one we came from)
func get_random_connected(exclude: Marker3D = null) -> Marker3D:
	var connected = get_connected_markers()
	
	# Remove the excluded marker (prevents immediate backtracking)
	if exclude != null:
		connected = connected.filter(func(m): return m != exclude)
	
	if connected.is_empty():
		push_warning("No connected markers available at: %s" % name)
		return null
	
	return connected[randi() % connected.size()]

# Check if this marker connects to another specific marker
func is_connected_to(marker: Marker3D) -> bool:
	return marker in get_connected_markers()

func _ready() -> void:
	_update_debug_lines()

# Update lines whenever properties change
func _update_debug_lines() -> void:
	if not is_inside_tree():
		return
	
	# Remove old debug lines
	for child in get_children():
		if child.has_meta("debug_line"):
			child.queue_free()
	
	# Only create new lines if show_connections is enabled
	if show_connections:
		for marker in get_connected_markers():
			if marker:
				var line = _create_line_mesh(global_position, marker.global_position)
				line.set_meta("debug_line", true)
				add_child(line)

func _create_line_mesh(from: Vector3, to: Vector3) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	var immediate_mesh = ImmediateMesh.new()
	var material = StandardMaterial3D.new()
	
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = connection_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.6
	
	mesh_instance.mesh = immediate_mesh
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	# Draw the line
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	immediate_mesh.surface_add_vertex(to_local(from))
	immediate_mesh.surface_add_vertex(to_local(to))
	immediate_mesh.surface_end()
	
	return mesh_instance

# Trigger updates when markers are moved in the editor
func _get_configuration_warnings() -> PackedStringArray:
	_update_debug_lines()
	return []
