extends Node

var Players = {}

@onready var debug_ui = get_tree().get_root().get_node('Scene/DebugUI')
func print_debug_msg(msg):
	print(msg)
	var label = debug_ui.get_node('Label')
	label.text = label.text + '\n' + msg
func set_listen_port_bound_text(value):
	var label = debug_ui.get_node('ListenPortBound')
	label.text = value
func set_connection_status_text(value):
	var label = debug_ui.get_node('ConnectionStatus')
	label.text = value
