extends "res://player.gd"

enum AiState { STANDING, TRAVERSING_EDGE, JUMP_SEQUENCE }
enum JumpPhase { LEAD_IN, JUMP_PRESS, ASCENT, AIR_CONTROL }

const ARRIVAL_DIST: float = 16.0
const LEAD_IN_DIST: float = 10.0  # must be this close to source node before initiating jump
const LARGE_JUMP_GAP_X: float = 40.0  # during ascent, steer toward target if horizontal gap exceeds this
@export var speed := 100.0

var _player: CharacterBody2D
var _ai_state: AiState = AiState.STANDING
var _source_node: StringName = &"" # source edge
var _dest_node: StringName = &"" # target edge
var _source_position: Vector2 = Vector2.ZERO
var _dest_position: Vector2 = Vector2.ZERO
var _current_node_id: StringName = &""  # node we've arrived at
var _path: Array[StringName] = [] # path from source to target edge
var _wants_jump_press: bool = false
var _jump_phase: JumpPhase = JumpPhase.JUMP_PRESS
var _jump_start_y: float = 0.0
var _jump_peak_y: float = 0.0
var _jump_back_out_dir: float = 0.0  # if inside ledge, move this way until peak (-1, 0, 1)
var _lead_in_target_x: float = 0.0  # takeoff edge x we walk toward during LEAD_IN

################################################################################
# Setup
################################################################################
func _ready() -> void:
	_player = get_parent().get_node("Player") as CharacterBody2D
	_graph = (get_parent().get_node("NaviGraph") as NaviGraph).graph
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
		_source_position = _graph.get_section_position(_source_node)
		_dest_position = _graph.get_section_position(_dest_node)

################################################################################
# Input
################################################################################
func _get_move_input() -> float:
	# Walking towards a node
	if _ai_state == AiState.TRAVERSING_EDGE and _has_dest_node():
		return signf(_dest_position.x - global_position.x)

	if _ai_state == AiState.JUMP_SEQUENCE:
		var x: float = _get_jump_sequence_move_input()
		print("jump move input: ", x, " jump_phase: ", _jump_phase)
		return x

	# Standing, pathless! Walk towards the player.
	if _ai_state == AiState.STANDING and _path.size() == 1:
		return signf(_player.global_position.x - global_position.x)

	return 0.0

func _get_jump_sequence_move_input() -> float:
	if _jump_phase == JumpPhase.LEAD_IN:
		return signf(_lead_in_target_x - global_position.x)

	if _jump_phase == JumpPhase.JUMP_PRESS:
		if absf(_dest_position.x - global_position.x) > LARGE_JUMP_GAP_X:
			return signf(_dest_position.x - global_position.x)
		return _jump_back_out_dir

	if _jump_phase == JumpPhase.ASCENT:
		var at_ledge_y: bool = global_position.y <= _dest_position.y
		if at_ledge_y and absf(_dest_position.x - global_position.x) > LARGE_JUMP_GAP_X:
			return signf(_dest_position.x - global_position.x)

		# Below ledge y: only allow back-out if it's not toward target (e.g. when inside ledge, back-out can point inward).
		if not at_ledge_y:
			var toward_target: float = signf(_dest_position.x - global_position.x)
			if toward_target != 0.0 and _jump_back_out_dir == toward_target:
				return 0.0
		return _jump_back_out_dir

	if _jump_phase == JumpPhase.AIR_CONTROL:
		# Always steer toward intended landing; don't chase player mid-air or we skip the platform.
		return signf(_dest_position.x - global_position.x)

	return 0.0

func _get_jump_just_pressed() -> bool:
	if _wants_jump_press:
		_wants_jump_press = false
		return true
	return false

func _get_move_speed() -> float:
	return speed

################################################################################
# Tick
################################################################################
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

	var arrived: bool = global_position.distance_to(_dest_position) <= ARRIVAL_DIST
	if is_on_floor() and _current_section_id == _dest_node:
		arrived = true
	if arrived:
		_current_node_id = _dest_node
		_stand_still()

func _tick_jump_sequence() -> void:
	match _jump_phase:
		JumpPhase.LEAD_IN:
			_tick_jump_lead_in()
		JumpPhase.JUMP_PRESS:
			_tick_jump_press()
		JumpPhase.ASCENT:
			_tick_jump_ascent()
		JumpPhase.AIR_CONTROL:
			_tick_jump_air_control()

func _tick_jump_lead_in() -> void:
	if absf(global_position.x - _lead_in_target_x) > LEAD_IN_DIST:
		return

	# Trigger jump press
	_jump_phase = JumpPhase.JUMP_PRESS
	_wants_jump_press = true
	_jump_start_y = global_position.y
	_jump_peak_y = global_position.y
	var ledge: Vector2 = _get_ledge_x_bounds(_dest_node)
	_compute_jump_back_out_dir(ledge.x, ledge.y)

func _tick_jump_press() -> void:
	if not is_on_floor():
		_jump_phase = JumpPhase.ASCENT
		_jump_peak_y = global_position.y

func _tick_jump_ascent() -> void:
	if is_on_floor():
		_current_node_id = _current_section_id
		_stand_still()
		return

	if global_position.y <= _dest_position.y:
		_jump_phase = JumpPhase.AIR_CONTROL

func _tick_jump_air_control() -> void:
	if is_on_floor():
		_current_node_id = _current_section_id
		_stand_still()

################################################################################
# Private helpers
################################################################################
func _update_current_section() -> void:
	if _ai_state == AiState.TRAVERSING_EDGE and _source_node != &"" and _has_dest_node():
		_current_section_id = _dest_node if global_position.distance_to(_dest_position) <= global_position.distance_to(_source_position) else _source_node
	elif is_on_floor():
		_current_section_id = _graph.get_section_under_body(self)

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

func _start_jump_sequence(edge_from: StringName, edge_to: StringName) -> void:
	_source_node = edge_from
	_dest_node = edge_to
	_source_position = _graph.get_section_position(edge_from)
	_dest_position = _graph.get_section_position(edge_to)
	_ai_state = AiState.JUMP_SEQUENCE
	_jump_phase = JumpPhase.LEAD_IN
	_jump_start_y = global_position.y
	_jump_peak_y = global_position.y
	_wants_jump_press = false
	_jump_back_out_dir = 0.0
	# Lead-in walks toward the takeoff edge (our platform's edge toward the dest), not the section position
	_lead_in_target_x = _get_lead_in_target_x(edge_from, edge_to)

# Lead-in walks toward the takeoff edge (our platform's edge toward the dest), not the section position.
func _get_lead_in_target_x(edge_from: StringName, edge_to: StringName) -> float:
	var ledge: Vector2 = _get_ledge_x_bounds(edge_to)
	var ledge_center_x: float = (ledge.x + ledge.y) * 0.5
	var approach_from_left: bool = _source_position.x < ledge_center_x
	var platform_other_x: float = _get_walk_neighbor_section_x(edge_from)
	if approach_from_left:
		return maxf(_source_position.x, platform_other_x)
	return minf(_source_position.x, platform_other_x)

func _get_walk_neighbor_section_x(edge: StringName) -> float:
	var pos: Vector2 = _source_position if edge == _source_node else _graph.get_section_position(edge)
	for nb in _graph.get_neighbors(edge):
		if nb.type == SectionGraph.EdgeType.WALK:
			return _graph.get_section_position(nb.to).x
	return pos.x

func _get_ledge_x_bounds(dest_node: StringName) -> Vector2:
	var pos_to: Vector2 = _dest_position if dest_node == _dest_node else _graph.get_section_position(dest_node)
	var ledge_min_x: float = pos_to.x
	var ledge_max_x: float = pos_to.x
	for nb in _graph.get_neighbors(dest_node):
		if nb.type == SectionGraph.EdgeType.WALK:
			var pos_nb: Vector2 = _graph.get_section_position(nb.to)
			ledge_min_x = minf(pos_to.x, pos_nb.x)
			ledge_max_x = maxf(pos_to.x, pos_nb.x)
			break
	return Vector2(ledge_min_x, ledge_max_x)

func _compute_jump_back_out_dir(ledge_min_x: float, ledge_max_x: float) -> void:
	var ledge_center_x: float = (ledge_min_x + ledge_max_x) * 0.5
	var approach_from_left: bool = _source_position.x < ledge_center_x
	var edge_x: float = ledge_min_x - 20.0 if approach_from_left else ledge_max_x + 20.0
	var inside: bool = (approach_from_left and global_position.x >= edge_x) or (not approach_from_left and global_position.x <= edge_x)
	_jump_back_out_dir = -1.0 if (inside and approach_from_left) else (1.0 if (inside and not approach_from_left) else 0.0)

func _stand_still() -> void:
	_ai_state = AiState.STANDING
	_source_node = &""
	_dest_node = &""
	_source_position = Vector2.ZERO
	_dest_position = Vector2.ZERO
	_jump_back_out_dir = 0.0

func _walk_from_edge_to_edge(edge_from: StringName, edge_to: StringName) -> void:
	_source_node = edge_from
	_dest_node = edge_to
	_source_position = _graph.get_section_position(edge_from)
	_dest_position = _graph.get_section_position(edge_to)
	_ai_state = AiState.TRAVERSING_EDGE

func _has_dest_node() -> bool:
	return _dest_node != &""
