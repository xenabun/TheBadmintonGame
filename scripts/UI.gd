extends Control

@export var menu_camera_pivot : Node
@export var player_camera : Node
@export var in_menu : bool = true :
	set(value):
		get_node('ServerBrowser').visible = value
		get_node('GameUI').visible = not value
		menu_camera_pivot.get_node('MenuCamera').set_current(value)
		in_menu = value
		if value == true:
			player_camera.set_current(false)

func _on_back_pressed():
	multiplayer.multiplayer_peer.disconnect_peer(1)
	in_menu = true

func _physics_process(_delta):
	if in_menu and Game.window_focus:
		menu_camera_pivot.rotation.y += 0.0005
