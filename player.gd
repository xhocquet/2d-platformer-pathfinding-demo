extends CharacterBody2D

@export var move_speed := 280.0
@export var jump_height := 320.0
@export var jump_cooldown_time := 0.4

var _jump_cooldown := 0.0

func _physics_process(delta: float) -> void:
	var g: float = ProjectSettings.get_setting("physics/2d/default_gravity")
	var jump_velocity: float = -sqrt(2.0 * jump_height * g)

	if _jump_cooldown > 0.0:
		_jump_cooldown -= delta

	var move: float = _get_move_input()
	velocity.x = move * _get_move_speed()
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y += g * delta

	if _get_jump_just_pressed() and is_on_floor() and _jump_cooldown <= 0.0:
		velocity.y = jump_velocity
		_jump_cooldown = jump_cooldown_time

	move_and_slide()

func _get_move_speed() -> float:
	return move_speed

func _get_move_input() -> float:
	return Input.get_axis(&"move_left", &"move_right")

func _get_jump_just_pressed() -> bool:
	return Input.is_action_just_pressed(&"jump")
