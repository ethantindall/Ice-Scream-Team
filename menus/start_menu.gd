extends Control

# It's better to use a preloaded PackedScene or a constant for the path
# to avoid typos and get autocomplete.

@onready var sceneSelectOptions = $CanvasLayer/SceneSelectOptions
@onready var settingsOptions = $CanvasLayer/SettingsOptions
@onready var languageOptions = $CanvasLayer/LanguageOptions

func _on_start_button_button_up() -> void:
	# Go to the loading screen first
	print("Start button pressed, going to loading screen...")
	get_tree().change_scene_to_file("res://menus/loading_screen.tscn")

func _on_scene_select_button_button_up() -> void:
	sceneSelectOptions.visible = true
	settingsOptions.visible = false
	languageOptions.visible = false
	pass
	
func _on_settings_button_button_up() -> void:
	#populate settings menu
	sceneSelectOptions.visible = false
	settingsOptions.visible = true
	languageOptions.visible = false
	

func _on_language_button_button_up() -> void:
	#populate language menu
	sceneSelectOptions.visible = false
	settingsOptions.visible = false
	languageOptions.visible = true
