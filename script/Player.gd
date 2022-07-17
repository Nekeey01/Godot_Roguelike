extends KinematicBody2D

var speed = 250
var velocity = Vector2()
var hp = 10
var damage = 2


#func get_input():
#	# Detect up/down/left/right keystate and only move when pressed.
#	if Input.is_action_pressed('ui_right'):
#		velocity.x += 32
#	if Input.is_action_pressed('ui_left'):
#		velocity.x -= 32
#	if Input.is_action_pressed('ui_down'):
#		velocity.y += 32
#	if Input.is_action_pressed('ui_up'):
#		velocity.y -= 32
##	velocity = velocity.normalized()

	
func _physics_process(_delta):
	var x_input = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	var y_input = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	move_and_slide(Vector2(x_input, y_input)*1500)
	

	pass

