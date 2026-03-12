extends Control


func _process(delta):
	if Input.is_action_just_pressed("debug_toggle"):
		visible = not visible
		if visible:
			open_debug_menu()
		else:
			var player = get_tree().get_first_node_in_group("player")
			if player:
				player.current_state = player.PlayerState.IDLE

	# Check for command execution every frame while visible
	if visible and Input.is_action_just_pressed("ui_accept"):
		var text = $TextEdit.text.strip_edges()
		if text != "":
			$TextEdit.text = ""
			execute_debug_event(text)


func open_debug_menu():
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.current_state = player.PlayerState.DIALOG
	$TextEdit.grab_focus()

func execute_debug_event(event_name: String):
	match event_name:
		"DAY": 
			GameSettings.set_time_of_day("DAY")
		"NIGHT":
			GameSettings.set_time_of_day("NIGHT")
