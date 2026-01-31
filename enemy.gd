extends "res://player.gd"

@export var speed := 140.0

var _player: Node2D

func _get_move_speed() -> float:
	return speed

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		_player = get_parent().get_node_or_null("Player") as Node2D

func _get_move_input() -> float:
	if _player == null:
		return 0.0
	return signf(_player.global_position.x - global_position.x)

func _get_jump_just_pressed() -> bool:
	return false
