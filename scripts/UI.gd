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
	
	var prompt = get_node('ConfirmationDialog')
	prompt.canceled.connect(clear_prompt_connections)

func _enter_tree():
	title_label.rotation = deg_to_rad(-title_rot_deg)
	title_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	title_tween.tween_property(title_label, 'rotation', deg_to_rad(title_rot_deg), title_rot_time)
	title_tween.chain().tween_property(title_label, 'rotation', deg_to_rad(-title_rot_deg), title_rot_time)

func clear_prompt_connections():
	print('clearing prompt connections')
	var prompt = get_node('ConfirmationDialog')
	var confirm_cons = prompt.confirmed.get_connections()
	for con in confirm_cons:
		prompt.confirmed.disconnect(con.callable)

@rpc('any_peer')
func leaderboard_init():
	var leaderboard = get_node('Leaderboard')
	var user_label_container = leaderboard.get_node('Panel/Table/Container/Left/Container/Content')
	var score_column_container = leaderboard.get_node('Panel/Table/Container/Right/Container')
	var user_label_prefab = preload("res://prefabs/leaderboard/user_label.tscn")
	var score_column_prefab = preload("res://prefabs/leaderboard/score_column.tscn")
	var score_label_prefab = preload("res://prefabs/leaderboard/score_label.tscn")

	leaderboard.get_node('Panel/Score').show()

	var i = 0
	for player_id in Network.Players:
		i += 1
		var player_data = Network.Players[player_id]
		var user_label = user_label_prefab.instantiate()
		user_label.name = str(player_id)
		user_label.get_node('Number/Label').text = str(i)
		user_label.get_node('Username/Label').text = player_data.username
		user_label_container.add_child(user_label, true)
		var score_column = score_column_prefab.instantiate()
		score_column.name = str(player_id)
		score_column.get_node('Top/Label').text = str(i)
		score_column_container.add_child(score_column, true)
		for player_id2 in Network.Players:
			var score_label = score_label_prefab.instantiate()
			score_label.name = str(player_id2)
			score_label.get_node('Label').text = '-' if player_id2 == player_id else ''
			score_column.get_node('Content').add_child(score_label, true)

func leaderboard_clear():
	var leaderboard = get_node('Leaderboard')
	var user_label_container = leaderboard.get_node('Panel/Table/Container/Left/Container/Content')
	var score_column_container = leaderboard.get_node('Panel/Table/Container/Right/Container')
	for child in user_label_container.get_children():
		child.queue_free()
	for child in score_column_container.get_children():
		child.queue_free()

func update_leaderboard_match_data():
	var score_column_container = get_node('Leaderboard/Panel/Table/Container/Right/Container')
	for id1 in Network.Leaderboard:
		for id2 in Network.Leaderboard[id1]:
			var score_label = score_column_container.get_node(str(id2) + '/Content/' + str(id1) + '/Label')
			var scores_unformatted = Network.Leaderboard[id1][id2]
			var scores : PackedStringArray = []
			for score in scores_unformatted:
				scores.push_back(str(score[0], '-', score[1]))
			var score_str = ' '.join(scores)
			score_label.text = score_str

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
func close_match_result():
	state.showing_leaderboard.set_state(false, false)
	get_node('GameResult').hide()

@rpc
func show_match_result(result_text, _score_text):
	get_node('GameControls').hide()
	var game_result_ui = get_node('GameResult')
	# game_result_ui.get_node('Result').text = result_text
	get_node('Leaderboard/Panel/Results/MatchResult').text = result_text
	# game_result_ui.get_node('Score').text = score_text
	game_result_ui.show()
	state.showing_leaderboard.set_state(true, true)
	# get_node('Leaderboard/Panel/Score').hide()
	# get_node('Leaderboard/Panel/Results').show()
	# get_node('GameUI').hide()
	state.showing_game_ui.set_state(false)

@rpc('any_peer')
func set_loading_screen(value):
	get_node('Loading').visible = value

func _on_game_exit_pressed():
	var prompt = get_node('ConfirmationDialog')
	prompt.dialog_text = "Вы действительно хотите покинуть матч?"
	prompt.confirmed.connect(Network.quit_server)
	prompt.confirmed.connect(clear_prompt_connections)
	prompt.popup_centered()

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
