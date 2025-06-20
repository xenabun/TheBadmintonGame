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

var debug : bool = false
var window_focus : bool = true
var players_finished : Dictionary = {}
var players_ready : Dictionary = {}
var is_match_finish_loop_running : bool = false

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

@rpc('any_peer', 'call_local')
func set_players_can_throw(match_id, player_num):
	# print('got set_players_can_throw_call by ', multiplayer.get_remote_sender_id())
	var id = multiplayer.get_unique_id()
	
	if not Network.Players.has(id): return
	var player_data = Network.Players[id]
	
	if (not player_data.has('match_id') or
			not player_data.has('num') or
			not Level.get_node('Players').has_node(str(id))): return

	if player_data.match_id == match_id and player_data.num == player_num:
		var player = Level.get_node('Players/' + str(id))
		player.set_can_throw(true)

	# for i in Network.Players:
	# 	var player_data = Network.Players[i]
	# 	if (player_data.has('match_id') and player_data.has('num')
	# 			and player_data.match_id == match_id and player_data.num == player_num
	# 			and Level.get_node('Players').has_node(str(player_data.id))):
	# 		var player = Level.get_node('Players/' + str(player_data.id))
	# 		if player_data.is_bot:
	# 			player.set_can_throw(true)
	# 		else:
	# 			player.set_can_throw.rpc_id(player_data.id, true)

func get_opponent_id(id):
	if not Network.Players.has(id): return

	var my_player_data = Network.Players[id]
	if not my_player_data.has('match_id'): return

	var match_id = my_player_data.match_id
	var opponent_id = null

	for player_id in Network.Players:
		if player_id == id: continue
		var player_data = Network.Players[player_id]
		if player_data.state != Network.player_state_type.PLAYER: continue
		if not player_data.has('match_id'): continue
		if player_data.match_id != match_id: continue
		opponent_id = player_id
		break
	
	if not opponent_id:
		opponent_id = id
	print('getting opponent in match:', match_id, '; opponent: ', opponent_id, '; of player: ', id)
	return opponent_id

func get_player_side(player_num: int):
	return 1 if player_num == 1 else -1

func get_throw_side(match_id: int, player_num: int, can_throw: bool):
	var player_index = player_num - 1
	if not can_throw:
		player_index = get_opponent_index(player_index)
	var player_round_score = get_player_round_score(match_id, player_index)
	var side = 'Even' if player_round_score % 2 == 0 else 'Odd'
	return side

func get_opponent_index(index):
	return abs(index - 1)

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

func get_match_spectators_data(match_id):
	var ids = {}

	for i in Network.Players:
		var pdata = Network.Players[i]
		if (pdata.has('match_id') and pdata.match_id == match_id
				and pdata.state == Network.player_state_type.SPECTATOR):
			ids[i] = pdata

	return ids

@rpc('any_peer', 'call_local')
func update_score_text(match_id = null, player_num = null):
	var player_id = multiplayer.get_unique_id()
	var player_data = Network.Players[player_id]
	if match_id == null and player_data.has('match_id'):
		match_id = player_data.match_id
	if player_num == null and player_data.has('num'):
		player_num = player_data.num
	# print('update_score_text(): match id: ', match_id, '; has match: ', Network.Matches.has(match_id), '; player data: ', player_data)
	if match_id == null or not Network.Matches.has(match_id): return

	var player_state = player_data.state
	var match_data = Network.Matches[match_id]
	var round_score = match_data.round_score
	var match_score = match_data.match_score
	var players_data = get_match_players_data(match_id)
	var game_ui = UI.get_node('GameUI')
	var score_control = game_ui.get_node('ScoreControl')
	var match_switch = game_ui.get_node('MatchSwitch')
	var score_leaderboard = UI.get_node('Leaderboard/Panel/Score')
	
	var set_score_texts = func(i1, i2):
		score_control.get_node('Player1Score2').text = str(match_score[players_data[i1].num - 1])
		score_control.get_node('Player2Score2').text = str(match_score[players_data[i2].num - 1])
		score_control.get_node('Player1Score').text = str(round_score[players_data[i1].num - 1])
		score_control.get_node('Player2Score').text = str(round_score[players_data[i2].num - 1])
		score_control.get_node('Player1').text = players_data[i1].username
		score_control.get_node('Player2').text = players_data[i2].username
		score_leaderboard.get_node('MatchScore').text = str(match_score[players_data[i1].num - 1], ' : ', match_score[players_data[i2].num - 1])
		score_leaderboard.get_node('RoundScore').text = str(round_score[players_data[i1].num - 1], ' : ', round_score[players_data[i2].num - 1])
	
	match_switch.get_node('Panel/Players').text = str(players_data[0].username, ' против ', players_data[1].username)
	var i = 0 if player_num == 1 or player_state == Network.player_state_type.SPECTATOR else 1
	set_score_texts.call(i, abs(i - 1))

func update_score_text_for_all():
	update_score_text.rpc()

func check_round_win(p, match_id):
	var match_data = Network.Matches[match_id]
	var round_score = match_data.round_score
	if debug:
		return round_score[p] >= 1
	else:
		if round_score[p] >= 20 and round_score[get_opponent_index(p)] >= 20:
			if round_score[p] >= 29 and round_score[get_opponent_index(p)] >= 29:
				return round_score[p] >= 30
			else: return round_score[p] - round_score[get_opponent_index(p)] >= 2
		else: return round_score[p] >= 21

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

func is_everyone_finished():
	for id in Network.Leaderboard:
		var player_data = Network.Players[id]
		if not players_finished.has(id) and player_data.state != Network.player_state_type.SPECTATOR:
			print('player ', str(id), ' has not finished playing yet!')
			return false
	return true

func can_continue():
	for id1 in Network.Leaderboard:
		for id2 in Network.Leaderboard[id1]:
			var score1 = Network.Leaderboard[id1][id2]
			var score2 = Network.Leaderboard[id2][id1]
			if score1.is_empty() and score2.is_empty():
				return true
	return false

func is_everyone_ready():
	for i in Network.Players:
		if not players_ready.has(i):
			return false
	return true

@rpc('any_peer', 'call_local')
func set_player_ready(i):
	players_ready[i] = true

@rpc('any_peer', 'call_local')
func finish_match(winner_index, match_id):
	if not multiplayer.is_server(): return
	var match_data = Network.Matches[match_id]
	if match_data.status == Network.match_status_type.FINISHED: return
	
	print('FINISHING MATCH!!!')
	match_data.status = Network.match_status_type.FINISHED
	var players_data = get_match_players_data(match_id)
	var spectators_data = get_match_spectators_data(match_id)

	for i in players_data:
		var player_id = players_data[i].id
		players_finished[player_id] = true
		var score_index = get_player_num(player_id) - 1
		var result_text = WIN_TEXT if winner_index == score_index else LOSE_TEXT
		if not players_data[i].is_bot:
			UI.show_match_result.rpc_id(player_id, result_text)
	
	for i in spectators_data:
		if get_player_match_id(i) != match_id: continue
		UI.show_match_result.rpc_id(i, '')		

	print('is everyone finished? ', is_everyone_finished(), '; can continue? ', can_continue())
	if not is_match_finish_loop_running:
		while not is_everyone_finished():
			await get_tree().create_timer(1.0).timeout
		if can_continue():
			print('CAN CONTINUE GAME, PREPARING...')
			for i in Network.Players:
				var pdata = Network.Players[i]
				pdata.erase('match_id')
			for i in Network.Balls:
				Network.remove_ball(i)
			Network.Balls = {}
			for player in get_tree().get_nodes_in_group('Player'):
				var multiplayer_authority = player.get_multiplayer_authority()
				if multiplayer_authority != multiplayer.get_unique_id():
					player.reset_authority.rpc_id(multiplayer_authority)
				# player.queue_free()
			for spectator in get_tree().get_nodes_in_group('Spectator'):
				var multiplayer_authority = spectator.get_multiplayer_authority()
				if multiplayer_authority != multiplayer.get_unique_id():
					spectator.reset_authority.rpc_id(multiplayer_authority)
				# spectator.queue_free()
			players_ready = {}
			UI.show_ready_check.rpc()
			print('IS EVERYONE READY???')
			while not is_everyone_ready():
				await get_tree().create_timer(1.0).timeout
			print('EVERYONE IS READY!!!')
			print('STARTING NEW GAME IN 3... 2... 1...')
			UI.set_loading_screen.rpc(true)
			await get_tree().create_timer(3.0).timeout
			UI.close_match_result.rpc()
			start_game()
		else:
			UI.show_match_result.rpc('Итоговая турнирная таблица', true)
			pass

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
		var player_data1 = Network.find_player_by_match_id_with_num(match_id, 1)
		var id1 = player_data1.id
		var id2 = player_data1.opponent_id # get_opponent_id(id1)
		print('applying leaderboard score for ids: ', str(id1), '; ', str(id2))
		var reverse_round_score = match_data.round_score.duplicate()
		reverse_round_score.reverse()
		Network.Leaderboard[id1][id2].push_back(match_data.round_score)
		Network.Leaderboard[id2][id1].push_back(reverse_round_score)
		UI.update_leaderboard_match_data()
		match_data.round_score = [ 0, 0 ]
		if check_match_win(p, match_id):
			finish_match.rpc_id(1, p, match_id)
	
	if match_id == player_match_id:
		var player_num = get_player_num(player_id)
		score_point_effect(p, player_num)
		update_score_text(match_id, player_num)

@rpc('any_peer', 'call_local')
func reset_player_positions(match_id):
	# print('got reset_player_positions call by ', multiplayer.get_remote_sender_id())
	if current_game_type == game_type.SINGLEPLAYER:
		for player in get_tree().get_nodes_in_group('Player'):
			player.reset_position()
		for bot in get_tree().get_nodes_in_group('Bot'):
			bot.reset_position()
	elif current_game_type == game_type.MULTIPLAYER:
		var id = multiplayer.get_unique_id()
		var player_data = Network.Players[id]
		if (player_data.has('match_id') and
				player_data.match_id == match_id and
				Level.get_node('Players').has_node(str(id))):
			Level.get_node('Players/' + str(id)).reset_position()

		# for id in Network.Players:
		# 	var player_data = Network.Players[id]
		# 	if not player_data.has('match_id') or player_data.match_id != match_id: continue
		# 	if not Level.get_node('Players').has_node(str(id)): continue
		# 	if player_data.is_bot:
		# 		Level.get_node('Players/' + str(id)).reset_position()
		# 	else:
		# 		Level.get_node('Players/' + str(id)).reset_position.rpc_id(id)

@rpc('any_peer')
func set_match_sync(player_id):
	Network.Players[player_id].match_sync = true

@rpc('any_peer', 'call_local')
func match_sync():
	if multiplayer.is_server(): return
	print(multiplayer.get_unique_id(), ' sync start')
	while not check_match_ready():
		await get_tree().create_timer(0.1).timeout
	print(multiplayer.get_unique_id(), ' sync end')
	var id = multiplayer.get_unique_id()
	set_match_sync.rpc_id(1, id)

func check_match_ready():
	for i in Network.Players:
		var player_data = Network.Players[i]
		if not player_data.has('match_ready'):
			return false
	return true

func check_match_sync():
	for i in Network.Players:
		var player_data = Network.Players[i]
		if not player_data.has('match_sync'):
			return false
	return true

func start_game():
	players_finished = {}
	is_match_finish_loop_running = false
	Network.server_state = Network.server_state_type.MATCH

	for i in Network.Players:
		Network._remove_player(i)

	if Network.Leaderboard.is_empty():
		for i in Network.Players:
			Network.Leaderboard[i] = {}
			for i2 in Network.Players:
				if i2 == i: continue
				Network.Leaderboard[i][i2] = []
		print('LEADERBOARD INIT CALL')
		UI.leaderboard_init.rpc()

	var busy_players : Dictionary = {}
	for id1 in Network.Leaderboard:
		for id2 in Network.Leaderboard[id1]:
			var score1 = Network.Leaderboard[id1][id2]
			var score2 = Network.Leaderboard[id2][id1]
			if score1.is_empty() and score2.is_empty() and not busy_players.has(id1) and not busy_players.has(id2):
				busy_players[id1] = id2
				busy_players[id2] = id1

	var match_amount = int(ceil(busy_players.size() / 2.0))
	var next_match_id = Network.Matches.size()
	var first_match_id = next_match_id
	var last_match_id = first_match_id + match_amount
	print('first match id: ', first_match_id, '; last match id: ', last_match_id, '; match amount: ', match_amount)

	for match_id in range(first_match_id, last_match_id):
		Network.Matches[match_id] = {
			match_score = [ 0, 0 ],
			round_score = [ 0, 0 ],
			status = Network.match_status_type.IN_PROGRESS,
		}

	if current_game_type == game_type.MULTIPLAYER:
		var players_applied = {}

		for id1 in busy_players:
			var id2 = busy_players[id1]
			var player_data1 = Network.Players[id1]
			if not players_applied.has(id1) and not players_applied.has(id2):
				players_applied[id1] = true
				players_applied[id2] = true
				var player_data2 = Network.Players[id2]
				player_data1.match_id = next_match_id
				player_data2.match_id = next_match_id
				player_data1.opponent_id = id2
				player_data2.opponent_id = id1
				player_data1.num = 1
				player_data2.num = 2
				next_match_id += 1
			player_data1.state = Network.player_state_type.PLAYER

		for i in Network.Players:
			var player_data = Network.Players[i]
			if not busy_players.has(i):
				player_data.match_id = first_match_id
				player_data.erase('num')
				player_data.state = Network.player_state_type.SPECTATOR
			player_data.match_ready = true
		match_sync.rpc()
		UI.set_loading_screen.rpc(true)

		Network.Players[1].match_sync = true
		print('server sync start')
		while not check_match_sync():
			await get_tree().create_timer(0.1).timeout
		print('server sync end')
		
		for match_id in range(first_match_id, last_match_id):
			Network.add_ball(match_id)

		UI.set_loading_screen.rpc(false)
		for i in Network.Players:
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
			player_data.opponent_id = 1 if player_data.is_bot else 2
			player_data.num = player_data.id
			player_data.state = Network.player_state_type.PLAYER
			
			if player_data.is_bot:
				Network.add_bot(player_data.username)
			else:
				Network.add_player(player_data.id, player_data.num)

		update_score_text()

func _ready():
	debug = get_tree().get_root().get_node('Scene/DebugUI').visible
	for argument in OS.get_cmdline_args():
		if argument.contains('-debug'):
			get_tree().get_root().get_node('Scene/DebugUI').visible = true
			debug = true
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
