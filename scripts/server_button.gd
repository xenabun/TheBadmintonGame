extends Button

signal join_server(ip)
signal restart_timer()
@export var ip : String
@export var port : int
@export var player_count : int
@export var max_player_count : int

@onready var timer = $Timer

func _ready():
	timer.start()
	restart_timer.connect(func():
		timer.start())
	
func _on_timer_timeout():
	queue_free()

func _on_connect_button_pressed():
	if port == 0: return
	if player_count >= max_player_count:
		OS.alert('Сервер полон')
		return
	join_server.emit(ip)
