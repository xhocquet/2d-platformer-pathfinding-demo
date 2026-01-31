extends Node2D

@export var debug_draw := true

var graph: SectionGraph

func _ready() -> void:
	graph = SectionGraph.new()
	graph.set_root(get_parent())
	queue_redraw()

func _draw() -> void:
	if not debug_draw or graph == null:
		return
	for sid in graph.section_ids:
		var pos := graph.get_section_position(sid)
		if pos == Vector2.ZERO:
			continue
		draw_circle(pos, 12.0, Color.GREEN)
		draw_arc(pos, 14.0, 0.0, TAU, 8, Color.WHITE)
	for sid in graph.section_ids:
		for neighbor in graph.get_neighbors(sid):
			var from_pos := graph.get_section_position(sid)
			var to_pos := graph.get_section_position(neighbor.to)
			if from_pos == Vector2.ZERO or to_pos == Vector2.ZERO:
				continue
			var c: Color = Color.YELLOW if neighbor.type == SectionGraph.EdgeType.JUMP else Color.ORANGE
			draw_line(from_pos, to_pos, c)
