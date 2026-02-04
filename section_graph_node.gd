@tool
class_name SectionGraphNode
extends Node2D

@export var debug_draw := true

var graph: SectionGraph
var _last_source_positions: Dictionary = {}  # node path -> Vector2 (editor only)
var _player: CharacterBody2D
var _enemy: CharacterBody2D

const RADIUS: float = 8.0
const EDGE_ARROW_LENGTH: float = 8.0
const EDGE_ARROW_WIDTH: float = 6.0

func _init() -> void:
	graph = SectionGraph.new()

func _ready() -> void:
	graph.set_root(get_parent())
	_player = get_parent().get_node("Player") as CharacterBody2D
	_enemy = get_parent().get_node("Enemy") as CharacterBody2D
	queue_redraw()

func _get_source_positions() -> Dictionary:
	var out: Dictionary = {}
	var parent: Node = get_parent()
	for body in SectionGraph.get_platform_bodies(parent):
		out[parent.get_path_to(body)] = body.global_position
	return out

func _source_positions_changed(new_positions: Dictionary) -> bool:
	if _last_source_positions.size() != new_positions.size():
		return true

	for path in new_positions:
		if (
			not _last_source_positions.has(path) or
			not _last_source_positions[path].is_equal_approx(new_positions[path])
		):
			return true

	return false

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		var positions := _get_source_positions()
		if not _source_positions_changed(positions):
			return
		_last_source_positions = positions
		graph = SectionGraph.new()
		graph.set_root(get_parent())
		queue_redraw()
		return

	queue_redraw()

func _draw() -> void:
	var player_sid: StringName = &""
	var enemy_sid: StringName = &""
	if not Engine.is_editor_hint():
		player_sid = _player.get_current_section_id() if _player else &""
		enemy_sid = _enemy.get_current_section_id() if _enemy else &""

	for sid in graph.get_section_ids():
		var from_pos := graph.get_section_position(sid)
		if from_pos == Vector2.ZERO:
			continue
		draw_circle(from_pos, RADIUS, Color.GREEN)
		# Left half π/2→3π/2, right half 3π/2→π/2+2π (sweep through 0)
		if sid == enemy_sid:
			_draw_filled_half_circle(from_pos, RADIUS, PI / 2.0, 3.0 * PI / 2.0, Color.RED)
		if sid == player_sid:
			_draw_filled_half_circle(from_pos, RADIUS, 3.0 * PI / 2.0, PI / 2.0 + TAU, Color.BLUE)

		var neighbors := graph.get_neighbors(sid)
		if Engine.is_editor_hint():
			var by_to: Dictionary = {}
			for neighbor in neighbors:
				var to_id: StringName = neighbor.to
				if not by_to.has(to_id):
					by_to[to_id] = []
				(by_to[to_id] as Array).append(neighbor)
			for to_id in by_to:
				var to_pos := graph.get_section_position(to_id)
				if from_pos == Vector2.ZERO or to_pos == Vector2.ZERO:
					continue
				var dir := (to_pos - from_pos).normalized()
				var perp := Vector2(-dir.y, dir.x)
				var group: Array = by_to[to_id]
				for i in min(2, group.size()):
					var neighbor: Dictionary = group[i]
					var offset_amount: float = -1.0 if i == 0 else 1.0
					var a := from_pos + perp * offset_amount
					var b := to_pos + perp * offset_amount
					draw_line(a, b, graph.get_debug_edge_color(neighbor.type))
			continue

		for neighbor in neighbors:
			var to_pos := graph.get_section_position(neighbor.to)
			if from_pos == Vector2.ZERO or to_pos == Vector2.ZERO:
				continue
			var a := from_pos
			var b := to_pos
			var c: Color = graph.get_debug_edge_color(neighbor.type)
			draw_line(a, b, c)

	if debug_draw:
		_draw_debug_legend()

func _draw_debug_legend() -> void:
	const LEGEND_OFFSET := Vector2(24.0, 24.0)
	const LINE_HEIGHT := 20.0
	const SAMPLE_LEN := 24.0
	var entries: Array = graph.get_debug_legend_entries()
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var pos := LEGEND_OFFSET + Vector2(0.0, i * LINE_HEIGHT)
		draw_line(pos, pos + Vector2(SAMPLE_LEN, 0.0), entry.color)
		draw_string(ThemeDB.fallback_font, pos + Vector2(SAMPLE_LEN + 8.0, 4.0), entry.label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, entry.color)

func _draw_filled_half_circle(center: Vector2, radius: float, start_angle: float, end_angle: float, color: Color) -> void:
	var points: PackedVector2Array = [center]
	for i in 8 + 1:
		var t: float = float(i) / float(8)
		var a: float = start_angle + t * (end_angle - start_angle)
		points.append(center + Vector2(cos(a), sin(a)) * radius)
	draw_polygon(points, [color])
