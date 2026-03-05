extends Node3D
class_name PlayerZoneHandler

var PLAYER_ZONE: String

signal player_zone_changed(new_zone: String)

func update_player_zone(new_zone: String) -> void:
	# This function can be called from anywhere to update the player's current zone
	PLAYER_ZONE = new_zone
	print("Player entered zone: ", new_zone)
	player_zone_changed.emit(new_zone)

func _on_northwest_zone_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Character":
		update_player_zone("Northwest")


func _on_main_street_zone_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Character":
		update_player_zone("Main Street")


func _on_park_zone_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Character":
		update_player_zone("Park")


func _on_central_zone_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Character":
		update_player_zone("Central")


func _on_south_zone_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Character":
		update_player_zone("South")
