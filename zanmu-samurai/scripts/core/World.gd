extends Node3D

const ROOM_SCENE := preload("res://scenes/Room.tscn")

const CAM_OFFSET := Vector3(10.0, 12.0, 10.0)

const ROOM_STEP := {
	"N": Vector3(0.0,  0.0, -12.0),
	"S": Vector3(0.0,  0.0,  12.0),
	"E": Vector3(18.0, 0.0,  0.0),
	"W": Vector3(-18.0, 0.0, 0.0),
}

var camera: Camera3D
var hud: HUD
var current_room: Room = null
var _transitioning := false
var _loaded_rooms: Dictionary = {}
var _music: AudioStreamPlayer


func _ready() -> void:
	_setup_environment()
	_setup_camera()
	_setup_music()
	hud = HUD.new()
	add_child(hud)
	_load_room(Vector3.ZERO)
	await get_tree().process_frame
	get_viewport().grab_focus()
	_fade_in_scene()


func _setup_environment() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode      = Environment.BG_COLOR
	env.background_color     = Color(0.08, 0.08, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color(0.35, 0.32, 0.42)
	env.ambient_light_energy = 0.45
	env.ssao_enabled = false
	env.ssil_enabled = false
	env.sdfgi_enabled = false
	env_node.environment = env
	add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0, -25.0, 0.0)
	sun.light_energy     = 1.2
	sun.light_color      = Color(1.0, 0.93, 0.80)
	sun.shadow_enabled   = false
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, 155.0, 0.0)
	fill.light_energy     = 0.28
	fill.light_color      = Color(0.65, 0.75, 1.0)
	fill.shadow_enabled   = false
	add_child(fill)


func _setup_music() -> void:
	_music = AudioStreamPlayer.new()
	_music.stream = load("res://music/game music/just-forget.mp3")
	_music.volume_db = -80.0
	_music.autoplay = false
	add_child(_music)
	_music.play()
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", 0.0, 5.0).set_trans(Tween.TRANS_LINEAR)


func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.fov     = 52.0
	camera.current = true
	camera.position = CAM_OFFSET
	add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.UP)


func _load_room(origin: Vector3) -> void:
	var room := ROOM_SCENE.instantiate() as Room
	room.position = origin
	add_child(room)
	current_room = room
	_loaded_rooms[origin] = room
	_connect_room(room)


func _connect_room(room: Room) -> void:
	if not room.transition_requested.is_connected(_begin_transition):
		room.transition_requested.connect(_begin_transition)
	if room.player == null:
		return
	_connect_player(room.player)


func _connect_player(p: Player) -> void:
	p.health_changed.connect(func(c: int, m: int) -> void: GameState.player_health = c)
	p.health_changed.connect(hud._on_player_health_changed)
	p.dash_cooldown_changed.connect(hud._on_player_dash_changed)
	p.died.connect(_on_player_died)
	hud._on_player_health_changed(p.health, p.max_health)
	hud._on_player_dash_changed(1.0)


func _begin_transition(exit_dir: String) -> void:
	if _transitioning:
		return
	_transitioning = true

	if current_room.player:
		current_room.player.queue_free()
		current_room.player = null

	GameState.enter_combat_room(exit_dir)

	var old_origin := current_room.position
	var new_origin: Vector3 = old_origin + ROOM_STEP[exit_dir]

	# Reuse the room if already loaded, otherwise build it
	var new_room: Room
	if _loaded_rooms.has(new_origin):
		new_room = _loaded_rooms[new_origin]
	else:
		new_room = ROOM_SCENE.instantiate() as Room
		new_room.skip_player = true
		new_room.position    = new_origin
		add_child(new_room)
		_loaded_rooms[new_origin] = new_room

	var old_cam := old_origin + CAM_OFFSET
	var new_cam := new_origin + CAM_OFFSET

	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(
		func(t: float) -> void:
			camera.position = old_cam.lerp(new_cam, t)
			camera.look_at(old_origin.lerp(new_origin, t), Vector3.UP),
		0.0, 1.0, 0.6
	)
	tw.tween_callback(func() -> void: _finish_transition(new_room, new_origin))


func _finish_transition(new_room: Room, new_origin: Vector3) -> void:
	# Old room stays in the world at its position — not freed
	camera.position = new_origin + CAM_OFFSET
	camera.look_at(new_origin, Vector3.UP)

	new_room.spawn_player()
	current_room = new_room
	_connect_room(new_room)
	_transitioning = false


func _fade_in_scene() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 100
	add_child(cl)
	var rect := ColorRect.new()
	rect.color = Color(0.0, 0.0, 0.0, 1.0)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	cl.add_child(rect)
	var tw := create_tween()
	tw.tween_property(rect, "color:a", 0.0, 5.0).set_trans(Tween.TRANS_LINEAR)
	tw.tween_callback(cl.queue_free)


func _on_player_died() -> void:
	var game_over := GameOverScreen.new()
	add_child(game_over)
