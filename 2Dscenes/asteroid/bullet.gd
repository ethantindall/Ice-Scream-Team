extends Node2D

@export var speed: float = 600.0

@onready var area: Area2D = $Area2D

func _ready() -> void:
	area.add_to_group("bullet")

func _process(delta: float) -> void:
	position.y -= speed * delta

	# Despawn if off screen
	if position.y < -50.0:
		queue_free()
