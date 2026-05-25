extends CharacterBody3D
class_name Kenjutsu

const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")
const TOON_SHADER    := preload("res://shaders/toon.gdshader")
const SLASH_SFX      := preload("res://music/sound effects/enemy-sword-slash.mp3")

signal died

enum State { IDLE, CHASE, TELEGRAPH, ATTACK, COOLDOWN }

const AGGRO_RANGE    := 5.6
const ATTACK_RANGE   := 1.3
const TELEGRAPH_TIME := 0.25
const ATTACK_TIME    := 0.15
const COOLDOWN_TIME  := 1.0

var max_health: int = 3
var health: int = 3
var damage: int = 1
var speed: float = 2.4
var state: State = State.IDLE
var state_timer: float = 0.0
var player = null

var visual:            MeshInstance3D
var telegraph_visual:  MeshInstance3D
var slash_visual:      MeshInstance3D
var _mat:              ShaderMaterial
var _slash_mat:        StandardMaterial3D

var base_color        := Color(0.78, 0.14, 0.14)
var hit_flash_timer   := 0.0
var locked_attack_dir := Vector3.RIGHT
var _attack_hit       := false
var _slash_sfx:        AudioStreamPlayer


func _ready() -> void:
	add_to_group("enemies")
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	_build_nodes()
	_slash_sfx = AudioStreamPlayer.new()
	_slash_sfx.stream = SLASH_SFX
	add_child(_slash_sfx)


func _build_nodes() -> void:
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.28
	shape.height = 0.9
	col.shape = shape
	col.position = Vector3(0.0, 0.5, 0.0)
	add_child(col)

	visual = MeshInstance3D.new()
	visual.position = Vector3(0.0, 0.55, 0.0)
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.28
	mesh.height = 0.9
	visual.mesh = mesh
	_mat = ShaderMaterial.new()
	_mat.shader = TOON_SHADER
	_mat.set_shader_parameter("albedo", base_color)
	visual.material_override = _mat
	add_child(visual)

	telegraph_visual = MeshInstance3D.new()
	var t_mesh := CylinderMesh.new()
	t_mesh.top_radius    = 0.55
	t_mesh.bottom_radius = 0.55
	t_mesh.height        = 0.04
	t_mesh.radial_segments = 16
	telegraph_visual.mesh = t_mesh
	var t_mat := StandardMaterial3D.new()
	t_mat.albedo_color = Color(1.0, 0.55, 0.1, 0.6)
	t_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	t_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	telegraph_visual.material_override = t_mat
	telegraph_visual.visible = false
	add_child(telegraph_visual)

	slash_visual = MeshInstance3D.new()
	var s_mesh := SphereMesh.new()
	s_mesh.radius = 0.45
	s_mesh.height = 0.9
	slash_visual.mesh = s_mesh
	_slash_mat = StandardMaterial3D.new()
	_slash_mat.albedo_color = Color(0.95, 0.2, 0.1, 0.9)
	_slash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_slash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	slash_visual.material_override = _slash_mat
	slash_visual.position = Vector3(0.0, 0.5, 0.0)
	slash_visual.visible = false
	add_child(slash_visual)


func _physics_process(delta: float) -> void:
	state_timer -= delta
	if hit_flash_timer > 0.0:
		hit_flash_timer -= delta
		if hit_flash_timer <= 0.0:
			_mat.set_shader_parameter("albedo", base_color)
	_update_state()
	velocity.y = 0.0
	move_and_slide()


func _update_state() -> void:
	match state:
		State.IDLE:
			velocity = Vector3.ZERO
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
				velocity = Vector3.ZERO
			else:
				velocity = _dir_to_player() * speed

		State.TELEGRAPH:
			velocity = locked_attack_dir * speed
			telegraph_visual.position = locked_attack_dir * 0.9 + Vector3(0.0, 0.02, 0.0)
			if state_timer <= 0.0:
				_enter_attack()

		State.ATTACK:
			velocity = locked_attack_dir * speed
			# Keep slash aligned with the telegraph disc as the enemy lunges
			slash_visual.position = locked_attack_dir * 0.9 + Vector3(0.0, 0.5, 0.0)
			# Continuous overlap check from slash world centre — hit once per swing
			if not _attack_hit and is_instance_valid(player):
				var slash_world := global_position + locked_attack_dir * 0.9
				var dx: float = slash_world.x - player.global_position.x
				var dz: float = slash_world.z - player.global_position.z
				if sqrt(dx * dx + dz * dz) <= 0.75:  # slash radius 0.45 + player radius 0.3
					player.take_damage(damage)
					_attack_hit = true
			var t := 1.0 - state_timer / ATTACK_TIME
			_slash_mat.albedo_color.a = 1.0 if t < 0.55 else lerpf(1.0, 0.0, (t - 0.55) / 0.45)
			if state_timer <= 0.0:
				telegraph_visual.visible = false
				slash_visual.visible = false
				state = State.COOLDOWN
				state_timer = COOLDOWN_TIME

		State.COOLDOWN:
			if is_instance_valid(player) and _dist_to_player() < AGGRO_RANGE:
				velocity = _dir_to_player() * speed * 0.4
			else:
				velocity = Vector3.ZERO
			if state_timer <= 0.0:
				state = State.CHASE if (is_instance_valid(player) and _dist_to_player() < AGGRO_RANGE) else State.IDLE


func _enter_telegraph() -> void:
	state = State.TELEGRAPH
	state_timer = TELEGRAPH_TIME
	locked_attack_dir = _dir_to_player()
	velocity = locked_attack_dir * speed
	telegraph_visual.visible = true
	telegraph_visual.position = locked_attack_dir * 0.9 + Vector3(0.0, 0.02, 0.0)
	_slash_sfx.play()


func _enter_attack() -> void:
	state = State.ATTACK
	state_timer = ATTACK_TIME
	_attack_hit = false
	slash_visual.position = locked_attack_dir * 0.9 + Vector3(0.0, 0.5, 0.0)
	slash_visual.visible = true
	_slash_mat.albedo_color.a = 1.0


func _add_outline(mesh_inst: MeshInstance3D, width: float) -> void:
	var outline := MeshInstance3D.new()
	outline.mesh = mesh_inst.mesh
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = OUTLINE_SHADER
	mat.set_shader_parameter("width", width)
	mat.set_shader_parameter("outline_color", Color(0.06, 0.04, 0.08))
	outline.material_override = mat
	mesh_inst.add_child(outline)


func take_damage(amount: int) -> void:
	health = max(0, health - amount)
	_mat.set_shader_parameter("albedo", Color(1.0, 1.0, 1.0))
	hit_flash_timer = 0.12
	if health <= 0:
		died.emit()
		queue_free()


func _dist_to_player() -> float:
	if not is_instance_valid(player):
		return INF
	return global_position.distance_to(player.global_position)


func _dir_to_player() -> Vector3:
	if not is_instance_valid(player):
		return Vector3.ZERO
	var diff: Vector3 = player.global_position - global_position
	diff.y = 0.0
	if diff == Vector3.ZERO:
		return Vector3.ZERO
	return diff.normalized()
