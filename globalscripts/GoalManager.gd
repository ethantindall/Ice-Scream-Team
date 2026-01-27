extends Node

# Current quest goal text
var current_goal: String = ""

# Reference to the player node (optional; we can fetch from group)
var player: Node = null

# Update the current goal and reflect it in the UI
func update_quest(goal: String) -> void:
	current_goal = goal
	_update_player_goal_label()

# Internal function to update the player's GoalLabel
func _update_player_goal_label() -> void:
	# Get player dynamically from "player" group
	var players = get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		push_warning("No player found in group 'player'")
		return

	for player in players:
		var goal_label = player.get_node_or_null("CanvasLayer/Control/GoalLabel")
		if goal_label:
			goal_label.text = current_goal
		else:
			push_warning("Player node %s has no GoalLabel child" % player.name)
