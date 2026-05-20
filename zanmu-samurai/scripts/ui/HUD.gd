extends CanvasLayer
class_name HUD

const HEART_FULL := Color(0.90, 0.15, 0.15, 1.0)
const HEART_EMPTY := Color(0.25, 0.25, 0.25, 1.0)
const DASH_READY_COLOR := Color(0.30, 0.82, 1.00, 1.0)
const DASH_CHARGING_COLOR := Color(0.45, 0.45, 0.52, 1.0)
const DEBUG_ON_COLOR  := Color(1.00, 0.50, 0.10)
const DEBUG_OFF_COLOR := Color(0.55, 0.55, 0.60)

var hearts: Array[Label] = []
var dash_bar: ProgressBar
var dash_label: Label
var debug_btn: Button
var _map_label: Label
var _map_container: Control


class MinimapDraw extends Control:
	const CELL := 12
	const GAP  := 3
	const STEP := CELL + GAP

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.04, 0.06, 0.85))
		var cx := size.x * 0.5
		var cy := size.y * 0.5
		for raw_pos in GameState.room_data:
			var pos := raw_pos as Vector2i
			var is_visited := GameState.visited_rooms.has(pos)
			if not GameState.debug_mode and not is_visited:
				continue
			var rt: int = GameState.room_data[pos].get("type", GameState.RoomType.SMALL)
			var col: Color
			if pos == GameState.current_room_pos:
				col = Color(1.00, 0.90, 0.20)
			elif rt == GameState.RoomType.WELCOME:
				col = Color(0.55, 0.38, 0.85)
			elif rt == GameState.RoomType.EXIT:
				col = Color(0.20, 0.85, 0.60)
			elif not is_visited:
				col = Color(0.22, 0.20, 0.18)  # dim — not yet discovered
			else:
				var cleared: bool = GameState.room_data[pos].get("cleared", false)
				col = Color(0.48, 0.43, 0.38) if cleared else Color(0.85, 0.35, 0.20)
			var dx := cx + pos.x * STEP - CELL * 0.5
			var dy := cy + pos.y * STEP - CELL * 0.5
			draw_rect(Rect2(dx, dy, CELL, CELL), col)

	func _process(_delta: float) -> void:
		queue_redraw()


func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var ctrl := Control.new()
	ctrl.anchor_right = 1.0
	ctrl.anchor_bottom = 1.0
	add_child(ctrl)

	# Three heart icons
	var hbox := HBoxContainer.new()
	hbox.position = Vector2(20, 16)
	ctrl.add_child(hbox)
	for i in 3:
		var h := Label.new()
		h.text = "♥"
		h.add_theme_font_size_override("font_size", 40)
		h.add_theme_color_override("font_color", HEART_FULL)
		hbox.add_child(h)
		hearts.append(h)

	# Dash recharge bar
	dash_bar = ProgressBar.new()
	dash_bar.position = Vector2(20, 74)
	dash_bar.size = Vector2(200, 20)
	dash_bar.max_value = 1.0
	dash_bar.value = 1.0
	dash_bar.show_percentage = false
	ctrl.add_child(dash_bar)

	dash_label = Label.new()
	dash_label.anchor_right = 1.0
	dash_label.anchor_bottom = 1.0
	dash_label.text = "DASH READY"
	dash_label.add_theme_font_size_override("font_size", 11)
	dash_label.add_theme_color_override("font_color", DASH_READY_COLOR)
	dash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dash_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dash_bar.add_child(dash_label)

	# Minimap — top right
	var map_opacity := 1.0 if GameState.debug_mode else 0.60

	_map_label = Label.new()
	_map_label.anchor_left = 1.0
	_map_label.anchor_right = 1.0
	_map_label.offset_left = -202.0
	_map_label.offset_right = -10.0
	_map_label.offset_top = 10.0
	_map_label.offset_bottom = 26.0
	_map_label.text = "Floor %d" % GameState.floor_number
	_map_label.add_theme_font_size_override("font_size", 11)
	_map_label.add_theme_color_override("font_color", Color(0.70, 0.68, 0.75))
	_map_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_map_label.modulate = Color(1.0, 1.0, 1.0, map_opacity)
	ctrl.add_child(_map_label)

	_map_container = Control.new()
	_map_container.anchor_left = 1.0
	_map_container.anchor_right = 1.0
	_map_container.offset_left = -202.0
	_map_container.offset_right = -10.0
	_map_container.offset_top = 28.0
	_map_container.offset_bottom = 208.0
	_map_container.modulate = Color(1.0, 1.0, 1.0, map_opacity)
	ctrl.add_child(_map_container)

	var map_draw := MinimapDraw.new()
	map_draw.anchor_right = 1.0
	map_draw.anchor_bottom = 1.0
	_map_container.add_child(map_draw)

	# Debug toggle — bottom left
	debug_btn = Button.new()
	debug_btn.anchor_top = 1.0
	debug_btn.anchor_bottom = 1.0
	debug_btn.offset_left = 10.0
	debug_btn.offset_right = 140.0
	debug_btn.offset_top = -46.0
	debug_btn.offset_bottom = -10.0
	debug_btn.text = "DEBUG: ON" if GameState.debug_mode else "DEBUG: OFF"
	debug_btn.add_theme_color_override(
		"font_color", DEBUG_ON_COLOR if GameState.debug_mode else DEBUG_OFF_COLOR
	)
	debug_btn.pressed.connect(_on_debug_toggle)
	ctrl.add_child(debug_btn)

	# Controls hint at bottom centre
	var hint := Label.new()
	hint.anchor_left = 0.0
	hint.anchor_top = 1.0
	hint.anchor_right = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_top = -34.0
	hint.text = "WASD: Move     K: Attack     Space: Dash"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ctrl.add_child(hint)

func _on_debug_toggle() -> void:
	GameState.debug_mode = not GameState.debug_mode
	var on := GameState.debug_mode
	debug_btn.text = "DEBUG: ON" if on else "DEBUG: OFF"
	debug_btn.add_theme_color_override("font_color", DEBUG_ON_COLOR if on else DEBUG_OFF_COLOR)
	var opacity := 1.0 if on else 0.60
	_map_container.modulate.a = opacity
	_map_label.modulate.a = opacity

func _on_player_health_changed(current: int, _maximum: int) -> void:
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
