class_name AshFoe
extends CharacterBody3D

var game: Node
var family := "stone"
var rank := 0
var arena_level := 1
var title := "Gravebound"
var max_health := 45.0
var health := 45.0
var dead := false
var body_radius := 0.5
var visual: Node3D
var marker: MeshInstance3D
var bar: MeshInstance3D
var bar_root: Node3D
var state := "idle"
var timer := 0.0
var cooldown := 1.0
var attack_type := 0
var attack_radius := 2.6
var windup := 0.9
var attack_point := Vector3.ZERO
var charge_direction := Vector3.ZERO
var enraged := false
var flash := 0.0
var gait := 0.0
var stagger_duration := 0.0
var knockback := Vector3.ZERO

func _ready() -> void:
	game = get_parent()
	collision_layer = 2
	collision_mask = 5
	body_radius = 0.8 if rank > 0 else 0.5
	max_health = (42.0 + arena_level * 9.0) * (3.0 if rank == 1 else (5.0 if rank == 2 else 1.0))
	health = max_health
	var shape := CapsuleShape3D.new()
	shape.radius = body_radius
	shape.height = 2.8 if rank > 0 else 2.0
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = shape.height * 0.5
	add_child(collider)
	visual = AshArt.enemy(self, family, rank > 0)
	title = {"stone": "Cairn Warden", "briar": "Hollowroot", "iron": "Cinderbound"}[family]
	if rank == 1:
		title = "The Bellkeeper" if family == "iron" else "Root of the Forsaken"
	elif rank == 2:
		title = "Veyr, the Ashen King"
	marker = AshArt.ring(self, 1.0, AshArt.BLOOD, 0.05)
	marker.visible = false
	bar_root = Node3D.new()
	add_child(bar_root)
	bar_root.position.y = 3.7 if rank > 0 else 2.6
	AshArt.box(bar_root, Vector3.ZERO, Vector3(1.1, 0.07, 0.035), AshArt.BLACK)
	bar = AshArt.box(bar_root, Vector3(0, 0, -0.025), Vector3(1.05, 0.045, 0.03), AshArt.BLOOD)
	bar.material_override = AshArt.material(AshArt.BLOOD, false, 0.5)
	cooldown = game.rng.randf_range(0.6, 1.5)

func _physics_process(delta: float) -> void:
	if dead or not game.playing or game.ui.is_open() or game.hitstop > 0:
		return
	timer += delta
	cooldown = maxf(0, cooldown - delta)
	flash = maxf(0, flash - delta)
	var toward: Vector3 = game.player.global_position - global_position
	toward.y = 0
	var distance := toward.length()
	bar_root.rotation.y = game.player.yaw
	bar_root.visible = health < max_health and rank == 0
	if rank > 0 and health < max_health * 0.5 and not enraged:
		enraged = true
		game.toast(title + " sheds its last mercy.")
		game.pulse(global_position, AshArt.BLOOD, 4.0)
	if state == "stagger":
		visual.rotation.z = sin(timer * 20) * 0.08
		if timer >= stagger_duration:
			state = "approach"
			cooldown = 0.5
	elif state == "windup":
		marker.visible = true
		marker.scale = Vector3.ONE * attack_radius * (0.85 + sin(timer * 18) * 0.04)
		if attack_type == 1 and family == "briar":
			marker.global_position = Vector3(attack_point.x, 0.12, attack_point.z)
			marker.scale = Vector3.ONE * 0.85
		visual.rotation.x = -0.18 * sin(timer / windup * PI)
		if timer >= windup:
			execute_attack()
	elif state == "recover":
		if attack_type == 1 and family != "briar" and timer < 0.3:
			velocity.x = charge_direction.x * (10 if rank > 0 else 7)
			velocity.z = charge_direction.z * (10 if rank > 0 else 7)
			if distance < 2.0:
					game.player.take_hit(16 + arena_level * 2, self)
		else:
			velocity.x = 0
			velocity.z = 0
		if timer > (0.8 if enraged else 1.1):
			state = "approach"
			cooldown = 0.6
	else:
		var alert_range := 24.0 if rank > 0 else 16.0
		var query := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.1, 0), game.player.global_position + Vector3(0, 1.1, 0), 1)
		var visible_player := get_world_3d().direct_space_state.intersect_ray(query).is_empty()
		if distance < alert_range and (visible_player or state == "approach"):
			state = "approach"
			visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-toward.x, -toward.z), minf(1, delta * 6))
			var desired_range := 5.0 if family == "briar" else 2.3
			if cooldown <= 0 and distance < desired_range + 0.8:
				begin_attack()
			elif distance > desired_range:
				var direction := toward.normalized()
				for other in game.foes:
					if other != self and is_instance_valid(other) and not other.dead:
						var away: Vector3 = global_position - other.global_position
						away.y = 0
						if away.length() < 2.2:
							direction += away.normalized() * 0.8
				var ahead := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.8, 0), global_position + Vector3(0, 0.8, 0) + direction.normalized() * 1.7, 1)
				if not get_world_3d().direct_space_state.intersect_ray(ahead).is_empty():
					direction = direction.rotated(Vector3.UP, 1.1)
				var speed_value := (2.0 if family == "stone" else 2.5) * (1.2 if enraged else 1.0)
				velocity.x = direction.normalized().x * speed_value
				velocity.z = direction.normalized().z * speed_value
				gait += delta * 7
				visual.position.y = sin(gait) * 0.06
			else:
				velocity.x = 0
				velocity.z = 0
		else:
			velocity.x = sin(timer * 0.5) * 0.35
			velocity.z = cos(timer * 0.5) * 0.35
	if state == "windup" or state == "stagger":
		velocity.x = 0
		velocity.z = 0
	velocity.y = -0.5 if is_on_floor() else velocity.y - 22 * delta
	velocity += knockback
	knockback = knockback.move_toward(Vector3.ZERO, 18 * delta)
	move_and_slide()
	visual.scale = Vector3.ONE * (1.65 if rank > 0 else 1.0) * (1.0 + flash * 0.35)
	if state != "windup":
		visual.rotation.x = lerpf(visual.rotation.x, 0, minf(1, delta * 15))

func begin_attack() -> void:
	attack_type = game.rng.randi_range(0, 1)
	state = "windup"
	timer = 0
	windup = (0.9 if attack_type == 0 else 0.7) * (0.78 if enraged else 1.0)
	attack_radius = (3.2 if family == "briar" else 2.8) * (1.35 if rank > 0 else 1.0)
	attack_point = game.player.global_position
	marker.position = Vector3(0, 0.08, 0)
	charge_direction = (attack_point - global_position).normalized()
	charge_direction.y = 0
	game.sound("warning", -10)

func execute_attack() -> void:
	marker.visible = false
	state = "recover"
	timer = 0
	if attack_type == 0:
		game.pulse(global_position, AshArt.BLOOD, attack_radius)
		game.sound("slam")
		var dist: float = game.player.global_position.distance_to(global_position)
		if dist < attack_radius:
			game.player.take_hit(14 + arena_level * 2 + rank * 4, self)
	elif family == "briar":
		game.spawn_bolt(global_position + Vector3(0, 1, 0), charge_direction, self, 15 + arena_level * 2)
		if rank > 0:
			for angle in [-0.3, 0.3]:
				game.spawn_bolt(global_position + Vector3(0, 1, 0), charge_direction.rotated(Vector3.UP, angle), self, 18)
		game.sound("swing")
	else:
		game.slash(global_position + Vector3(0, 1, 0), charge_direction, 2.5, false, AshArt.BLOOD)
		game.sound("swing")
		if game.player.global_position.distance_to(global_position) < 2.6:
			game.player.take_hit(17 + arena_level * 2, self)

func stagger(seconds: float) -> void:
	state = "stagger"
	timer = 0
	stagger_duration = seconds
	cooldown = 0.0
	marker.visible = false
	game.pulse(global_position, AshArt.GOLD, 1.5)

func take_hit(damage: float, poise_break: bool, from: Vector3) -> void:
	if dead:
		return
	if state == "stagger":
		damage *= 1.35
	health = maxf(0, health - damage)
	bar.scale.x = health / max_health
	bar.position.x = -(1.0 - health / max_health) * 0.52
	flash = 0.22
	game.damage_number(global_position + Vector3(0, 2.1 if rank == 0 else 3.2, 0), int(damage))
	game.pulse(global_position + Vector3(0, 0.6, 0), AshArt.GOLD, 0.7)
	game.sound("hit")
	if poise_break or rank == 0:
		stagger(0.8 if poise_break else 0.3)
	var away := (global_position - from).normalized()
	velocity += away * 2.0
	if health <= 0:
		dead = true
		collision_layer = 0
		collision_mask = 0
		marker.visible = false
		game.enemy_defeated(self)
		var tween := create_tween()
		tween.tween_property(visual, "scale", Vector3.ZERO, 0.35)
		tween.tween_callback(queue_free)
