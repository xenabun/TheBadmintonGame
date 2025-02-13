extends Control

@export var state : UI_State

@export var menu_camera_pivot : Node
@export var player_camera : Node
@export var title_label : Node
@export var username_box : Node
@export var lobby_player_list : Node
@export var Network : Node
@export var ServerBrowser : Node

var title_tween
var title_rot_deg = 1
var title_rot_time = 4

func _ready():
	state = UI_State.new(self, Network)

func _enter_tree():
	title_label.rotation = deg_to_rad(-title_rot_deg)
	title_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	title_tween.tween_property(title_label, 'rotation', deg_to_rad(title_rot_deg), title_rot_time)
	title_tween.chain().tween_property(title_label, 'rotation', deg_to_rad(-title_rot_deg), title_rot_time)

func clear_lobby_player_list():
	for child in lobby_player_list.get_children():
		child.queue_free()

@rpc('any_peer')
func update_lobby_player_list(players):
	if not state.in_server_lobby.get_state(): return

	clear_lobby_player_list()
	for player_id in players:
		var player_data = players[player_id]
		var player_label = preload("res://prefabs/player_label.tscn").instantiate()
		# player_label.player_id = player_data.id
		player_label.get_node('Username').text = player_data.username
		lobby_player_list.add_child(player_label)
		if multiplayer.is_server() and multiplayer.get_unique_id() != player_data.id:
			var kick_button = player_label.get_node('Kick')
			kick_button.disabled = false
			kick_button.pressed.connect(func():
				Network.kick_peer(player_data.id)) # player_label.player_id))

@rpc('any_peer')
func close_lobby_player_list():
	state.in_menu.set_state(false)
	state.in_server_lobby.set_state(false)

@rpc
func show_match_result(result_text, score_text):
	var game_result_ui = get_node('GameResult')
	game_result_ui.get_node('Result').text = result_text
	game_result_ui.get_node('Score').text = score_text
	game_result_ui.show()
	get_node('GameUI').hide()

@rpc('any_peer')
func set_loading_screen(value):
	get_node('Loading').visible = value

func _on_game_exit_pressed():
	Network.quit_server()

func _on_server_browser_back_pressed():
	state.in_main_menu.set_state(true)
	state.in_server_browser.set_state(false)

func _on_pause_menu_close():
	state.in_game_menu.set_state(false)
	# get_node('Menu').hide()
	# if Game.current_game_type == Game.game_type.SINGLEPLAYER:
	# 	Game.game_in_progress = true

func _on_title_visibility_changed():
	if title_label.visible:
		title_label.rotation = deg_to_rad(-title_rot_deg)
		title_tween.play()
	else:
		title_tween.stop()
		
func _on_username_confirm_pressed():
	if get_node('MainMenu/Username/UsernameBox').text.is_empty(): return
	state.editing_username.set_state(false)
	username_box.text = get_node('MainMenu/Username/UsernameBox').text
func _on_username_change_pressed():
	state.editing_username.set_state(true)

func _on_singleplayer_pressed():
	Network.start_singleplayer()

func _on_multiplayer_pressed():
	# state.entering_port.set_state(true)
	state.in_main_menu.set_state(false)
	state.in_server_browser.set_state(true)

func _on_port_change_pressed():
	state.entering_port.set_state(true)

func _on_port_menu_close_pressed():
	state.entering_port.set_state(false)

func _on_port_confirm():
	var port_text = get_node('MainMenu/Port/VBoxContainer/LineEdit').text
	var port_num = port_text.to_int()
	if port_num and port_num >= 1024 and port_num <= 49151:
		Network.PORT = port_num
		state.entering_port.set_state(false)
		# state.in_main_menu.set_state(false)
		# state.in_server_browser.set_state(true)
	else:
		OS.alert('Введено неверное значение')

func _on_lobby_exit_pressed():
	Network.quit_server()

func show_message(value):
	get_node('Message/Panel/MarginContainer/MessageText').text = value
	state.showing_message.set_state(true)
func _on_message_close_pressed():
	state.showing_message.set_state(false)

func _on_controls_close():
	get_node('GameControls').hide()

func _on_app_exit_pressed():
	get_tree().quit()

func _physics_process(_delta):
	if Game.window_focus:
		menu_camera_pivot.rotation.y += 0.0005
