extends Control

func _on_games_pressed():
	get_tree().change_scene_to_file("res://scenes/games.tscn")


func _on_play_pressed():
	get_tree().change_scene_to_file("res://scenes/game_field.tscn")


func _on_exit_pressed():
	get_tree().quit()


func _on_settings_pressed():
	get_tree().change_scene_to_file("res://scenes/settings.tscn")
