class_name State extends Node

signal state_changed(old_state, new_state)

var state = null

func _init(initial_state = false):
    state = initial_state

func get_state():
    return state

func set_state(new_state, args = {}):
    var old_state = state
    state = new_state
    state_changed.emit(old_state, state, args)
