extends CharacterBody3D

#@onready var Player = get_parent().get_node('Player')
var BASE_PLAYER_POS_Y = 4.824 / 2
@onready var Level = get_tree().get_first_node_in_group('Level_root')
@onready var FieldArea = Level.get_node('World/FieldArea') #get_parent().get_node('FieldArea')
@onready var FloorArea = Level.get_node('World/Floor/Area') #get_parent().get_node('Floor/Area')
@onready var Player1Area = Level.get_node('World/Player1Area') #get_parent().get_node('Player1Area')
@onready var Player2Area = Level.get_node('World/Player2Area') #get_parent().get_node('Player2Area')

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

#func _ready():
	#set_physics_process(multiplayer.is_server())

func _physics_process(_delta):
	#print(get_multiplayer_authority())
	#print(multiplayer.get_unique_id())
	
	if Game.ball_ready:
		for node in get_children():
			if node.name.contains('Debug'):
				node.position = Vector3(0, 0, 0)
	#print('ball authority: ', get_multiplayer_authority())
	
	if get_multiplayer_authority() != multiplayer.get_unique_id(): return
	if not Game.game_in_progress or Game.ball_ready: return
	#print(get_multiplayer_authority())
	
	## position reset when inactive
	#if Game.ball_ready:
	##Player.get('ball_ready'):
		#ignored_area = null
		#velocity = Vector3.ZERO
		#position = Vector3(0, -2, 0)
		#return
	
	# reset when leaves field area
	if not $Area.overlaps_area(FieldArea):
		#Player.set('ball_ready', true)
		#Game.ball_ready = true
		Game.set_ball_ready.rpc(true)
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
		#Player.set('ball_ready', true)
		#Game.ball_ready = true
		Game.set_ball_ready.rpc(true)
		return
	
	# racket interact
	var overlapped_areas = $Area.get_overlapping_areas()
	#print('ball touched: ', overlapped_areas)
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
		
		Game.bounce_ball.rpc(Game.get_opponent_peer_id(str(player_name).to_int()),
				velocity_x, dir, new_power, position.y, position.z, player_name, oarea)
		#velocity.x = x
		#direction = VectorMath.look_vector(oarea).z
		#power = new_power
		#launch_y = position.y
		#launch_z = position.z
		#last_interact = oarea.get_parent().name
		#ignored_area = oarea
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
	
	$Debug_LaunchHeight.global_position = Vector3(position.x, launch_y + get_launch_height(), launch_z)
	$Debug_MaxHeight.global_position = Vector3(position.x, get_max_height(), position.z)
	$Debug_Z.global_position = Vector3(position.x, 1, launch_z)
	$Debug_ZLand.global_position = Vector3(position.x, 1, get_land_z())
	
	#var debug = CSGSphere3D.new()
	#debug.scale = Vector3.ONE * 0.2
	#debug.position = Vector3(position.x, height, position.z)
	#get_parent().add_child(debug)
	#get_parent().get_node('CSGSphere3D').position.y = BASE_PLAYER_POS_Y
	#get_parent().get_node('CSGSphere3D').position.z = get_land_z()
