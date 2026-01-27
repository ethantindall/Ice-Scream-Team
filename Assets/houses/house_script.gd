extends Node3D
class_name House

var rng := RandomNumberGenerator.new()

@export var randomize_house_on: bool = true
@export var house_on: bool = false

func _ready():
	if randomize_house_on:
		rng.randomize()
		house_on = rng.randi_range(0, 1) == 1
