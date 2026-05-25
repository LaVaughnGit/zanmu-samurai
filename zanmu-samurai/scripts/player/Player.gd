extends CharacterBody3D
class_name Player

const OUTLINE_SHADER  := preload("res://shaders/outline.gdshader")
const TOON_SHADER     := preload("res://shaders/toon.gdshader")
const SLASH_SFX       := preload("res://music/sound effects/player-sword-slash.mp3")
const CLASH_SFX       := preload("res://music/sound effects/swords-clashing.mp3")
const DEATH_SFX       := preload("res://music/sound effects/death-sword-effect.mp3")

signal health_changed(current: int, maximum: int)
signal dash_cooldown_changed(ratio: float)
signal died

const SPEED         := 5.0
const DASH_SPEED    := 10.0
const DASH_DURATION := 0.15
const DASH_COOLDOWN := 0.8
const ATTACK_DURATION := 0.25
const ATTACK_DAMAGE   := 1
const ATTACK_OFFSET   := 1.0

var max_health := 3
var health     := 3
var facing     := Vector3(1.0, 0.0, 0.0)

var is_dashing  := false
var dash_timer  := 0.0
var dash_cooldown_timer := 0.0

var is_attacking  := false
var attack_timer  := 0.0
var attack_visual_timer := 0.0

var is_invincible           := false
var hit_invincibility_timer := 0.0
var hit_flash_timer         := 0.0

var visual:           MeshInstance3D
var attack_area:      Area3D
var attack_collision: CollisionShape3D
var attack_visual:    MeshInstance3D
var _slash_sfx:       AudioStreamPlayer
var _clash_sfx:       AudioStreamPlayer
var _death_sfx:       AudioStreamPlayer


func _ready() -> void:
	add_to_group("player")
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	_build_nodes()
	_setup_visuals()
	attack_area.body_entered.connect(_on_attack_hit)
	_slash_sfx = AudioStreamPlayer.new()
	_slash_sfx.stream = SLASH_SFX
	add_child(_slash_sfx)
	_clash_sfx = AudioStreamPlayer.new()
	_clash_sfx.stream = CLASH_SFX
	add_child(_clash_sfx)
	_death_sfx = AudioStreamPlayer.new()
	_death_sfx.stream = DEATH_SFX
	add_child(_death_sfx)


func _build_nodes() -> void:
	# Body collision
	var body_col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.0
	body_col.shape = capsule
	body_col.position = Vector3(0.0, 0.5, 0.0)
	add_child(body_col)

	# Visual mesh — raised 0.05 so the outline hull doesn't clip the floor
	visual = MeshInstance3D.new()
	visual.position = Vector3(0.0, 0.55, 0.0)
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)

	# Attack flash visual
	attack_visual = MeshInstance3D.new()
	attack_visual.visible = false
	attack_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(attack_visual)

	# Attack area
	attack_area = Area3D.new()
	attack_area.position = Vector3(0.0, 0.5, 0.0)
	attack_area.monitoring = false
	attack_area.monitorable = false
	attack_area.collision_layer = 0
	attack_area.collision_mask = 4
	add_child(attack_area)

	attack_collision = CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.7
	attack_collision.shape = sphere
	attack_collision.disabled = true
	attack_area.add_child(attack_collision)


func _setup_visuals() -> void:
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.3
	capsule_mesh.height = 1.0
	visual.mesh = capsule_mesh
	visual.material_override = _flat_material(Color(0.251, 0.388, 0.847))

	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.5
	sphere_mesh.height = 1.0
	attack_visual.mesh = sphere_mesh
	var amat := StandardMaterial3D.new()
	amat.albedo_color = Color(1.0, 1.0, 1.0, 0.8)
	amat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	amat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	attack_visual.material_override = amat


func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	_tick_timers(delta)
	_handle_movement(delta)
	velocity.y = 0.0
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if health <= 0:
		return
	if event.is_action_pressed("attack") and not is_attacking:
		_slash_sfx.play()
		_do_attack()
	if event.is_action_pressed("dash") and not is_dashing and dash_cooldown_timer <= 0.0:
		_do_dash()


func _handle_movement(delta: float) -> void:
	var raw := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var dir := Vector3(raw.x, 0.0, raw.y)
	if is_dashing:
		velocity.x = facing.x * DASH_SPEED
		velocity.z = facing.z * DASH_SPEED
	elif dir != Vector3.ZERO:
		facing = dir.normalized()
		velocity.x = dir.x * SPEED
		velocity.z = dir.z * SPEED
		if is_attacking:
			attack_area.position = facing * ATTACK_OFFSET + Vector3(0.0, 0.5, 0.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED * 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, SPEED * 8.0 * delta)


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
		var alpha := 1.0 if t < 0.55 else lerpf(1.0, 0.0, (t - 0.55) / 0.45)
		var mat := attack_visual.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color.a = alpha
		if attack_visual_timer <= 0.0:
			attack_visual.visible = false

	if hit_flash_timer > 0.0:
		hit_flash_timer -= delta
		visual.visible = fmod(hit_flash_timer, 0.2) > 0.1
		if hit_flash_timer <= 0.0:
			visual.visible = true


func _do_attack() -> void:
	is_attacking = true
	attack_timer = ATTACK_DURATION
	var attack_pos := facing * ATTACK_OFFSET + Vector3(0.0, 0.5, 0.0)
	attack_area.position = attack_pos
	attack_collision.disabled = false
	attack_area.monitoring = true
	attack_visual.position = attack_pos
	attack_visual.visible = true
	attack_visual_timer = ATTACK_DURATION
	var mat := attack_visual.material_override as StandardMaterial3D
	if mat:
		mat.albedo_color.a = 1.0


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
		if body is Kenjutsu and body.state == Kenjutsu.State.ATTACK:
			_clash_sfx.play()
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
	await get_tree().create_timer(0.25).timeout
	_death_sfx.play()


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


func _flat_material(color: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = TOON_SHADER
	mat.set_shader_parameter("albedo", color)
	return mat
