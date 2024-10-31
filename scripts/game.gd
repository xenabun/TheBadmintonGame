extends Node

var window_focus = true

var data = {}
var path = "res://BadmintonData.json"
func save_json_file():
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	file = null
func load_json_file():
	var file
	if FileAccess.file_exists(path):
		file = FileAccess.open(path, FileAccess.READ)
	else:
		file = FileAccess.open(path, FileAccess.WRITE_READ)
	var filetext = file.get_as_text()
	var res
	if filetext.length() > 0:
		var parsed_result = JSON.parse_string(filetext)
		if parsed_result is Dictionary:
			res = parsed_result
	if not res:
		var _data = { 'score_data': [] }
		file.store_string(JSON.stringify(_data))
		res = _data
	file.close()
	file = null
	return res

const WIN_TEXT = 'Победа!'
const LOSE_TEXT = 'Поражение'

var score = [ 0, 0 ]
#var winner = null
var game_in_progress = true
@onready var UI = get_tree().get_first_node_in_group('UI_root')
@onready var Level = get_tree().get_first_node_in_group('Level_root')
@onready var ball = Level.get_node('World/Ball')
@onready var ServerBrowser = get_tree().get_first_node_in_group('ServerBrowser_root')

var ball_ready = true:
	set(value):
		ball_ready = value
		#ball.visible = value
		if value == true and Game.game_in_progress:
			ball.ignored_area = null
			ball.velocity = Vector3.ZERO
			ball.position = Vector3(0, -2, 0)
			for player in get_tree().get_nodes_in_group('Player'):
				player.reset_position.emit()
@rpc('any_peer', 'call_local')
func set_ball_ready(value):
	ball_ready = value

@rpc("any_peer", 'call_local')
func throw_ball(peer_id, pos, dir):
	Game.ball_ready = false
	ball.position = pos
	#ball.set('direction', dir)
	#ball.set('power', PlayerVariables.MAX_POWER)
	#ball.set('launch_y', pos.y)
	#ball.set('launch_z', pos.z)
	#ball.set('last_interact', name)
	ball.direction = dir
	ball.power = PlayerVariables.MAX_POWER
	ball.launch_y = pos.y
	ball.launch_z = pos.z
	ball.last_interact = name
	ball.set_multiplayer_authority(peer_id)
@rpc('any_peer', 'call_local')
func bounce_ball(peer_id, x, dir, new_power, y, z, player_name, oarea):
	ball.velocity.x = x
	ball.direction = dir
	ball.power = new_power
	ball.launch_y = y
	ball.launch_z = z
	ball.last_interact = player_name
	ball.ignored_area = oarea
	ball.set_multiplayer_authority(peer_id)
#@rpc('any_peer', 'call_local')
func reset_ball():
	ball_ready = true
	ball.ignored_area = null
	ball.velocity = Vector3.ZERO
	ball.position = Vector3(0, -2, 0)

func get_opponent_peer_id(peer_id):
	var opponent_id = null
	for id in GameManager.Players:
		if id == peer_id: continue
		opponent_id = id
		break
	if !opponent_id:
		opponent_id = peer_id
	return opponent_id

var score_text_path = 'GameUI/ScoreControl/Score'
func get_score_str():
	return str(score[0], ' : ', score[1])
func update_score_text():
	if UI.has_node(score_text_path):
	#get_parent().has_node(score_text_path):
		var score_text = UI.get_node(score_text_path)
		score_text.text = get_score_str()
func i(p): return abs(p - 1)
func peer_id_to_score_index(id):
	return 0 if id == 1 else 1
func check_win(p):
	#return true
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
		#winner = p
		game_in_progress = false
		var game_result_ui = UI.get_node('GameResult')
		var score_index = peer_id_to_score_index(multiplayer.get_unique_id())
		var result_text = WIN_TEXT if p == score_index else LOSE_TEXT
		game_result_ui.get_node('Result').text = result_text
		game_result_ui.get_node('Score').text = get_score_str()
		game_result_ui.show()
		UI.get_node('GameUI').hide()
		reset_score()
		reset_ball()
		if multiplayer.is_server():
			ServerBrowser.stop_broadcast()
	update_score_text()
func reset_score():
	#winner = null
	score = [ 0, 0 ]
	update_score_text()

func start_game():
	reset_score()
	game_in_progress = true
func _ready():
	start_game()
	get_viewport().focus_entered.connect(_on_window_focus_in)
	get_viewport().focus_exited.connect(_on_window_focus_out)

func _on_window_focus_in():
	window_focus = true
func _on_window_focus_out():
	window_focus = false
