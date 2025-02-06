class_name UI_State

extends Node

var ui

func init(_ui):
	ui = _ui
	ui.get_node('MainMenu/Username').show()
	ui.get_node('MainMenu/Menu').hide()
	ui.get_node('MainMenu/Port').hide()
	ui.get_node('MainMenu').show()
	
	ui.get_node('CurrentUsername').hide()
	ui.get_node('ServerBrowser').hide()
	ui.get_node('GameUI').hide()
	ui.get_node('Menu').hide()
	ui.get_node('GameResult').hide()
	ui.get_node('GameControls').hide()
	ui.get_node('Connecting').hide()
	ui.get_node('Lobby').hide()

