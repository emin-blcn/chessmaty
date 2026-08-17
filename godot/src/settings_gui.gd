extends Panel

@onready var resolution_button: Button = $resolution_button
@onready var fullscreen_check_button: CheckButton = $fullscreen_check_button


func _ready() -> void:
	var window_size: Vector2i = get_window().size
	resolution_button.text = "Resolution: " + str(window_size.x) + "x" + str(window_size.y)
	
	if Global.settings_data["fullscreen"]:
		fullscreen_check_button.set_pressed_no_signal(true)
		resolution_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		resolution_button.modulate.a = 0.5


func _on_resolution_button_pressed() -> void:
	if DisplayServer.screen_get_size() <= get_window().size:
		Global.settings_data["resolution"] = 3
	else:
		Global.settings_data["resolution"] += 1
	Global.apply_resolution_setting()
	
	var new_resolution: Vector2i =  Global.BASE_RESOLUTION * Global.settings_data["resolution"]
	resolution_button.text = "Resolution: " + str(new_resolution.x) + "x" + str(new_resolution.y)


func _on_fullscreen_check_button_toggled(toggled_on: bool) -> void:
	Global.settings_data["fullscreen"] = toggled_on
	Global.apply_fullscreen_setting()
	
	if toggled_on:
		resolution_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		resolution_button.modulate.a = 0.5
	else:
		Global.apply_resolution_setting()
		resolution_button.mouse_filter = Control.MOUSE_FILTER_STOP
		resolution_button.modulate.a = 1.0
	
	Global.apply_fullscreen_setting()



func _on_okay_button_pressed() -> void:
	Global.save_settings_data()
	hide()
