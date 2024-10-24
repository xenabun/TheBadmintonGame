extends MultiplayerSynchronizer

@export var direction := Vector3()

func _ready():
	set_process(get_multiplayer_authority() == multiplayer.get_unique_id())

func _process(_delta):
	var input_dir = Input.get_vector("left", "right", "up", "down")
	direction = (get_parent().transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
