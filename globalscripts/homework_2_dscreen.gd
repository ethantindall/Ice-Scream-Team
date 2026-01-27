extends Node2D

@onready var _lines: Node2D = $Line2D
@onready var _background: Sprite2D = $Background
@onready var _draw_area: Area2D = $Paper/Area2D   # Area2D with CollisionShape2D

var _pressed: bool = false
var _current_line: Line2D = null

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _input(event: InputEvent) -> void:
	# Exit homework (E / ui_drop)
	if event.is_action_pressed("ui_drop"):
		exit_homework()
		return

	# Drawing input
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
	# 1️⃣ Switch back to 3D scene
	#SceneManager.load_scene("res://scenes/3d_scene.tscn")
	# 2️⃣ Re-enable player nodes
	
	DialogicHandler.run("quest_2")

	for player in get_tree().get_nodes_in_group("player"):

		var canvas_layer = player.get_node_or_null("CanvasLayer")
		if canvas_layer:
			canvas_layer.visible = true

	
	# 3️⃣ Optional: unload the 2D homework scene
	SceneManager.unload_scene("res://2Dscenes/homework2dscreen.tscn")

	# 4️⃣ Recapture the mouse for 3D control
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


# Godot 4 proper way: use PhysicsPointQueryParameters2D
func _is_inside_draw_area(point: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collision_mask = _draw_area.collision_layer
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var result = space_state.intersect_point(query)
	return result.size() > 0
