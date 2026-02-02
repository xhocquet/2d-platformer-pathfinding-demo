extends "res://player.gd"

@export var speed := 100.0

var _player: CharacterBody2D

func _get_move_speed() -> float:
	return speed

func _ready() -> void:
	_player = get_parent().get_node("Player") as CharacterBody2D
	_graph = (get_parent().get_node("SectionGraph") as Node2D).graph

func _physics_process(delta: float) -> void:
	super._physics_process(delta)

func _get_move_input() -> float:
	return signf(_player.global_position.x - global_position.x)

func _get_jump_just_pressed() -> bool:
	return false
