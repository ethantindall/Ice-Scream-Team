extends Node2D

signal hit_by_bullet(asteroid: Node2D)
signal hit_player

@export var speed: float = 200.0

@onready var area: Area2D = $Area2D

func _ready() -> void:
	area.area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	position.y += speed * delta

	# Despawn if off screen
	if position.y > get_viewport_rect().size.y + 50.0:
		queue_free()

func _on_area_entered(other: Area2D) -> void:
	# Bullet hit
	if other.is_in_group("bullet"):
		emit_signal("hit_by_bullet", self)
		other.get_parent().queue_free()

	# Player hit
	elif other.is_in_group("player_hitbox"):
		emit_signal("hit_player")
