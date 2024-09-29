extends Control

@onready var container = $ScrollContainer/VBoxContainer

func _ready():
	if Game.data.score_data.size() > 0:
		$ListEmpty.visible = false
		for score_entry in Game.data.score_data:
			var label = Label.new()
			var labelsettings = LabelSettings.new()
			labelsettings.outline_color = Color.html("#000000")
			labelsettings.outline_size = 3
			label.label_settings = labelsettings
			label.text = str(score_entry)
			container.add_child(label)
	else:
		$ListEmpty.visible = true

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
