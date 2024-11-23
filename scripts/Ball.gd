extends CharacterBody3D

var BASE_PLAYER_POS_Y = 4.824 / 2
@onready var Level = get_tree().get_first_node_in_group('Level_root')
@onready var FieldArea = Level.get_node('World/FieldArea')
@onready var FloorArea = Level.get_node('World/Floor/Area')
@onready var Player1Area = Level.get_node('World/Player1Area')
@onready var Player2Area = Level.get_node('World/Player2Area')

var direction = 0.0
var power = 0.0
var launch_y = 0.0
var launch_z = 0.0
var ignored_area = null
var last_interact = null
func get_launch_height():
	var power_frac = ((power - PlayerVariables.BASE_POWER) /
			(PlayerVariables.MAX_POWER - PlayerVariables.BASE_POWER))
	var height = (BallVariables.BASE_Y + (BallVariables.MAX_Y -
			BallVariables.BASE_Y) * power_frac)
	return height
func get_max_height():
	return launch_y + get_launch_height()
func get_height(z):
	var lz = launch_z
	var y = get_launch_height()
	var my = get_max_height()
	var p = power
	return my - (4.0 * y * ((abs(lz - z) - (p / 2.0)) ** 2.0)) / (p ** 2.0)
func get_land_z():
	var lz = launch_z
	var y = get_launch_height()
	var my = get_max_height()
	var by = BASE_PLAYER_POS_Y
	var p = power
	var d = direction
	return (p / 2.0) * (1.0 + sqrt((my - by) / y)) * d + lz
func get_land_x():
	
	pass

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
func throw_ball(peer_id, pos, dir):
	if not peer_id or peer_id < 1 or Game.current_game_type == Game.game_type.SINGLEPLAYER:
		peer_id = 1
	ball_ready = false
	position = pos
	direction = dir
	power = PlayerVariables.MAX_POWER
	launch_y = pos.y
	launch_z = pos.z
	last_interact = name
	set_multiplayer_authority(peer_id)
@rpc('any_peer', 'call_local')
func bounce_ball(peer_id, x, dir, new_power, y, z, player_name, oarea):
	if not peer_id or peer_id < 1 or Game.current_game_type == Game.game_type.SINGLEPLAYER:
		peer_id = 1
	velocity.x = x
	direction = dir
	power = new_power
	launch_y = y
	launch_z = z
	last_interact = player_name
	ignored_area = oarea
	set_multiplayer_authority(peer_id)
func reset_ball():
	ignored_area = null
	velocity = Vector3.ZERO
	position = Vector3(0, -10, 30)

func _ready():
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
		
		var new_power = oarea.get_parent().get('throw_power')
		var power_frac = new_power / PlayerVariables.MAX_POWER
		
		var offset_x = position.x - oarea.global_position.x
		var area_velocity_x = oarea.get_parent().velocity.x
		var velocity_x = ((offset_x * 1.5) + (area_velocity_x * 0.25)) * (1 + power_frac * 0.5)
		var player_name = oarea.get_parent().name
		var dir = VectorMath.look_vector(oarea).z
		
		bounce_ball.rpc(Game.get_opponent_peer_id(str(player_name).to_int()),
				velocity_x, dir, new_power, position.y, position.z, player_name, oarea)
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
		$Debug_LaunchHeight.global_position = Vector3(position.x, launch_y + get_launch_height(), launch_z)
		$Debug_MaxHeight.global_position = Vector3(position.x, get_max_height(), position.z)
		$Debug_Z.global_position = Vector3(position.x, 1, launch_z)
		$Debug_ZLand.global_position = Vector3(position.x, 1, get_land_z())
