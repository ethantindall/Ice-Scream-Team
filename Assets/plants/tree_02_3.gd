extends Node3D


var rng = RandomNumberGenerator.new()

func _ready():
	rng.randomize()
	
	var my_random_number = rng.randf_range(0.0, 360.0)
	self.rotation.y = my_random_number
	
	var height_random = rng.randf_range(.6, 2.0)
	self.scale.x = height_random
	self.scale.y = height_random
	self.scale.z = height_random
