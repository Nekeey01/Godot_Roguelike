extends Area2D

#const World = preload("res://scene/World.tscn")

var SPEED = 250.0

enum STATES { IDLE, FOLLOW }
var _state = null

var path = []
var target_point_world = Vector2()
var target_position = Vector2()

var velocity = Vector2()

var _player
func _ready():
	_change_state(STATES.IDLE)
	
	 

func _change_state(new_state):
	if new_state == STATES.FOLLOW:
		
		path = get_parent().get_node('TileMap').find_path(position, target_position)
		
		if not path or len(path) == 1:
			_change_state(STATES.IDLE)
			return
		# Индекс 0 - это начальная ячейка
# в этом примере мы не хотим, чтобы персонаж возвращался к нему
		target_point_world = path[1]
	_state = new_state

var new_pos_player = 0
var old_pos_player = 0#get_parent().player.position

func _process(delta):
	check_player()
	if not _state == STATES.FOLLOW:
		return
	var arrived_to_next_point = move_to(target_point_world)
	if arrived_to_next_point:
		path.remove(0)
		if len(path) == 0:
			_change_state(STATES.IDLE)
			return
		target_point_world = path[0]
		
	

func move_to(world_position):
	var ARRIVE_DISTANCE = 5.0
#
	var desired_velocity = (world_position - position).normalized() * SPEED
	var steering = desired_velocity - velocity
	velocity += steering
	position += velocity * get_process_delta_time()
	rotation = velocity.angle()

	return position.distance_to(world_position) < ARRIVE_DISTANCE


func check_player():
	
	_player = get_parent().player
	new_pos_player = _player.global_position
	if global_position.distance_to(new_pos_player) > 15*32:
		_change_state(STATES.FOLLOW)
		
		return
	if new_pos_player != old_pos_player:# and _state!=STATES.FOLLOW:
		target_position = new_pos_player
		_change_state(STATES.FOLLOW)
	old_pos_player = new_pos_player
	
		
func _input(event):
	if event.is_action_pressed('click'):
		if Input.is_key_pressed(KEY_SHIFT):
			global_position = get_global_mouse_position()
		else:
			target_position = get_global_mouse_position()
		_change_state(STATES.FOLLOW)



var hp = 2
var damage = 1
signal hit(value)

signal die_enemy
func _on_enemy_body_entered(body):
	if body.is_in_group('player_group'):
		emit_signal("hit", damage)
		hp -= _player.damage
		if hp<=0:
			emit_signal("die_enemy")
			$CollisionShape2D.set_deferred("disabled", true)
			queue_free()
		
	
	print("hit")

