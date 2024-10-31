extends Button

signal join_server(ip)
signal restart_timer()
@export var ip : String
@export var port : int

@onready var timer = $Timer

func _ready():
	timer.start()
	restart_timer.connect(func():
		timer.start())
	
func _on_timer_timeout():
	queue_free()

func _on_connect_button_pressed():
	if port == 0: return
	join_server.emit(ip)
