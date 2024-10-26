extends Button

signal join_server(ip)
@export var ip : String
@export var port : int

func _on_connect_button_pressed():
	if port == 0: return
	join_server.emit(ip)
