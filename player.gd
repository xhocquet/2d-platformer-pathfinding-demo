extends CharacterBody2D

@export var move_speed: float = 280.0
@export var jump_height: float = 220.0
@export var jump_cooldown_time: float = 0.4

var _jump_cooldown: float = 0.0
var _graph: SectionGraph
var _current_section_id: StringName

func _ready() -> void:
	_graph = (get_parent().get_node("SectionGraph") as Node2D).graph

func _physics_process(delta: float) -> void:
	_update_closest_section()

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

func _update_closest_section() -> void:
	var canvas := get_viewport().get_canvas_transform()
	var player_screen: Vector2 = canvas * global_position
	var best_id: StringName = &""
	var best_dist: float = INF

	for sid in _graph.get_section_ids():
		var section_pos: Vector2 = _graph.get_section_position(sid)
		var section_screen: Vector2 = canvas * section_pos
		var d: float = player_screen.distance_to(section_screen)
		if d < best_dist:
			best_dist = d
			best_id = sid

	_current_section_id = best_id

func get_current_section_id() -> StringName:
	return _current_section_id
