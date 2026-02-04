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

func draw_section_graph(canvas: CanvasItem, graph: SectionGraph, player_section_id: StringName, enemy_section_id: StringName) -> void:
	if not visible:
		return
	_draw_section_nodes(canvas, graph, player_section_id, enemy_section_id)
	_draw_edges(canvas, graph)

func draw_legend(canvas: CanvasItem, graph: SectionGraph) -> void:
	if not visible:
		return
	var entries: Array = graph.get_debug_legend_entries()
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var pos: Vector2 = LEGEND_OFFSET + Vector2(0.0, i * LEGEND_LINE_HEIGHT)
		canvas.draw_line(pos, pos + Vector2(LEGEND_SAMPLE_LEN, 0.0), entry.color)
		canvas.draw_string(ThemeDB.fallback_font, pos + Vector2(LEGEND_SAMPLE_LEN + 8.0, 4.0), entry.label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, entry.color)

func _draw_section_nodes(canvas: CanvasItem, graph: SectionGraph, player_section_id: StringName, enemy_section_id: StringName) -> void:
	for sid in graph.get_section_ids():
		var from_pos: Vector2 = graph.get_section_position(sid)
		if from_pos == Vector2.ZERO:
			continue
		canvas.draw_circle(from_pos, NODE_RADIUS, Color.GREEN)
		if sid == enemy_section_id:
			_draw_filled_half_circle(canvas, from_pos, NODE_RADIUS, PI / 2.0, 3.0 * PI / 2.0, Color.RED)
		if sid == player_section_id:
			_draw_filled_half_circle(canvas, from_pos, NODE_RADIUS, 3.0 * PI / 2.0, PI / 2.0 + TAU, Color.BLUE)

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
				canvas.draw_line(a, b, graph.get_debug_edge_color(neighbor.type))

func _draw_filled_half_circle(canvas: CanvasItem, center: Vector2, radius: float, start_angle: float, end_angle: float, color: Color) -> void:
	var points: PackedVector2Array = [center]
	for i in 8 + 1:
		var t: float = float(i) / float(8)
		var a: float = start_angle + t * (end_angle - start_angle)
		points.append(center + Vector2(cos(a), sin(a)) * radius)
	canvas.draw_polygon(points, [color])
