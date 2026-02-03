extends "res://player.gd"

enum AiState { STANDING, TRAVERSING_EDGE }

const ARRIVAL_DIST: float = 16.0

@export var speed := 100.0

var _player: CharacterBody2D
var _ai_state: AiState = AiState.STANDING
var _edge_from: StringName = &"" # source edge
var _edge_to: StringName = &"" # target edge
var _current_node_id: StringName = &""  # node we've arrived at
var _path: Array[StringName] = [] # path from source to target edge

func _ready() -> void:
	_player = get_parent().get_node("Player") as CharacterBody2D
	_graph = (get_parent().get_node("SectionGraph") as Node2D).graph
	call_deferred("_initialize_ai_state")

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_process_ai(delta)

func _get_move_speed() -> float:
	return speed

func _get_move_input() -> float:
	if _ai_state == AiState.TRAVERSING_EDGE and _edge_to != &"":
		var target_pos: Vector2 = _graph.get_section_position(_edge_to)
		return signf(target_pos.x - global_position.x)
	if _ai_state == AiState.STANDING and _path.size() == 1:
		return signf(_player.global_position.x - global_position.x)
	return 0.0

func _get_jump_just_pressed() -> bool:
	return false

func _initialize_ai_state() -> void:
	var from_id: StringName = _graph.get_section_under_body(self)
	if from_id == &"":
		return
	_current_section_id = from_id
	_current_node_id = from_id
	_path = _calculate_path()
	if _path.size() >= 2:
		_ai_state = AiState.TRAVERSING_EDGE
		_edge_from = _path[0]
		_edge_to = _path[1]

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

func _update_current_section() -> void:
	if _ai_state == AiState.TRAVERSING_EDGE and _edge_from != &"" and _edge_to != &"":
		var pos_from: Vector2 = _graph.get_section_position(_edge_from)
		var pos_to: Vector2 = _graph.get_section_position(_edge_to)
		_current_section_id = _edge_to if global_position.distance_to(pos_to) <= global_position.distance_to(pos_from) else _edge_from
	elif is_on_floor():
		_current_section_id = _graph.get_section_under_body(self)

func _tick_standing() -> void:
	_path = _calculate_path()

	if _path.size() >= 2:
		_walk_from_edge_to_edge(_path[0], _path[1])

func _tick_traversing_edge() -> void:
	if _edge_to == &"":
		_stand_still()
		return

	var target_pos: Vector2 = _graph.get_section_position(_edge_to)
	var arrived: bool = global_position.distance_to(target_pos) <= ARRIVAL_DIST
	if is_on_floor():
		var section_under: StringName = _graph.get_section_under_body(self)
		if section_under == _edge_to:
			arrived = true
	if arrived:
		_current_node_id = _edge_to
		_stand_still()

func _stand_still() -> void:
	_ai_state = AiState.STANDING
	_edge_from = &""
	_edge_to = &""

func _walk_from_edge_to_edge(edge_from: StringName, edge_to: StringName) -> void:
	_edge_from = edge_from
	_edge_to = edge_to
	_ai_state = AiState.TRAVERSING_EDGE
