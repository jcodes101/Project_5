class_name AshKnight
extends CharacterBody3D

var game: Node
var visual: Node3D
var hand: Node3D
var blade: Node3D
var pivot: Node3D
var camera: Camera3D
var spring: SpringArm3D
var stamina := 100.0
var yaw := 0.0
var pitch := -0.32
var facing := Vector3.FORWARD
var dodge_direction := Vector3.ZERO
var action := "idle"
var timer := 0.0
var duration := 0.0
var invincible := 0.0
var parry_window := 0.0
var regen_delay := 0.0
var strike_at := 0.0
var struck := false
var heavy := false
var special := false
var combo := 0
var combo_grace := 0.0
var buffered := false
var locked: AshFoe
var equipped_kind := ""
var hit_flash := 0.0
var shake := 0.0
var gait := 0.0

func _ready() -> void:
	game = get_parent()
	collision_layer = 4
	collision_mask = 3
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.75
	collision.shape = shape
	collision.position.y = 0.9
	add_child(collision)
	visual = AshArt.knight(self)
	hand = Node3D.new()
	visual.add_child(hand)
	hand.position = Vector3(0.45, 0.92, -0.2)
	pivot = Node3D.new()
	add_child(pivot)
	pivot.top_level = true
	spring = SpringArm3D.new()
	pivot.add_child(spring)
	spring.spring_length = 5.8
	spring.margin = 0.25
	spring.collision_mask = 1
	spring.add_excluded_object(get_rid())
	camera = Camera3D.new()
	spring.add_child(camera)
	camera.current = true
	camera.fov = 65
	camera.near = 0.1
	camera.far = 100
	refresh_weapon()
	reset_camera()

func reset_camera() -> void:
	yaw = 0.0
	pitch = -0.32
	pivot.global_position = global_position + Vector3(0, 1.5, 0)
	pivot.rotation = Vector3(pitch, yaw, 0)

func refresh_weapon() -> void:
	var entry: Dictionary = game.run.equipped()
	if entry.is_empty() or entry.kind == equipped_kind:
		return
	equipped_kind = entry.kind
	if is_instance_valid(blade):
		blade.queue_free()
	blade = AshArt.weapon(hand, equipped_kind, AshData.COLORS[entry.rarity])

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and game.playing and not game.ui.is_open():
		yaw -= event.relative.x * 0.003
		pitch = clampf(pitch - event.relative.y * 0.003, -0.95, 0.08)

func _physics_process(delta: float) -> void:
	if not game.playing or game.ui.is_open() or game.transitioning:
		return
	if game.hitstop > 0.0:
		return
	invincible = maxf(0, invincible - delta)
	parry_window = maxf(0, parry_window - delta)
	regen_delay = maxf(0, regen_delay - delta)
	combo_grace = maxf(0, combo_grace - delta)
	hit_flash = maxf(0, hit_flash - delta)
	if regen_delay <= 0.0 and action == "idle":
		stamina = minf(100.0, stamina + 15.0 * delta)
	if Input.is_action_just_pressed("lock"):
		toggle_lock()
	if is_instance_valid(locked):
		if locked.dead or global_position.distance_to(locked.global_position) > 22:
			locked = null
		else:
			var toward := locked.global_position - global_position
			yaw = lerp_angle(yaw, atan2(-toward.x, -toward.z), 1.0 - exp(-8 * delta))
			pitch = lerpf(pitch, -0.26, delta * 3)
	var movement := Input.get_vector("left", "right", "forward", "back")
	var direction := Vector3(movement.x, 0, movement.y).rotated(Vector3.UP, yaw)
	if Input.is_action_just_pressed("light") and action == "attack" and timer > duration - 0.22:
		buffered = true
	if action == "idle":
		if Input.is_action_just_pressed("dodge"):
			begin_dodge(direction)
		elif Input.is_action_just_pressed("parry"):
			if spend(10):
				action = "parry"
				timer = 0.0
				duration = 0.5
				parry_window = 0.25
				game.sound("swing")
		elif Input.is_action_just_pressed("special"):
			if game.run.equipped().xp >= 50:
				begin_attack(false, true)
			else:
				game.toast("Special attack unlocks at 50 weapon mastery XP.")
		elif Input.is_action_just_pressed("heavy"):
			begin_attack(true)
		elif Input.is_action_just_pressed("light"):
			begin_attack(false)
		elif Input.is_action_just_pressed("heal"):
			if game.run.quick_heal():
				action = "heal"
				timer = 0
				duration = 0.95
				game.pulse(global_position, AshArt.GOLD, 1.4)
				game.sound("heal")
	timer += delta
	if action == "attack":
		if not struck and timer >= strike_at:
			struck = true
			strike()
		if timer >= duration:
			action = "idle"
			combo_grace = 0.65
			if buffered:
				buffered = false
				begin_attack(false)
	elif action != "idle" and timer >= duration:
		action = "idle"
		visual.rotation.x = 0.0
	var speed_value: float = 4.5 * game.run.speed_scale
	if action == "attack":
		speed_value *= 0.23
	elif action == "heal" or action == "parry":
		speed_value *= 0.3
	elif action == "hurt":
		speed_value *= 0.1
	velocity.x = direction.x * speed_value
	velocity.z = direction.z * speed_value
	if action == "dodge":
		velocity.x = dodge_direction.x * 10.0
		velocity.z = dodge_direction.z * 10.0
	if action == "attack" and timer > strike_at - 0.08 and timer < strike_at + 0.08:
		velocity += facing * (3.0 if heavy else 2.2)
	velocity.y = -0.5 if is_on_floor() else velocity.y - 22.0 * delta
	move_and_slide()
	if action == "idle" or action == "parry":
		if is_instance_valid(locked):
			facing = (locked.global_position - global_position).normalized()
			facing.y = 0
		elif direction.length() > 0.1:
			facing = direction.normalized()
	visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-facing.x, -facing.z), minf(1, delta * 18))
	gait += delta * speed_value * movement.length() * 2.5
	visual.position.y = sin(gait * 2) * 0.035 if action == "idle" else 0.0
	visual.rotation.z = sin(gait) * 0.035 * movement.length()
	hand.rotation = Vector3(-0.3, -0.3, -0.12)
	if action == "attack":
		var swing := clampf((timer - strike_at + 0.1) / 0.25, 0, 1)
		hand.rotation.y = lerpf(1.6, -1.8, swing) if not special else swing * TAU
		hand.rotation.z = -0.35
	elif action == "parry":
		hand.rotation = Vector3(-0.4, 0.7, 1.0)
	elif action == "dodge":
		visual.rotation.x = -timer / duration * TAU
	else:
		visual.rotation.x = lerpf(visual.rotation.x, 0, minf(1, delta * 20))
	update_camera(delta)

func update_camera(delta: float) -> void:
	var desired := global_position + Vector3(0, 1.45, 0)
	pivot.global_position = pivot.global_position.lerp(desired, 1.0 - exp(-14 * delta))
	shake = maxf(0, shake - delta * 2)
	pivot.rotation = Vector3(pitch + randf_range(-shake, shake) * 0.03, yaw + randf_range(-shake, shake) * 0.02, 0)

func spend(amount: float) -> bool:
	if stamina < amount:
		game.toast("Stamina depleted. Leave an opening to recover.")
		return false
	stamina -= amount
	regen_delay = 0.55
	return true

func begin_dodge(direction: Vector3) -> void:
	if not spend(15):
		return
	dodge_direction = direction.normalized() if direction.length() > 0.1 else -facing
	action = "dodge"
	timer = 0
	duration = 0.42
	invincible = 0.3
	game.sound("dodge")
	game.pulse(global_position, AshArt.MOSS, 0.7)

func begin_attack(is_heavy: bool, is_special: bool = false) -> void:
	var entry: Dictionary = game.run.equipped()
	var weapon: Dictionary = AshData.WEAPONS[entry.kind]
	var cost: float = 30 if is_special else minf(30, weapon.cost * (1.65 if is_heavy else 1.0))
	if not spend(cost):
		return
	combo = (combo + 1) % 3 if combo_grace > 0 else 0
	heavy = is_heavy
	special = is_special
	struck = false
	buffered = false
	strike_at = weapon.windup * (1.5 if heavy else 1.0)
	duration = strike_at + weapon.recovery * (1.3 if heavy else 1.0)
	timer = 0
	action = "attack"
	if is_instance_valid(locked):
		facing = (locked.global_position - global_position).normalized()
		facing.y = 0
	else:
		facing = Vector3.FORWARD.rotated(Vector3.UP, yaw)

func strike() -> void:
	var entry: Dictionary = game.run.equipped()
	var weapon: Dictionary = AshData.WEAPONS[entry.kind]
	var damage: float = game.rng.randi_range(weapon.min, weapon.max) * game.run.damage_scale * (1.0 + entry.rarity * 0.15)
	damage *= 2.4 if special else (1.75 if heavy else 1.0)
	if entry.xp >= 25 and combo == 2 and not heavy:
		damage *= 1.6
	var reach: float = weapon.reach + (0.8 if special else 0.0)
	game.slash(global_position + Vector3(0, 0.9, 0), facing, reach, special)
	game.sound("swing")
	for foe in game.foes:
		if not is_instance_valid(foe) or foe.dead:
			continue
		var toward: Vector3 = foe.global_position - global_position
		toward.y = 0
		if toward.length() <= reach + foe.body_radius and (special or toward.normalized().dot(facing) > 0.15):
			foe.take_hit(damage, heavy or special, global_position)
			shake = 0.35
			game.hitstop = 0.055 if not heavy else 0.085

func take_hit(damage: float, source: Node3D = null, parryable: bool = true) -> bool:
	if game.run.health <= 0 or invincible > 0 or not game.playing:
		return false
	if parry_window > 0 and parryable and is_instance_valid(source):
		var toward := (source.global_position - global_position).normalized()
		if toward.dot(facing) > -0.1:
			if source.has_method("stagger"):
				source.stagger(1.5)
			game.toast("PARRY  ·  Strike while the enemy is staggered")
			game.pulse(global_position, AshArt.GOLD, 2.5)
			game.sound("parry")
			game.hitstop = 0.09
			stamina = minf(100, stamina + 5)
			return false
	game.run.health = maxf(0, game.run.health - damage)
	game.run.changed.emit()
	invincible = 0.65
	action = "hurt"
	timer = 0
	duration = 0.32
	shake = 0.8
	hit_flash = 0.35
	game.sound("hurt")
	game.pulse(global_position, AshArt.BLOOD, 0.8)
	if game.run.health <= 0:
		game.finish_run(false)
	return true

func toggle_lock() -> void:
	if is_instance_valid(locked):
		locked = null
		return
	var best := 20.0
	for foe in game.foes:
		if not is_instance_valid(foe) or foe.dead:
			continue
		var dist: float = global_position.distance_to(foe.global_position)
		if dist < best and not camera.is_position_behind(foe.global_position):
			best = dist
			locked = foe
