extends Panel

@onready var resolution_button: Button = $resolution_button
@onready var fullscreen_check_button: CheckButton = $fullscreen_check_button
@onready var sfx_label: Label = $sfx_label
@onready var sfx_slider: HSlider = $sfx_label/sfx_slider


func _ready() -> void:
	var window_size: Vector2i = get_window().size
	resolution_button.text = "Resolution: " + str(window_size.x) + "x" + str(window_size.y)
	
	if Global.user_data["fullscreen"]:
		fullscreen_check_button.set_pressed_no_signal(true)
		resolution_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		resolution_button.modulate.a = 0.5
	
	var sfx_volume_percent: int = int(Global.user_data["sfx_volume"] * 100)
	sfx_label.text = "SFX Volume: " + str(sfx_volume_percent)
	sfx_slider.value = sfx_volume_percent


func _on_resolution_button_pressed() -> void:
	Sound.button_tick.play()
	if DisplayServer.screen_get_size() <= get_window().size:
		Global.user_data["resolution"] = 3
	else:
		Global.user_data["resolution"] += 1
	Global.apply_resolution_setting()
	
	var new_resolution: Vector2i =  Global.BASE_RESOLUTION * Global.user_data["resolution"]
	resolution_button.text = "Resolution: " + str(new_resolution.x) + "x" + str(new_resolution.y)


func _on_fullscreen_check_button_toggled(toggled_on: bool) -> void:
	Sound.button_tick.play()
	Global.user_data["fullscreen"] = toggled_on
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
	Sound.button_tick.play()
	hide()
	get_node("../bg/Label").show()


func _on_sfx_slider_value_changed(value: float) -> void:
	sfx_label.text = "SFX Volume: " + str(int(value))
	Global.user_data["sfx_volume"] = value / 100
	Global.apply_sfx_volume_setting()
