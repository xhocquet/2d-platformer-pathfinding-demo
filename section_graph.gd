class_name SectionGraph
extends RefCounted

# Edge type: walk (same level / drop off), fall, jump
enum EdgeType { WALK, FALL, JUMP }

const PLATFORM_NAMES: Array[StringName] = [&"Floor", &"Platform1", &"Platform2", &"Platform3"]
# Built in set_root after positions exist; used by debug draw and A*
var SECTION_IDS: Array[StringName] = []

# from_id, to_id, type
var _edges: Array[Dictionary] = []
var _positions: Dictionary = {}  # section_id -> Vector2 (filled when root set)
var _node_to_sections: Dictionary = {}  # Node -> [section_id_left, section_id_right]
var _root: Node2D

func _init() -> void:
	pass  # edges built in set_root after we have positions

# Two nodes per platform (L/R edges). Walk same platform; fall to floor edges; jump between adjacent ledges.
func _build_edges() -> void:
	_edges.clear()
	var FL := &"Floor_L"
	var FR := &"Floor_R"
	var P1L := &"Platform1_L"
	var P1R := &"Platform1_R"
	var P2L := &"Platform2_L"
	var P2R := &"Platform2_R"
	var P3L := &"Platform3_L"
	var P3R := &"Platform3_R"
	# Walk: same platform L <-> R
	_add_edge(FL, FR, EdgeType.WALK)
	_add_edge(FR, FL, EdgeType.WALK)
	_add_edge(P1L, P1R, EdgeType.WALK)
	_add_edge(P1R, P1L, EdgeType.WALK)
	_add_edge(P2L, P2R, EdgeType.WALK)
	_add_edge(P2R, P2L, EdgeType.WALK)
	_add_edge(P3L, P3R, EdgeType.WALK)
	_add_edge(P3R, P3L, EdgeType.WALK)
	# Fall: each platform edge -> both floor edges
	for pid in [P1L, P1R, P2L, P2R, P3L, P3R]:
		_add_edge(pid, FL, EdgeType.FALL)
		_add_edge(pid, FR, EdgeType.FALL)
	# Jump: floor to platform; adjacent platform ledges (all ledges jumpable)
	_add_edge(FL, P1L, EdgeType.JUMP)
	_add_edge(FL, P1R, EdgeType.JUMP)
	_add_edge(FR, P3L, EdgeType.JUMP)
	_add_edge(FR, P3R, EdgeType.JUMP)
	_add_edge(P1R, P2L, EdgeType.JUMP)
	_add_edge(P2L, P1R, EdgeType.JUMP)
	_add_edge(P2R, P3L, EdgeType.JUMP)
	_add_edge(P3L, P2R, EdgeType.JUMP)

func _add_edge(from: StringName, to: StringName, type: EdgeType) -> void:
	_edges.append({ from = from, to = to, type = type })

func set_root(root: Node2D) -> void:
	_root = root
	_positions.clear()
	_node_to_sections.clear()
	SECTION_IDS.clear()
	for pname in PLATFORM_NAMES:
		var n: Node2D = root.get_node_or_null(NodePath(pname)) as Node2D
		if n == null:
			continue
		var shape: CollisionShape2D = n.get_node_or_null("CollisionShape2D") as CollisionShape2D
		var ext := Vector2.ZERO
		if shape != null and shape.shape is RectangleShape2D:
			var rect: RectangleShape2D = shape.shape as RectangleShape2D
			ext = rect.size * n.scale / 2.0
		var left_sid := StringName(str(pname) + "_L")
		var right_sid := StringName(str(pname) + "_R")
		var top_y := n.global_position.y - ext.y
		_positions[left_sid] = Vector2(n.global_position.x - ext.x, top_y)
		_positions[right_sid] = Vector2(n.global_position.x + ext.x, top_y)
		SECTION_IDS.append(left_sid)
		SECTION_IDS.append(right_sid)
		_node_to_sections[n] = [left_sid, right_sid]
	_build_edges()

func get_section_position(section_id: StringName) -> Vector2:
	return _positions.get(section_id, Vector2.ZERO)

func get_section_under_body(body: CharacterBody2D) -> StringName:
	if _root == null:
		return &""
	if not body.is_on_floor():
		return &""
	var space_state: PhysicsDirectSpaceState2D = body.get_world_2d().direct_space_state
	var from_pos := body.global_position
	var to_pos := from_pos + Vector2(0, 40)
	var q := PhysicsRayQueryParameters2D.create(from_pos, to_pos)
	q.exclude = [body.get_rid()]
	var result := space_state.intersect_ray(q)
	if result.is_empty():
		return &""
	var sections: Array = _node_to_sections.get(result.collider, [])
	if sections.is_empty():
		return &""
	var x := body.global_position.x
	var left_pos: Vector2 = _positions.get(sections[0], Vector2.ZERO)
	var right_pos: Vector2 = _positions.get(sections[1], Vector2.ZERO)
	return sections[0] if x < (left_pos.x + right_pos.x) / 2.0 else sections[1]

func get_neighbors(section_id: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in _edges:
		if e.from != section_id:
			continue
		out.append({ to = e.to, type = e.type })
	return out

func get_heuristic(from_id: StringName, to_id: StringName) -> float:
	var a: Vector2 = _positions.get(from_id, Vector2.ZERO)
	var b: Vector2 = _positions.get(to_id, Vector2.ZERO)
	return a.distance_to(b)
