@tool
extends Node2D

@export var debug_draw := true

var graph: SectionGraph
var _last_source_positions: Dictionary = {}  # node path -> Vector2 (editor only)

func _ready() -> void:
	graph = SectionGraph.new()
	graph.set_root(get_parent())
	queue_redraw()

# Same criteria as SectionGraph: PlatformN StaticBody2D with CollisionShape2D + RectangleShape2D
func _get_source_positions() -> Dictionary:
	var out: Dictionary = {}
	for child in get_parent().get_children():
		var body: StaticBody2D = child as StaticBody2D
		if body == null or not str(body.name).begins_with("Platform"):
			continue

		var shape: CollisionShape2D = body.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape == null or not (shape.shape is RectangleShape2D):
			continue

		out[get_parent().get_path_to(body)] = body.global_position

	return out

func _source_positions_changed(new_positions: Dictionary) -> bool:
	if _last_source_positions.size() != new_positions.size():
		return true

	for path in new_positions:
		if not _last_source_positions.has(path) or not _last_source_positions[path].is_equal_approx(new_positions[path]):
			return true

	return false

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return

	var positions := _get_source_positions()
	if not _source_positions_changed(positions):
		return

	_last_source_positions = positions
	graph = SectionGraph.new()
	graph.set_root(get_parent())
	queue_redraw()

func _draw() -> void:
	if not debug_draw or graph == null:
		return

	for sid in graph.get_section_ids():
		var pos := graph.get_section_position(sid)
		if pos == Vector2.ZERO:
			continue
		draw_circle(pos, 12.0, Color.GREEN)
		draw_arc(pos, 14.0, 0.0, TAU, 8, Color.WHITE)

	for sid in graph.get_section_ids():
		for neighbor in graph.get_neighbors(sid):
			var from_pos := graph.get_section_position(sid)
			var to_pos := graph.get_section_position(neighbor.to)
			if from_pos == Vector2.ZERO or to_pos == Vector2.ZERO:
				continue

			var c: Color = Color.YELLOW if neighbor.type == SectionGraph.EdgeType.JUMP else Color.ORANGE
			draw_line(from_pos, to_pos, c)
