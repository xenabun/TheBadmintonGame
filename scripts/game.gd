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
@onready var ball = Level.get_node('World/Ball')

var debug = false

var window_focus = true
var score = [ 0, 0 ]
var game_in_progress = true

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

func peer_id_to_score_index(id):
	return 0 if get_player_num(id) == 1 else 1

func get_player_num(id):
	if Network.Players.has(id):
		var player_data = Network.Players[id]
		if player_data.has('num'):
			return player_data.num

func get_full_score_str():
	if get_player_num(multiplayer.get_unique_id()) == 1:
		return str(score[0], ' : ', score[1])
	else:
		return str(score[1], ' : ', score[0])

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
func update_score_text():
	var pdata = Network.Players[multiplayer.get_unique_id()]
	var match_id = pdata.match_id
	var players_data = get_match_players_data(match_id)
	var score_control = UI.get_node('GameUI/ScoreControl')
	
	if pdata.has('num') and pdata.num == 2:
		score_control.get_node('Player1Score').text = str(score[players_data[1].num - 1])
		score_control.get_node('Player2Score').text = str(score[players_data[0].num - 1])
		score_control.get_node('Player1').text = players_data[1].username
		score_control.get_node('Player2').text = players_data[0].username
	else:
		score_control.get_node('Player1Score').text = str(score[players_data[0].num - 1])
		score_control.get_node('Player2Score').text = str(score[players_data[1].num - 1])
		score_control.get_node('Player1').text = players_data[0].username
		score_control.get_node('Player2').text = players_data[1].username

func update_score_text_for_all():
	for i in Network.Players:
		if multiplayer.get_unique_id() == i:
			update_score_text()
		else:
			update_score_text.rpc_id(i)

func check_win(p):
	return score[p] >= 2
	# if score[p] >= 20 and score[get_opponent_index(p)] >= 20:
	# 	if score[p] >= 29 and score[get_opponent_index(p)] >= 29:
	# 		return score[p] >= 30
	# 	else: return score[p] - score[get_opponent_index(p)] >= 2
	# else: return score[p] >= 21

func score_point_effect(p):
	var player_num = get_player_num(multiplayer.get_unique_id())
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

@rpc('any_peer', 'call_local')
func grant_point(p):
	score[p] += 1
	score_point_effect(p)
	update_score_text()
	if check_win(p):
		game_in_progress = false
		var game_result_ui = UI.get_node('GameResult')
		var score_index = peer_id_to_score_index(multiplayer.get_unique_id())
		var result_text = WIN_TEXT if p == score_index else LOSE_TEXT
		game_result_ui.get_node('Result').text = result_text
		game_result_ui.get_node('Score').text = get_full_score_str()
		game_result_ui.show()
		UI.get_node('GameUI').hide()
		reset_score()
		ball.set_ball_ready()
		ball.reset_ball()
		if multiplayer.is_server():
			ServerBrowser.stop_broadcast()

func reset_score():
	score = [ 0, 0 ]

@rpc('any_peer')
func set_match_sync(player_id):
	Network.Players[player_id].match_sync = true

@rpc('any_peer')
func match_sync():
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
@rpc('any_peer')

func set_loading_screen(value):
	UI.get_node('Loading').visible = value

func start_game():
	game_in_progress = true
	Network.server_state = Network.server_state_type.MATCH

	if current_game_type == game_type.MULTIPLAYER:
		var next_match_id = 0
		var next_player_num = 1
		var next_match = []

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
			if i != 1:
				set_loading_screen.rpc_id(i, true)
				match_sync.rpc_id(i)
			else:
				set_loading_screen(true)
		
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
		
		for i in Network.Players:
			if i != 1:
				set_loading_screen.rpc_id(i, false)
			else:
				set_loading_screen(false)
			var player_data = Network.Players[i]
			player_data.erase('match_ready')
			player_data.erase('match_sync')
			if player_data.state == Network.player_state_type.PLAYER:
				Network.add_player(player_data.id, player_data.num)
			elif player_data.state == Network.player_state_type.SPECTATOR:
				Network.add_spectator(player_data.id)
		
		update_score_text_for_all()

	elif current_game_type == game_type.SINGLEPLAYER:
		for i in Network.Players:
			var player_data = Network.Players[i]
			player_data.match_id = 0
			player_data.num = player_data.id
			player_data.state = Network.player_state_type.PLAYER
			
			# if not player_data.is_bot:
			# 	Network.add_spectator.call_deferred(player_data.id)

			if player_data.is_bot:
				Network.add_bot(player_data.username)
			else:
				Network.add_player(player_data.id, player_data.num)

		update_score_text()

	reset_score()

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
