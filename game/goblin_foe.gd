class_name GoblinFoe
extends AshFoe

const GOBLIN_ART = preload("res://game/goblin_art.gd")
const GOBLIN_MISSILE = preload("res://game/goblin_missile.gd")
const ELECTRIC_TEXTURE = preload("res://game/goblin_electricity.png")
const MAGIC_HIT_START := 0.21
const MAGIC_HIT_END := 0.42
const CLUB_HIT_TIME := 0.33

var kind := "club"
var combat_scale := 1.0
var parts: Dictionary
var attack_done := false
var death_time := 0.0
var lightning: Array[MeshInstance3D] = []
var lightning_sprites: Array[Sprite3D] = []
var club_smear: MeshInstance3D
var club_smear_mesh: ImmediateMesh
var club_smear_material: StandardMaterial3D
var club_smear_inner: Array[Vector3] = []
var club_smear_outer: Array[Vector3] = []

func _ready() -> void:
	game = get_parent()
	family = {"club": "stone", "caster": "briar", "missile": "iron"}[kind]
	title = {"club": "Club Clobberer", "caster": "Magic Caster", "missile": "Missile Goblin"}[kind]
	max_health = 55.0 + arena_level * 9.0
	health = max_health
	body_radius = 0.48
	collision_layer = 2
	collision_mask = 5
	var shape := CapsuleShape3D.new()
	shape.radius = body_radius
	shape.height = 2.25
	var collider := CollisionShape3D.new()
	collider.name = "BodyCollider"
	collider.shape = shape
	collider.position.y = 1.12
	add_child(collider)
	parts = GOBLIN_ART.make(self, kind)
	visual = parts.root
	if kind == "club":
		club_smear_mesh = ImmediateMesh.new()
		club_smear = MeshInstance3D.new()
		club_smear.name = "ClubSwingSmear"
		club_smear.mesh = club_smear_mesh
		club_smear.visible = false
		visual.add_child(club_smear)
		club_smear_material = StandardMaterial3D.new()
		club_smear_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		club_smear_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		club_smear_material.vertex_color_use_as_albedo = true
		club_smear_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	marker = AshArt.ring(self, 1.0, GOBLIN_ART.VIOLET if kind == "caster" else AshArt.BLOOD, 0.055)
	marker.visible = false
	bar_root = Node3D.new()
	add_child(bar_root)
	bar_root.position.y = 2.6
	AshArt.box(bar_root, Vector3.ZERO, Vector3(1.1, 0.07, 0.035), AshArt.BLACK)
	bar = AshArt.box(bar_root, Vector3(0, 0, -0.025), Vector3(1.05, 0.045, 0.03), AshArt.BLOOD)
	cooldown = 0.8
	if kind == "caster":
		for i in range(16):
			var arc := AshArt.box(self, Vector3.ZERO, Vector3(0.15, 0.055, 0.055), GOBLIN_ART.VIOLET)
			arc.material_override = AshArt.material(GOBLIN_ART.VIOLET, false, 2.0)
			arc.visible = false
			lightning.append(arc)
		for i in range(8):
			var spark := Sprite3D.new()
			spark.name = "ElectricitySprite%d" % i
			spark.texture = ELECTRIC_TEXTURE
			spark.pixel_size = 0.00105
			spark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			spark.shaded = false
			spark.visible = false
			add_child(spark)
			lightning_sprites.append(spark)

func _physics_process(delta: float) -> void:
	if not game.playing or game.ui.is_open() or game.hitstop > 0:
		return
	timer += delta
	cooldown = maxf(0.0, cooldown - delta)
	flash = maxf(0.0, flash - delta)
	if dead:
		_animate("die", delta)
		death_time += delta
		if death_time >= 0.7:
			queue_free()
		return
	var toward: Vector3 = game.player.global_position - global_position
	toward.y = 0
	var distance := toward.length()
	bar_root.rotation.y = game.player.yaw
	bar_root.visible = health < max_health
	if state == "stagger":
		velocity.x = 0
		velocity.z = 0
		_animate("hurt", delta)
		if timer >= stagger_duration:
			state = "idle"
			cooldown = 0.45
	elif state == "windup":
		velocity.x = 0
		velocity.z = 0
		marker.visible = false
		_animate("windup", delta)
		if timer >= windup:
			state = "attack"
			timer = 0
			marker.visible = false
			attack_done = false
	elif state == "attack":
		velocity.x = 0
		velocity.z = 0
		_animate("attack", delta)
		marker.visible = kind == "caster" and timer >= MAGIC_HIT_START and timer <= MAGIC_HIT_END
		if marker.visible:
			marker.scale = Vector3.ONE * attack_radius
		if timer >= (CLUB_HIT_TIME if kind == "club" else 0.27) and not attack_done:
			attack_done = true
			_execute_goblin_attack(toward, distance)
		if timer >= (0.78 if kind == "club" else 0.58):
			state = "recover"
			timer = 0
			marker.visible = false
	elif state == "recover":
		velocity.x = 0
		velocity.z = 0
		_animate("recover", delta)
		if timer >= 0.45:
			state = "idle"
			cooldown = 0.9 if kind == "club" else 1.3
	else:
		var desired := (2.5 if kind == "club" else (3.0 if kind == "caster" else 6.0)) * combat_scale
		if distance < 17.0:
			visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-toward.x, -toward.z), minf(1.0, delta * 7.0))
			if cooldown <= 0 and distance <= desired + 0.35:
				_begin_goblin_attack()
			elif distance > desired:
				var step := toward.normalized() * (2.25 if kind == "club" else 2.0)
				velocity.x = step.x
				velocity.z = step.z
				gait += delta * 8.5
				_animate("walk", delta)
			else:
				velocity.x = 0
				velocity.z = 0
				_animate("idle", delta)
		else:
			velocity.x = 0
			velocity.z = 0
			_animate("idle", delta)
	velocity.y = -0.5 if is_on_floor() else velocity.y - 22.0 * delta
	move_and_slide()
	visual.scale = Vector3.ONE * (1.0 + flash * 0.22)
	if kind == "missile" and not dead:
		_aim_cannon()
	_update_club_smear()
	_update_lightning()

func _begin_goblin_attack() -> void:
	state = "windup"
	timer = 0.0
	windup = 0.65 if kind == "club" else 0.9
	attack_radius = 2.9 if kind == "club" else (3.0 if kind == "caster" else 0.45)
	if kind == "club":
		club_smear_inner.clear()
		club_smear_outer.clear()
	game.sound("warning", -10)

func _execute_goblin_attack(toward: Vector3, distance: float) -> void:
	if kind == "club":
		game.slash(global_position + Vector3(0, 1, 0), -visual.global_basis.z, 2.9, false, AshArt.GOLD)
		game.sound("swing")
		if distance < 2.9 and toward.normalized().dot(-visual.global_basis.z) > 0.15:
			game.player.take_hit(17 + arena_level * 2, self)
	elif kind == "caster":
		game.pulse(global_position, GOBLIN_ART.VIOLET, 3.0)
		game.sound("slam")
		if distance < 3.0:
			game.player.take_hit(15 + arena_level * 2, self)
	else:
		_aim_cannon()
		var cannon: Node3D = parts.weapon
		var muzzle := cannon.to_global(Vector3(0, -0.04, -1.35))
		var missile = GOBLIN_MISSILE.new()
		missile.game = game
		missile.source = self
		missile.direction = (game.player.global_position + Vector3(0, 0.9, 0) - muzzle).normalized()
		game.effects.add_child(missile)
		missile.global_position = muzzle
		game.sound("swing")

func _aim_cannon() -> void:
	var cannon: Node3D = parts.weapon
	var target: Vector3 = game.player.global_position + Vector3(0, 0.9, 0)
	if cannon.global_position.distance_squared_to(target) > 0.01:
		cannon.look_at(target, Vector3.UP)

func _animate(pose: String, delta: float) -> void:
	var left_arm: Node3D = parts.left_arm
	var right_arm: Node3D = parts.right_arm
	var left_leg: Node3D = parts.left_leg
	var right_leg: Node3D = parts.right_leg
	var torso: Node3D = parts.torso
	var head: Node3D = parts.head
	var stride := sin(gait) if pose == "walk" else 0.0
	var target_left_arm := stride * 0.55
	var target_right_arm := -stride * 0.55
	var target_left_leg := -stride * 0.52
	var target_right_leg := stride * 0.52
	var target_torso := sin(timer * 2.3) * 0.025
	var target_head := 0.0
	var target_right_arm_y := 0.0
	var target_right_arm_z := 0.0
	if pose == "windup":
		target_right_arm = 0.15 if kind == "club" else (0.55 if kind == "missile" else -1.05)
		if kind == "club":
			target_right_arm_y = -1.7
			target_right_arm_z = 1.55
		target_left_arm = -0.65
		target_torso = -0.18
		target_head = -0.13
	elif pose == "attack":
		target_right_arm = 0.15 if kind == "club" else (0.55 if kind == "missile" else -0.45)
		if kind == "club":
			var sweep := smoothstep(0.0, 1.0, clampf(timer / 0.66, 0.0, 1.0))
			target_right_arm = 0.15 + 1.35 * sin(sweep * PI)
			target_right_arm_y = lerpf(-1.7, 1.7, sweep)
			target_right_arm_z = lerpf(1.55, -1.45, sweep)
		target_left_arm = -0.45
		target_torso = 0.22 if kind != "club" else lerpf(-0.2, 0.24, clampf(timer / 0.66, 0.0, 1.0))
		target_head = 0.12
	elif pose == "hurt":
		target_torso = -0.2
		target_head = 0.18
	elif pose == "die":
		target_left_arm = 1.0
		target_right_arm = 1.0
		target_left_leg = -0.5
		target_right_leg = -0.5
		target_torso = -1.25
		target_head = 0.4
	var blend := minf(1.0, delta * (16.0 if pose == "attack" else 9.0))
	left_arm.rotation.x = lerpf(left_arm.rotation.x, target_left_arm, blend)
	right_arm.rotation.x = lerpf(right_arm.rotation.x, target_right_arm, blend)
	right_arm.rotation.y = lerpf(right_arm.rotation.y, target_right_arm_y, blend)
	right_arm.rotation.z = lerpf(right_arm.rotation.z, target_right_arm_z, blend)
	if kind == "club":
		var club: Node3D = parts.weapon
		club.rotation.x = -right_arm.rotation.x
	left_leg.rotation.x = lerpf(left_leg.rotation.x, target_left_leg, blend)
	right_leg.rotation.x = lerpf(right_leg.rotation.x, target_right_leg, blend)
	torso.rotation.x = lerpf(torso.rotation.x, target_torso, blend)
	head.rotation.x = lerpf(head.rotation.x, target_head, blend)
	visual.position.y = sin(gait * 2.0) * 0.06 if pose == "walk" else lerpf(visual.position.y, 0.0, blend)
	if pose == "die":
		visual.position.y = -minf(0.5, death_time * 0.7)

func _update_club_smear() -> void:
	if kind != "club":
		return
	club_smear.visible = state == "attack" and timer >= 0.07 and timer <= 0.7
	if not club_smear.visible:
		return
	var club: Node3D = parts.weapon
	var grip := visual.to_local(club.to_global(Vector3(0, -0.05, -0.18)))
	var tip := visual.to_local(club.to_global(Vector3(0, -0.05, -1.8)))
	club_smear_inner.append(grip + Vector3(0, -0.12, 0))
	club_smear_outer.append(tip + (tip - grip).normalized() * 0.7 + Vector3(0, 0.23, 0))
	if club_smear_inner.size() > 18:
		club_smear_inner.pop_front()
		club_smear_outer.pop_front()
	club_smear_mesh.clear_surfaces()
	if club_smear_inner.size() < 2:
		return
	club_smear_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, club_smear_material)
	for i in range(club_smear_inner.size() - 1):
		var alpha := 0.12 + float(i + 1) / float(club_smear_inner.size()) * 0.7
		_smear_quad(club_smear_inner[i], club_smear_outer[i], club_smear_inner[i + 1], club_smear_outer[i + 1], alpha)
	club_smear_mesh.surface_end()

func _smear_quad(inner_a: Vector3, outer_a: Vector3, inner_b: Vector3, outer_b: Vector3, alpha: float) -> void:
	var color := Color(1.0, 0.75, 0.25, alpha)
	for point in [inner_a, outer_a, inner_b, inner_b, outer_a, outer_b]:
		club_smear_mesh.surface_set_color(color)
		club_smear_mesh.surface_add_vertex(point)

func _update_lightning() -> void:
	if kind != "caster":
		return
	var active := state == "attack" and timer >= MAGIC_HIT_START and timer <= MAGIC_HIT_END
	for i in lightning.size():
		var arc := lightning[i]
		arc.visible = active
		if active:
			var angle := TAU * float(i) / float(lightning.size())
			var flicker := sin(timer * 37.0 + i * 2.7) * 0.12
			var radius_value := 2.9 + flicker
			arc.position = Vector3(cos(angle) * radius_value, 0.11 + absf(flicker) * 0.5, sin(angle) * radius_value)
			arc.rotation.y = -angle
			arc.scale.x = 1.0 + absf(flicker) * 2.0
	for i in lightning_sprites.size():
		var spark := lightning_sprites[i]
		spark.visible = active
		if active:
			var angle := TAU * float(i) / float(lightning_sprites.size()) + timer * 0.3
			var flicker := sin(timer * 29.0 + i * 3.1)
			spark.position = Vector3(cos(angle) * 2.8, 0.62 + flicker * 0.09, sin(angle) * 2.8)
			spark.rotation.z = sin(timer * 15.0 + i) * 0.15
			spark.modulate.a = 0.65 + absf(flicker) * 0.35

func take_hit(damage: float, poise_break: bool, from: Vector3) -> void:
	if dead:
		return
	health = maxf(0.0, health - damage)
	bar.scale.x = health / max_health
	bar.position.x = -(1.0 - health / max_health) * 0.52
	flash = 0.22
	game.damage_number(global_position + Vector3(0, 2.3, 0), int(damage))
	game.pulse(global_position + Vector3(0, 0.8, 0), AshArt.GOLD, 0.6)
	game.sound("hit")
	if health <= 0:
		dead = true
		state = "die"
		death_time = 0.0
		marker.visible = false
		if is_instance_valid(club_smear):
			club_smear.visible = false
		collision_layer = 0
		collision_mask = 0
		game.enemy_defeated(self)
	elif poise_break:
		state = "stagger"
		timer = 0
		stagger_duration = 0.4
