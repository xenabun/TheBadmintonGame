extends Node3D

@onready var player = get_node('Player')
@onready var bot = get_node('Bot')

func _ready():
	Game.update_score_text()
	player.update_camera_transform(1)

func _on_close_pressed():
	Game.game_in_progress = not Game.game_in_progress
	$Menu.visible = not Game.game_in_progress

func _on_back_pressed():
	$ConfirmationDialog.popup_centered()

func _on_confirmation_dialog_confirmed():
	Game.game_in_progress = true
	Game.reset_score()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_new_game_pressed():
	$GameResult.visible = false
	$GameResult/Control.visible = false
	$GameResult/UsernameInputBox.visible = false
	$StaminaBarControl.visible = true
	$ScoreControl.visible = true
	Game.reset_score()
	Game.game_in_progress = true
	player.position = Vector3(0, 1.172, 15)
	bot.position = Vector3(0, 1.172, -15)
	player.update_camera_transform(1)

func _on_rback_pressed():
	$GameResult.visible = false
	$StaminaBarControl.visible = true
	$ScoreControl.visible = true
	Game.reset_score()
	Game.game_in_progress = true
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_username_confirm_pressed():
	var username : String = $GameResult/UsernameInputBox/LineEdit.text
	if username.length() <= 0:
		$UsernameInputError.popup_centered()
		return
	$GameResult/UsernameInputBox/LineEdit.text = ""
	$GameResult/UsernameInputBox.visible = false
	var lresulttext = 'Победа!' if (Game.winner + 1) == 1 else 'Поражение'
	var lscoretext = Game.get_score_str()
	$GameResult/Control/Result.text = lresulttext
	$GameResult/Control/Score.text = lscoretext
	$GameResult/Control.visible = true
	$StaminaBarControl.visible = false
	$ScoreControl.visible = false
	Game.data['score_data'].append(username + " - " + lscoretext + " - " + lresulttext)
	Game.save_json_file()
