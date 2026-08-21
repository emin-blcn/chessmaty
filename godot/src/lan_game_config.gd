extends Control

signal config_finished(config_data: Dictionary[String, Variant])

const time_per_side_minute_values: PackedFloat64Array = [0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0,
	13.0, 14.0, 15.0, 16.0, 17.0,18.0, 19.0, 20.0, 25.0, 30.0, 35.0, 40.0, 45.0, 60.0, 75.0, 90.0, 105.0, 120.0, 135.0, 150.0, 165.0, 180.0, -1.0]
const time_increment_second_values: PackedInt64Array = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9,
	10, 11, 12, 13, 14, 15, 16,17, 18, 19, 20, 25, 30, 35, 40, 45, 60, 90, 120, 150, 180]

@onready var create_stream_config_node: Control = $TabContainer/create/create_stream_config
@onready var player_name_line_edit: LineEdit = $TabContainer/create/create_stream_config/player_name_line_edit
@onready var game_mode_button: Button = $TabContainer/create/create_stream_config/game_mode_button
@onready var player_color_button: Button = $TabContainer/create/create_stream_config/player_color_button
@onready var time_per_side_label: Label = $TabContainer/create/create_stream_config/time_per_side_bar/time_per_side_label
@onready var time_increment_bar: HScrollBar = $TabContainer/create/create_stream_config/time_increment_bar
@onready var time_increment_label: Label = $TabContainer/create/create_stream_config/time_increment_bar/time_increment_label

@onready var wait_client_node: Control = $TabContainer/create/wait_client
@onready var cancel_wait_button: Button = $TabContainer/create/wait_client/cancel_wait_button

@onready var refresh_stream_list_button: Button = $TabContainer/join/refresh_stream_list_button
@onready var element_nodes: VBoxContainer = $TabContainer/join/ColorRect/ScrollContainer/elements
@onready var element_instance_node: ColorRect = $TabContainer/join/ColorRect/ScrollContainer/elements/element_instance

var lan_stream: LanStream = LanStream.new()
var lan_client: LanClient = LanClient.new()
var is_streams_searching: bool = false
var is_client_waitinig: bool = false
var config_data: Dictionary[String, Variant] = {
	"player_name": "Player",
	"player_color": Enums.ChessColor.WHITE,
	"game_mode": Enums.GameMode.STANDARD,
	"connection_type": Enums.ConnectionType.LAN,
	"time_per_side": -60_000,
	"time_increment": 0}


func _on_game_config_tab_changed(tab: int) -> void:
	if tab == 1:
		discover_streams()


func _on_refresh_stream_list_button_pressed() -> void:
	discover_streams()


func discover_streams():
	if is_streams_searching:
		return
	is_streams_searching = true
	
	refresh_stream_list_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	refresh_stream_list_button.modulate.a = 0.5
	cancel_wait_button.hide()
	
	for element: ColorRect in element_nodes.get_children():
		if element != element_instance_node:
			element.queue_free()
	
	WorkerThreadPool.add_task(_discover_streams)


func _discover_streams():
	var discovered_streams: Dictionary[String, String] = lan_client.scan_all_streams()
	call_deferred("_on_stream_discover_finished", discovered_streams)


func _on_stream_discover_finished(discovered_streams: Dictionary[String, String]):
	for key_ip in discovered_streams.keys():
		var value: String = discovered_streams[key_ip]
		var data_list: PackedStringArray = value.split("|")
		var player_name: String = data_list[1]
		var player_color: Enums.ChessColor = int(data_list[2]) as Enums.ChessColor
		var game_mode: Enums.GameMode = int(data_list[3]) as Enums.GameMode
		var time_per_side: int = int(data_list[4])
		var time_increment: int = int(data_list[5])
		var new_element_node: ColorRect = element_instance_node.duplicate()
		
		new_element_node.get_node("join_button").pressed.connect(_on_stream_join_button_pressed.bind(key_ip))
		
		match player_color:
			Enums.ChessColor.WHITE:
				new_element_node.get_node("player_name_label").text = player_name + " (White)"
			Enums.ChessColor.BLACK:
				new_element_node.get_node("player_name_label").text = player_name + " (Black)"
		
		match game_mode:
			Enums.GameMode.STANDARD:
				new_element_node.get_node("game_mode_label").text = "game mode (Standard)"
			Enums.GameMode.CHESS960:
				new_element_node.get_node("game_mode_label").text = "game mode (Chess960)"
		
		if time_per_side == -60_000:
			new_element_node.get_node("HBoxContainer/minute_per_side_label").text = "no time limit"
			new_element_node.get_node("HBoxContainer/increment_second_label").hide()
		else:
			@warning_ignore_start("integer_division")
			var minute_per_side: float = float(time_per_side) / 60.0 / 1000.0
			if str(minute_per_side).split(".")[1] == "0":
				new_element_node.get_node("HBoxContainer/minute_per_side_label").text = "minute per side (" + str(int(time_per_side) / 60 / 1000) + ")"
			else:
				new_element_node.get_node("HBoxContainer/minute_per_side_label").text = "minute per side (" + str(time_per_side / 60.0 / 1000.0) + ")"
			
			if time_increment == 0:
				new_element_node.get_node("HBoxContainer/increment_second_label").text = "no time increment"
			else:
				new_element_node.get_node("HBoxContainer/increment_second_label").text = "increment in seconds (" + str(time_increment / 1000) + ")"
			@warning_ignore_restore("integer_division")
		
		element_nodes.add_child(new_element_node)
		new_element_node.show()
	
	refresh_stream_list_button.mouse_filter = Control.MOUSE_FILTER_STOP
	refresh_stream_list_button.modulate.a = 1.0
	cancel_wait_button.show()
	is_streams_searching = false


func _on_stream_join_button_pressed(stream_ip: String):
	print(stream_ip)


func _on_player_color_button_pressed() -> void:
	match config_data["player_color"]:
		Enums.ChessColor.WHITE:
			config_data["player_color"] = Enums.ChessColor.BLACK
			player_color_button.text = "Player side: Black"
		Enums.ChessColor.BLACK:
			config_data["player_color"] = Enums.ChessColor.WHITE
			player_color_button.text = "Player side: White"


func _on_game_mode_button_pressed() -> void:
	match config_data["game_mode"]:
		Enums.GameMode.STANDARD:
			config_data["game_mode"] = Enums.GameMode.CHESS960
			game_mode_button.text = "Game mode: Chess960"
		Enums.GameMode.CHESS960:
			config_data["game_mode"] = Enums.GameMode.STANDARD
			game_mode_button.text = "Game mode: Standard"


func _on_time_per_side_bar_value_changed(value: float) -> void:
	var index: int = int(value)
	var new_minute: float = time_per_side_minute_values[index]
	var new_time: int = int(new_minute * 60 * 1000)
	
	config_data["time_per_side"] = new_time
	
	if new_time == -60_000:
		time_per_side_label.text = "Minutes per side: Unlimited"
		time_increment_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		time_increment_bar.modulate.a = 0.5
		time_increment_label.modulate.a = 0.5
	else:
		if str(new_minute).split(".")[1] == "0":
			time_per_side_label.text = "Minutes per side: " + str(int(new_minute))
		else:
			time_per_side_label.text = "Minutes per side: " + str(new_minute)
		time_increment_bar.mouse_filter = Control.MOUSE_FILTER_STOP
		time_increment_bar.modulate.a = 1.0
		time_increment_label.modulate.a = 1.0


func _on_time_increment_bar_value_changed(value: float) -> void:
	config_data["time_increment"] = time_increment_second_values[int(value)] * 1000
	time_increment_label.text = "Increment in seconds " + str(time_increment_second_values[int(value)])


func _on_crate_stream_button_pressed() -> void:
	config_data["player_name"] = player_name_line_edit.text
	wait_a_client()


func wait_a_client():
	if is_client_waitinig:
		return
	is_client_waitinig = true
	
	create_stream_config_node.hide()
	wait_client_node.show()
	
	WorkerThreadPool.add_task(_wait_a_client)


func _wait_a_client():
	var client_info: String = lan_stream.wait_a_client(config_data)
	call_deferred("msg_received", client_info)


func msg_received(msg: String):
	print("STREAM, msg received: ", msg)
	is_client_waitinig = false


func _on_cancel_wait_button_pressed() -> void:
	lan_stream.cancel_wait()
	wait_client_node.hide()
	create_stream_config_node.show()
