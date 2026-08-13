extends Control

@onready var main_buttons_node: VBoxContainer = $main_buttons
@onready var settings_node: Panel = $settings

@onready var resolution_button_node: Button = $settings/resolution_button
@onready var fullscreen_check_button_node: CheckButton = $settings/fullscreen_check_button


func _ready() -> void:
	var window_size: Vector2i = get_window().size
	resolution_button_node.text = "Resolution: " + str(window_size.x) + "x" + str(window_size.y)
	if Global.settings_data["fullscreen"]:
		fullscreen_check_button_node.set_pressed_no_signal(true)
		resolution_button_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		resolution_button_node.modulate.a = 0.5


func _on_local_game_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game_local.tscn")


func _on_settings_button_pressed() -> void:
	main_buttons_node.hide()
	settings_node.show()


func _on_exit_button_pressed() -> void:
	get_tree().quit()


func _on_resolution_button_pressed() -> void:
	Global.update_resolution_setting()
	var window_size: Vector2i = get_window().size
	resolution_button_node.text = "Resolution: " + str(window_size.x) + "x" + str(window_size.y)


func _on_fullscreen_check_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		resolution_button_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		resolution_button_node.modulate.a = 0.5
	else:
		resolution_button_node.mouse_filter = Control.MOUSE_FILTER_STOP
		resolution_button_node.modulate.a = 1.0
	
	Global.update_fullscreen_setting(toggled_on)


func _on_okay_button_pressed() -> void:
	Global.save_settings_data()
	settings_node.hide()
	main_buttons_node.show()
