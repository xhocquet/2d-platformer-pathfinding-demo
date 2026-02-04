@tool
class_name SectionGraphNode
extends Node2D

@export var debug_draw := true

var graph: SectionGraph
var debug_ui: DebugUI
var _last_source_positions: Dictionary = {}  # node path -> Vector2 (editor only)
var _player: CharacterBody2D
var _enemy: CharacterBody2D

const EDGE_ARROW_LENGTH: float = 8.0
const EDGE_ARROW_WIDTH: float = 6.0

func _init() -> void:
	graph = SectionGraph.new()
	debug_ui = DebugUI.new()

func _ready() -> void:
	graph.set_root(get_parent())
	_player = get_parent().get_node("Player") as CharacterBody2D
	_enemy = get_parent().get_node("Enemy") as CharacterBody2D
	debug_ui.visible = debug_draw
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

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event.is_action_pressed("toggle_debug"):
		debug_ui.toggle_visibility()
		queue_redraw()
		get_viewport().set_input_as_handled()

func _draw() -> void:
	var player_sid: StringName = &""
	var enemy_sid: StringName = &""
	if not Engine.is_editor_hint():
		player_sid = _player.get_current_section_id() if _player else &""
		enemy_sid = _enemy.get_current_section_id() if _enemy else &""

	debug_ui.draw_section_graph(self, graph, player_sid, enemy_sid)
	debug_ui.draw_legend(self, graph)
