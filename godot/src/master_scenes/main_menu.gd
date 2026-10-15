extends Control

@onready var title_label: Label = $title
@onready var main_buttons_node: VBoxContainer = $main_buttons
@onready var settings_node: Panel = $setings


func _ready() -> void:
	$version.text = ProjectSettings.get_setting("application/config/version")


func _on_start_button_pressed() -> void:
	Sound.button_tick.play()
	get_tree().change_scene_to_file("uid://ccx66rc44ejbv")


func _on_settings_button_pressed() -> void:
	Sound.button_tick.play()
	main_buttons_node.hide()
	title_label.hide()
	settings_node.show()


func _on_quit_button_pressed() -> void:
	get_tree().quit()
