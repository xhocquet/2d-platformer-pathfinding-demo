extends "res://player.gd"

enum AiState { STANDING, TRAVERSING_EDGE, JUMP_SEQUENCE }
enum JumpPhase { LEAD_IN, JUMP_PRESS, ASCENT, AIR_CONTROL }

const ARRIVAL_DIST: float = 16.0
const LEAD_IN_DIST: float = 10.0  # must be this close to source node before initiating jump
const JUMP_AIR_CONTROL_HEIGHT_RATIO: float = 0.7

@export var speed := 100.0

var _player: CharacterBody2D
var _ai_state: AiState = AiState.STANDING
var _source_node: StringName = &"" # source edge
var _dest_node: StringName = &"" # target edge
var _current_node_id: StringName = &""  # node we've arrived at
var _path: Array[StringName] = [] # path from source to target edge
var _wants_jump_press: bool = false
var _jump_phase: JumpPhase = JumpPhase.JUMP_PRESS
var _jump_start_y: float = 0.0
var _jump_peak_y: float = 0.0
var _jump_back_out_dir: float = 0.0  # if inside ledge, move this way until peak (-1, 0, 1)
var _lead_in_target_x: float = 0.0  # takeoff edge x we walk toward during LEAD_IN

func _ready() -> void:
	_player = get_parent().get_node("Player") as CharacterBody2D
	_graph = (get_parent().get_node("SectionGraph") as Node2D).graph
	call_deferred("_initialize_ai_state")

func _initialize_ai_state() -> void:
	var from_id: StringName = _graph.get_section_under_body(self)
	if from_id == &"":
		return
	_current_section_id = from_id
	_current_node_id = from_id
	_path = _calculate_path()
	if _path.size() >= 2:
		_ai_state = AiState.TRAVERSING_EDGE
		_source_node = _path[0]
		_dest_node = _path[1]

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_process_ai(delta)

func _process_ai(_delta: float) -> void:
	_update_current_section()
	match _ai_state:
		AiState.STANDING:
			_tick_standing()
		AiState.TRAVERSING_EDGE:
			_tick_traversing_edge()
		AiState.JUMP_SEQUENCE:
			_tick_jump_sequence()

func _get_move_input() -> float:
	# Walking towards a node
	if _ai_state == AiState.TRAVERSING_EDGE and _has_dest_node():
		var target_pos: Vector2 = _graph.get_section_position(_dest_node)
		return signf(target_pos.x - global_position.x)

	if _ai_state == AiState.JUMP_SEQUENCE:
		return _get_jump_sequence_move_input()

	# Standing, pathless! Walk towards the player.
	if _ai_state == AiState.STANDING and _path.size() == 1:
		return signf(_player.global_position.x - global_position.x)

	return 0.0

func _get_jump_sequence_move_input() -> float:
	if _jump_phase == JumpPhase.LEAD_IN:
		return signf(_lead_in_target_x - global_position.x)

	if _jump_back_out_dir != 0.0 and (_jump_phase == JumpPhase.JUMP_PRESS or _jump_phase == JumpPhase.ASCENT):
		return _jump_back_out_dir

	if _jump_phase == JumpPhase.AIR_CONTROL:
		return signf(_player.global_position.x - global_position.x)

	return 0.0

func _get_jump_just_pressed() -> bool:
	if _wants_jump_press:
		_wants_jump_press = false
		return true
	return false

func _calculate_path() -> Array[StringName]:
	var from_id: StringName = _current_node_id if _current_node_id != &"" else _graph.get_section_under_body(self)
	if from_id == &"":
		from_id = _current_section_id
	var to_id: StringName = _graph.get_section_under_body(_player)
	if to_id == &"":
		print("[Enemy] path: no to_id (player section empty)")
		return []
	var path: Array[StringName] = _graph.find_path(from_id, to_id)
	return path

func _update_current_section() -> void:
	if _ai_state == AiState.TRAVERSING_EDGE and _source_node != &"" and _has_dest_node():
		var pos_from: Vector2 = _graph.get_section_position(_source_node)
		var pos_to: Vector2 = _graph.get_section_position(_dest_node)
		_current_section_id = _dest_node if global_position.distance_to(pos_to) <= global_position.distance_to(pos_from) else _source_node
	elif is_on_floor():
		_current_section_id = _graph.get_section_under_body(self)

func _tick_standing() -> void:
	_path = _calculate_path()

	if _path.size() >= 2:
		var edge_type: SectionGraph.EdgeType = _graph.get_edge_type(_path[0], _path[1])
		if edge_type == SectionGraph.EdgeType.JUMP:
			_start_jump_sequence(_path[0], _path[1])
		else:
			_walk_from_edge_to_edge(_path[0], _path[1])

func _tick_traversing_edge() -> void:
	if _dest_node == &"":
		_stand_still()
		return

	var target_pos: Vector2 = _graph.get_section_position(_dest_node)
	var arrived: bool = global_position.distance_to(target_pos) <= ARRIVAL_DIST
	if is_on_floor() and _current_section_id == _dest_node:
		arrived = true
	if arrived:
		_current_node_id = _dest_node
		_stand_still()

func _stand_still() -> void:
	_ai_state = AiState.STANDING
	_source_node = &""
	_dest_node = &""
	_jump_back_out_dir = 0.0

func _walk_from_edge_to_edge(edge_from: StringName, edge_to: StringName) -> void:
	_source_node = edge_from
	_dest_node = edge_to
	_ai_state = AiState.TRAVERSING_EDGE

func _start_jump_sequence(edge_from: StringName, edge_to: StringName) -> void:
	_source_node = edge_from
	_dest_node = edge_to
	_ai_state = AiState.JUMP_SEQUENCE
	_jump_phase = JumpPhase.LEAD_IN
	_jump_start_y = global_position.y
	_jump_peak_y = global_position.y
	_wants_jump_press = false
	_jump_back_out_dir = 0.0
	# Lead-in walks toward the takeoff edge (our platform’s edge toward the dest), not the section position
	var pos_to: Vector2 = _graph.get_section_position(edge_to)
	var ledge_min_x: float = pos_to.x
	var ledge_max_x: float = pos_to.x
	for nb in _graph.get_neighbors(edge_to):
		if nb.type == SectionGraph.EdgeType.WALK:
			var pos_nb: Vector2 = _graph.get_section_position(nb.to)
			ledge_min_x = minf(pos_to.x, pos_nb.x)
			ledge_max_x = maxf(pos_to.x, pos_nb.x)
			break
	var pos_from: Vector2 = _graph.get_section_position(edge_from)
	var ledge_center_x: float = (ledge_min_x + ledge_max_x) * 0.5
	var approach_from_left: bool = pos_from.x < ledge_center_x
	var platform_other_x: float = pos_from.x
	for nb in _graph.get_neighbors(edge_from):
		if nb.type == SectionGraph.EdgeType.WALK:
			platform_other_x = _graph.get_section_position(nb.to).x
			break
	_lead_in_target_x = maxf(pos_from.x, platform_other_x) if approach_from_left else minf(pos_from.x, platform_other_x)

func _tick_jump_sequence() -> void:
	if _jump_phase == JumpPhase.LEAD_IN:
		if absf(global_position.x - _lead_in_target_x) <= LEAD_IN_DIST:
			_jump_phase = JumpPhase.JUMP_PRESS
			_wants_jump_press = true
			_jump_start_y = global_position.y
			_jump_peak_y = global_position.y
			var pos_to: Vector2 = _graph.get_section_position(_dest_node)
			var ledge_min_x: float = pos_to.x
			var ledge_max_x: float = pos_to.x
			for nb in _graph.get_neighbors(_dest_node):
				if nb.type == SectionGraph.EdgeType.WALK:
					var pos_nb: Vector2 = _graph.get_section_position(nb.to)
					ledge_min_x = minf(pos_to.x, pos_nb.x)
					ledge_max_x = maxf(pos_to.x, pos_nb.x)
					break
			var pos_from: Vector2 = _graph.get_section_position(_source_node)
			var ledge_center_x: float = (ledge_min_x + ledge_max_x) * 0.5
			var approach_from_left: bool = pos_from.x < ledge_center_x
			var edge_x: float = ledge_min_x if approach_from_left else ledge_max_x
			var inside: bool = (approach_from_left and global_position.x >= edge_x) or (not approach_from_left and global_position.x <= edge_x)
			_jump_back_out_dir = -1.0 if (inside and approach_from_left) else (1.0 if (inside and not approach_from_left) else 0.0)
	elif _jump_phase == JumpPhase.JUMP_PRESS:
		if not is_on_floor():
			_jump_phase = JumpPhase.ASCENT
			_jump_peak_y = global_position.y
	elif _jump_phase == JumpPhase.ASCENT:
		if is_on_floor():
			_current_node_id = _current_section_id
			_stand_still()
			return
		_jump_peak_y = minf(_jump_peak_y, global_position.y)
		var height_total: float = _jump_start_y - _jump_peak_y
		var height_now: float = _jump_start_y - global_position.y
		if height_total > 0.0 and height_now >= JUMP_AIR_CONTROL_HEIGHT_RATIO * height_total:
			_jump_phase = JumpPhase.AIR_CONTROL
	elif _jump_phase == JumpPhase.AIR_CONTROL:
		if is_on_floor():
			_current_node_id = _current_section_id
			_stand_still()


func _get_move_speed() -> float:
	return speed

func _has_dest_node() -> bool:
	return _dest_node != &""
