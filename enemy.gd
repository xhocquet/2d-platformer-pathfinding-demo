extends "res://player.gd"

enum AiState { STANDING, TRAVERSING_EDGE, FALLING, JUMPING }

@export var speed := 100.0

var _player: CharacterBody2D
var _ai_state: AiState = AiState.STANDING
var _path: Array[StringName] = []
var _edge_from: StringName = &""
var _edge_to: StringName = &""
var _current_node_id: StringName = &""  # node we've arrived at (for pathfinding)

func _get_move_speed() -> float:
	return speed

func _ready() -> void:
	_player = get_parent().get_node("Player") as CharacterBody2D
	_graph = (get_parent().get_node("SectionGraph") as Node2D).graph
	call_deferred("_initialize_ai_state")

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_process_ai(delta)

func _get_move_input() -> float:
	if _ai_state == AiState.TRAVERSING_EDGE and _edge_to != &"":
		var target_pos: Vector2 = _graph.get_section_position(_edge_to)
		var move: float = signf(target_pos.x - global_position.x)
		if Engine.get_process_frames() % 60 == 0:
			print("[Enemy] move_input: state=TRAVERSING_EDGE pos.x=", global_position.x, " target.x=", target_pos.x, " move=", move)
		return move
	return 0.0

func _get_jump_just_pressed() -> bool:
	return false

func _initialize_ai_state() -> void:
	var from_id: StringName = _graph.get_section_under_body(self)
	print("[Enemy] init_ai: from_id=", from_id)
	if from_id == &"":
		return
	_current_section_id = from_id
	_current_node_id = from_id
	_path = _calculate_path()
	print("[Enemy] init_ai: path size=", _path.size(), " path=", _path)
	if _path.size() >= 2:
		_ai_state = AiState.TRAVERSING_EDGE
		_edge_from = _path[0]
		_edge_to = _path[1]
		print("[Enemy] init_ai: TRAVERSING_EDGE edge ", _edge_from, " -> ", _edge_to)

func _calculate_path() -> Array[StringName]:
	var from_id: StringName = _current_node_id if _current_node_id != &"" else _graph.get_section_under_body(self)
	if from_id == &"":
		from_id = _current_section_id
	var to_id: StringName = _graph.get_section_under_body(_player)
	if to_id == &"":
		print("[Enemy] path: no to_id (player section empty)")
		return []
	var path: Array[StringName] = _graph.find_path(from_id, to_id)
	print("[Enemy] path: from=", from_id, " to=", to_id, " result size=", path.size())
	return path

func _process_ai(_delta: float) -> void:
	_update_current_section()
	match _ai_state:
		AiState.STANDING:
			_tick_standing()
		AiState.TRAVERSING_EDGE:
			_tick_traversing_edge()
		AiState.FALLING:
			_tick_falling()
		AiState.JUMPING:
			_tick_jumping()

func _update_current_section() -> void:
	if is_on_floor():
		_current_section_id = _graph.get_section_under_body(self)

func _tick_standing() -> void:
	_path = _calculate_path()
	if _path.size() >= 2:
		_edge_from = _path[0]
		_edge_to = _path[1]
		_ai_state = AiState.TRAVERSING_EDGE
		print("[Enemy] standing -> TRAVERSING_EDGE ", _edge_from, " -> ", _edge_to)

const ARRIVAL_DIST: float = 16.0

func _tick_traversing_edge() -> void:
	if _edge_to == &"":
		print("[Enemy] traversing_edge: empty _edge_to -> STANDING")
		_ai_state = AiState.STANDING
		_edge_from = &""
		return
	var target_pos: Vector2 = _graph.get_section_position(_edge_to)
	var arrived: bool = _current_section_id == _edge_to or global_position.distance_to(target_pos) <= ARRIVAL_DIST
	if arrived:
		print("[Enemy] traversing_edge: arrived at ", _edge_to, " -> STANDING")
		_current_node_id = _edge_to
		_ai_state = AiState.STANDING
		_edge_from = &""
		_edge_to = &""

func _tick_falling() -> void:
	pass

func _tick_jumping() -> void:
	pass
