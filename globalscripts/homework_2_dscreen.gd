extends Node2D

@onready var _lines: Node2D = $Line2D
@onready var _background: Sprite2D = $Background
@onready var _draw_area: Area2D = $Paper/Area2D 

var _pressed: bool = false
var _current_line: Line2D = null

func _ready() -> void:
	# 1. Find the player and lock them into DIALOG state
	var player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player:
		# This freezes movement and enables the mouse cursor automatically
		player.force_look = true
		
		# Hide the 3D HUD while doing homework
		var canvas_layer = player.get_node_or_null("CanvasLayer")
		if canvas_layer:
			canvas_layer.visible = false

func _input(event: InputEvent) -> void:
	# Exit homework (E / ui_drop)
	if event.is_action_pressed("ui_drop"):
		exit_homework()
		return

	# Drawing logic
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pressed = event.pressed
		if _pressed:
			var mouse_pos := get_global_mouse_position()
			if _is_inside_draw_area(mouse_pos):
				_current_line = Line2D.new()
				_current_line.default_color = Color.BLUE
				_current_line.width = 4
				_lines.add_child(_current_line)
				_current_line.add_point(mouse_pos)

	elif event is InputEventMouseMotion and _pressed:
		var mouse_pos := get_global_mouse_position()
		if _current_line and _is_inside_draw_area(mouse_pos):
			_current_line.add_point(mouse_pos)

func exit_homework():
	# 1. Get player reference
	var player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	
	if player:
		# Show the HUD/Canvas again
		var canvas_layer = player.get_node_or_null("CanvasLayer")
		if canvas_layer:
			canvas_layer.visible = true
		
		# Ensure processing is active for the coming dialogue
		player.set_process(true)
		player.set_physics_process(true)

	# 2. Run the dialogue
	# DialogicHandler.run will keep force_look = true, 
	# keeping the player frozen and mouse visible.
	DialogicHandler.run("quest_2")

	# 3. Unload the 2D homework scene
	SceneManager.unload_scene("res://2Dscenes/homework2dscreen.tscn")

	# Note: We do NOT set mouse mode to CAPTURED here. 
	# The DialogicHandler/Player script will do that once the timeline ends.

func _is_inside_draw_area(point: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collision_mask = _draw_area.collision_layer
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var result = space_state.intersect_point(query)
	return result.size() > 0