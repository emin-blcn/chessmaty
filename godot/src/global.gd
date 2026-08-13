extends Node

const BASE_RESOLUTION: Vector2i = Vector2i(320, 180)

var settings_data: Dictionary = {
	"resolution": 3,
	"fullscreen": true}


func _ready() -> void:
	load_settings_data()
	apply_resolution_setting()
	apply_fullscreen_setting()


func load_settings_data():
	var file_path: String = "user://".path_join("settings.bin")
	if !FileAccess.file_exists(file_path):
		save_settings_data()
		return
	
	var file_access: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	settings_data = file_access.get_var()
	file_access.close()


func save_settings_data():
	var file_path: String = "user://".path_join("settings.bin")
	var file_access: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	file_access.store_var(settings_data)
	file_access.close()


func apply_resolution_setting():
	DisplayServer.window_set_size(BASE_RESOLUTION * settings_data["resolution"])
	get_window().size = BASE_RESOLUTION * settings_data["resolution"]
	get_window().move_to_center()


func update_resolution_setting():
	var active_resolution: int = settings_data["resolution"]
	if DisplayServer.screen_get_size() <= BASE_RESOLUTION * active_resolution:
		active_resolution = 3
	else:
		active_resolution += 1
	settings_data["resolution"] = active_resolution
	apply_resolution_setting()


func apply_fullscreen_setting():
	if settings_data["fullscreen"]:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		apply_resolution_setting()


func update_fullscreen_setting(fullscreen: bool):
	settings_data["fullscreen"] = fullscreen
	apply_fullscreen_setting()
