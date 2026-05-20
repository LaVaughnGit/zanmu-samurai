extends CharacterBody2D
class_name Enemy

signal died

enum State { IDLE, CHASE, TELEGRAPH, ATTACK, COOLDOWN }

var max_health: int = 3
var health: int = 3
var damage: int = 1
var speed: float = 120.0
var state: State = State.IDLE
var state_timer: float = 0.0
var player = null

@onready var visual: Polygon2D = $Visual
var base_color: Color
var hit_flash_timer := 0.0

func _ready() -> void:
	add_to_group("enemies")
	base_color = visual.color

func _physics_process(delta: float) -> void:
	state_timer -= delta
	if hit_flash_timer > 0.0:
		hit_flash_timer -= delta
		if hit_flash_timer <= 0.0:
			visual.color = base_color
	_update_state(delta)
	move_and_slide()

func _update_state(_delta: float) -> void:
	pass

func take_damage(amount: int) -> void:
	health = max(0, health - amount)
	visual.color = Color(1.0, 1.0, 1.0)
	hit_flash_timer = 0.12
	if health <= 0:
		_die()

func _die() -> void:
	died.emit()
	queue_free()

func _dist_to_player() -> float:
	if not is_instance_valid(player):
		return INF
	return global_position.distance_to(player.global_position)

func _dir_to_player() -> Vector2:
	if not is_instance_valid(player):
		return Vector2.ZERO
	return (player.global_position - global_position).normalized()
