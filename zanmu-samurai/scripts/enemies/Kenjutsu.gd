extends Enemy
class_name Kenjutsu

const AGGRO_RANGE := 280.0
const ATTACK_RANGE := 65.0
const TELEGRAPH_TIME := 0.25
const ATTACK_TIME := 0.15
const COOLDOWN_TIME := 1.0

@onready var telegraph_visual: Polygon2D = $TelegraphIndicator
@onready var slash_visual: Polygon2D = $SlashVisual

var slash_start_angle := 0.0
var locked_attack_dir := Vector2.RIGHT

func _ready() -> void:
	super()
	telegraph_visual.visible = false
	slash_visual.visible = false

func _update_state(_delta: float) -> void:
	match state:
		State.IDLE:
			velocity = Vector2.ZERO
			if is_instance_valid(player) and _dist_to_player() < AGGRO_RANGE:
				state = State.CHASE

		State.CHASE:
			if not is_instance_valid(player):
				state = State.IDLE
				return
			var dist := _dist_to_player()
			if dist <= ATTACK_RANGE:
				_enter_telegraph()
			elif dist > AGGRO_RANGE * 1.5:
				state = State.IDLE
				velocity = Vector2.ZERO
			else:
				velocity = _dir_to_player() * speed

		State.TELEGRAPH:
			velocity = locked_attack_dir * speed
			telegraph_visual.rotation = locked_attack_dir.angle()
			if state_timer <= 0.0:
				_enter_attack()

		State.ATTACK:
			velocity = locked_attack_dir * speed
			var t := 1.0 - state_timer / ATTACK_TIME
			slash_visual.rotation = slash_start_angle + t * PI * 0.8
			slash_visual.modulate.a = 1.0 if t < 0.55 else lerp(1.0, 0.0, (t - 0.55) / 0.45)
			if state_timer <= 0.0:
				telegraph_visual.visible = false
				slash_visual.visible = false
				slash_visual.modulate.a = 1.0
				state = State.COOLDOWN
				state_timer = COOLDOWN_TIME

		State.COOLDOWN:
			if is_instance_valid(player) and _dist_to_player() < AGGRO_RANGE:
				velocity = _dir_to_player() * speed * 0.4
			else:
				velocity = Vector2.ZERO
			if state_timer <= 0.0:
				state = State.CHASE if (is_instance_valid(player) and _dist_to_player() < AGGRO_RANGE) else State.IDLE

func _enter_telegraph() -> void:
	state = State.TELEGRAPH
	state_timer = TELEGRAPH_TIME
	locked_attack_dir = _dir_to_player()
	velocity = locked_attack_dir * speed
	telegraph_visual.visible = true
	telegraph_visual.rotation = locked_attack_dir.angle()

func _enter_attack() -> void:
	state = State.ATTACK
	state_timer = ATTACK_TIME
	slash_visual.visible = true
	slash_visual.modulate.a = 1.0
	slash_start_angle = locked_attack_dir.angle() - PI * 0.4
	slash_visual.rotation = slash_start_angle
	if is_instance_valid(player) and _dist_to_player() <= ATTACK_RANGE:
		player.take_damage(damage)
