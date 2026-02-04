class_name DebugUI
extends RefCounted

var visible: bool = true

const NODE_RADIUS: float = 8.0
const PARALLEL_LINE_OFFSET: float = 1.0
const LEGEND_OFFSET := Vector2(24.0, 24.0)
const LEGEND_LINE_HEIGHT := 20.0
const LEGEND_SAMPLE_LEN := 24.0

func set_visible(value: bool) -> void:
	visible = value

func toggle_visibility() -> void:
	visible = not visible

func draw_graph(c: CanvasItem, g: SectionGraph, player_node_id, enemy_node_id) -> void:
	if not visible:
		return
	_draw_nodes(c, g, player_node_id, enemy_node_id)
	_draw_edges(c, g)

func draw_legend(c: CanvasItem) -> void:
	if not visible:
		return
	var entries: Array = _get_debug_legend_entries()
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var pos: Vector2 = LEGEND_OFFSET + Vector2(0.0, i * LEGEND_LINE_HEIGHT)
		c.draw_line(pos, pos + Vector2(LEGEND_SAMPLE_LEN, 0.0), entry.color)
		c.draw_string(
			ThemeDB.fallback_font, pos + Vector2(LEGEND_SAMPLE_LEN + 8.0, 4.0),
			entry.label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, entry.color
		)

func _draw_nodes(c: CanvasItem, graph: SectionGraph, player_node_id, enemy_node_id) -> void:
	for sid in graph.get_section_ids():
		var from_pos: Vector2 = graph.get_section_position(sid)
		if from_pos == Vector2.ZERO:
			continue
		c.draw_circle(from_pos, NODE_RADIUS, Color.GREEN)
		if sid == enemy_node_id:
			_draw_filled_half_circle(c, from_pos, NODE_RADIUS, PI / 2.0, 3.0 * PI / 2.0, Color.RED)
		if sid == player_node_id:
			_draw_filled_half_circle(c, from_pos, NODE_RADIUS, 3.0 * PI / 2.0, PI / 2.0 + TAU, Color.BLUE)

func _draw_edges(canvas: CanvasItem, graph: SectionGraph) -> void:
	for sid in graph.get_section_ids():
		var from_pos: Vector2 = graph.get_section_position(sid)
		if from_pos == Vector2.ZERO:
			continue
		var neighbors: Array = graph.get_neighbors(sid)
		var by_to: Dictionary = {}
		for neighbor in neighbors:
			var to_id: StringName = neighbor.to
			if not by_to.has(to_id):
				by_to[to_id] = []
			(by_to[to_id] as Array).append(neighbor)
		for to_id in by_to:
			var to_pos: Vector2 = graph.get_section_position(to_id)
			if from_pos == Vector2.ZERO or to_pos == Vector2.ZERO:
				continue
			var dir: Vector2 = (to_pos - from_pos).normalized()
			var perp: Vector2 = Vector2(-dir.y, dir.x)
			var group: Array = by_to[to_id]
			for i in min(2, group.size()):
				var neighbor: Dictionary = group[i]
				var offset_amount: float = -PARALLEL_LINE_OFFSET if i == 0 else PARALLEL_LINE_OFFSET
				var a: Vector2 = from_pos + perp * offset_amount
				var b: Vector2 = to_pos + perp * offset_amount
				canvas.draw_line(a, b, _get_debug_edge_color(neighbor.type))

func _draw_filled_half_circle(c: CanvasItem, center: Vector2, r: float, start_angle: float, end_angle: float, color: Color) -> void:
	var points: PackedVector2Array = [center]
	for i in 8 + 1:
		var t: float = float(i) / float(8)
		var a: float = start_angle + t * (end_angle - start_angle)
		points.append(center + Vector2(cos(a), sin(a)) * r)
	c.draw_polygon(points, [color])

func _get_debug_edge_color(type: SectionGraph.EdgeType) -> Color:
	match type:
		SectionGraph.EdgeType.WALK:
			return Color.CYAN
		SectionGraph.EdgeType.JUMP:
			return Color.RED
		SectionGraph.EdgeType.FALL:
			return Color.GREEN
	return Color.CYAN

func _get_debug_legend_entries() -> Array:
	return [
		{ label = "Walk", color = _get_debug_edge_color(SectionGraph.EdgeType.WALK) },
		{ label = "Jump", color = _get_debug_edge_color(SectionGraph.EdgeType.JUMP) },
		{ label = "Fall", color = _get_debug_edge_color(SectionGraph.EdgeType.FALL) }
	]
