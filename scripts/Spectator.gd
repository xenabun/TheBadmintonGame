extends CharacterBody3D

const CAMERA_HORIZONTAL_SPEED = 0.15
const CAMERA_VERTICAL_SPEED = 0.1
const ZOOM_STEP = 10

@export var player_id : int

@onready var UI = get_tree().get_root().get_node('Scene/UI')
@onready var camera = get_node('HorizontalAxis/VerticalAxis/Camera')
@onready var h_axis = get_node('HorizontalAxis')
@onready var v_axis = get_node('HorizontalAxis/VerticalAxis')

var mouse_velocity
var zoom_delta = 0
var zoom_tween

func _ready():
	player_id = get_multiplayer_authority()
	set_physics_process(multiplayer.get_unique_id() == player_id)
	if multiplayer.get_unique_id() != player_id: return
	camera.make_current()
	var GameUI = UI.get_node('GameUI')
	GameUI.get_node('StaminaBarControl/StaminaBar').hide()
	GameUI.show()
	if Game.window_focus:
		Input.set_mouse_mode(Input.MouseMode.MOUSE_MODE_CAPTURED)
	Game.window_focus_changed.connect(func(new_focus):
		var mouse_mode = Input.MouseMode.MOUSE_MODE_CAPTURED if new_focus else Input.MouseMode.MOUSE_MODE_VISIBLE
		Input.set_mouse_mode(mouse_mode)
		)
	UI.state.in_game_menu.state_changed.connect(func(_old_state, new_state, _args):
		var mouse_mode = Input.MouseMode.MOUSE_MODE_VISIBLE if new_state else Input.MouseMode.MOUSE_MODE_CAPTURED
		Input.set_mouse_mode(mouse_mode)
		)

func _enter_tree():
	set_multiplayer_authority(str(name).to_int())

func _input(event):
	if get_multiplayer_authority() != multiplayer.get_unique_id(): return

	if event.is_action_pressed('ui_cancel'):
		var current_state = UI.state.in_game_menu.get_state()
		var new_state = not current_state
		UI.state.in_game_menu.set_state(new_state)
	
	if event is InputEventMouseMotion:
		var normal_window_size = get_viewport().get_visible_rect().size
		var window_size = get_window().size
		var relative_velocity = event.get_relative()
		mouse_velocity = relative_velocity * (Vector2(window_size) / normal_window_size)
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_delta = -1
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_delta = 1

func _physics_process(delta):
	if not UI.state.in_game_menu.get_state() and Game.window_focus:
		if mouse_velocity:
			var x_vel = mouse_velocity.x * delta * CAMERA_HORIZONTAL_SPEED
			var y_vel = mouse_velocity.y * delta * CAMERA_VERTICAL_SPEED

			var h_axis_rot = h_axis.rotation.y
			var v_axis_rot = v_axis.rotation.x
			h_axis.rotation.y = h_axis_rot - x_vel
			v_axis.rotation.x = clamp(v_axis_rot - y_vel, deg_to_rad(-60), deg_to_rad(5))
			mouse_velocity = null
		if zoom_delta != 0:
			var z_pos = camera.position.z
			zoom_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			zoom_tween.tween_property(camera, 'position:z', clamp(z_pos + zoom_delta * ZOOM_STEP, 10, 50), 0.2)
			zoom_tween.play()
			zoom_delta = 0

	# var mouse_vel = InputEventMouseMotion.get_screen_velocity()
	# print(mouse_vel)


	# Add the gravity.
	# if not is_on_floor():
	# 	velocity.y -= gravity * delta

	# # Handle jump.
	# if Input.is_action_just_pressed("ui_accept") and is_on_floor():
	# 	velocity.y = JUMP_VELOCITY

	# # Get the input direction and handle the movement/deceleration.
	# # As good practice, you should replace UI actions with custom gameplay actions.
	# var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	# var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	# if direction:
	# 	velocity.x = direction.x * SPEED
	# 	velocity.z = direction.z * SPEED
	# else:
	# 	velocity.x = move_toward(velocity.x, 0, SPEED)
	# 	velocity.z = move_toward(velocity.z, 0, SPEED)

	# move_and_slide()
	pass
