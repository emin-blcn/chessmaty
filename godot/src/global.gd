extends Node

const BASE_RESOLUTION: Vector2i = Vector2i(320, 180)

var user_data_file_path: String = OS.get_user_data_dir().path_join("user_data.bin")
var user_data: Dictionary = {
	"resolution": 3,
	"fullscreen": true,
	"sfx_volume": 1.0}
var sfx_bus_index: int = AudioServer.get_bus_index("sfx")


func _ready() -> void:
	load_settings_data()
	apply_resolution_setting()
	apply_fullscreen_setting()
	apply_sfx_volume_setting()


func load_settings_data() -> void:
	if !FileAccess.file_exists(user_data_file_path):
		save_settings_data()
		return
	
	var file: FileAccess = FileAccess.open(user_data_file_path, FileAccess.READ)
	user_data.merge(file.get_var(), true)
	file.close()


func save_settings_data() -> void:
	var file: FileAccess = FileAccess.open(user_data_file_path, FileAccess.WRITE)
	file.store_var(user_data)
	file.close()


func apply_resolution_setting() -> void:
	DisplayServer.window_set_size(BASE_RESOLUTION * user_data["resolution"])
	get_window().size = BASE_RESOLUTION * user_data["resolution"]
	get_window().move_to_center()


func apply_fullscreen_setting() -> void:
	if user_data["fullscreen"]:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func apply_sfx_volume_setting() -> void:
	AudioServer.set_bus_volume_db(sfx_bus_index, linear_to_db(user_data["sfx_volume"]))
