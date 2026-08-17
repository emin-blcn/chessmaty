extends Control

@onready var main_buttons_node: VBoxContainer = $main_buttons
@onready var settings_gui_node: Panel = $settings_gui


func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("uid://ccx66rc44ejbv")


func _on_settings_button_pressed() -> void:
	settings_gui_node.show()


func _on_exit_button_pressed() -> void:
	get_tree().quit()
