extends SubViewportContainer

func _ready():
	# Give the engine a few frames to initialize the 3D world and lighting
	await get_tree().create_timer(0.5).timeout
	
	var viewport = $SubViewport
	# Ensure the texture is retrieved after the render pipeline has run
	var tex = viewport.get_texture()
	var img = tex.get_image()
	
	# Check if the image is empty
	if img.is_empty():
		print("Error: Image is empty. Check if SubViewport has a Camera3D.")
		return

	var error = img.save_png("res://tree_billboard.png")
	
	if error == OK:
		print("Success! Saved to res://tree_billboard.png")
	else:
		print("Save failed. Error code: ", error)
