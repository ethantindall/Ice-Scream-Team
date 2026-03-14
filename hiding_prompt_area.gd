extends Area3D

@onready var player = get_tree().get_first_node_in_group("player") as CharacterBody3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_body_entered(body: Node3D) -> void:
	if body == player:
		MasterEventHandler._on_dialogic_signal("hiding_prompt")
		queue_free()
