extends CharacterBody2D
class_name Player

signal health_changed(current: int, maximum: int)
signal dash_cooldown_changed(ratio: float)
signal died

const SPEED := 250.0
const DASH_SPEED := 500.0
const DASH_DURATION := 0.15
const DASH_COOLDOWN := 0.8
const ATTACK_DURATION := 0.25
const ATTACK_DAMAGE := 1

var max_health := 3
var health := 3
var facing := Vector2.RIGHT
var is_dashing := false
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var is_attacking := false
var attack_timer := 0.0
var is_invincible := false
var hit_invincibility_timer := 0.0
var hit_flash_timer := 0.0

@onready var visual: Polygon2D = $Visual
@onready var attack_area: Area2D = $AttackArea
@onready var attack_collision: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var attack_visual: Polygon2D = $AttackVisual

var attack_visual_timer := 0.0
var attack_start_angle := 0.0

func _ready() -> void:
	attack_collision.disabled = true
	attack_area.monitoring = false
	attack_area.body_entered.connect(_on_attack_hit)
	attack_visual.visible = false

func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	_tick_timers(delta)
	_handle_movement(delta)
	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if health <= 0:
		return
	if event.is_action_pressed("attack") and not is_attacking:
		_do_attack()
	if event.is_action_pressed("dash") and not is_dashing and dash_cooldown_timer <= 0.0:
		_do_dash()

func _handle_movement(delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if is_dashing:
		velocity = facing * DASH_SPEED
	elif dir != Vector2.ZERO:
		facing = dir.normalized()
		velocity = dir * SPEED
		if is_attacking:
			attack_area.position = facing * 48.0
	else:
		velocity = velocity.move_toward(Vector2.ZERO, SPEED * 8.0 * delta)

func _tick_timers(delta: float) -> void:
	if dash_timer > 0.0:
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
			collision_mask = 5
			collision_layer = 2

	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta
		if dash_cooldown_timer <= 0.0:
			dash_cooldown_timer = 0.0
			dash_cooldown_changed.emit(1.0)
		else:
			dash_cooldown_changed.emit(1.0 - dash_cooldown_timer / DASH_COOLDOWN)

	if hit_invincibility_timer > 0.0:
		hit_invincibility_timer -= delta
	is_invincible = dash_timer > 0.0 or hit_invincibility_timer > 0.0

	if attack_timer > 0.0:
		attack_timer -= delta
		if attack_timer <= 0.0:
			_end_attack()

	if attack_visual_timer > 0.0:
		attack_visual_timer -= delta
		var t := 1.0 - attack_visual_timer / ATTACK_DURATION
		attack_visual.rotation = attack_start_angle + t * PI * 0.8
		attack_visual.modulate.a = 1.0 if t < 0.55 else lerp(1.0, 0.0, (t - 0.55) / 0.45)
		if attack_visual_timer <= 0.0:
			attack_visual.visible = false
			attack_visual.modulate.a = 1.0

	if hit_flash_timer > 0.0:
		hit_flash_timer -= delta
		visual.visible = fmod(hit_flash_timer, 0.2) > 0.1
		if hit_flash_timer <= 0.0:
			visual.visible = true

func _do_attack() -> void:
	is_attacking = true
	attack_timer = ATTACK_DURATION
	attack_area.position = facing * 48.0
	attack_collision.disabled = false
	attack_area.monitoring = true
	attack_start_angle = facing.angle() - PI * 0.4
	attack_visual.rotation = attack_start_angle
	attack_visual.modulate.a = 1.0
	attack_visual.visible = true
	attack_visual_timer = ATTACK_DURATION

func _end_attack() -> void:
	is_attacking = false
	attack_collision.disabled = true
	attack_area.monitoring = false

func _do_dash() -> void:
	is_dashing = true
	dash_timer = DASH_DURATION
	dash_cooldown_timer = DASH_COOLDOWN
	dash_cooldown_changed.emit(0.0)
	collision_mask = 1
	collision_layer = 0

func _on_attack_hit(body: Node) -> void:
	if body.is_in_group("enemies"):
		body.take_damage(999 if GameState.debug_mode else ATTACK_DAMAGE)
		attack_collision.disabled = true
		attack_area.monitoring = false

func take_damage(amount: int) -> void:
	if is_invincible or GameState.debug_mode:
		return
	health = max(0, health - amount)
	health_changed.emit(health, max_health)
	hit_invincibility_timer = 0.8
	hit_flash_timer = 0.8
	if health <= 0:
		_on_death()

func _on_death() -> void:
	visual.visible = true
	set_physics_process(false)
	set_process_unhandled_input(false)
	died.emit()
