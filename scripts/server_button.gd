extends Button

signal join_server(ip)
@export var ip : String

func _on_connect_button_pressed():
	join_server.emit(ip)
