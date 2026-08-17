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
	var file_path: String = OS.get_user_data_dir().path_join("settings.bin")
	if !FileAccess.file_exists(file_path):
		save_settings_data()
		return
	
	var file_access: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	settings_data = file_access.get_var()
	file_access.close()


func save_settings_data():
	var file_path: String = OS.get_user_data_dir().path_join("settings.bin")
	var file_access: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	file_access.store_var(settings_data)
	file_access.close()


func apply_resolution_setting():
	DisplayServer.window_set_size(BASE_RESOLUTION * settings_data["resolution"])
	get_window().size = BASE_RESOLUTION * settings_data["resolution"]
	get_window().move_to_center()


func apply_fullscreen_setting():
	if settings_data["fullscreen"]:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)










	
