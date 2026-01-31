class_name SectionGraph
extends RefCounted

# Edge type: walk (same level / drop off), fall, jump
enum EdgeType { WALK, FALL, JUMP }

const PLATFORM_NAMES: Array[StringName] = [&"Floor", &"Platform1", &"Platform2", &"Platform3"]
# Built in set_root after positions exist; used by debug draw and A*
var section_ids: Array[StringName] = []

# from_id, to_id, type
var _edges: Array[Dictionary] = []
var _positions: Dictionary = {}  # section_id -> Vector2 (filled when root set)
var _node_to_sections: Dictionary = {}  # Node -> [section_id_left, section_id_right]
var _root: Node2D
# Max vertical rise for jump edges; edges exceeding this are not added (match player jump_height).
var max_jump_height := 320.0
# Horizontal offset of jump points from ledge edge (away from ledge; left/right edge -> move that way).
var jump_point_offset := 100.0

func _init() -> void:
	pass  # edges built in set_root after we have positions

# Two nodes per platform (L/R edges). Walk same platform; fall to floor edges; jump between adjacent ledges.
func _build_edges() -> void:
	_edges.clear()
	_add_walk_edges()
	_add_fall_edges()
	_add_platform_jump_edges()
	_add_jump_point_edges()
	_filter_edges_by_vertical_reach()

func _add_walk_edges() -> void:
	var fl := &"Floor_L"
	var fr := &"Floor_R"
	var p1l := &"Platform1_L"
	var p1r := &"Platform1_R"
	var p2l := &"Platform2_L"
	var p2r := &"Platform2_R"
	var p3l := &"Platform3_L"
	var p3r := &"Platform3_R"
	_add_edge(fl, fr, EdgeType.WALK)
	_add_edge(fr, fl, EdgeType.WALK)
	_add_edge(p1l, p1r, EdgeType.WALK)
	_add_edge(p1r, p1l, EdgeType.WALK)
	_add_edge(p2l, p2r, EdgeType.WALK)
	_add_edge(p2r, p2l, EdgeType.WALK)
	_add_edge(p3l, p3r, EdgeType.WALK)
	_add_edge(p3r, p3l, EdgeType.WALK)

func _add_fall_edges() -> void:
	var fl := &"Floor_L"
	var fr := &"Floor_R"
	var p1l := &"Platform1_L"
	var p1r := &"Platform1_R"
	var p2l := &"Platform2_L"
	var p2r := &"Platform2_R"
	var p3l := &"Platform3_L"
	var p3r := &"Platform3_R"
	for pid in [p1l, p1r, p2l, p2r, p3l, p3r]:
		_add_edge(pid, fl, EdgeType.FALL)
		_add_edge(pid, fr, EdgeType.FALL)

func _add_platform_jump_edges() -> void:
	var p1r := &"Platform1_R"
	var p2l := &"Platform2_L"
	var p2r := &"Platform2_R"
	var p3l := &"Platform3_L"
	_add_jump_edge_if_reachable(p1r, p2l)
	_add_jump_edge_if_reachable(p2l, p1r)
	_add_jump_edge_if_reachable(p2r, p3l)
	_add_jump_edge_if_reachable(p3l, p2r)

func _add_jump_point_edges() -> void:
	var fl := &"Floor_L"
	var fr := &"Floor_R"
	var p1l := &"Platform1_L"
	var p1r := &"Platform1_R"
	var p2l := &"Platform2_L"
	var p2r := &"Platform2_R"
	var p3l := &"Platform3_L"
	var p3r := &"Platform3_R"
	var jps := [
		&"Platform1_L_jump", &"Platform1_R_jump", &"Platform2_L_jump",
		&"Platform2_R_jump", &"Platform3_L_jump", &"Platform3_R_jump"
	]
	for jp in jps:
		_add_edge(fl, jp, EdgeType.WALK)
		_add_edge(jp, fl, EdgeType.WALK)
		_add_edge(fr, jp, EdgeType.WALK)
		_add_edge(jp, fr, EdgeType.WALK)
	_add_jump_edge_if_reachable(&"Platform1_L_jump", p1l)
	_add_jump_edge_if_reachable(&"Platform1_R_jump", p1r)
	_add_jump_edge_if_reachable(&"Platform2_L_jump", p2l)
	_add_jump_edge_if_reachable(&"Platform2_R_jump", p2r)
	_add_jump_edge_if_reachable(&"Platform3_L_jump", p3l)
	_add_jump_edge_if_reachable(&"Platform3_R_jump", p3r)

func _add_edge(from: StringName, to: StringName, type: EdgeType) -> void:
	_edges.append({ from = from, to = to, type = type })

func _filter_edges_by_vertical_reach() -> void:
	var keep: Array[Dictionary] = []
	for e in _edges:
		var a: Vector2 = _positions.get(e.from, Vector2.ZERO)
		var b: Vector2 = _positions.get(e.to, Vector2.ZERO)
		if absf(a.y - b.y) <= max_jump_height:
			keep.append(e)
	_edges = keep

func _add_jump_edge_if_reachable(from_id: StringName, to_id: StringName) -> void:
	var from_pos: Vector2 = _positions.get(from_id, Vector2.ZERO)
	var to_pos: Vector2 = _positions.get(to_id, Vector2.ZERO)
	var rise := from_pos.y - to_pos.y  # positive when destination is above
	if rise > max_jump_height:
		return
	_add_edge(from_id, to_id, EdgeType.JUMP)

func set_root(root: Node2D) -> void:
	_root = root
	_positions.clear()
	_node_to_sections.clear()
	section_ids.clear()
	var floor_top_y := _register_platform_positions(root)
	_register_jump_point_positions(floor_top_y)
	_build_edges()

func _register_platform_positions(root: Node2D) -> float:
	var floor_top_y := 0.0
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
		section_ids.append(left_sid)
		section_ids.append(right_sid)
		_node_to_sections[n] = [left_sid, right_sid]
		if pname == &"Floor":
			floor_top_y = top_y
	return floor_top_y

func _register_jump_point_positions(floor_top_y: float) -> void:
	for pname in PLATFORM_NAMES:
		if pname == &"Floor":
			continue
		var left_sid := StringName(str(pname) + "_L")
		var right_sid := StringName(str(pname) + "_R")
		var left_pos: Vector2 = _positions.get(left_sid, Vector2.ZERO)
		var right_pos: Vector2 = _positions.get(right_sid, Vector2.ZERO)
		var jp_l := StringName(str(pname) + "_L_jump")
		var jp_r := StringName(str(pname) + "_R_jump")
		_positions[jp_l] = Vector2(left_pos.x - jump_point_offset, floor_top_y)
		_positions[jp_r] = Vector2(right_pos.x + jump_point_offset, floor_top_y)
		section_ids.append(jp_l)
		section_ids.append(jp_r)

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

func get_edge_type(from_id: StringName, to_id: StringName) -> EdgeType:
	for nb in get_neighbors(from_id):
		if nb.to == to_id:
			return nb.type
	return EdgeType.WALK

func get_heuristic(from_id: StringName, to_id: StringName) -> float:
	var a: Vector2 = _positions.get(from_id, Vector2.ZERO)
	var b: Vector2 = _positions.get(to_id, Vector2.ZERO)
	return a.distance_to(b)

# Returns path from from_id to to_id (inclusive), or empty if no path.
func find_path(from_id: StringName, to_id: StringName) -> Array[StringName]:
	if from_id == to_id:
		return [from_id]
	var open: Array[StringName] = [from_id]
	var came_from: Dictionary = {}
	var g_score: Dictionary = { from_id: 0.0 }
	var f_score: Dictionary = { from_id: get_heuristic(from_id, to_id) }
	while open.size() > 0:
		var current: StringName = _open_lowest_f(open, f_score)
		if current == to_id:
			return _reconstruct_path(came_from, current)
		open.erase(current)
		for neighbor in get_neighbors(current):
			var to_id_n: StringName = neighbor.to
			var edge_cost: float = get_section_position(current).distance_to(get_section_position(to_id_n))
			var tentative_g: float = g_score.get(current, INF) + edge_cost
			if tentative_g < g_score.get(to_id_n, INF):
				came_from[to_id_n] = current
				g_score[to_id_n] = tentative_g
				f_score[to_id_n] = tentative_g + get_heuristic(to_id_n, to_id)
				if open.has(to_id_n) == false:
					open.append(to_id_n)
	return []

func _open_lowest_f(open: Array[StringName], f_score: Dictionary) -> StringName:
	var best: StringName = open[0]
	var best_f: float = f_score.get(best, INF)
	for i in range(1, open.size()):
		var id_key: StringName = open[i]
		var f: float = f_score.get(id_key, INF)
		if f < best_f:
			best_f = f
			best = id_key
	return best

func _reconstruct_path(came_from: Dictionary, current: StringName) -> Array[StringName]:
	var path: Array[StringName] = [current]
	while came_from.has(current):
		current = came_from[current]
		path.insert(0, current)
	return path
