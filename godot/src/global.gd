extends Node

const BASE_RESOLUTION: Vector2i = Vector2i(320, 180)

var user_data_file_path: String = OS.get_user_data_dir().path_join("user_data.bin")
var user_data: Dictionary = {
	"resolution": 3,
	"fullscreen": true}


func _ready() -> void:
	load_settings_data()
	apply_resolution_setting()
	apply_fullscreen_setting()


func load_settings_data():
	if !FileAccess.file_exists(user_data_file_path):
		save_settings_data()
		return
	
	var file: FileAccess = FileAccess.open(user_data_file_path, FileAccess.READ)
	user_data = file.get_var()
	file.close()


func save_settings_data():
	var file: FileAccess = FileAccess.open(user_data_file_path, FileAccess.WRITE)
	file.store_var(user_data)
	file.close()


func apply_resolution_setting():
	DisplayServer.window_set_size(BASE_RESOLUTION * user_data["resolution"])
	get_window().size = BASE_RESOLUTION * user_data["resolution"]
	get_window().move_to_center()


func apply_fullscreen_setting():
	if user_data["fullscreen"]:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
