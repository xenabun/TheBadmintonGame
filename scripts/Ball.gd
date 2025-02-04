extends CharacterBody3D

const BASE_PLAYER_POS_Y = 4.824 / 2

@export var Level : Node
@export var FieldArea : Node
@export var FloorArea : Node
@export var Player1Area : Node
@export var Player2Area : Node

var direction : float = 0.0
var power : float = 0.0
var launch_pos : Vector3 = Vector3.ZERO
var ignored_area
var last_interact : String = ''

func get_launch_height():
	return (BallVariables.BASE_Y + (BallVariables.MAX_Y -
			BallVariables.BASE_Y) * ((power - PlayerVariables.BASE_POWER) /
			(PlayerVariables.MAX_POWER - PlayerVariables.BASE_POWER)))
func get_max_height():
	return launch_pos.y + get_launch_height()
func get_height(z):
	return (get_max_height() - (4.0 * get_launch_height() *
			((abs(launch_pos.z - z) - (power / 2.0)) ** 2.0)) /
			(power ** 2.0))
func get_land_z():
	return ((power / 2.0) * (1.0 + sqrt((get_max_height() -
			BASE_PLAYER_POS_Y) / get_launch_height())) *
			direction + launch_pos.z)
func get_land_x():
	return (launch_pos.x + velocity.x * abs(launch_pos.z - get_land_z()) / 
			(power * (BallVariables.BASE_SPEED_MULT + 
			BallVariables.MAX_SPEED_MULT) / 2))

var ball_ready = true:
	set(value):
		ball_ready = value
		if value == true and Game.game_in_progress:
			reset_ball()
			for player in get_tree().get_nodes_in_group('Player'):
				player.reset_position.emit()
			for bot in get_tree().get_nodes_in_group('Bot'):
				bot._reset_position()
@rpc('any_peer', 'call_local')
func set_ball_ready(value = true):
	ball_ready = value
@rpc("any_peer", 'call_local')
func throw_ball(peer_id :int, player_name :String, new_position :Vector3,
		new_direction :float, new_velocity_x :float, aim_dir_y :float):
	if not peer_id or peer_id < 1 or Game.current_game_type == Game.game_type.SINGLEPLAYER:
		peer_id = 1
	ball_ready = false
	position = new_position
	velocity.x = new_velocity_x
	launch_pos = new_position
	direction = new_direction
	power = (PlayerVariables.BASE_POWER + (PlayerVariables.MAX_POWER -
			PlayerVariables.BASE_POWER) * aim_dir_y)
	last_interact = player_name
	get_node('Trail').emitting = true
	set_multiplayer_authority(peer_id)
	set_physics_process(true)
@rpc('any_peer', 'call_local')
func bounce_ball(peer_id :int, player_name :String, new_velocity_x :float, new_direction :float,
		new_power :float, new_launch_pos :Vector3, oarea):
	if not peer_id or peer_id < 1 or Game.current_game_type == Game.game_type.SINGLEPLAYER:
		peer_id = 1
	velocity.x = new_velocity_x
	launch_pos = new_launch_pos
	direction = new_direction
	power = new_power
	last_interact = player_name
	ignored_area = oarea
	set_multiplayer_authority(peer_id)
func reset_ball():
	set_physics_process(false)
	get_node('Trail').emitting = false
	get_node('Trail').restart()
	ignored_area = null
	velocity = Vector3.ZERO
	position = Vector3(0, -10, 30)

func _ready():
	set_physics_process(false)
	$Debug_MaxHeight.visible = Game.debug
	$Debug_Z.visible = Game.debug
	$Debug_ZLand.visible = Game.debug
	$Debug_LaunchHeight.visible = Game.debug

func _physics_process(_delta):
	# reset debug
	if Game.debug and ball_ready:
		for node in get_children():
			if node.name.contains('Debug'):
				node.position = Vector3.ZERO
	
	if get_multiplayer_authority() != multiplayer.get_unique_id(): return
	if not Game.game_in_progress or ball_ready: return
	
	# reset when leaves field area
	if not $Area.overlaps_area(FieldArea):
		set_ball_ready.rpc()
		return
	
	# floor interact
	if $Area.overlaps_area(FloorArea):
		if $Area.overlaps_area(Player1Area):
			Game.grant_point.rpc(1)
		elif $Area.overlaps_area(Player2Area):
			Game.grant_point.rpc(0)
		else:
			if last_interact == '1':
				Game.grant_point.rpc(1)
			else:
				Game.grant_point.rpc(0)
		set_ball_ready.rpc()
		return
	
	# racket interact
	var overlapped_areas = $Area.get_overlapping_areas()
	for oarea in overlapped_areas:
		if oarea.name != 'RacketArea': continue
		if oarea == ignored_area: continue
		
		var player = oarea.get_parent()
		var player_name = player.name
		var new_power = player.throw_power
		var new_direction = VectorMath.look_vector(oarea).z
		var aim_x = sin((player.aim_x * PI) / 2)
		var new_velocity_x = aim_x * 30 * -new_direction
		
		bounce_ball.rpc(Game.get_opponent_peer_id(str(player_name).to_int()),
				player_name, new_velocity_x, new_direction, new_power,
				position, oarea)
		break
	
	# shadow
	if $RayCast3D.is_colliding():
		var floor_point = $RayCast3D.get_collision_point()
		var floor_normal = $RayCast3D.get_collision_normal()
		if floor_point + floor_normal / 2 != floor_point + floor_normal:
			$Shadow.look_at_from_position(
					floor_point + floor_normal / 2,
					floor_point + floor_normal,
					Vector3(0, 0, -1)
			)
		$Shadow.scale = Vector3.ONE * (0.5 + (position.y / 6))
		$Shadow.visible = true
	else:
		$Shadow.visible = false
	
	# position
	move_and_slide()
	var height = get_height(position.z)
	var height_frac = (BallVariables.BASE_SPEED_MULT +
			(BallVariables.MAX_SPEED_MULT - BallVariables.BASE_SPEED_MULT) *
			abs( 1 - (height - BASE_PLAYER_POS_Y) / get_max_height() ))
	position.y = height
	velocity.z = power * direction * height_frac
	
	if Game.debug:
		$Debug_LaunchHeight.global_position = launch_pos + Vector3(0, get_launch_height(), 0)
		$Debug_MaxHeight.global_position = Vector3(position.x, get_max_height(), position.z)
		$Debug_Z.global_position = Vector3(launch_pos.x, 1, launch_pos.z)
		$Debug_ZLand.global_position = Vector3(get_land_x(), 1, get_land_z())
