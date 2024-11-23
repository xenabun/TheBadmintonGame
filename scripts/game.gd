extends Node

var window_focus = true
var debug = false

enum game_type {
	NONE,
	SINGLEPLAYER,
	MULTIPLAYER
}
@export var current_game_type : game_type = game_type.NONE

const WIN_TEXT = 'Победа!'
const LOSE_TEXT = 'Поражение'

var score = [ 0, 0 ]
var game_in_progress = true
@onready var UI = get_tree().get_first_node_in_group('UI_root')
@onready var Level = get_tree().get_first_node_in_group('Level_root')
@onready var ball = Level.get_node('World/Ball')
@onready var ServerBrowser = get_tree().get_first_node_in_group('ServerBrowser_root')

func get_opponent_peer_id(peer_id):
	var opponent_id = null
	for id in GameManager.Players:
		if id == peer_id: continue
		opponent_id = id
		break
	if !opponent_id:
		opponent_id = peer_id
	return opponent_id

func get_score_str():
	if multiplayer.is_server():
		return str(score[0], ' : ', score[1])
	else:
		return str(score[1], ' : ', score[0])
func get_player_usernames():
	var my_peer = multiplayer.get_unique_id()
	var op_peer = get_opponent_peer_id(my_peer)
	var usernames = []
	var my_info = GameManager.Players.get(my_peer, {'username': ''})
	var op_info = GameManager.Players.get(op_peer, {'username': ''}) if op_peer != my_peer else {'username': ''}
	usernames.insert(0, my_info.username)
	usernames.insert(1, op_info.username)
	return usernames
@rpc("any_peer")
func update_score_text():
	var score_control = UI.get_node('GameUI/ScoreControl')
	var score_str = get_score_str()
	var usernames = get_player_usernames()
	score_control.get_node('Score').text = score_str
	score_control.get_node('Player1').text = usernames[0]
	score_control.get_node('Player2').text = usernames[1]
@rpc("any_peer", 'call_local')
func update_score_text_for_all():
	update_score_text()
func i(p): return abs(p - 1)
func peer_id_to_score_index(id):
	return 0 if id == 1 else 1
func check_win(p):
	if score[p] >= 20 and score[i(p)] >= 20:
		if score[p] >= 29 and score[i(p)] >= 29:
			if score[p] >= 30:
				return true
		else:
			if score[p] - score[i(p)] >= 2:
				return true
	else:
		if score[p] >= 21:
			return true
@rpc('any_peer', 'call_local')
func grant_point(p):
	score[p] += 1
	if check_win(p):
		game_in_progress = false
		var game_result_ui = UI.get_node('GameResult')
		var score_index = peer_id_to_score_index(multiplayer.get_unique_id())
		var result_text = WIN_TEXT if p == score_index else LOSE_TEXT
		game_result_ui.get_node('Result').text = result_text
		game_result_ui.get_node('Score').text = get_score_str()
		game_result_ui.show()
		UI.get_node('GameUI').hide()
		reset_score()
		ball.set_ball_ready()
		ball.reset_ball()
		if multiplayer.is_server():
			ServerBrowser.stop_broadcast()
	update_score_text()
func reset_score():
	score = [ 0, 0 ]
	update_score_text()

func start_game():
	reset_score()
	game_in_progress = true
func _ready():
	debug = get_tree().get_root().get_node('Scene/DebugUI').visible
	for argument in OS.get_cmdline_args():
		if argument.contains('-debug'):
			get_tree().get_root().get_node('Scene/DebugUI').visible = true
			debug = true
	start_game()
	get_viewport().focus_entered.connect(_on_window_focus_in)
	get_viewport().focus_exited.connect(_on_window_focus_out)

func _on_window_focus_in():
	window_focus = true
func _on_window_focus_out():
	window_focus = false
