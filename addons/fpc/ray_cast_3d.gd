extends RayCast3D

@onready var player = get_tree().get_first_node_in_group("player")
@onready var interaction_label = player.get_node("CanvasLayer/Control/InteractionLabel")

var interactable_node: Node = null
var pickup_node: Node3D = null
var held_item: Node = null
var is_hidden = false

@export var max_throw_charge := 1.2
@export var min_throw_charge := 0.25
@export var throw_force := 14.0

var _throw_charge := 0.0
var _charging_throw := false

@export var drop_height: float = 0.2
@export var drop_forward_offset: float = 0.5


func _physics_process(delta: float):
	if is_hidden:
		return

	if DialogicHandler.is_running:
		interaction_label.text = "" # Force it to stay empty
		return

	if held_item and Input.is_action_pressed("ui_drop"):
		_charging_throw = true
		_throw_charge = min(_throw_charge + delta, max_throw_charge)

	if is_colliding():
		var collider = get_collider()

		if collider.is_in_group("interactable"):
			interactable_node = collider.get_parent() if collider.get_parent() != null and !collider.is_in_group("pickup") else collider

			if interactable_node.has_method("get_display_text"):
				interaction_label.text = interactable_node.get_display_text()
			else:
				interaction_label.text = interactable_node.name
		else:
			interactable_node = null

		if collider.is_in_group("pickup") and held_item == null:
			pickup_node = collider as Node3D
			if pickup_node.has_method("get_display_text"):
				interaction_label.text = pickup_node.get_display_text()
		else:
			pickup_node = null
	else:
		interaction_label.text = ""
		interactable_node = null
		pickup_node = null


func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if interactable_node and interactable_node.has_method("toggle"):
			interactable_node.toggle()

		if interactable_node and interactable_node.has_method("hide_enter") and player.is_hidden == false:
			interactable_node.hide_enter()
			is_hidden = true
			interaction_label.text = "Press E to exit"

		if interactable_node and interactable_node.has_method("climb"):
			interactable_node.climb()

		if interactable_node and interactable_node.has_method("do_homework"):
			if interactable_node.disabled == false:
				interactable_node.do_homework()

		if interactable_node and interactable_node.has_method("open_computer"):
			interactable_node.open_computer()

		if interactable_node and interactable_node.has_method("interact"):
			interactable_node.interact()

		if interactable_node and interactable_node.has_method("talk_to"):
			interactable_node.talk_to()

		if interactable_node and interactable_node.has_method("sit_down"):
			interactable_node.sit_down()

		if pickup_node and pickup_node.has_method("pickup"):
			print("picked up item")
			pickup_node.pickup()
			held_item = pickup_node
			pickup_node = null
			interaction_label.text = "Hold E to throw"
			

	if event.is_action_released("ui_drop") and held_item:
		if _throw_charge >= min_throw_charge:
			_throw_held_item(_throw_charge / max_throw_charge)
		else:
			_drop_held_item()

		_throw_charge = 0.0
		_charging_throw = false


func _drop_held_item():
	if not held_item or not player:
		return

	var camera: Node3D = player.get_node("Camera")
	var raycast: RayCast3D = camera.get_node_or_null("RayCast3D")

	# forward direction always available
	var forward: Vector3 = -camera.global_transform.basis.z.normalized()
	var drop_position: Vector3

	if raycast and raycast.is_colliding():
		drop_position = raycast.get_collision_point() + Vector3.UP * drop_height
	else:
		var ray_end: Vector3 = camera.global_transform.origin + forward * 2.0
		drop_position = ray_end + forward * drop_forward_offset

	# Prevent downward clipping
	if forward.y < 0 and forward.y > -0.8:
		drop_position.y += 0.5

	held_item.drop(drop_position)
	held_item = null
	interaction_label.text = ""


func _throw_held_item(strength: float):
	if not held_item or not player:
		return

	var camera: Node3D = player.get_node("Camera")
	var forward := -camera.global_transform.basis.z.normalized()
	var start_pos := camera.global_transform.origin + forward * 0.8

	var item := held_item
	held_item = null
	interaction_label.text = ""

	item.drop(start_pos)
	item.call_deferred("_apply_throw", forward, throw_force * strength)
