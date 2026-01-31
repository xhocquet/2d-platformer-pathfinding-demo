extends "res://player.gd"

@export var speed := 100.0
@export var path_replan_interval := 0.2
@export var jump_trigger_distance := 80.0

var _player: CharacterBody2D
var _graph: SectionGraph
var _path: Array[StringName] = []
var _target_position: Vector2
var _replan_timer := 0.0
var _jump_this_frame := false

func _get_move_speed() -> float:
	return speed

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if _player == null:
		_player = get_parent().get_node_or_null("Player") as CharacterBody2D
	var graph_node: Node = get_parent().get_node_or_null("SectionGraph")
	if graph_node != null and graph_node.get("graph") != null:
		_graph = graph_node.graph

func _physics_process(delta: float) -> void:
	_jump_this_frame = false
	if _graph == null:
		var gn: Node = get_parent().get_node_or_null("SectionGraph")
		if gn != null and gn.get("graph") != null:
			_graph = gn.graph
	if _graph != null and _player != null:
		_update_path(delta)
		_update_target_and_jump()
	super._physics_process(delta)

func _update_path(delta: float) -> void:
	_replan_timer -= delta
	var my_section: StringName = _graph.get_section_under_body(self)
	var player_section: StringName = _graph.get_section_under_body(_player)
	if my_section == &"" or player_section == &"":
		return
	var goal_changed: bool = _path.size() > 0 and _path[_path.size() - 1] != player_section
	if _path.is_empty() or goal_changed or _replan_timer <= 0.0:
		_replan_timer = path_replan_interval
		var full: Array[StringName] = _graph.find_path(my_section, player_section)
		_path.clear()
		if full.size() > 1:
			for i in range(1, full.size()):
				_path.append(full[i])
	while _path.size() > 0 and _graph.get_section_under_body(self) == _path[0]:
		_path.remove_at(0)
	# Jump-point waypoints: we never "stand" in them (we're on Floor). Pop when close so path advances.
	if _path.size() > 0 and str(_path[0]).ends_with("_jump"):
		var jp_pos: Vector2 = _graph.get_section_position(_path[0])
		if absf(global_position.x - jp_pos.x) <= jump_trigger_distance:
			_path.remove_at(0)

func _update_target_and_jump() -> void:
	if _path.is_empty():
		_target_position = _player.global_position if _player != null else global_position
		return
	var next_section: StringName = _path[0]
	var my_section: StringName = _graph.get_section_under_body(self)
	if my_section == &"":
		_target_position = _player.global_position if _player != null else global_position
		return
	if _path.size() == 1:
		_target_position = _player.global_position
	else:
		_target_position = _graph.get_section_position(next_section)
	if not is_on_floor():
		return
	var edge_type: SectionGraph.EdgeType = _graph.get_edge_type(my_section, next_section)
	if edge_type == SectionGraph.EdgeType.JUMP:
		var ledge_pos: Vector2 = _graph.get_section_position(my_section)
		if absf(global_position.x - ledge_pos.x) <= jump_trigger_distance:
			_jump_this_frame = true
		return
	# Floor jump: next waypoint is a jump-point section (we're in Floor_L/Floor_R). Edge from that section to path[1] is JUMP.
	if _path.size() >= 2 and str(next_section).ends_with("_jump"):
		var jp_pos: Vector2 = _graph.get_section_position(next_section)
		if _graph.get_edge_type(next_section, _path[1]) == SectionGraph.EdgeType.JUMP and absf(global_position.x - jp_pos.x) <= jump_trigger_distance:
			_jump_this_frame = true

func _get_move_input() -> float:
	if _player == null:
		return 0.0
	return signf(_target_position.x - global_position.x)

func _get_jump_just_pressed() -> bool:
	return _jump_this_frame
