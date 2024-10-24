extends Node

var Players = {}

func print_debug_msg(msg):
	print(msg)
	var debug = get_tree().get_first_node_in_group('Debug_root')
	if debug:
		var label = debug.get_node('Label')
		label.text = label.text + '\n' + msg
