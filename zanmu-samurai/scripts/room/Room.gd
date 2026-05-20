extends Node2D
class_name Room

signal room_cleared

const PLAYER_SCENE   := preload("res://scenes/Player.tscn")
const KENJUTSU_SCENE := preload("res://scenes/enemies/Kenjutsu.tscn")

const HALF_W := 400.0
const HALF_H := 260.0
const WALL_T := 40.0
const DOOR_W := 70.0

var player: Player
var enemies_node: Node2D
var hud: HUD

var _active_doors: Dictionary = {}
var _door_blockers: Array[Node] = []


func _ready() -> void:
	y_sort_enabled = true
	_roll_doors()
	_build_environment()
	_build_player()
	if GameState.room_type == GameState.RoomType.WELCOME and GameState.floor_number == 1:
		_build_welcome_content()
	elif GameState.room_type == GameState.RoomType.EXIT:
		_build_portal()
	elif not _is_current_room_cleared():
		_build_enemies()
		if GameState.room_type == GameState.RoomType.OBSTACLE:
			_build_obstacles()
	hud = HUD.new()
	add_child(hud)
	_connect_signals()


func _is_current_room_cleared() -> bool:
	var data = GameState.room_data.get(GameState.current_room_pos, null)
	return data != null and data.get("cleared", false)


# ── Doors (layout comes from GameState, not re-rolled) ────────────────────────

func _roll_doors() -> void:
	var data = GameState.room_data.get(GameState.current_room_pos, null)
	if data:
		_active_doors = data.doors.duplicate()
	else:
		_active_doors = {"N": true, "S": true, "E": true, "W": true}


# ── Environment ───────────────────────────────────────────────────────────────

func _build_environment() -> void:
	var cam := Camera2D.new()
	cam.zoom = Vector2(1.4, 0.85)
	add_child(cam)

	var floor_poly := Polygon2D.new()
	floor_poly.z_index = -1
	floor_poly.polygon = PackedVector2Array([
		Vector2(-HALF_W, -HALF_H), Vector2(HALF_W, -HALF_H),
		Vector2(HALF_W,  HALF_H),  Vector2(-HALF_W,  HALF_H),
	])
	floor_poly.color = _floor_color()
	add_child(floor_poly)

	_build_horiz_wall(-(HALF_H + WALL_T * 0.5), _active_doors.get("N", false))
	_build_horiz_wall( (HALF_H + WALL_T * 0.5), _active_doors.get("S", false))
	_build_vert_wall( -(HALF_W + WALL_T * 0.5), _active_doors.get("W", false))
	_build_vert_wall(  (HALF_W + WALL_T * 0.5), _active_doors.get("E", false))

	var top_face := Polygon2D.new()
	top_face.position = Vector2(0.0, -HALF_H)
	top_face.polygon = PackedVector2Array([
		Vector2(-(HALF_W + WALL_T), 0.0),
		Vector2( (HALF_W + WALL_T), 0.0),
		Vector2( (HALF_W + WALL_T), 50.0),
		Vector2(-(HALF_W + WALL_T), 50.0),
	])
	top_face.color = Color(0.38, 0.32, 0.24)
	add_child(top_face)

	_setup_doors()


func _floor_color() -> Color:
	match GameState.room_type:
		GameState.RoomType.WELCOME:
			return Color(0.20, 0.18, 0.26)
		GameState.RoomType.EXIT:
			return Color(0.14, 0.22, 0.20)
	return Color(0.27, 0.24, 0.20)


func _build_horiz_wall(cy: float, has_door: bool) -> void:
	var half_total := HALF_W + WALL_T
	if has_door:
		var dh := DOOR_W * 0.5
		var seg := half_total - dh
		_make_wall(Vector2(-(dh + seg * 0.5), cy), Vector2(seg, WALL_T))
		_make_wall(Vector2( (dh + seg * 0.5), cy), Vector2(seg, WALL_T))
	else:
		_make_wall(Vector2(0.0, cy), Vector2(half_total * 2.0, WALL_T))


func _build_vert_wall(cx: float, has_door: bool) -> void:
	var half_total := HALF_H + WALL_T
	if has_door:
		var dh := DOOR_W * 0.5
		var seg := half_total - dh
		_make_wall(Vector2(cx, -(dh + seg * 0.5)), Vector2(WALL_T, seg))
		_make_wall(Vector2(cx,  (dh + seg * 0.5)), Vector2(WALL_T, seg))
	else:
		_make_wall(Vector2(cx, 0.0), Vector2(WALL_T, half_total * 2.0))


func _make_wall(pos: Vector2, size: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.position = pos
	wall.collision_layer = 1
	wall.collision_mask = 0
	var hw := size.x * 0.5
	var hh := size.y * 0.5
	var vis := Polygon2D.new()
	vis.polygon = PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh),
	])
	vis.color = Color(0.20, 0.18, 0.16)
	wall.add_child(vis)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	wall.add_child(col)
	add_child(wall)


# ── Door setup ────────────────────────────────────────────────────────────────

func _door_wall_pos(dir: String) -> Vector2:
	match dir:
		"N": return Vector2(0,       -(HALF_H + WALL_T * 0.5))
		"S": return Vector2(0,        (HALF_H + WALL_T * 0.5))
		"W": return Vector2(-(HALF_W + WALL_T * 0.5), 0)
		"E": return Vector2( (HALF_W + WALL_T * 0.5), 0)
	return Vector2.ZERO


func _door_trigger_pos(dir: String) -> Vector2:
	match dir:
		"N": return Vector2(0,       -HALF_H + 18)
		"S": return Vector2(0,        HALF_H - 18)
		"W": return Vector2(-HALF_W + 18, 0)
		"E": return Vector2( HALF_W - 18, 0)
	return Vector2.ZERO


func _door_size(dir: String) -> Vector2:
	if dir == "N" or dir == "S":
		return Vector2(DOOR_W, WALL_T)
	return Vector2(WALL_T, DOOR_W)


func _setup_doors() -> void:
	# Doors are open immediately in welcome rooms and already-cleared rooms
	var open_immediately := _is_current_room_cleared()
	for dir: String in _active_doors:
		if not _active_doors[dir]:
			continue
		var wpos := _door_wall_pos(dir)
		var dsize := _door_size(dir)
		var hw := dsize.x * 0.5
		var hh := dsize.y * 0.5
		var verts := PackedVector2Array([
			Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)
		])

		var gap := Polygon2D.new()
		gap.position = wpos
		gap.polygon = verts
		gap.color = Color(0.10, 0.08, 0.07)
		add_child(gap)

		if open_immediately:
			_add_trigger(dir)
		else:
			var vis_block := Polygon2D.new()
			vis_block.position = wpos
			vis_block.polygon = verts
			vis_block.color = Color(0.48, 0.10, 0.08, 0.90)
			add_child(vis_block)
			_door_blockers.append(vis_block)

			var phys_block := StaticBody2D.new()
			phys_block.position = wpos
			phys_block.collision_layer = 1
			phys_block.collision_mask = 0
			var pcol := CollisionShape2D.new()
			var pshape := RectangleShape2D.new()
			pshape.size = dsize
			pcol.shape = pshape
			phys_block.add_child(pcol)
			add_child(phys_block)
			_door_blockers.append(phys_block)


func _add_trigger(dir: String) -> void:
	var area := Area2D.new()
	area.position = _door_trigger_pos(dir)
	area.collision_layer = 0
	area.collision_mask = 2
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = _door_size(dir)
	col.shape = shape
	area.add_child(col)
	area.body_entered.connect(func(body: Node) -> void:
		if body is Player:
			GameState.enter_combat_room(dir)
			get_tree().reload_current_scene()
	)
	add_child(area)


# ── Welcome room ──────────────────────────────────────────────────────────────

func _build_welcome_content() -> void:
	var cl := CanvasLayer.new()
	var lbl := Label.new()
	lbl.text = "Welcome to the dream."
	lbl.anchor_left   = 0.5
	lbl.anchor_top    = 0.5
	lbl.anchor_right  = 0.5
	lbl.anchor_bottom = 0.5
	lbl.offset_left   = -220.0
	lbl.offset_right  =  220.0
	lbl.offset_top    =  -20.0
	lbl.offset_bottom =   20.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", Color(0.88, 0.82, 0.96, 0.85))
	cl.add_child(lbl)
	add_child(cl)

	var tween := create_tween()
	tween.tween_interval(2.5)
	tween.tween_property(lbl, "modulate:a", 0.0, 1.0)


# ── Exit / portal room ────────────────────────────────────────────────────────

func _build_portal() -> void:
	var segments := 32
	var outer_r := 32.0
	var inner_r := 16.0

	var outer_pts := PackedVector2Array()
	var inner_pts := PackedVector2Array()
	for i in segments:
		var angle := i * TAU / segments
		outer_pts.append(Vector2(cos(angle) * outer_r, sin(angle) * outer_r))
		inner_pts.append(Vector2(cos(angle) * inner_r, sin(angle) * inner_r))

	var portal_area := Area2D.new()
	portal_area.position = Vector2.ZERO
	portal_area.collision_layer = 0
	portal_area.collision_mask = 2

	var outer_vis := Polygon2D.new()
	outer_vis.polygon = outer_pts
	outer_vis.color = Color(0.18, 0.82, 0.70, 0.80)
	portal_area.add_child(outer_vis)

	var inner_vis := Polygon2D.new()
	inner_vis.polygon = inner_pts
	inner_vis.color = Color(0.72, 1.00, 0.92, 0.95)
	portal_area.add_child(inner_vis)

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = outer_r
	col.shape = shape
	portal_area.add_child(col)

	portal_area.body_entered.connect(func(body: Node) -> void:
		if body is Player:
			player.set_physics_process(false)
			player.set_process_unhandled_input(false)
			var fcs := FloorClearScreen.new()
			add_child(fcs)
	)
	add_child(portal_area)

	var cl := CanvasLayer.new()
	var lbl := Label.new()
	lbl.text = "Portal to Floor %d" % (GameState.floor_number + 1)
	lbl.anchor_left   = 0.5
	lbl.anchor_top    = 0.5
	lbl.anchor_right  = 0.5
	lbl.anchor_bottom = 0.5
	lbl.offset_left   = -220.0
	lbl.offset_right  =  220.0
	lbl.offset_top    = -80.0
	lbl.offset_bottom = -44.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.50, 0.95, 0.80, 0.80))
	cl.add_child(lbl)
	add_child(cl)


# ── Player ────────────────────────────────────────────────────────────────────

func _build_player() -> void:
	player = PLAYER_SCENE.instantiate() as Player
	player.position = _player_spawn_pos(GameState.entry_direction)
	if GameState.player_health > 0:
		player.health = GameState.player_health
	add_child(player)


func _player_spawn_pos(entry_dir: String) -> Vector2:
	# Spawn far enough from each wall that the player's collision shape (25px half-height)
	# never overlaps door trigger areas (which sit ~18px from the wall interior).
	match entry_dir:
		"N": return Vector2(0.0,           HALF_H - 90.0)
		"S": return Vector2(0.0,          -(HALF_H - 90.0))
		"E": return Vector2(-(HALF_W - 90.0), 0.0)
		"W": return Vector2( (HALF_W - 90.0), 0.0)
	return Vector2.ZERO  # welcome room: center


# ── Enemies ───────────────────────────────────────────────────────────────────

func _build_enemies() -> void:
	enemies_node = Node2D.new()
	enemies_node.name = "Enemies"
	add_child(enemies_node)
	for pos in _enemy_positions():
		var e := KENJUTSU_SCENE.instantiate()
		e.position = pos
		enemies_node.add_child(e)


func _enemy_positions() -> Array[Vector2]:
	match GameState.room_type:
		GameState.RoomType.SMALL:
			return [Vector2(0, -120)]
		GameState.RoomType.MEDIUM:
			return [Vector2(250, 50), Vector2(-250, 50), Vector2(0, -180)]
		GameState.RoomType.LARGE:
			return [Vector2(280, 30), Vector2(-280, 30), Vector2(0, -200),
					Vector2(200, -130), Vector2(-200, -130)]
		GameState.RoomType.OBSTACLE:
			return [Vector2(220, 70), Vector2(-220, 70), Vector2(0, -170)]
		GameState.RoomType.AMBUSH:
			return [Vector2(100, 80), Vector2(-100, 80),
					Vector2(130, -60), Vector2(-130, -60), Vector2(0, 30)]
	return [Vector2(0, -120)]


# ── Obstacles (OBSTACLE room only) ────────────────────────────────────────────

func _build_obstacles() -> void:
	var spots: Array[Vector2] = [
		Vector2(140, 60), Vector2(-140, 60),
		Vector2(0, -110), Vector2(210, -110), Vector2(-210, -110),
	]
	for pos in spots:
		_make_pillar(pos)


func _make_pillar(pos: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	var r := 22.0
	var vis := Polygon2D.new()
	vis.polygon = PackedVector2Array([
		Vector2(-r, -r * 1.4), Vector2(r, -r * 1.4),
		Vector2(r,   r * 0.6), Vector2(-r,  r * 0.6),
	])
	vis.color = Color(0.30, 0.26, 0.20)
	body.add_child(vis)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(r * 2.0, r * 2.0)
	col.shape = shape
	body.add_child(col)
	add_child(body)


# ── Signals ───────────────────────────────────────────────────────────────────

func _connect_signals() -> void:
	player.health_changed.connect(func(current: int, _max: int) -> void:
		GameState.player_health = current
	)
	player.health_changed.connect(hud._on_player_health_changed)
	player.dash_cooldown_changed.connect(hud._on_player_dash_changed)
	player.died.connect(_on_player_died)
	hud._on_player_health_changed(player.health, player.max_health)
	hud._on_player_dash_changed(1.0)

	if enemies_node != null:
		room_cleared.connect(_on_room_cleared)
		for e in enemies_node.get_children():
			if e is Enemy:
				e.player = player
				e.died.connect(_on_enemy_died.bind(e))


func _on_room_cleared() -> void:
	var data = GameState.room_data.get(GameState.current_room_pos, null)
	if data:
		data.cleared = true
	for blocker in _door_blockers:
		if is_instance_valid(blocker):
			blocker.queue_free()
	_door_blockers.clear()
	for dir: String in _active_doors:
		if _active_doors[dir]:
			_add_trigger(dir)


func _on_enemy_died(_enemy: Node) -> void:
	await get_tree().process_frame
	var alive := enemies_node.get_children().filter(
		func(c: Node) -> bool: return c is Enemy and is_instance_valid(c)
	)
	if alive.is_empty():
		room_cleared.emit()


func _on_player_died() -> void:
	if enemies_node != null:
		for e in enemies_node.get_children():
			if is_instance_valid(e):
				e.set_physics_process(false)
	var game_over := GameOverScreen.new()
	add_child(game_over)
