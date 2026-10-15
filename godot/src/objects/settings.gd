extends Panel

@onready var master_scene: Control = get_tree().current_scene
@onready var fullscreen_check_button: CheckButton = $VBoxContainer/setting_items/fullscreen
@onready var window_size_button: Button = $VBoxContainer/setting_items/window_size
@onready var sfx_slider: HSlider = $VBoxContainer/setting_items/sfx/HSlider
@onready var sfx_label: Label = $VBoxContainer/setting_items/sfx/Label


func _ready() -> void:
	var window_size: Vector2i = get_window().size
	window_size_button.text = "Window Size: " + str(window_size.x) + "x" + str(window_size.y)
	
	if Global.user_data["fullscreen"]:
		fullscreen_check_button.set_pressed_no_signal(true)
		window_size_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		window_size_button.modulate.a = 0.5
	
	sfx_label.text = "SFX Volume: " + str( int( Global.user_data["sfx_volume"] * 100) ) + "%"
	sfx_slider.set_value_no_signal(Global.user_data["sfx_volume"])


func _on_window_size_pressed() -> void:
	Sound.button_tick.play()
	if DisplayServer.screen_get_size() <= get_window().size:
		Global.user_data["window_size"] = 3
	else:
		Global.user_data["window_size"] += 1
	Global.apply_window_size_setting()
	
	var new_resolution: Vector2i =  Global.BASE_RESOLUTION * Global.user_data["window_size"]
	window_size_button.text = "Window Size: " + str(new_resolution.x) + "x" + str(new_resolution.y)


func _on_fullscreen_check_button_toggled(toggled_on: bool) -> void:
	Sound.button_tick.play()
	Global.user_data["fullscreen"] = toggled_on
	Global.apply_fullscreen_setting()
	
	if toggled_on:
		window_size_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		window_size_button.modulate.a = 0.5
	else:
		Global.apply_window_size_setting()
		window_size_button.mouse_filter = Control.MOUSE_FILTER_STOP
		window_size_button.modulate.a = 1.0
	
	Global.apply_fullscreen_setting()


func _on_okay_button_pressed() -> void:
	Sound.button_tick.play()
	Global.save_settings_data()
	hide()
	master_scene.title_label.show()
	master_scene.main_buttons_node.show()


func _on_sfx_slider_value_changed(value: float) -> void:
	sfx_label.text = "SFX Volume: " + str(int(value * 100)) + "%"
	Global.user_data["sfx_volume"] = value
	Global.apply_sfx_volume_setting()
