extends Panel

var screen_size: Vector2i = DisplayServer.screen_get_size()
var max_window_size: int = screen_size.x / ProjectSettings.get_setting("display/window/size/viewport_width")
var min_window_size: int = max_window_size - 3

@onready var master_scene: Control = get_tree().current_scene
@onready var fullscreen_check_button: CheckButton = $VBoxContainer/setting_items/fullscreen
@onready var window_size_button: Button = $VBoxContainer/setting_items/window_size
@onready var sfx_slider: HSlider = $VBoxContainer/setting_items/sfx/HSlider
@onready var sfx_label: Label = $VBoxContainer/setting_items/sfx/Label


func _ready() -> void:
	if Global.user_data.get("fullscreen"):
		fullscreen_check_button.set_pressed_no_signal(true)
		window_size_button.disabled = true

	var window_size: Vector2i = Global.BASE_WINDOW_SIZE * Global.user_data.get("window_size")
	window_size_button.text = "Window Size: " + str(window_size).remove_chars("(),").replace(" ", "x")

	sfx_label.text = "SFX Volume: %d%%" % [Global.user_data.get("sfx_volume") * 100]
	sfx_slider.set_value_no_signal(Global.user_data.get("sfx_volume"))


func _on_fullscreen_check_button_toggled(toggled_on: bool) -> void:
	Sound.button_tick.play()
	Global.user_data.set("fullscreen", toggled_on)
	Global.apply_fullscreen_setting()

	if toggled_on:
		window_size_button.disabled = true
	else:
		Global.apply_window_size_setting()
		window_size_button.disabled = false


func _on_window_size_pressed() -> void:
	Sound.button_tick.play()

	if Global.user_data.get("window_size") >= max_window_size:
		Global.user_data.set("window_size", min_window_size)
	else:
		Global.user_data["window_size"] += 1
	Global.apply_window_size_setting()

	var new_window_size: Vector2i = Global.BASE_WINDOW_SIZE * Global.user_data.get("window_size")
	window_size_button.text = "Window Size: " + str(new_window_size).remove_chars("(),").replace(" ", "x")


func _on_okay_button_pressed() -> void:
	Sound.button_tick.play()
	Global.save_user_data()
	hide()
	master_scene.title_label.show()
	master_scene.main_buttons_node.show()


func _on_sfx_slider_value_changed(value: float) -> void:
	sfx_label.text = "SFX Volume: %d%%" % [value * 100]
	Global.user_data.set("sfx_volume", value)
	Global.apply_sfx_volume_setting()
