extends Node2D

var score: int = 0
@export var move_speed: float = 400.0

# -------------------------------
# Nodes
@onready var spaceship: Node2D = $Spaceship
@onready var asteroid_timer: Timer = $AsteroidSpawnTimer
@onready var asteroids: Node2D = $Asteroids
@onready var bullets: Node2D = $Bullets
@onready var spawn_area: Area2D = $AsteroidSpawnArea

# -------------------------------
# Scenes
const ASTEROID_SCENE := preload("res://2Dscenes/asteroid/asteroid.tscn")
const BULLET_SCENE := preload("res://2Dscenes/asteroid/bullet.tscn")

# -------------------------------
signal game_done

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	asteroid_timer.timeout.connect(_spawn_asteroid)
	asteroid_timer.start()
	$CanvasLayer/Control/Label.text = "Score: " + str(score)
# -------------------------------
func _process(delta: float) -> void:
	# Spaceship movement
	var dir: float = 0.0
	if Input.is_action_pressed("ui_left"):
		dir -= 1.0
	if Input.is_action_pressed("ui_right"):
		dir += 1.0

	spaceship.position.x += dir * move_speed * delta
	spaceship.position.x = clamp(
		spaceship.position.x,
		0.0,
		get_viewport_rect().size.x
	)

# -------------------------------
func _input(event: InputEvent) -> void:
	# Exit homework (E / ui_drop)
	if event.is_action_pressed("ui_drop"):
		exit_computer()
		return

	# Fire bullet with left click
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		_fire_bullet()

# -------------------------------
# Spawn an asteroid inside AsteroidSpawnArea
func _spawn_asteroid() -> void:
	var asteroid: Node2D = ASTEROID_SCENE.instantiate()
	asteroids.add_child(asteroid)

	# Get rectangle bounds of spawn area
	var shape: Shape2D = spawn_area.get_node("CollisionShape2D").shape
	if shape is RectangleShape2D:
		var rect: Rect2 = shape.get_rect()
		var x := randf_range(rect.position.x, rect.position.x + rect.size.x)
		asteroid.position = Vector2(x, spawn_area.global_position.y)
	else:
		# fallback
		asteroid.position = Vector2(randf_range(0.0, get_viewport_rect().size.x), -50.0)

	print("Spawned asteroid at:", asteroid.position) # debug

	# Connect signals
	asteroid.hit_by_bullet.connect(_on_asteroid_destroyed)
	asteroid.hit_player.connect(_on_player_died)

# -------------------------------
func _fire_bullet() -> void:
	var bullet: Node2D = BULLET_SCENE.instantiate()
	bullets.add_child(bullet)
	bullet.position = spaceship.position

# -------------------------------
# Events
func _on_asteroid_destroyed(asteroid: Node2D) -> void:
	score += 1
	asteroid.queue_free()
	$CanvasLayer/Control/Label.text = "Score: " + str(score)

func _on_player_died() -> void:
	exit_computer()

# -------------------------------
# Exit homework and restore 3D
func exit_computer() -> void:
	MasterEventHandler._on_dialogic_signal("game_done")
	print("added signal")
	await get_tree().create_timer(1.0).timeout
	for player in get_tree().get_nodes_in_group("player"):
		player.set_process(true)
		player.set_physics_process(true)

		var canvas_layer := player.get_node_or_null("CanvasLayer")
		if canvas_layer:
			canvas_layer.visible = true

	SceneManager.unload_scene("res://2Dscenes/asteroid/computerscreen.tscn")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	MasterEventHandler._on_dialogic_signal("game_done_2")
