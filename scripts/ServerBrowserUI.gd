extends Control

signal host_pressed

func _on_host_pressed():
	host_pressed.emit()
