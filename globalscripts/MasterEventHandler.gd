extends Node

# Next conversation variables for each NPC
var my_next_convo: String = ""
var mom_next_convo: String = "quest_1"
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

var player: CharacterBody3D

var homeworkEnabled = false
var homeworkLabel = ""

var mikeFrontDoor: Node3D = null
var beanbagAtMikeHouse: Node3D = null
var mikeMomAtMikeHouse: Node3D = null
var playerInitialPosition: Vector3 = Vector3(431, 4, 399)


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D
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
			DialogicHandler.arrow_original_visible = true
			var timmyFrontdoor = get_tree().current_scene.get_node_or_null("Timmy's house/House/Doors/TimmyFrontDoor")
			if timmyFrontdoor: timmyFrontdoor.locked = false

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
			var arrow = player.get_node("Camera/Arrow")
			arrow.visible = false
			arrow.set_process(false)
			arrow.set_physics_process(false)
			mike_mom_next_convo = ""
			GoalManager.update_quest("Talk to Mike.")
			mikeMomAtMikeHouse.walk_along_path()

		"mikes_house_2_end":
			mike_next_convo = ""
			GoalManager.update_quest("Sit on the beanbag and play.")
			
		"game_done":
			if beanbagAtMikeHouse: beanbagAtMikeHouse.disabled = true
			GameSettings.time_of_day = "NIGHT"
			GameSettings.apply_time_of_day()
			GoalManager.update_quest("")
			if mikeFrontDoor:
				mikeFrontDoor.locked = false
				mikeFrontDoor.click_to_knock = false
				if mikeFrontDoor.is_open == true:
					mikeFrontDoor.toggle()

		"game_done_2":
			await get_tree().create_timer(2.0).timeout
			DialogicHandler.run("mikes_house_3")
			mike_mom_next_convo = "mikes_house_4"
			mike_next_convo = ""
			GoalManager.update_quest("Hurry home.")

		"mikes_house_4_end":
			mike_mom_next_convo = ""

		"nighttime_ambiance_on":
			await get_tree().create_timer(7.5).timeout
			_trigger_drive_by2("IceCreamTruck-Night-1", false, false, true, 6.0, true)
			DialogicHandler.run("demo_done")

		"caught":
			if player:
				# Using the DRAGGED state we created in the player script
				player.current_state = player.PlayerState.DRAGGED

# --- Helper Functions ---

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


func _trigger_drive_by2(truckname, should_force_look, wait_for_truck, cleanup, truckspeed, trigger_end_game) -> void:
	var trucknode = get_tree().current_scene.find_child(truckname, true, false)
	if truckspeed != null and trucknode:
		trucknode.speed = truckspeed    
	
	if trucknode and player:
		trucknode.visible = true
		var follower = trucknode.get_parent()

		if not (follower is PathFollow3D): return

		follower.progress_ratio = 0.0
		var original_forward_point = player.CAMERA.global_position - player.CAMERA.global_transform.basis.z * 10.0
		trucknode.is_driving = true
		
		# UPDATED: Replaced immobile with the correct state setters
		if wait_for_truck:
			player.current_state = player.PlayerState.DIALOG # Manual lock
		
		if should_force_look:
			player.force_look = true
			var marker = trucknode.find_child("Marker3D", true, false)
			if marker:
				player.forced_look_target = marker.global_position
		
		var audio = trucknode.find_child("AudioStreamPlayer3D", true, false)
		if audio: audio.play()

		while follower.progress_ratio < 0.99:
			await get_tree().process_frame
		
		trucknode.is_driving = false

		if should_force_look:
			player.forced_look_target = original_forward_point
			await get_tree().create_timer(1.5).timeout

		if cleanup:
			if audio: audio.stop()
			player.force_look = false
			player.current_state = player.PlayerState.IDLE
			follower.progress_ratio = 0.4
			trucknode.speed = 6.0
