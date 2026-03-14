extends Node

# Next conversation variables for each NPC
var my_next_convo: String = ""
var mom_next_convo: String = "quest_3"

#var mom_next_convo: String = "quest_1"
var boone_next_convo: String = "talk_to_boone_1"
var icm_next_convo: String = "quest_4"
var mike_next_convo: String = "mikes_house_2"
var mike_mom_next_convo: String = "mikes_house_1"
var killer_next_convo: String = "killer_0"
var omj_next_convo: String = "jenkins_1"
var neighborhood_kid_next_convo: String = "neighborhoodkid_1"
var hs_kid_next_convo: String = ""
var mrs_jenkins_next_convo: String = "jenkins_2"
var neighborhood_dad_next_convo: String = "neighborhood_dad_1"
var police_officer_next_convo: String = "police_0"

var player: CharacterBody3D = null
var truckWithAI: Node3D = null
var badguy: Node3D = null

var homeworkEnabled = false
var homeworkLabel = ""

var timmyFrontdoor: Node3D = null
var mikeFrontDoor: Node3D = null
var beanbagAtMikeHouse: Node3D = null
var mikeMomAtMikeHouse: Node3D = null
var playerInitialPosition: Vector3 = Vector3(431, 4, 399)

var remaining_chock_blocks = 2
var badguy_locked_gate:bool = false


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	truckWithAI = get_tree().get_first_node_in_group("truckWithAI") as Node3D
	#player.global_position = playerInitialPosition


	# Connect to Dialogic's signal system
	Dialogic.signal_event.connect(_on_dialogic_signal)
	
	# Initial delay before starting the intro
	#await get_tree().create_timer(3.0).timeout
	#DialogicHandler.run("quest_0")

func _on_dialogic_signal(argument: String) -> void:
	match argument:
		"quest_0_end":
			mom_next_convo = "quest_1"
			GoalManager.update_quest("Talk to mom.")

		"quest_1_end":
			mom_next_convo = ""
			GoalManager.update_quest("Go upstairs and finish your homework.")
			homeworkEnabled = true
			homeworkLabel = "Desk - Click to do homework"

		"quest_2_end":
			mom_next_convo = "quest_3"
			GoalManager.update_quest("Tell Mom you've finished your homework.")

		"trigger_drive_by":
			_trigger_drive_by("IceCreamTruck-Day-1")

		"quest_3_end":
			mom_next_convo = "mom_filler_1"
			GoalManager.update_quest("Head to Mike's House.\n OPTIONAL: Get ice cream.\nOPTIONAL: Talk to neighbors on the way.")

			timmyFrontdoor = get_tree().current_scene.get_node_or_null("Timmy's house/House/Doors/TimmyFrontDoor")
			if timmyFrontdoor: timmyFrontdoor.locked = false

			await get_tree().create_timer(8.0).timeout
			var pathfinding_arrow = player.get_node_or_null("Camera/Arrow")
			if pathfinding_arrow: pathfinding_arrow.set_active(true)
			
		"quest_4_end":
			icm_next_convo = "icm_filler_1"
			GoalManager.update_quest("Head to Mike's House.\nOPTIONAL: Talk to neighbors on the way.")

		"boone_1_end":
			boone_next_convo = "boone_filler"
			
		"police_0_end":
			await get_tree().create_timer(6.0).timeout
			DialogicHandler.run("police_1")

		"police_1_end":
			GoalManager.update_quest("Find another way to Mike's House.\nOPTIONAL: Talk to neighbors on the way.")

		"jenkins_1_end":
			omj_next_convo = "jenkins_filler"
			
		"jenkins_2_end":
			mrs_jenkins_next_convo= ""
			
		"killer_0_end":
			killer_next_convo =""
		
		"neighborhoodkid_1_end":
			neighborhood_kid_next_convo = ""
			
		"mikes_house_1_end":
			var pathfinding_arrow = player.get_node_or_null("Camera/Arrow")

			if pathfinding_arrow: pathfinding_arrow.set_active(false)

			mike_mom_next_convo = ""
			GoalManager.update_quest("Talk to Mike.")
			mikeMomAtMikeHouse.walk_along_path()

		"mikes_house_2_end":
			mike_next_convo = ""
			GoalManager.update_quest("Sit on the beanbag and play.")
			
		"game_done":
			if beanbagAtMikeHouse: beanbagAtMikeHouse.disabled = true
			GameSettings.set_time_of_day("NIGHT")
			GoalManager.update_quest("")
			if mikeFrontDoor:
				mikeFrontDoor.locked = false
				mikeFrontDoor.click_to_knock = false
				if mikeFrontDoor.is_open == true:
					mikeFrontDoor.toggle()

		"game_done_2":
			await get_tree().create_timer(2.0).timeout
			#DialogicHandler.run("mikes_house_3")
			mike_mom_next_convo = "mikes_house_4"
			mike_next_convo = ""
			GoalManager.update_quest("Hurry home.")

		"mikes_house_4_end":
			mike_mom_next_convo = ""

		"nighttime_ambiance_on":
			await get_tree().create_timer(0.5).timeout
			var marker_a = get_tree().current_scene.find_child("Marker3D27", true, false)
			var marker_b = get_tree().current_scene.find_child("Marker3D25", true, false)
			truckWithAI.set_position_and_target(marker_a, marker_b)
			truckWithAI.movement_enabled = true
			truckWithAI.searching_enabled = true
			# 1. Find the Gate pivot
			var pivot_point = get_tree().current_scene.get_node_or_null("PrivacyFence/FirstOpenGate/PivotPoint")
			if pivot_point:
				print("PivotPoint found under gate.")
				pivot_point.rotation_degrees = Vector3(90, 0, 90)
			else:
				print("PivotPoint not found under gate!")

		"truck_arrived_at_point":
			var marker_b = get_tree().current_scene.find_child("Marker3D25", true, false)
			
			# Ensure we are at the right destination
			if truckWithAI.current_target == marker_b:
				truckWithAI.movement_enabled = false
				truckWithAI.searching_enabled = false		
				truckWithAI.spawner.start_spawn_sequence()
				await get_tree().create_timer(1.0).timeout
				badguy = get_tree().get_first_node_in_group("badguy") as Node3D
				if badguy:
					print("Got badguy reference, freezing him.")
					badguy.freeze = true	
				else:
					print("Error: Badguy not found after spawn sequence.")

		"trigger_way_home_3":
			pass
			badguy.talk_to("way_home_3")

		"way_home_3_end":
			GoalManager.update_quest("RUN AND HIDE!")
			
			await get_tree().create_timer(1.0).timeout

			var gate_marker = get_tree().current_scene.get_node_or_null("PrivacyFence/FirstOpenGate/Marker3D")
			if gate_marker:
				var direction_to_gate = (gate_marker.global_position - player.global_position).normalized()
				
				# Calculate the final goal angle (+ PI to fix the 180 flip)
				var target_rotation_y = atan2(direction_to_gate.x, direction_to_gate.z) + PI
				
				# Start at current rotation
				var start_rotation = player.rotation.y
				
				var tween = create_tween()
				# Instead of tween_property, we use tween_method to call a custom lerp
				tween.tween_method(
					func(val): player.rotation.y = lerp_angle(start_rotation, target_rotation_y, val),
					0.0, # Start 'val' at 0
					1.0, # End 'val' at 1
					0.8  # Duration in seconds
				).set_trans(Tween.TRANS_SINE)

			await get_tree().create_timer(5.0).timeout
			if badguy:
				badguy.freeze = false
			if truckWithAI:
				truckWithAI.movement_enabled = true
				truckWithAI.searching_enabled = true

		"hiding_prompt":
			var doghouse_marker = get_tree().current_scene.get_node_or_null("NIGHTTIME_STUFF/HidingPromptArea/DoghouseMarker3D")
			if doghouse_marker:
				var direction_to_doghouse = (doghouse_marker.global_position - player.global_position).normalized()
				
				# Calculate the final goal angle (+ PI to fix the 180 flip)
				var target_rotation_y = atan2(direction_to_doghouse.x, direction_to_doghouse.z) + PI
				
				# Start at current rotation
				var start_rotation = player.rotation.y
				
				var tween = create_tween()
				# Instead of tween_property, we use tween_method to call a custom lerp
				tween.tween_method(
					func(val): player.rotation.y = lerp_angle(start_rotation, target_rotation_y, val),
					0.0, # Start 'val' at 0
					1.0, # End 'val' at 1
					0.4  # Duration in seconds
				).set_trans(Tween.TRANS_SINE)
			if badguy:
				badguy.freeze = true

				DialogicHandler.run("hiding_prompt_1")

		"hiding_prompt_complete":
			if badguy:
				badguy.freeze = false
				#connect to badguy return to truck signal
				if not badguy.is_connected("returned_to_truck", _on_badguy_returned_to_truck):
					badguy.connect("returned_to_truck", _on_badguy_returned_to_truck)
					#when badguy returns to truck close gate

		"badguy_locked_gate_end":
			badguy_locked_gate = false

		"successfully_hid":
			pass



		"caught":
			if player:
				# Using the DRAGGED state we created in the player script
				player.current_state = player.PlayerState.DRAGGED

		"move_boones_car":
			print("Moving Boone's car...")
			var boones_car = get_tree().current_scene.find_child("Boones Car", true, false)
			if boones_car:
				boones_car.follow_path()

# --- Helper Functions ---



func _on_badguy_returned_to_truck():
	var pivot_point = get_tree().current_scene.get_node_or_null("PrivacyFence/FirstOpenGate/PivotPoint")
	if pivot_point:
		print("PivotPoint found under gate.")
		pivot_point.rotation_degrees = Vector3(90, 0, 0)
		badguy_locked_gate = true
	else:
		print("PivotPoint not found under gate!")


func _trigger_drive_by(truckname) -> void:
	var trucknode = get_tree().current_scene.find_child(truckname, true, false)

	if trucknode and player:
		trucknode.visible = true
		var follower = get_tree().current_scene.find_child("PathFollow3D", true, false)
		
		if not follower or follower.get_parent().name != "Path3D - DriveBy 1":
			follower = get_tree().current_scene.get_node_or_null("Path3D - DriveBy 1/PathFollow3D")

		if follower:
			follower.progress_ratio = 0.0

		var original_forward_point = player.CAMERA.global_position - player.CAMERA.global_transform.basis.z * 10.0
		trucknode.is_driving = true
		
		player.force_look = true
		
		var marker = trucknode.find_child("TruckMarker", true, false)
		if marker:
			player.forced_look_target = marker.global_position
		
		var audio = trucknode.find_child("AudioStreamPlayer3D", true, false)
		if audio: audio.play()

		await get_tree().create_timer(6.5).timeout
		
		# Return to original view
		player.forced_look_target = original_forward_point
		
		await get_tree().create_timer(1.5).timeout

		if audio: audio.stop()
		player.force_look = false
		follower.progress_ratio = 0.4
		trucknode.speed = 6.0



func update_chock_block_counter():
	remaining_chock_blocks -=1
	print("Chock blocks remaining: ", remaining_chock_blocks)
	if remaining_chock_blocks <= 0:
		_on_dialogic_signal("move_boones_car")
