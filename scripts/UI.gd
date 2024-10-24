extends Control

@export var menu_camera_pivot : Node3D
@export var in_menu : bool = true :
	set(value):
		if value == false:
			get_node('ServerBrowser').hide()
			menu_camera_pivot.get_node('MenuCamera').set_current(false)
		in_menu = value

func _physics_process(_delta):
	if in_menu:
		menu_camera_pivot.rotation.y += 0.0005
