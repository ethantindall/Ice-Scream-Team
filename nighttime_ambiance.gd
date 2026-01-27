extends AudioStreamPlayer

var normal_volume = -15.0
@export var fade_duration = 4.0 # Seconds


func turn_on():
	# 1. Set volume to "silent" before starting
	# In Godot, -80.0 dB is effectively silent
	self.volume_db = -80.0
	
	# 2. Start playing
	self.play()
	
	# 3. Create a tween to transition volume_db to normal_volume
	var tween = create_tween()
	tween.tween_property(self, "volume_db", normal_volume, fade_duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN)
	
	MasterEventHandler._on_dialogic_signal("nighttime_ambiance_on")
