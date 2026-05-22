extends Node3D
class_name Room

signal room_cleared
signal transition_requested(direction: String)

const PLAYER_SCENE    := preload("res://scenes/Player.tscn")
const KENJUTSU_SCENE  := preload("res://scenes/enemies/Kenjutsu.tscn")
const OUTLINE_SHADER  := preload("res://shaders/outline.gdshader")
const TOON_SHADER     := preload("res://shaders/toon.gdshader")

# Room dimensions in 3D units (original pixel values / 50)
const HALF_W := 8.0    # was 400 px
const HALF_H := 5.2    # was 260 px
const WALL_T := 0.8    # was 40 px — wall thickness
const WALL_H := 2.5    # wall height (new 3D axis)
const DOOR_W := 1.4    # was 70 px — door opening width
const DOOR_H := 2.0    # door opening height (leaves a 0.5-unit lintel)

var player = null
var enemies_node: Node3D
var skip_player := false

var _active_doors: Dictionary = {}
var _door_blockers: Array[Node] = []


func _ready() -> void:
	_roll_doors()
	_build_environment()
	if not skip_player:
		_build_player()
	if GameState.room_type == GameState.RoomType.WELCOME and GameState.floor_number == 1:
		_build_welcome_content()
	elif GameState.room_type == GameState.RoomType.EXIT:
		_build_portal()
	elif not _is_current_room_cleared():
		_build_enemies()
	if not skip_player:
		_connect_signals()


func _is_current_room_cleared() -> bool:
	var data = GameState.room_data.get(GameState.current_room_pos, null)
	return data != null and data.get("cleared", false)


# ── Doors (layout from GameState, not re-rolled) ──────────────────────────────

func _roll_doors() -> void:
	var data = GameState.room_data.get(GameState.current_room_pos, null)
	if data:
		_active_doors = data.doors.duplicate()
	else:
		_active_doors = {"N": true, "S": true, "E": true, "W": true}


# ── Environment ───────────────────────────────────────────────────────────────

func _build_environment() -> void:
	_build_floor()
	_build_north_wall(_active_doors.get("N", false))
	_build_south_wall(_active_doors.get("S", false))
	_build_east_wall(_active_doors.get("E", false))
	_build_west_wall(_active_doors.get("W", false))
	_setup_doors()


func _build_floor() -> void:
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.position = Vector3(0.0, -0.05, 0.0)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(HALF_W * 2.0, 0.1, HALF_H * 2.0)
	mesh_inst.mesh = mesh
	mesh_inst.material_override = _flat_material(_floor_color())
	add_child(mesh_inst)


func _floor_color() -> Color:
	match GameState.room_type:
		GameState.RoomType.WELCOME:
			return Color(0.20, 0.18, 0.26)
		GameState.RoomType.EXIT:
			return Color(0.14, 0.22, 0.20)
	return Color(0.27, 0.24, 0.20)


# ── Walls ─────────────────────────────────────────────────────────────────────

func _build_north_wall(has_door: bool) -> void:
	var z := -(HALF_H + WALL_T * 0.5)
	var full_w := (HALF_W + WALL_T) * 2.0
	if has_door:
		var dh := DOOR_W * 0.5
		var seg := (HALF_W + WALL_T) - dh
		_make_wall_3d(Vector3(-(dh + seg * 0.5), WALL_H * 0.5, z), Vector3(seg, WALL_H, WALL_T))
		_make_wall_3d(Vector3( (dh + seg * 0.5), WALL_H * 0.5, z), Vector3(seg, WALL_H, WALL_T))
		_make_wall_3d(Vector3(0.0, DOOR_H + (WALL_H - DOOR_H) * 0.5, z), Vector3(DOOR_W, WALL_H - DOOR_H, WALL_T))
	else:
		_make_wall_3d(Vector3(0.0, WALL_H * 0.5, z), Vector3(full_w, WALL_H, WALL_T))


func _build_south_wall(has_door: bool) -> void:
	var z := (HALF_H + WALL_T * 0.5)
	var full_w := (HALF_W + WALL_T) * 2.0
	if has_door:
		var dh := DOOR_W * 0.5
		var seg := (HALF_W + WALL_T) - dh
		_make_wall_3d(Vector3(-(dh + seg * 0.5), WALL_H * 0.5, z), Vector3(seg, WALL_H, WALL_T))
		_make_wall_3d(Vector3( (dh + seg * 0.5), WALL_H * 0.5, z), Vector3(seg, WALL_H, WALL_T))
		_make_wall_3d(Vector3(0.0, DOOR_H + (WALL_H - DOOR_H) * 0.5, z), Vector3(DOOR_W, WALL_H - DOOR_H, WALL_T))
	else:
		_make_wall_3d(Vector3(0.0, WALL_H * 0.5, z), Vector3(full_w, WALL_H, WALL_T))


func _build_east_wall(has_door: bool) -> void:
	var x := (HALF_W + WALL_T * 0.5)
	var full_h := (HALF_H + WALL_T) * 2.0
	if has_door:
		var dh := DOOR_W * 0.5
		var seg := (HALF_H + WALL_T) - dh
		_make_wall_3d(Vector3(x, WALL_H * 0.5, -(dh + seg * 0.5)), Vector3(WALL_T, WALL_H, seg))
		_make_wall_3d(Vector3(x, WALL_H * 0.5,  (dh + seg * 0.5)), Vector3(WALL_T, WALL_H, seg))
		_make_wall_3d(Vector3(x, DOOR_H + (WALL_H - DOOR_H) * 0.5, 0.0), Vector3(WALL_T, WALL_H - DOOR_H, DOOR_W))
	else:
		_make_wall_3d(Vector3(x, WALL_H * 0.5, 0.0), Vector3(WALL_T, WALL_H, full_h))


func _build_west_wall(has_door: bool) -> void:
	var x := -(HALF_W + WALL_T * 0.5)
	var full_h := (HALF_H + WALL_T) * 2.0
	if has_door:
		var dh := DOOR_W * 0.5
		var seg := (HALF_H + WALL_T) - dh
		_make_wall_3d(Vector3(x, WALL_H * 0.5, -(dh + seg * 0.5)), Vector3(WALL_T, WALL_H, seg))
		_make_wall_3d(Vector3(x, WALL_H * 0.5,  (dh + seg * 0.5)), Vector3(WALL_T, WALL_H, seg))
		_make_wall_3d(Vector3(x, DOOR_H + (WALL_H - DOOR_H) * 0.5, 0.0), Vector3(WALL_T, WALL_H - DOOR_H, DOOR_W))
	else:
		_make_wall_3d(Vector3(x, WALL_H * 0.5, 0.0), Vector3(WALL_T, WALL_H, full_h))


func _make_wall_3d(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0

	var mesh_inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_inst.mesh = mesh
	mesh_inst.material_override = _flat_material(Color(0.20, 0.18, 0.16))
	body.add_child(mesh_inst)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	add_child(body)


# ── Door setup ────────────────────────────────────────────────────────────────

func _door_wall_pos(dir: String) -> Vector3:
	match dir:
		"N": return Vector3(0.0,  DOOR_H * 0.5, -(HALF_H + WALL_T * 0.5))
		"S": return Vector3(0.0,  DOOR_H * 0.5,  (HALF_H + WALL_T * 0.5))
		"E": return Vector3( (HALF_W + WALL_T * 0.5), DOOR_H * 0.5, 0.0)
		"W": return Vector3(-(HALF_W + WALL_T * 0.5), DOOR_H * 0.5, 0.0)
	return Vector3.ZERO


func _door_trigger_pos(dir: String) -> Vector3:
	var inset := 0.36
	match dir:
		"N": return Vector3(0.0,  DOOR_H * 0.5, -HALF_H + inset)
		"S": return Vector3(0.0,  DOOR_H * 0.5,  HALF_H - inset)
		"E": return Vector3( HALF_W - inset, DOOR_H * 0.5, 0.0)
		"W": return Vector3(-HALF_W + inset, DOOR_H * 0.5, 0.0)
	return Vector3.ZERO


func _door_size(dir: String) -> Vector3:
	if dir == "N" or dir == "S":
		return Vector3(DOOR_W, DOOR_H, WALL_T)
	return Vector3(WALL_T, DOOR_H, DOOR_W)


func _setup_doors() -> void:
	var open_immediately := _is_current_room_cleared()
	for dir: String in _active_doors:
		if not _active_doors[dir]:
			continue
		if open_immediately:
			_add_trigger(dir)
		else:
			var dsize := _door_size(dir)
			var dpos  := _door_wall_pos(dir)

			var vis_block := MeshInstance3D.new()
			vis_block.position = dpos
			var bmesh := BoxMesh.new()
			bmesh.size = dsize
			vis_block.mesh = bmesh
			vis_block.material_override = _flat_material(Color(0.48, 0.10, 0.08))
			add_child(vis_block)
			_door_blockers.append(vis_block)

			var phys_block := StaticBody3D.new()
			phys_block.position = dpos
			phys_block.collision_layer = 1
			phys_block.collision_mask = 0
			var pcol := CollisionShape3D.new()
			var pshape := BoxShape3D.new()
			pshape.size = dsize
			pcol.shape = pshape
			phys_block.add_child(pcol)
			add_child(phys_block)
			_door_blockers.append(phys_block)


func _add_trigger(dir: String) -> void:
	var area := Area3D.new()
	area.position = _door_trigger_pos(dir)
	area.collision_layer = 0
	area.collision_mask = 2
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = _door_size(dir)
	col.shape = shape
	area.add_child(col)
	area.body_entered.connect(func(body: Node) -> void:
		if body.is_in_group("player"):
			transition_requested.emit(dir)
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
	var portal_node := Node3D.new()
	portal_node.position = Vector3.ZERO
	add_child(portal_node)

	var outer := MeshInstance3D.new()
	var outer_mesh := CylinderMesh.new()
	outer_mesh.top_radius = 0.72
	outer_mesh.bottom_radius = 0.72
	outer_mesh.height = 0.08
	outer_mesh.radial_segments = 32
	outer.mesh = outer_mesh
	outer.position = Vector3(0.0, 0.04, 0.0)
	outer.material_override = _flat_material(Color(0.18, 0.82, 0.70), true)
	portal_node.add_child(outer)

	var inner := MeshInstance3D.new()
	var inner_mesh := CylinderMesh.new()
	inner_mesh.top_radius = 0.36
	inner_mesh.bottom_radius = 0.36
	inner_mesh.height = 0.10
	inner_mesh.radial_segments = 32
	inner.mesh = inner_mesh
	inner.position = Vector3(0.0, 0.05, 0.0)
	inner.material_override = _flat_material(Color(0.72, 1.00, 0.92), true)
	portal_node.add_child(inner)

	var portal_area := Area3D.new()
	portal_area.collision_layer = 0
	portal_area.collision_mask = 2
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.72
	shape.height = 0.5
	col.shape = shape
	portal_area.add_child(col)
	portal_area.body_entered.connect(func(body: Node) -> void:
		if body.is_in_group("player") and player != null:
			player.set_physics_process(false)
			player.set_process_unhandled_input(false)
			var fcs := FloorClearScreen.new()
			add_child(fcs)
	)
	portal_node.add_child(portal_area)

	var lbl := Label3D.new()
	lbl.text = "Portal to Floor %d" % (GameState.floor_number + 1)
	lbl.position = Vector3(0.0, 1.6, 0.0)
	lbl.font_size = 48
	lbl.modulate = Color(0.50, 0.95, 0.80, 0.90)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	portal_node.add_child(lbl)


# ── Player ────────────────────────────────────────────────────────────────────

func _build_player() -> void:
	player = PLAYER_SCENE.instantiate()
	player.position = _player_spawn_pos(GameState.entry_direction)
	if GameState.player_health > 0:
		player.health = GameState.player_health
	add_child(player)


func spawn_player() -> void:
	_build_player()
	player.died.connect(_on_player_died)
	if enemies_node != null:
		if not room_cleared.is_connected(_on_room_cleared):
			room_cleared.connect(_on_room_cleared)
		for e in enemies_node.get_children():
			if e is Kenjutsu:
				e.player = player
				e.died.connect(_on_enemy_died.bind(e))


func _player_spawn_pos(entry_dir: String) -> Vector3:
	match entry_dir:
		"N": return Vector3(0.0, 0.0,  HALF_H - 1.8)
		"S": return Vector3(0.0, 0.0, -(HALF_H - 1.8))
		"E": return Vector3(-(HALF_W - 1.8), 0.0, 0.0)
		"W": return Vector3( (HALF_W - 1.8), 0.0, 0.0)
	return Vector3.ZERO


# ── Enemies ───────────────────────────────────────────────────────────────────

func _build_enemies() -> void:
	enemies_node = Node3D.new()
	add_child(enemies_node)
	for pos in _enemy_positions():
		var enemy: Kenjutsu = KENJUTSU_SCENE.instantiate()
		enemy.position = pos
		enemies_node.add_child(enemy)


func _enemy_positions() -> Array[Vector3]:
	match GameState.room_type:
		GameState.RoomType.SMALL:
			return [Vector3(0.0, 0.0, -2.4)]
		GameState.RoomType.MEDIUM:
			return [Vector3(5.0, 0.0, 1.0), Vector3(-5.0, 0.0, 1.0), Vector3(0.0, 0.0, -3.6)]
		GameState.RoomType.LARGE:
			return [Vector3(5.6, 0.0, 0.6), Vector3(-5.6, 0.0, 0.6), Vector3(0.0, 0.0, -4.0),
					Vector3(4.0, 0.0, -2.6), Vector3(-4.0, 0.0, -2.6)]
		GameState.RoomType.OBSTACLE:
			return [Vector3(4.4, 0.0, 1.4), Vector3(-4.4, 0.0, 1.4), Vector3(0.0, 0.0, -3.4)]
		GameState.RoomType.AMBUSH:
			return [Vector3(2.0, 0.0, 1.6), Vector3(-2.0, 0.0, 1.6),
					Vector3(2.6, 0.0, -1.2), Vector3(-2.6, 0.0, -1.2), Vector3(0.0, 0.0, 0.6)]
	return [Vector3(0.0, 0.0, -2.4)]


# ── Obstacles ─────────────────────────────────────────────────────────────────

func _build_obstacles() -> void:
	pass  # Phase 3: BoxMesh StaticBody3D pillars


# ── Signals ───────────────────────────────────────────────────────────────────

func _connect_signals() -> void:
	player.died.connect(_on_player_died)

	if enemies_node != null:
		room_cleared.connect(_on_room_cleared)
		for e in enemies_node.get_children():
			if e is Kenjutsu:
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
		func(c: Node) -> bool: return c is Kenjutsu and is_instance_valid(c)
	)
	if alive.is_empty():
		room_cleared.emit()


func _on_player_died() -> void:
	if enemies_node != null:
		for e in enemies_node.get_children():
			if is_instance_valid(e):
				e.set_physics_process(false)


# ── Utilities ─────────────────────────────────────────────────────────────────

func _flat_material(color: Color, unshaded: bool = false) -> Material:
	if unshaded:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		return mat
	var mat := ShaderMaterial.new()
	mat.shader = TOON_SHADER
	mat.set_shader_parameter("albedo", color)
	return mat
