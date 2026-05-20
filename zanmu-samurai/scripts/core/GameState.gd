extends Node

enum RoomType { WELCOME, SMALL, MEDIUM, LARGE, OBSTACLE, AMBUSH, EXIT }

var room_type: RoomType = RoomType.WELCOME
var rng := RandomNumberGenerator.new()

var player_health: int = -1
var debug_mode: bool = false
var floor_number: int = 1
var rooms_on_floor: int = 8
var rooms_visited: int = 0
var current_room_pos: Vector2i = Vector2i(0, 0)
var entry_direction: String = ""

# Maps Vector2i → {type: RoomType, doors: Dictionary, cleared: bool}
# Fully populated at floor start — all rooms exist before the player visits them.
var room_data: Dictionary = {}
# Maps Vector2i → RoomType for rooms the player has actually entered (minimap fog).
var visited_rooms: Dictionary = {}

func _ready() -> void:
	rng.randomize()
	_init_floor()

func _init_floor() -> void:
	rooms_on_floor = rng.randi_range(7, 9)
	rooms_visited = 0
	current_room_pos = Vector2i(0, 0)
	entry_direction = ""
	room_data = {}
	visited_rooms = {}
	_generate_floor()

func _generate_floor() -> void:
	var dirs: Array[String] = ["N", "S", "E", "W"]

	# Random-walk growth — start at origin and expand one room at a time.
	var positions: Array[Vector2i] = [Vector2i(0, 0)]
	var position_set: Dictionary = {Vector2i(0, 0): true}
	var max_attempts := rooms_on_floor * 30

	var attempts := 0
	while positions.size() < rooms_on_floor and attempts < max_attempts:
		attempts += 1
		var source := positions[rng.randi_range(0, positions.size() - 1)]
		var d := dirs[rng.randi_range(0, 3)]
		var new_pos := source + _dir_offset(d)
		if not position_set.has(new_pos):
			positions.append(new_pos)
			position_set[new_pos] = true

	# Assign types: first = welcome, last = exit, everything else = random combat.
	for i in positions.size():
		var pos := positions[i]
		var rt: RoomType
		if i == 0:
			rt = RoomType.WELCOME
		elif i == positions.size() - 1:
			rt = RoomType.EXIT
		else:
			rt = rng.randi_range(RoomType.SMALL, RoomType.AMBUSH) as RoomType

		# Doors connect to every placed neighbor so the graph is always fully traversable.
		var doors := {"N": false, "S": false, "E": false, "W": false}
		for d in dirs:
			if position_set.has(pos + _dir_offset(d)):
				doors[d] = true

		room_data[pos] = {
			"type": rt,
			"doors": doors,
			"cleared": rt == RoomType.WELCOME or rt == RoomType.EXIT
		}

	# Player starts in the welcome room.
	visited_rooms[Vector2i(0, 0)] = RoomType.WELCOME

func enter_combat_room(direction: String) -> void:
	var new_pos := current_room_pos + _dir_offset(direction)
	current_room_pos = new_pos
	entry_direction = direction
	# Room already exists from pre-generation; just restore its type.
	room_type = room_data.get(new_pos, {}).get("type", RoomType.SMALL)
	rooms_visited += 1
	if not visited_rooms.has(new_pos):
		visited_rooms[new_pos] = room_type

func _dir_offset(dir: String) -> Vector2i:
	match dir:
		"N": return Vector2i(0, -1)
		"S": return Vector2i(0, 1)
		"E": return Vector2i(1, 0)
		"W": return Vector2i(-1, 0)
	return Vector2i.ZERO

func _opposite_dir(dir: String) -> String:
	match dir:
		"N": return "S"
		"S": return "N"
		"E": return "W"
		"W": return "E"
	return "N"

func next_floor() -> void:
	floor_number += 1
	room_type = RoomType.WELCOME
	_init_floor()

func reset() -> void:
	player_health = -1
	floor_number = 1
	room_type = RoomType.WELCOME
	_init_floor()
