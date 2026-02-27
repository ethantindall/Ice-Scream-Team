extends Node3D

@export var item_name = "Chock Block"
@export var npc_to_look_at: Node3D = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func get_display_text():
	return item_name


func interact():
	var player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if not player: return
	#MasterEventHandler.boone_next_convo = "chock_block_inspect"
	
	if GameSettings.time_of_day == "NIGHT":
		if npc_to_look_at and npc_to_look_at.has_method("talk_to"):
			npc_to_look_at.talk_to("chock_block_inspect")
	else:
		#remove the chock block
		MasterEventHandler.update_chock_block_counter()
		queue_free()
