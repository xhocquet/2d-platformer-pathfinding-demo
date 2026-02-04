@tool
class_name NaviGraph
extends Node2D

@export var debug_draw := true
@export var max_jump_height: float = 220.0 # Max vertical rise for jump edges
@export var jump_point_offset: float = 40.0 # Horizontal offset of jump points from ledge edge
@export var max_edge_length: float = 300.0 # Max edge length (0 = no limit)
@export var collapse_radius: float = 20.0 # Merge points within this distance

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

func _apply_graph_params() -> void:
	graph.max_jump_height = max_jump_height
	graph.jump_point_offset = jump_point_offset
	graph.max_edge_length = max_edge_length
	graph.collapse_radius = collapse_radius

func _ready() -> void:
	_apply_graph_params()
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

func _node_positions_changed(new_positions: Dictionary) -> bool:
	if _last_source_positions.size() != new_positions.size():
		return true

	for path in new_positions:
		if (
			not _last_source_positions.has(path) or
			not _last_source_positions[path].is_equal_approx(new_positions[path])
		):
			return true

	return false

# In the editor, regenerate the graph when node positions change
func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		var positions := _get_source_positions()
		if not _node_positions_changed(positions):
			return
		_last_source_positions = positions
		graph = SectionGraph.new()
		_apply_graph_params()
		graph.set_root(get_parent())

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

	if debug_ui:
		debug_ui.draw_section_graph(self, graph, player_sid, enemy_sid)
		debug_ui.draw_legend(self, graph)
