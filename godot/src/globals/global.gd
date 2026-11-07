extends Node

const BASE_WINDOW_SIZE: Vector2i = Vector2i(320, 180)
 
var sfx_bus_index: int = AudioServer.get_bus_index("sfx")
var user_data_file_dir: String = OS.get_user_data_dir().path_join("user_data.bin")
@warning_ignore("integer_division")
var user_data: Dictionary[String, Variant] = {
	"fullscreen": true,
	"window_size": DisplayServer.screen_get_size().x / BASE_WINDOW_SIZE.x,
	"sfx_volume": 1.0}


func _ready() -> void:
	load_user_data()
	apply_sfx_volume_setting()
	if user_data["fullscreen"]:
		apply_fullscreen_setting()
	else:
		apply_window_size_setting()


func load_user_data() -> void:
	if !FileAccess.file_exists(user_data_file_dir):
		save_user_data()
		return
	
	var file_access: FileAccess = FileAccess.open(user_data_file_dir, FileAccess.READ)
	var loaded_data = file_access.get_var()
	
	# save again default data if file content is broken
	if loaded_data == null:
		push_error("User data file is founded, but data is broken or was changed. \nWill write again from default values.")
		save_user_data()
		return
	
	var new_user_data: Dictionary[String, Variant] = loaded_data
	user_data.merge(new_user_data, true)
	file_access.close()


func save_user_data() -> void:
	var file_access: FileAccess = FileAccess.open(user_data_file_dir, FileAccess.WRITE)
	if file_access == null:
		push_error("User data file could not be written to user data directory")
		return
	
	file_access.store_var(user_data)
	file_access.close()


func apply_window_size_setting() -> void:
	get_window().size = BASE_WINDOW_SIZE * user_data.get("window_size")
	get_window().move_to_center()


func apply_fullscreen_setting() -> void:
	if user_data["fullscreen"]:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func apply_sfx_volume_setting() -> void:
	AudioServer.set_bus_volume_db(sfx_bus_index, linear_to_db(user_data["sfx_volume"]))
