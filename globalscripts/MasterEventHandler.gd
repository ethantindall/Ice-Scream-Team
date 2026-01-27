extends Node

# Next conversation variables for each NPC
# These are strings containing the name of the Dialogic Timeline
var my_next_convo: String = ""
#var mom_next_convo: String = "quest_3"
var mom_next_convo: String = "quest_1"

var boone_next_convo: String = "talk_to_boone_1"

var icm_next_convo: String = "quest_4"
var mike_next_convo: String = "mikes_house_2"
var mike_mom_next_convo: String = ""
var killer_next_convo: String = "killer_0"
var omj_next_convo: String = "jenkins_1"
var neighborhood_kid_next_convo: String = "neighborhoodkid_1"
var hs_kid_next_convo: String = ""
var mrs_jenkins_next_convo: String = "jenkins_2"
var neighborhood_dad_next_convo: String = "neighborhood_dad_1"
var police_officer_next_convo: String = "police_0"

var player

var homeworkEnabled = false
var homeworkLabel = ""


var mikeFrontDoor: Node3D = null
var beanbagAtMikeHouse: Node3D = null

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D

			
	# 1. Connect to Dialogic's signal system to listen for events inside timelines
	Dialogic.signal_event.connect(_on_dialogic_signal)
	
	await get_tree().create_timer(3.0).timeout
	DialogicHandler.run("quest_0")
	
	

	
func _on_dialogic_signal(argument: String) -> void:
	# This catches ANY 'Signal' event you put in your Dialogic timelines
	# Use this to update the linear progress of the game
	match argument:
		"quest_0_end":
			# When quest_0 sends "mom1", Mom is now ready for quest_1
			mom_next_convo = "quest_1"
			print("Master: Mom's next conversation updated to quest_1")
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
			# Tell the handler that when it finishes, the arrow SHOULD be on
			DialogicHandler.arrow_original_visible = true
			#unlock Timmy's front door
			var timmyFrontdoor = get_tree().current_scene.get_node_or_null("Timmy's house/House/Doors/TimmyFrontDoor")
			timmyFrontdoor.locked = false
				

		"quest_4_end":
			icm_next_convo = "icm_filler_1"
			GoalManager.update_quest("Head to Mike's House.\nOPTIONAL: Talk to neighbors on the way.")

		"boone_1_end":
			boone_next_convo = "boone_filler"
			
		"police_0_end":
			#wait 3 seconds
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
			arrow.set_process(false)         # Stops _process
			arrow.set_physics_process(false) # Stops _physics_process
			mike_mom_next_convo = ""
			GoalManager.update_quest("Talk to Mike.")
			
		"mikes_house_2_end":
			mike_next_convo = ""
			GoalManager.update_quest("Sit on the beanbag and play.")
			
		"game_done":
			beanbagAtMikeHouse.disabled = true
			#get WorldEnvironment and update to night
			#why isnt this changing things?
			GameSettings.time_of_day = "NIGHT"
			GameSettings.apply_time_of_day()
			GoalManager.update_quest("")
			mikeFrontDoor.locked = false
			mikeFrontDoor.click_to_knock = false
			if mikeFrontDoor.is_open == true:
				mikeFrontDoor.toggle()  #close the door for the player			

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
			
# --- Helper Functions ---

func _trigger_world_event(event_name: String) -> void:
	# Useful for triggering scares or environmental changes
	match event_name:
		"flicker_lights":
			get_tree().call_group("street_lights", "flicker")


func _trigger_drive_by(truckname) -> void:
	var trucknode = get_tree().current_scene.find_child(truckname, true, false)


	if trucknode and player:
		trucknode.visible = true
		# 1. Reset Path Position using absolute path
		# This goes to the root of your scene and searches for the specific path name
		var follower = get_tree().current_scene.find_child("PathFollow3D", true, false)
		
		# If you have multiple paths and want the specific one:
		if not follower or follower.get_parent().name != "Path3D - DriveBy 1":
			follower = get_tree().current_scene.get_node_or_null("Path3D - DriveBy 1/PathFollow3D")

		if follower:
			follower.progress_ratio = 0.0
			print("Master: Resetting ", follower.get_path())
		else:
			print("Master Error: Could not find Path3D - DriveBy 1/PathFollow3D")

		# 2. Capture original forward direction
		var original_forward_point = player.CAMERA.global_position - player.CAMERA.global_transform.basis.z * 10.0
		trucknode.is_driving = true
		
		player.immobile = true
		player.force_look = true
		
		# 3. Handle 75-degree look offset
		var marker = trucknode.find_child("Marker3D", true, false)
		if marker:
			var dir_to_truck = marker.global_position - player.global_position
			var rotated_direction = dir_to_truck.rotated(Vector3.UP, deg_to_rad(0))
			player.forced_look_target = player.global_position + rotated_direction
		
		var audio = trucknode.find_child("AudioStreamPlayer3D", true, false)
		if audio: audio.play()

		await get_tree().create_timer(6.5).timeout
		
		# 4. Return to original view (matching the 75-degree offset)
		var dir_to_original = original_forward_point - player.global_position
		var rotated_original = dir_to_original.rotated(Vector3.UP, deg_to_rad(0))
		player.forced_look_target = player.global_position + rotated_original
		
		await get_tree().create_timer(1.5).timeout

		if audio: audio.stop()
		player.force_look = false
		player.immobile = false
		follower.progress_ratio = 0.4
		trucknode.speed = 6.0


func _trigger_drive_by2(
			truckname: String, 
			should_force_look: bool = true, 
			wait_for_truck: bool = true, 
			cleanup: bool = true, 
			truckspeed = null,
			trigger_end_game: bool = false
		) -> void:
	var trucknode = get_tree().current_scene.find_child(truckname, true, false)
	if truckspeed != null and trucknode:
		trucknode.speed = truckspeed    
	
	if trucknode and player:
		trucknode.visible = true
		var follower = trucknode.get_parent()

		if follower is PathFollow3D:
			follower.progress_ratio = 0.0
		else:
			print("Master Error: Parent is not PathFollow3D")
			return

		# 1. Setup Drive-By State
		var original_forward_point = player.CAMERA.global_position - player.CAMERA.global_transform.basis.z * 10.0
		trucknode.is_driving = true
		
		if wait_for_truck:
			player.immobile = true 
		
		# 2. Handle Optional Forced Look
		if should_force_look:
			player.force_look = true
			var marker = trucknode.find_child("Marker3D", true, false)
			if marker:
				var dir_to_truck = marker.global_position - player.global_position
				var rotated_direction = dir_to_truck.rotated(Vector3.UP, deg_to_rad(0))
				player.forced_look_target = player.global_position + rotated_direction
		
		var audio = trucknode.find_child("AudioStreamPlayer3D", true, false)
		if audio: audio.play()

		# --- NEW PATH MONITORING LOGIC ---
		# We wait until the follower's progress_ratio reaches the end (1.0)
		while follower.progress_ratio < 0.99:
			await get_tree().process_frame
		
		# Once it hits the end, stop the driving logic
		trucknode.is_driving = false
		# ---------------------------------

		# 3. Handle Optional Return Look
		if should_force_look:
			var dir_to_original = original_forward_point - player.global_position
			player.forced_look_target = player.global_position + dir_to_original
			await get_tree().create_timer(1.5).timeout

		# 4. Cleanup
		if cleanup:
			if audio: audio.stop()
			if should_force_look:
				player.force_look = false
				
			player.immobile = false
			follower.progress_ratio = 0.4 # Or wherever you want it to reset to
			trucknode.speed = 6.0
