extends Node

signal window_focus_changed

enum game_type {
	NONE,
	SINGLEPLAYER,
	MULTIPLAYER
}

const WIN_TEXT = 'Победа!'
const LOSE_TEXT = 'Поражение'

@export var current_game_type : game_type = game_type.NONE

@onready var Level = get_tree().get_root().get_node('Scene/Level')
@onready var UI = get_tree().get_root().get_node('Scene/UI')
@onready var Network = get_tree().get_root().get_node('Scene/Network')
@onready var ServerBrowser = get_tree().get_root().get_node('Scene/ServerBrowser')
# @onready var ball = Level.get_node('World/Ball')

var debug = false
var window_focus = true

func is_match_in_progress(match_id):
	if not Network.Matches.has(match_id): return
	var match_data = Network.Matches[match_id]
	return match_data.status == Network.match_status_type.IN_PROGRESS

func get_player_round_score(match_id, player_index):
	return Network.Matches[match_id].round_score[player_index]

func get_ball_by_match_id(match_id):
	for i in Network.Balls:
		var ball = Network.Balls[i]
		if (ball.has('match_id') and ball.match_id == match_id
				and Level.get_node('Balls').has_node(str(match_id))):
			return Level.get_node('Balls/' + str(match_id))
	return null

@rpc('any_peer')
func set_players_can_throw(match_id, player_num):
	for i in Network.Players:
		var player_data = Network.Players[i]
		if (player_data.has('match_id') and player_data.has('num')
				and player_data.match_id == match_id and player_data.num == player_num
				and Level.get_node('Players').has_node(str(player_data.id))):
			var player = Level.get_node('Players/' + str(player_data.id))
			if player_data.is_bot or player_data.id == 1:
				player.set_can_throw(true)
			else:
				player.set_can_throw.rpc_id(player_data.id, true)

func get_opponent_id(id):
	if not Network.Players.has(id): return

	var my_player_data = Network.Players[id]
	if not my_player_data.has('match_id'): return

	var match_id = my_player_data.match_id
	var opponent_id = null

	for player_id in Network.Players:
		if player_id == id: continue
		var player_data = Network.Players[player_id]
		if not player_data.has('match_id'): continue
		if player_data.match_id != match_id: continue
		opponent_id = player_id
		break
	
	if not opponent_id:
		opponent_id = id

	return opponent_id

func get_opponent_index(index):
	return abs(index - 1)

# func peer_id_to_score_index(id):
# 	return get_player_num(id) - 1

func get_player_num(id):
	if not Network.Players.has(id): return
	var player_data = Network.Players[id]
	if player_data.has('num'):
		return player_data.num

func get_player_match_id(id):
	if not Network.Players.has(id): return
	var player_data = Network.Players[id]
	if player_data.has('match_id'):
		return player_data.match_id

func get_full_score_str(player_num, match_id):
	var match_data = Network.Matches[match_id]
	var match_score = match_data.match_score
	if player_num == 1:
		return str(match_score[0], ' : ', match_score[1])
	else:
		return str(match_score[1], ' : ', match_score[0])

func get_match_players_data(match_id):
	var ids = {0: null, 1: null}

	for i in Network.Players:
		var pdata = Network.Players[i]
		if (pdata.has('match_id') and pdata.match_id == match_id
				and pdata.state == Network.player_state_type.PLAYER):
			ids[pdata.num - 1] = pdata
	
	for i in 2:
		if ids[i] == null:
			ids[i] = {'username': 'Неизвестен', 'num': i + 1}
	
	return ids

@rpc('any_peer')
func update_score_text(match_id = null, player_num = null):
	# var pdata = Network.Players[multiplayer.get_unique_id()]
	# if match_id == null:
		# match_id = pdata.match_id
	if match_id == null or player_num == null:
		var player_id = multiplayer.get_unique_id()
		match_id = get_player_match_id(player_id)
		player_num = get_player_num(player_id)
	
	var match_data = Network.Matches[match_id]
	var round_score = match_data.round_score
	var match_score = match_data.match_score
	var players_data = get_match_players_data(match_id)
	var score_control = UI.get_node('GameUI/ScoreControl')
	var score_leaderboard = UI.get_node('Leaderboard/Panel/Score')
	
	if player_num == 1:
		score_control.get_node('Player1Score2').text = str(match_score[players_data[0].num - 1])
		score_control.get_node('Player2Score2').text = str(match_score[players_data[1].num - 1])
		score_control.get_node('Player1Score').text = str(round_score[players_data[0].num - 1])
		score_control.get_node('Player2Score').text = str(round_score[players_data[1].num - 1])
		score_control.get_node('Player1').text = players_data[0].username
		score_control.get_node('Player2').text = players_data[1].username
		score_leaderboard.get_node('MatchScore').text = str(match_score[players_data[0].num - 1], ' : ', match_score[players_data[1].num - 1])
		score_leaderboard.get_node('RoundScore').text = str(round_score[players_data[0].num - 1], ' : ', round_score[players_data[1].num - 1])
	else:
		score_control.get_node('Player1Score2').text = str(match_score[players_data[1].num - 1])
		score_control.get_node('Player2Score2').text = str(match_score[players_data[0].num - 1])
		score_control.get_node('Player1Score').text = str(round_score[players_data[1].num - 1])
		score_control.get_node('Player2Score').text = str(round_score[players_data[0].num - 1])
		score_control.get_node('Player1').text = players_data[1].username
		score_control.get_node('Player2').text = players_data[0].username
		score_leaderboard.get_node('MatchScore').text = str(match_score[players_data[1].num - 1], ' : ', match_score[players_data[0].num - 1])
		score_leaderboard.get_node('RoundScore').text = str(round_score[players_data[1].num - 1], ' : ', round_score[players_data[0].num - 1])

func update_score_text_for_all():
	for i in Network.Players:
		if multiplayer.get_unique_id() == i:
			update_score_text()
		else:
			update_score_text.rpc_id(i)

func check_round_win(p, match_id):
	var match_data = Network.Matches[match_id]
	var round_score = match_data.round_score
	return round_score[p] >= 2
	# if round_score[p] >= 20 and round_score[get_opponent_index(p)] >= 20:
	# 	if round_score[p] >= 29 and round_score[get_opponent_index(p)] >= 29:
	# 		return round_score[p] >= 30
	# 	else: return round_score[p] - round_score[get_opponent_index(p)] >= 2
	# else: return round_score[p] >= 21

func check_match_win(p, match_id):
	var match_data = Network.Matches[match_id]
	var match_score = match_data.match_score
	return match_score[p] >= 2

func score_point_effect(p, player_num):
	if player_num == 2:
		p = get_opponent_index(p)
	var score_control = UI.get_node('GameUI/ScoreControl')
	var score_label = score_control.get_node('Player' + str(p + 1) + 'Score')
	var score_effect = score_label.duplicate()
	var label_settings = score_label.label_settings.duplicate()
	label_settings.font_color = '#ffffff80'
	label_settings.outline_color = '#00000080'
	score_effect.label_settings = label_settings
	score_effect.position.y += score_effect.size.y / 2
	score_effect.text = '1'
	score_control.add_child(score_effect)
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(score_effect, 'position', score_label.position, 0.5)
	await get_tree().create_timer(0.5).timeout
	score_effect.queue_free()

@rpc('any_peer')
func finish_match(winner_index, match_id):
	var match_data = Network.Matches[match_id]
	match_data.status = Network.match_status_type.PAUSED
	Network.remove_ball(match_id)
	var players_data = get_match_players_data(match_id)
	
	for i in players_data:
		var player_id = players_data[i].id
		var score_index = get_player_num(player_id) - 1
		var result_text = WIN_TEXT if winner_index == score_index else LOSE_TEXT
		var score_text = get_full_score_str(get_player_num(player_id), match_id)
		if player_id == 1:
			UI.show_match_result(result_text, score_text)
		else:
			if current_game_type != game_type.SINGLEPLAYER:
				UI.show_match_result.rpc_id(player_id, result_text, score_text)

# @rpc('any_peer')
# func push_round_score():
# 	Network.Leaderboard[][].push_back()

@rpc('any_peer', 'call_local')
func grant_point(p, match_id):
	var match_data = Network.Matches[match_id]
	var round_score = match_data.round_score
	var player_id = multiplayer.get_unique_id()
	var player_match_id = get_player_match_id(player_id)

	round_score[p] += 1
	
	if check_round_win(p, match_id):
		var match_score = match_data.match_score
		match_score[p] += 1
		# match_data.round_history.push_back(match_data.round_score)
		# push_round_score()
		var id1 = Network.find_player_by_match_id_with_num(match_id, 1).id
		var id2 = get_opponent_id(id1)
		var reverse_round_score = match_data.round_score.duplicate()
		reverse_round_score.reverse()
		Network.Leaderboard[id1][id2].push_back(match_data.round_score)
		Network.Leaderboard[id2][id1].push_back(reverse_round_score)
		UI.update_leaderboard_match_data()
		match_data.round_score = [ 0, 0 ]
		if check_match_win(p, match_id):
			if player_id == 1:
				finish_match(p, match_id)
			else:
				finish_match.rpc_id(1, p, match_id)
	
	if match_id == player_match_id:
		var player_num = get_player_num(player_id)
		score_point_effect(p, player_num)
		update_score_text(match_id, player_num)

@rpc('any_peer')
func reset_player_positions(match_id):
	if current_game_type == game_type.SINGLEPLAYER:
		for player in get_tree().get_nodes_in_group('Player'):
			player.reset_position()
		for bot in get_tree().get_nodes_in_group('Bot'):
			bot.reset_position()
	elif current_game_type == game_type.MULTIPLAYER:
		# print('RESETING PLAYER POSITIONS:')
		for id in Network.Players:
			var player_data = Network.Players[id]
			# print('reseting step 1 for id ', id)
			if not player_data.has('match_id') or player_data.match_id != match_id: continue
			# print('reseting step 2 for id ', id)
			if not Level.get_node('Players').has_node(str(id)): continue
			# print('reseting step 3 for id ', id)
			if player_data.is_bot or id == 1:
				Level.get_node('Players/' + str(id)).reset_position()
			else:
				Level.get_node('Players/' + str(id)).reset_position.rpc_id(id)

# func reset_score(match_id):
# 	score = [ 0, 0 ]

@rpc('any_peer')
func set_match_sync(player_id):
	Network.Players[player_id].match_sync = true

@rpc('any_peer')
func match_sync(): # balls_amount):
	print(multiplayer.get_unique_id(), ' sync start')
	while not check_match_ready(): # balls_amount):
		await get_tree().create_timer(0.1).timeout
	print(multiplayer.get_unique_id(), ' sync end')
	var id = multiplayer.get_unique_id()
	set_match_sync.rpc_id(1, id)

func check_match_ready(): # balls_amount):
	for i in Network.Players:
		var player_data = Network.Players[i]
		if not player_data.has('match_ready'):
			return false
	# if Network.Balls.size() != balls_amount:
	# 	return false
	return true

func check_match_sync():
	for i in Network.Players:
		var player_data = Network.Players[i]
		if not player_data.has('match_sync'):
			return false
	return true

func start_game():
	Network.server_state = Network.server_state_type.MATCH
	var match_amount = ceil(Network.Players.size() / 2)
	for match_id in match_amount:
		Network.Matches[match_id] = {
			match_score = [ 0, 0 ],
			round_score = [ 0, 0 ],
			status = Network.match_status_type.IN_PROGRESS,
		}

	if current_game_type == game_type.MULTIPLAYER:
		var next_match_id = 0
		var next_player_num = 1
		var next_match = []

		# for match_id in match_amount:
		# 	Network.add_ball(match_id)

		for i in Network.Players:
			if next_match.size() >= 2:
				next_match_id += 1
				next_player_num = 1
				next_match.clear()
			next_match.push_back(i)
			var player_data = Network.Players[i]
			player_data.match_id = next_match_id
			player_data.num = next_player_num
			player_data.state = Network.player_state_type.PLAYER
			player_data.match_ready = true
			next_player_num += 1

			Network.Leaderboard[i] = {}
			for i2 in Network.Players:
				if i2 == i: continue
				Network.Leaderboard[i][i2] = []

			if i != 1:
				UI.set_loading_screen.rpc_id(i, true)
				match_sync.rpc_id(i) # , match_amount)
			else:
				UI.set_loading_screen(true)
		
		if next_match.size() == 1:
			var spare_id = next_match[0]
			var player_data = Network.Players[spare_id]
			player_data.match_id = 0
			player_data.erase('num')
			player_data.state = Network.player_state_type.SPECTATOR

		Network.Players[1].match_sync = true
		print('server sync start')
		while not check_match_sync():
			await get_tree().create_timer(0.1).timeout
		print('server sync end')
		
		for match_id in match_amount:
			Network.add_ball(match_id)

		for i in Network.Players:
			if i != 1:
				UI.set_loading_screen.rpc_id(i, false)
			else:
				UI.set_loading_screen(false)
			var player_data = Network.Players[i]
			player_data.erase('match_ready')
			player_data.erase('match_sync')
			if player_data.state == Network.player_state_type.PLAYER:
				Network.add_player(player_data.id, player_data.num)
			elif player_data.state == Network.player_state_type.SPECTATOR:
				Network.add_spectator(player_data.id)
		
		update_score_text_for_all()

	elif current_game_type == game_type.SINGLEPLAYER:
		Network.add_ball(0)
		for i in Network.Players:
			var player_data = Network.Players[i]
			
			player_data.match_id = 0
			# player_data.match_id = player_data.id - 1

			player_data.num = player_data.id
			player_data.state = Network.player_state_type.PLAYER
			
			Network.Leaderboard[i] = {}
			for i2 in Network.Players:
				if i2 == i: continue
				Network.Leaderboard[i][i2] = []

			# if not player_data.is_bot:
			# 	Network.add_spectator(player_data.id)
			
			if player_data.is_bot:
				Network.add_bot(player_data.username)
			else:
				Network.add_player(player_data.id, player_data.num)

		update_score_text()

	# for match_id in match_amount:
	# 	reset_score(match_id)

func _ready():
	debug = get_tree().get_root().get_node('Scene/DebugUI').visible
	for argument in OS.get_cmdline_args():
		if argument.contains('-debug'):
			get_tree().get_root().get_node('Scene/DebugUI').visible = true
			debug = true
	# start_game()
	get_viewport().focus_entered.connect(_on_window_focus_in)
	get_viewport().focus_exited.connect(_on_window_focus_out)

func _on_window_focus_in():
	window_focus = true
	window_focus_changed.emit(window_focus)
func _on_window_focus_out():
	window_focus = false
	window_focus_changed.emit(window_focus)



@onready var debug_ui = get_tree().get_root().get_node('Scene/DebugUI')
func print_debug_msg(msg):
	print(msg)
	var label = debug_ui.get_node('Label')
	label.text = label.text + '\n' + msg
func set_listen_port_bound_text(value):
	var label = debug_ui.get_node('ListenPortBound')
	label.text = value
func set_connection_status_text(value):
	var label = debug_ui.get_node('ConnectionStatus')
	label.text = value
