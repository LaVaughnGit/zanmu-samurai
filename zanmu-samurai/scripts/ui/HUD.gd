extends CanvasLayer
class_name HUD

const HEART_FULL          := Color(0.90, 0.15, 0.15, 1.0)
const HEART_EMPTY         := Color(0.25, 0.25, 0.25, 1.0)
const DASH_READY_COLOR    := Color(0.30, 0.82, 1.00, 1.0)
const DASH_CHARGING_COLOR := Color(0.45, 0.45, 0.52, 1.0)
const DEBUG_ON_COLOR      := Color(1.00, 0.50, 0.10)
const DEBUG_OFF_COLOR     := Color(0.55, 0.55, 0.60)

# Base font sizes designed for 720 p; scaled proportionally at runtime
const BASE_HEART_SIZE  := 44
const BASE_LABEL_SIZE  := 13
const BASE_HINT_SIZE   := 14
const BASE_H           := 720.0

var hearts: Array[Label] = []
var _heart_box: HBoxContainer
var dash_bar: ProgressBar
var dash_label: Label
var debug_btn: Button
var _map_label: Label
var _map_container: Control
var _hint_label: Label


class MinimapDraw extends Control:
	const CELL := 14
	const GAP  := 3
	const STEP := CELL + GAP

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.04, 0.06, 0.85))
		var cx := size.x * 0.5
		var cy := size.y * 0.5
		for raw_pos in GameState.room_data:
			var pos := raw_pos as Vector2i
			var is_visited  := GameState.visited_rooms.has(pos)
			var is_adjacent := _is_adjacent_to_visited(pos)
			if not GameState.debug_mode and not is_visited and not is_adjacent:
				continue
			var rt: int = GameState.room_data[pos].get("type", GameState.RoomType.SMALL)
			var col: Color
			if pos == GameState.current_room_pos:
				col = Color(1.00, 0.90, 0.20)
			elif not is_visited:
				col = Color(0.22, 0.20, 0.18, 0.45)
			elif rt == GameState.RoomType.WELCOME:
				col = Color(0.55, 0.38, 0.85)
			elif rt == GameState.RoomType.EXIT:
				col = Color(0.20, 0.85, 0.60)
			else:
				var cleared: bool = GameState.room_data[pos].get("cleared", false)
				col = Color(0.48, 0.43, 0.38) if cleared else Color(0.85, 0.35, 0.20)
			var dx := cx + pos.x * STEP - CELL * 0.5
			var dy := cy + pos.y * STEP - CELL * 0.5
			draw_rect(Rect2(dx, dy, CELL, CELL), col)

	func _is_adjacent_to_visited(pos: Vector2i) -> bool:
		for offset in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]:
			if GameState.visited_rooms.has(pos + offset):
				return true
		return false

	func _process(_delta: float) -> void:
		queue_redraw()


func _ready() -> void:
	_build_ui()
	get_viewport().size_changed.connect(_on_viewport_resized)
	_update_font_sizes()


func _scale() -> float:
	return get_viewport().get_visible_rect().size.y / BASE_H


func _scaled(base: int) -> int:
	return max(1, int(base * _scale()))


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# ── Top-left: hearts + dash ───────────────────────────────────────────────
	var top_left := VBoxContainer.new()
	top_left.anchor_left   = 0.015
	top_left.anchor_top    = 0.022
	top_left.anchor_right  = 0.28
	top_left.anchor_bottom = 0.20
	top_left.add_theme_constant_override("separation", 6)
	root.add_child(top_left)

	_heart_box = HBoxContainer.new()
	_heart_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_heart_box.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_heart_box.add_theme_constant_override("separation", 4)
	top_left.add_child(_heart_box)

	dash_bar = ProgressBar.new()
	dash_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dash_bar.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	dash_bar.max_value = 1.0
	dash_bar.value = 1.0
	dash_bar.show_percentage = false
	top_left.add_child(dash_bar)

	dash_label = Label.new()
	dash_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	dash_label.text = "DASH READY"
	dash_label.add_theme_color_override("font_color", DASH_READY_COLOR)
	dash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dash_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	dash_bar.add_child(dash_label)

	# ── Top-right: minimap ────────────────────────────────────────────────────
	var map_opacity := 1.0 if GameState.debug_mode else 0.65

	_map_label = Label.new()
	_map_label.anchor_left   = 0.80
	_map_label.anchor_top    = 0.015
	_map_label.anchor_right  = 0.99
	_map_label.anchor_bottom = 0.055
	_map_label.text = "Floor %d" % GameState.floor_number
	_map_label.add_theme_color_override("font_color", Color(0.70, 0.68, 0.75))
	_map_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_map_label.modulate = Color(1.0, 1.0, 1.0, map_opacity)
	root.add_child(_map_label)

	_map_container = Control.new()
	_map_container.anchor_left   = 0.80
	_map_container.anchor_top    = 0.058
	_map_container.anchor_right  = 0.99
	_map_container.anchor_bottom = 0.31
	_map_container.modulate = Color(1.0, 1.0, 1.0, map_opacity)
	root.add_child(_map_container)

	var map_draw := MinimapDraw.new()
	map_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_container.add_child(map_draw)

	# ── Bottom-left: debug toggle ─────────────────────────────────────────────
	debug_btn = Button.new()
	debug_btn.anchor_left   = 0.01
	debug_btn.anchor_top    = 0.920
	debug_btn.anchor_right  = 0.13
	debug_btn.anchor_bottom = 0.985
	debug_btn.text = "DEBUG: ON" if GameState.debug_mode else "DEBUG: OFF"
	debug_btn.add_theme_color_override(
		"font_color", DEBUG_ON_COLOR if GameState.debug_mode else DEBUG_OFF_COLOR
	)
	debug_btn.focus_mode = Control.FOCUS_NONE
	debug_btn.pressed.connect(_on_debug_toggle)
	root.add_child(debug_btn)

	# ── Bottom-centre: controls hint ──────────────────────────────────────────
	_hint_label = Label.new()
	_hint_label.anchor_left   = 0.0
	_hint_label.anchor_top    = 0.930
	_hint_label.anchor_right  = 1.0
	_hint_label.anchor_bottom = 0.995
	_hint_label.text = "WASD  Move     K  Attack     Space  Dash"
	_hint_label.add_theme_color_override("font_color", Color(0.75, 0.72, 0.80, 0.75))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	root.add_child(_hint_label)


func _update_font_sizes() -> void:
	var lsz := _scaled(BASE_LABEL_SIZE)
	var hsz := _scaled(BASE_HINT_SIZE)
	if dash_label:
		dash_label.add_theme_font_size_override("font_size", lsz)
	if _map_label:
		_map_label.add_theme_font_size_override("font_size", lsz)
	if debug_btn:
		debug_btn.add_theme_font_size_override("font_size", lsz)
	if _hint_label:
		_hint_label.add_theme_font_size_override("font_size", hsz)
	# Update existing hearts
	var heart_sz := _scaled(BASE_HEART_SIZE)
	for h in hearts:
		h.add_theme_font_size_override("font_size", heart_sz)


func _on_viewport_resized() -> void:
	_update_font_sizes()


func _on_debug_toggle() -> void:
	GameState.debug_mode = not GameState.debug_mode
	var on := GameState.debug_mode
	debug_btn.text = "DEBUG: ON" if on else "DEBUG: OFF"
	debug_btn.add_theme_color_override("font_color", DEBUG_ON_COLOR if on else DEBUG_OFF_COLOR)
	var opacity := 1.0 if on else 0.65
	_map_container.modulate.a = opacity
	_map_label.modulate.a = opacity


func _on_player_health_changed(current: int, maximum: int) -> void:
	if hearts.size() != maximum:
		for h in hearts:
			h.queue_free()
		hearts.clear()
		var heart_sz := _scaled(BASE_HEART_SIZE)
		for i in maximum:
			var h := Label.new()
			h.text = "♥"
			h.add_theme_font_size_override("font_size", heart_sz)
			_heart_box.add_child(h)
			hearts.append(h)
	for i in hearts.size():
		hearts[i].add_theme_color_override(
			"font_color", HEART_FULL if i < current else HEART_EMPTY
		)


func _on_player_dash_changed(ratio: float) -> void:
	dash_bar.value = ratio
	var ready := ratio >= 1.0
	dash_label.text = "DASH READY" if ready else "DASH"
	dash_label.add_theme_color_override(
		"font_color", DASH_READY_COLOR if ready else DASH_CHARGING_COLOR
	)
	dash_bar.modulate = Color(1.0, 1.0, 1.0) if ready else Color(0.7, 0.7, 0.75)
