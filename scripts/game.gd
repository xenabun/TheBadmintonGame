extends Node

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

var score = [ 0, 0 ]
var winner = null
var game_in_progress = true
var score_text_path = 'Node3D/ScoreControl/Score'
func get_score_str():
	return str(score[0], ' : ', score[1])
func update_score_text():
	if get_parent().has_node(score_text_path):
		var score_text = get_parent().get_node(score_text_path)
		score_text.text = get_score_str()
func i(p): return abs(p - 1)
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
func grant_point(p):
	score[p] += 1
	if check_win(p):
		winner = p
		game_in_progress = false
		var gresult = get_parent().get_node('Node3D/GameResult')
		var usernameinputbox = gresult.get_node('UsernameInputBox')
		usernameinputbox.visible = true
		gresult.visible = true
	update_score_text()
func reset_score():
	winner = null
	score = [ 0, 0 ]
	update_score_text()

func _ready():
	data = load_json_file()
