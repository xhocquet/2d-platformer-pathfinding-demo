@tool
class_name SectionGraph
extends RefCounted

# Edge type: walk (same level / drop off), fall, jump
enum EdgeType { WALK, FALL, JUMP }

# from_id, to_id, type
var _edges: Array[Dictionary] = []
var _positions: Dictionary = {}  # section_id -> Vector2 (filled when root set)
var _node_to_sections: Dictionary = {}  # Node -> [section_id_left, section_id_right]
var _root: Node2D
# Max vertical rise for jump edges; edges exceeding this are not added (match player jump_height).
var max_jump_height: float = 220.0
# Horizontal offset of jump points from ledge edge (away from ledge; left/right edge -> move that way).
var jump_point_offset: float = 40.0
# Merge points within this distance (≈75% overlap if points had this radius).
var _collapse_radius: float = 20.0


func _init() -> void:
	pass  # edges built in set_root after we have positions

func _add_edge(from: StringName, to: StringName, type: EdgeType) -> void:
	for e in _edges:
		if e.from == from and e.to == to and e.type == type:
			return
	_edges.append({ from = from, to = to, type = type })

func set_root(root: Node2D) -> void:
	_root = root
	_positions.clear()
	_node_to_sections.clear()
	_edges.clear()
	var platforms: Array[StaticBody2D] = _discover_platforms(root)
	_register_positions_from_platforms(platforms)
	_register_jump_points_from_platforms(platforms)
	_sanitize_points()
	_build_edges(platforms)
	# _filter_edges_by_vertical_reach()

func _discover_platforms(root: Node2D) -> Array[StaticBody2D]:
	var list: Array[StaticBody2D] = []
	for child in root.get_children():
		var body := child as StaticBody2D
		if body == null or not str(body.name).begins_with("Platform"):
			continue
		var shape: CollisionShape2D = body.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape == null or not (shape.shape is RectangleShape2D):
			continue
		list.append(body)
	list.sort_custom(func(a: StaticBody2D, b: StaticBody2D) -> bool: return a.global_position.x < b.global_position.x)
	return list

func _register_positions_from_platforms(platforms: Array[StaticBody2D]) -> void:
	for n in platforms:
		var pname: StringName = n.name
		var shape: CollisionShape2D = n.get_node_or_null("CollisionShape2D") as CollisionShape2D
		var ext := Vector2.ZERO
		if shape != null and shape.shape is RectangleShape2D:
			var rect: RectangleShape2D = shape.shape as RectangleShape2D
			ext = rect.size * n.global_scale / 2.0
		var left_sid := StringName(str(pname) + "_L")
		var right_sid := StringName(str(pname) + "_R")
		var top_y := n.global_position.y - ext.y
		_positions[left_sid] = Vector2(n.global_position.x - ext.x, top_y)
		_positions[right_sid] = Vector2(n.global_position.x + ext.x, top_y)
		_node_to_sections[n] = [left_sid, right_sid]


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


func _sanitize_points() -> void:
	var min_x := INF
	var max_x := -INF
	for sid in _positions:
		if str(sid).ends_with("_jump"):
			continue

		var p: Vector2 = _positions[sid]
		if p.x < min_x:
			min_x = p.x
		if p.x > max_x:
			max_x = p.x
	if min_x <= max_x:
		for sid in _positions.duplicate():
			var p: Vector2 = _positions[sid]
			if p.x < min_x or p.x > max_x:
				_positions.erase(sid)

		for n in _node_to_sections.duplicate():
			var pair: Array = _node_to_sections[n]
			if not _positions.has(pair[0]) or not _positions.has(pair[1]):
				_node_to_sections.erase(n)

	var ids: Array = _positions.keys()
	var parent: Dictionary = {}  # section_id -> section_id (union-find)
	for sid in ids:
		parent[sid] = sid

	for i in range(ids.size()):
		for j in range(i + 1, ids.size()):
			var a: StringName = ids[i]
			var b: StringName = ids[j]
			var pa: Vector2 = _positions.get(a, Vector2.ZERO)
			var pb: Vector2 = _positions.get(b, Vector2.ZERO)
			if pa.distance_to(pb) < _collapse_radius:
				var ra := _collapse_find(parent, a)
				var rb := _collapse_find(parent, b)
				if ra != rb:
					parent[rb] = ra

	var canonical: Dictionary = {}  # sid -> chosen canonical for cluster
	for sid in ids:
		var root: StringName = _collapse_find(parent, sid)
		if not canonical.has(root):
			canonical[root] = _collapse_pick_canonical(parent, root, ids)
		canonical[sid] = canonical[root]

	var seen: Dictionary = {}
	for sid in ids:
		var c: StringName = canonical[sid]
		if not seen.get(c, false):
			seen[c] = true
		if c != sid:
			_positions.erase(sid)

	for n in _node_to_sections:
		var pair: Array = _node_to_sections[n]
		_node_to_sections[n] = [canonical.get(pair[0], pair[0]), canonical.get(pair[1], pair[1])]

func _collapse_find(parent: Dictionary, sid: StringName) -> StringName:
	if parent[sid] != sid:
		parent[sid] = _collapse_find(parent, parent[sid])
	return parent[sid]

func _collapse_pick_canonical(parent: Dictionary, root: StringName, ids: Array) -> StringName:
	var cluster: Array[StringName] = []
	for sid in ids:
		if _collapse_find(parent, sid) == root:
			cluster.append(sid)
	# Prefer platform L/R over _jump so platform endpoints remain.
	for sid in cluster:
		if not str(sid).ends_with("_jump"):
			return sid
	return cluster[0]

# Segments: (left_x, right_x, top_y). First surface straight below (x, ledge_y): segment spanning x with top_y > ledge_y; pick smallest top_y (highest surface). Use tolerance so points at/near edge still hit.
const _SEGMENT_X_TOLERANCE := 2.0

func _y_under_point(segments: Array, x: float, ledge_y: float, fallback_y: float) -> float:
	var best := INF
	for s in segments:
		if s.left_x - _SEGMENT_X_TOLERANCE <= x and x <= s.right_x + _SEGMENT_X_TOLERANCE and s.top_y > ledge_y and s.top_y < best:
			best = s.top_y
	return best if best < INF else fallback_y

# Fallback y for _y_under_point is lowest surface (max top_y among platforms).
func _register_jump_points_from_platforms(platforms: Array[StaticBody2D]) -> void:
	var segments: Array = []  # { left_x, right_x, top_y }
	var fallback_y := -INF
	for p in platforms:
		var pname: StringName = p.name
		var pl: Vector2 = _positions.get(StringName(str(pname) + "_L"), Vector2.ZERO)
		var pr: Vector2 = _positions.get(StringName(str(pname) + "_R"), Vector2.ZERO)
		segments.append({ left_x = minf(pl.x, pr.x), right_x = maxf(pl.x, pr.x), top_y = pl.y })
		if pl.y > fallback_y:
			fallback_y = pl.y
	fallback_y = fallback_y if fallback_y > -INF else 0.0

	for p in platforms:
		var pname: StringName = p.name
		var left_sid := StringName(str(pname) + "_L")
		var right_sid := StringName(str(pname) + "_R")
		var left_pos: Vector2 = _positions.get(left_sid, Vector2.ZERO)
		var right_pos: Vector2 = _positions.get(right_sid, Vector2.ZERO)
		var jp_l := StringName(str(pname) + "_L_jump")
		var jp_r := StringName(str(pname) + "_R_jump")
		var jp_l_x := left_pos.x - jump_point_offset
		var jp_r_x := right_pos.x + jump_point_offset
		_positions[jp_l] = Vector2(jp_l_x, _y_under_point(segments, jp_l_x, left_pos.y, fallback_y))
		_positions[jp_r] = Vector2(jp_r_x, _y_under_point(segments, jp_r_x, right_pos.y, fallback_y))

func _get_section_at_pos(x: float, y: float) -> StringName:
	for sid in get_section_ids():
		if str(sid).ends_with("_jump"):
			continue
		var pos: Vector2 = _positions.get(sid, Vector2.ZERO)
		var base := str(sid).trim_suffix("_L").trim_suffix("_R")
		var other_sid := StringName(base + "_R") if sid == StringName(base + "_L") else StringName(base + "_L")
		var other: Vector2 = _positions.get(other_sid, Vector2.ZERO)
		var left_x := minf(pos.x, other.x)
		var right_x := maxf(pos.x, other.x)
		if left_x <= x and x <= right_x and is_equal_approx(pos.y, y):
			var mid := (left_x + right_x) / 2.0
			return StringName(base + "_L") if x < mid else StringName(base + "_R")
	return &""

func _build_edges(platforms: Array[StaticBody2D]) -> void:
	for p in platforms:
		var pname: StringName = p.name
		var pl := StringName(str(pname) + "_L")
		var pr := StringName(str(pname) + "_R")
		_add_edge(pl, pr, EdgeType.WALK)
		_add_edge(pr, pl, EdgeType.WALK)
		_add_edge(pl, StringName(str(pname) + "_L_jump"), EdgeType.FALL)
		_add_edge(pr, StringName(str(pname) + "_R_jump"), EdgeType.FALL)

	for i in range(platforms.size() - 1):
		var pr := StringName(str(platforms[i].name) + "_R")
		var next_pl := StringName(str(platforms[i + 1].name) + "_L")
		_add_jump_edge_if_reachable(pr, next_pl)
		_add_jump_edge_if_reachable(next_pl, pr)

	# Connect each endpoint to any platform surface directly below (fixes stacked/overlapping platforms, e.g. left side).
	for p in platforms:
		var pair: Array = _node_to_sections.get(p, [])
		if pair.size() < 2:
			continue
		var left_sid: StringName = pair[0]
		var right_sid: StringName = pair[1]
		for sid in [left_sid, right_sid]:
			var pos: Vector2 = _positions.get(sid, Vector2.ZERO)
			if pos == Vector2.ZERO:
				continue
			var x: float = pos.x
			var y: float = pos.y
			for q in platforms:
				if q == p:
					continue
				var qpair: Array = _node_to_sections.get(q, [])
				if qpair.size() < 2:
					continue
				var ql: Vector2 = _positions.get(qpair[0], Vector2.ZERO)
				var qr: Vector2 = _positions.get(qpair[1], Vector2.ZERO)
				var q_left_x: float = minf(ql.x, qr.x)
				var q_right_x: float = maxf(ql.x, qr.x)
				var q_top_y: float = ql.y
				if x < q_left_x - _SEGMENT_X_TOLERANCE or x > q_right_x + _SEGMENT_X_TOLERANCE or q_top_y <= y:
					continue
				var under_section: StringName = _get_section_at_pos(x, q_top_y)
				if under_section == &"" or under_section == sid:
					continue
				_add_jump_edge_if_reachable(sid, under_section)
				_add_jump_edge_if_reachable(under_section, sid)

	for p in platforms:
		var pname: StringName = p.name
		var pl := StringName(str(pname) + "_L")
		var pr := StringName(str(pname) + "_R")
		var jp_l := StringName(str(pname) + "_L_jump")
		var jp_r := StringName(str(pname) + "_R_jump")
		var jp_l_pos: Vector2 = _positions.get(jp_l, Vector2.ZERO)
		var jp_r_pos: Vector2 = _positions.get(jp_r, Vector2.ZERO)
		var under_l := _get_section_at_pos(jp_l_pos.x, jp_l_pos.y)
		var under_r := _get_section_at_pos(jp_r_pos.x, jp_r_pos.y)
		if under_l != &"":
			_add_edge(under_l, jp_l, EdgeType.WALK)
			_add_edge(jp_l, under_l, EdgeType.WALK)
		if under_r != &"":
			_add_edge(under_r, jp_r, EdgeType.WALK)
			_add_edge(jp_r, under_r, EdgeType.WALK)
		_add_jump_edge_if_reachable(jp_l, pl)
		_add_jump_edge_if_reachable(jp_r, pr)
		_add_jump_edge_if_reachable(pl, jp_l)
		_add_jump_edge_if_reachable(pr, jp_r)

func get_section_ids() -> Array:
	return _positions.keys()

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
