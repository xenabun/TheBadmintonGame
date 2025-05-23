extends Control

@export var state : UI_State

@export var menu_camera_pivot : Node
@export var player_camera : Node
@export var title_label : Node
@export var username_box : Node
@export var lobby_player_list : Node
@export var Level : Node
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

@rpc('any_peer', 'call_local')
func leaderboard_init():
	print('running leaderboard init ', multiplayer.get_unique_id())
	var leaderboard = get_node('Leaderboard')
	leaderboard.get_node('Panel/Results/WaitText').show()
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
			var score_label_name = str(id2) + '/Content/' + str(id1) + '/Label'
			if score_column_container.has_node(score_label_name):
				var score_label = score_column_container.get_node(score_label_name)
				var scores_unformatted = Network.Leaderboard[id1][id2]
				var scores : PackedStringArray = []
				for score in scores_unformatted:
					scores.push_back(str(score[0], '-', score[1]))
				var score_str = ' '.join(scores)
				score_label.text = score_str

func clear_lobby_player_list():
	for child in lobby_player_list.get_children():
		child.queue_free()

@rpc('any_peer', 'call_local')
func update_lobby_player_list(players):
	if not state.in_server_lobby.get_state(): return

	clear_lobby_player_list()
	for player_id in players:
		var player_data = players[player_id]
		var player_label = preload("res://prefabs/player_label.tscn").instantiate()
		player_label.get_node('Username').text = player_data.username
		lobby_player_list.add_child(player_label)
		if multiplayer.is_server() and multiplayer.get_unique_id() != player_data.id:
			var kick_button = player_label.get_node('Kick')
			kick_button.disabled = false
			kick_button.pressed.connect(func():
				Network.kick_peer(player_data.id))

@rpc('any_peer', 'call_local')
func close_lobby_player_list():
	state.in_menu.set_state(false)
	state.in_server_lobby.set_state(false)

@rpc('call_local')
func show_ready_check():
	var ready_check = get_node('Leaderboard/Panel/ReadyCheck')
	ready_check.get_node('Ready').disabled = false
	ready_check.get_node('Ready').text = 'Готов'
	ready_check.get_node('Panel/Check').hide()
	ready_check.get_node('Panel/Cross').show()
	ready_check.show()

@rpc('call_local')
func close_match_result():
	state.showing_leaderboard.set_state(false, false)
	get_node('GameResult').hide()

@rpc('call_local')
func show_match_result(result_text, final = false):
	get_node('GameControls').hide()
	var game_result_ui = get_node('GameResult')
	get_node('Leaderboard/Panel/Results/MatchResult').text = result_text
	game_result_ui.show()
	state.showing_leaderboard.set_state(true, true)
	state.showing_game_ui.set_state(false)
	
	if final:
		var leaderboard = get_node('Leaderboard')
		leaderboard.get_node('Panel/Results/WaitText').hide()
		leaderboard.get_node('Panel/Score').hide()

		leaderboard_clear()
		
		var user_label_container = leaderboard.get_node('Panel/Table/Container/Left/Container/Content')
		var score_column_container = leaderboard.get_node('Panel/Table/Container/Right/Container')
		var user_label_prefab = preload("res://prefabs/leaderboard/user_label.tscn")
		var score_column_prefab = preload("res://prefabs/leaderboard/score_column.tscn")
		var score_label_prefab = preload("res://prefabs/leaderboard/score_label.tscn")
		
		var points_column = score_column_prefab.instantiate()
		points_column.get_node('Top/Label').text = 'Очки'
		points_column.get_node('Top').custom_minimum_size.x = 100
		score_column_container.add_child(points_column)
		
		var match_amount_column = score_column_prefab.instantiate()
		match_amount_column.get_node('Top/Label').text = 'Матчи'
		match_amount_column.get_node('Top').custom_minimum_size.x = 125
		score_column_container.add_child(match_amount_column)
		
		var match_score_column = score_column_prefab.instantiate()
		match_score_column.get_node('Top/Label').text = 'Разница геймов'
		score_column_container.add_child(match_score_column)
		
		var round_score_column = score_column_prefab.instantiate()
		round_score_column.get_node('Top/Label').text = 'Разница очков'
		score_column_container.add_child(round_score_column)
		
		var player_stats = {}
		var player_points = []
		for player_id in Network.Players:
			var player_data = Network.Players[player_id]
			var leaderboard_data = Network.Leaderboard[player_id]
			var points = 0
			var match_amount = leaderboard_data.size()
			var match_score = [ 0, 0 ]
			var round_score = [ 0, 0 ]
			for i in leaderboard_data:
				var round_data = leaderboard_data[i]
				for score in round_data:
					if score[0] > score[1]:
						points += 1
						match_score[0] += 1
					else:
						match_score[1] += 1
					round_score[0] += score[0]
					round_score[1] += score[1]
			player_points.push_back({ id = player_id, points = points })
			player_stats[player_id] = {
				username = player_data.username,
				points = points,
				match_amount = match_amount,
				match_score = match_score,
				round_score = round_score,
			}
		player_points.sort_custom(func(a, b): return a.points > b.points)

		for i in range(0, player_points.size()):
			var player_id = player_points[i].id
			var player_data = player_stats[player_id]

			var user_label = user_label_prefab.instantiate()
			user_label.get_node('Number/Label').text = str(i + 1)
			user_label.get_node('Username/Label').text = player_data.username
			user_label_container.add_child(user_label)
			
			var points_row = score_label_prefab.instantiate()
			points_row.get_node('Label').text = str(player_data.points)
			points_row.custom_minimum_size.x = 100
			points_column.get_node('Content').add_child(points_row)

			var match_amount_row = score_label_prefab.instantiate()
			match_amount_row.get_node('Label').text = str(player_data.match_amount)
			match_amount_row.custom_minimum_size.x = 125
			match_amount_column.get_node('Content').add_child(match_amount_row)
			
			var match_score_row = score_label_prefab.instantiate()
			match_score_row.get_node('Label').text = str(player_data.match_score[0], '-', player_data.match_score[1])
			match_score_column.get_node('Content').add_child(match_score_row)
			
			var round_score_row = score_label_prefab.instantiate()
			round_score_row.get_node('Label').text = str(player_data.round_score[0], '-', player_data.round_score[1])
			round_score_column.get_node('Content').add_child(round_score_row)

@rpc('any_peer', 'call_local')
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
	else:
		OS.alert('Введено неверное значение')

func _on_next_match_ready_pressed():
	var ready_check = get_node('Leaderboard/Panel/ReadyCheck')
	ready_check.get_node('Ready').disabled = true
	ready_check.get_node('Panel/Check').show()
	ready_check.get_node('Panel/Cross').hide()
	Game.set_player_ready.rpc_id(1, multiplayer.get_unique_id())

func switch_match(offset):
	var player_id = multiplayer.get_unique_id()
	var player_data = Network.Players[player_id]
	var player_state = player_data.state
	if player_state != Network.player_state_type.SPECTATOR: return
	
	var player_match_id = player_data.match_id
	var current_match_data = Network.Matches[player_match_id]
	if current_match_data.status != Network.match_status_type.IN_PROGRESS: return

	var new_match_id = player_match_id
	var begin = 0
	var end = Network.Matches.size() - 1

	while true:
		new_match_id += offset
		if new_match_id < begin:
			new_match_id = end
		elif new_match_id > end:
			new_match_id = 0
		if Network.Matches.has(new_match_id):
			var match_data = Network.Matches[new_match_id]
			var match_status = match_data.status
			if match_status == Network.match_status_type.IN_PROGRESS:
				break
	
	if Level.get_node('Spectators').has_node(str(player_id)):
		var spectator = Level.get_node('Spectators/' + str(player_id))
		spectator.match_id = new_match_id
	for player in Level.get_node('Players').get_children():
		player.visible = player.match_id == new_match_id
	for ball in Level.get_node('Balls').get_children():
		ball.visible = ball.match_id == new_match_id

	Network.set_match_id.rpc_id(1, player_id, new_match_id)
	Game.update_score_text(new_match_id)

func _on_previous_match_switch_pressed():
	switch_match(-1)
func _on_next_match_switch_pressed():
	switch_match(1)

func _on_game_controls_hidden():
	if Game.current_game_type == Game.game_type.MULTIPLAYER:
		var player_id = multiplayer.get_unique_id()
		if Level.get_node('Players').has_node(str(player_id)):
			var player = Level.get_node('Players/' + str(player_id))
			player.can_play = true

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
