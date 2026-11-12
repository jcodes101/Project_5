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
var roll_pivot: Node3D
var offhand: Node3D
var special_cooldowns: Dictionary = {}
var strike_index := 0
var strike_times: Array[float] = []
var attack_kind := "sword"
var counter_ready := false
var roll_bounds: Array[Vector3] = []
var torso: Node3D
var greatsword_arms: Array[MeshInstance3D] = []
var original_arms: Array[Node3D] = []
var planted_legs: Array[Node3D] = []
var sword_feet: Array[MeshInstance3D] = []

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
	roll_pivot = Node3D.new()
	add_child(roll_pivot)
	visual = AshArt.knight(roll_pivot)
	build_upper_body()
	hand = Node3D.new()
	torso.add_child(hand)
	hand.position = Vector3(0.45, 0.02, -0.2)
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
	combo = 0
	combo_grace = 0
	if is_instance_valid(offhand):
		offhand.queue_free()
	if is_instance_valid(blade):
		blade.queue_free()
	blade = AshArt.weapon(hand, equipped_kind, AshData.COLORS[entry.rarity])
	if equipped_kind == "dagger":
		offhand = AshArt.weapon(torso, "dagger", AshData.COLORS[entry.rarity])
		offhand.position = Vector3(-0.43, 0.12, -0.2)
	pose_greatsword()
	cache_roll_bounds(visual)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and game.playing and not game.ui.is_open():
		yaw -= event.relative.x * 0.003
		pitch = clampf(pitch - event.relative.y * 0.003, -0.95, 0.08)

func _physics_process(delta: float) -> void:
	if not game.playing or game.ui.is_open() or game.transitioning:
		return
	if game.hitstop > 0.0:
		return
	for kind in special_cooldowns.keys():
		special_cooldowns[kind] = maxf(0, special_cooldowns[kind] - delta)
	if action == "idle":
		for number in range(1, 5):
			if Input.is_action_just_pressed("weapon_%d" % number):
				switch_weapon(["sword", "dagger", "greatsword", "spear"][number - 1])
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
	if Input.is_action_just_pressed("light") and action == "attack" and not heavy and not special and combo_grace > 0 and timer > duration - 0.22:
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
		while strike_index < strike_times.size() and timer >= strike_times[strike_index]:
			strike()
			strike_index += 1
			struck = true
		if timer >= duration:
			action = "idle"
			if buffered:
				buffered = false
				combo_grace = 0.01
				begin_attack(false)
	elif action == "counter":
		if timer >= duration:
			action = "idle"
			counter_ready = false
	elif action != "idle" and timer >= duration:
		action = "idle"
		visual.rotation.x = 0.0
	var mobility: float = 1.0 - AshData.WEAPONS[game.run.equipped().kind].slow
	var speed_value: float = 4.5 * game.run.speed_scale * mobility
	if action == "attack":
		speed_value *= 0.23
	elif action in ["heal", "parry", "riposte"]:
		speed_value *= 0.3
	elif action == "hurt":
		speed_value *= 0.1
	velocity.x = direction.x * speed_value
	velocity.z = direction.z * speed_value
	if action == "dodge":
		velocity.x = dodge_direction.x * 8.0 * mobility
		velocity.z = dodge_direction.z * 8.0 * mobility
	if action == "counter":
		velocity.x = 0
		velocity.z = 0
	if action == "attack" and attack_kind in ["dagger", "spear"] and ((heavy and timer <= strike_at) or special):
		velocity += facing * (4.0 if heavy else (2.2 if attack_kind == "dagger" else 0.0))
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
	roll_pivot.position = Vector3.ZERO
	roll_pivot.rotation = Vector3.ZERO
	visual.scale = Vector3.ONE
	visual.rotation.z = sin(gait) * 0.035 * movement.length()
	torso.rotation = Vector3.ZERO
	hand.position = Vector3(0.45, 0.02, -0.2)
	if is_instance_valid(offhand):
		offhand.rotation = Vector3(-0.3, 0.3, 0.12)
	hand.rotation = Vector3(-0.3, -0.3, -0.12)
	if action == "attack":
		animate_attack()
	elif action == "parry" or action == "counter":
		hand.rotation = Vector3(-0.4, 0.7, 1.0)
	elif action == "dodge":
		animate_roll(clampf(timer / duration, 0, 1))
	else:
		visual.rotation.x = lerpf(visual.rotation.x, 0, minf(1, delta * 20))
	pose_greatsword()
	update_camera(delta)

func build_upper_body() -> void:
	torso = Node3D.new()
	torso.name = "TorsoPivot"
	visual.add_child(torso)
	torso.position.y = 0.9
	for part in visual.get_children():
		if part is MeshInstance3D and is_equal_approx(part.position.y, 0.3):
			planted_legs.append(part)
		if part is MeshInstance3D and part.position.y > 0.65:
			part.reparent(torso, false)
			part.position.y -= 0.9
			if part.name in ["LeftArm", "RightArm"]:
				original_arms.append(part)
	for side in [-1, 1]:
		var foot: MeshInstance3D = AshArt.box(visual, Vector3(side * 0.18, 0.08, -0.08), Vector3(0.24, 0.16, 0.4), Color("3f4037"))
		foot.name = "LeftFoot" if side < 0 else "RightFoot"
		sword_feet.append(foot)
	for side in [-1, 1]:
		for segment in 3:
			var mesh: MeshInstance3D = AshArt.box(torso, Vector3.ZERO, Vector3(0.17, 1, 0.19) if segment < 2 else Vector3(0.16, 0.16, 0.16), AshArt.WOOD if segment < 2 else Color("747465"))
			mesh.name = ("Left" if side < 0 else "Right") + ["UpperArm", "Forearm", "Grip"][segment]
			mesh.visible = false
			greatsword_arms.append(mesh)

func pose_greatsword() -> void:
	var enabled: bool = equipped_kind in ["greatsword", "sword", "dagger", "spear"]
	torso.position.y = 0.9
	for leg in planted_legs:
		leg.position.z = 0.0
		leg.position.y = 0.3
	for foot in sword_feet:
		foot.visible = equipped_kind != "greatsword"
		foot.rotation.y = 0.0
	for arm in original_arms:
		arm.visible = not enabled
	for arm in greatsword_arms:
		arm.visible = enabled
	if not enabled:
		return
	if equipped_kind in ["dagger", "spear"]:
		pose_agile_weapon()
		return
	if equipped_kind == "sword":
		pose_sword()
		return
	var rest_pos := Vector3(0.38, 0.34, -0.3)
	var rest_rot := Vector3(2.85, -0.12, -0.08)
	hand.position = rest_pos
	hand.rotation = rest_rot
	torso.rotation = Vector3(0, -0.12, 0)
	if action == "attack" and attack_kind == "greatsword":
		var overhead: bool = heavy or (combo == 2 and not special)
		var reverse: bool = combo == 1 and not special
		var sign_value: float = -1.0 if reverse else 1.0
		var wind_pos := Vector3(0.42 * sign_value, 0.5, 0.08)
		var wind_rot := Vector3(2.3, -1.1 * sign_value, -0.35 * sign_value)
		var impact_pos := Vector3(0, 0.25, -0.65)
		var impact_rot := Vector3(0.05, 0.3 * sign_value, -0.15 * sign_value)
		var follow_pos := Vector3(-0.42 * sign_value, 0.1, -0.2)
		var follow_rot := Vector3(0.15, 1.65 * sign_value, -0.2 * sign_value)
		var wind_body := Vector3(-0.08, -0.6 * sign_value, 0.08 * sign_value)
		var impact_body := Vector3(0.08, 0.25 * sign_value, -0.05 * sign_value)
		var follow_body := Vector3(0.13, 0.75 * sign_value, -0.1 * sign_value)
		var contact: float = 0.65 if special else strike_at
		if overhead:
			wind_pos = Vector3(0, 0.78, 0)
			wind_rot = Vector3(1.85, 0, 0)
			impact_pos = Vector3(0, 0.32, -0.6)
			impact_rot = Vector3(-0.25, 0, 0)
			follow_pos = Vector3(0, 0.22, -0.45)
			follow_rot = Vector3(-0.3, 0, 0)
			wind_body = Vector3(-0.15, 0, 0)
			impact_body = Vector3(0.14, 0, 0)
			follow_body = Vector3(0.2, 0, 0)
		var wind_time: float = maxf(0.04, contact - 0.16)
		var follow_time: float = minf(duration - 0.08, contact + 0.18)
		var blend: float
		if timer < wind_time:
			blend = smoothstep(0, wind_time, timer)
			hand.position = rest_pos.lerp(wind_pos, blend)
			hand.rotation = rest_rot.lerp(wind_rot, blend)
			torso.rotation = Vector3(0, -0.12, 0).lerp(wind_body, blend)
		elif timer < contact:
			blend = smoothstep(wind_time, contact, timer)
			hand.position = wind_pos.lerp(impact_pos, blend)
			hand.rotation = wind_rot.lerp(impact_rot, blend)
			torso.rotation = wind_body.lerp(impact_body, blend)
		elif timer < follow_time:
			blend = smoothstep(contact, follow_time, timer)
			hand.position = impact_pos.lerp(follow_pos, blend)
			hand.rotation = impact_rot.lerp(follow_rot, blend)
			torso.rotation = impact_body.lerp(follow_body, blend)
		else:
			blend = smoothstep(follow_time, duration, timer)
			hand.position = follow_pos.lerp(rest_pos, blend)
			hand.rotation = follow_rot.lerp(rest_rot, blend)
			torso.rotation = follow_body.lerp(Vector3(0, -0.12, 0), blend)
		if special:
			# Rotate the whole silhouette around planted feet for Titan's Cleave.
			visual.rotation.y = atan2(-facing.x, -facing.z) + smoothstep(0.15, 0.95, timer) * TAU
			hand.rotation.x = 0.15
	elif action == "dodge":
		# Keep a compact two-handed guard while the roll pivot rotates.
		torso.rotation = Vector3.ZERO
		hand.position = Vector3(0.1, 0.22, -0.4)
		hand.rotation = Vector3(0.95, 0, -0.2)
	if action == "attack" and not special:
		visual.rotation.y = atan2(-facing.x, -facing.z) + torso.rotation.y * 0.35
		visual.rotation.z = torso.rotation.z * 0.3
		for leg in planted_legs:
			leg.position.z = signf(leg.position.x) * torso.rotation.y * 0.12
	pose_gripping_arms(true)

func pose_gripping_arms(two_handed: bool, left_grip_weight: float = 1.0) -> void:
	for index in 2:
		var side: float = -1.0 if index == 0 else 1.0
		var shoulder := Vector3(side * 0.42, 0.22, 0)
		var grip: Vector3 = hand.transform * Vector3(0, 0, (-0.4 if equipped_kind == "spear" else 0.19) if index == 0 else 0.015)
		if index == 0:
			var free_hand := Vector3(-0.44, -0.13, 0.06)
			if action == "attack" and not two_handed:
				free_hand += Vector3(-0.08, 0.08, torso.rotation.y * 0.2)
			if equipped_kind == "dagger" and is_instance_valid(offhand):
				grip = offhand.transform * Vector3(0, 0, 0.015)
			else:
				grip = free_hand.lerp(grip, left_grip_weight if two_handed else 0.0)
		var halfway: Vector3 = (shoulder + grip) * 0.5
		var bend: float = sqrt(maxf(0.015, 0.48 * 0.48 - shoulder.distance_squared_to(grip) * 0.25))
		var elbow: Vector3 = halfway + Vector3(side * 0.6, -0.6, 0.25).normalized() * bend
		pose_arm_segment(greatsword_arms[index * 3], shoulder, elbow)
		pose_arm_segment(greatsword_arms[index * 3 + 1], elbow, grip)
		greatsword_arms[index * 3 + 2].position = grip

func sword_pose_between(a: Array, b: Array, blend: float) -> void:
	hand.position = (a[0] as Vector3).lerp(b[0], blend)
	hand.rotation = (a[1] as Vector3).lerp(b[1], blend)
	torso.rotation = (a[2] as Vector3).lerp(b[2], blend)

func pose_sword() -> void:
	var ready: Array = [Vector3(0.48, -0.1, -0.4), Vector3(0.12, -0.12, -0.15), Vector3(0, -0.1, 0)]
	var guard: Array = [Vector3(0.08, 0.32, -0.42), Vector3(0.8, -0.7, -0.5), Vector3(-0.06, -0.2, 0)]
	var two_handed := false
	var footwork := 0.0
	sword_pose_between(ready, ready, 0)
	if action == "counter":
		var enter: float = smoothstep(0, 0.12, timer)
		var exit: float = smoothstep(0.82, 1.0, timer)
		sword_pose_between(ready, guard, enter * (1.0 - exit))
	elif action == "riposte":
		var deflect: Array = [Vector3(0.28, 0.38, -0.4), Vector3(0.65, -1.1, -0.35), Vector3(0, -0.3, 0)]
		var counter: Array = [Vector3(-0.12, 0.15, -0.65), Vector3(0.1, 0.8, -0.45), Vector3(0.08, 0.35, 0)]
		if timer < 0.07:
			sword_pose_between(guard, deflect, smoothstep(0, 0.07, timer))
		elif timer < 0.17:
			sword_pose_between(deflect, counter, smoothstep(0.07, 0.17, timer))
		else:
			sword_pose_between(counter, ready, smoothstep(0.17, duration, timer))
		footwork = sin(PI * clampf(timer / duration, 0, 1)) * 0.12
	elif action == "attack" and attack_kind == "sword":
		var wind: Array
		var impact: Array
		var follow: Array
		if heavy:
			two_handed = true
			wind = [Vector3(0, 0.8, 0.02), Vector3(1.9, 0, 0), Vector3(-0.18, -0.12, 0)]
			impact = [Vector3(0, 0.18, -0.6), Vector3(-0.25, 0, 0), Vector3(0.18, 0.08, 0)]
			follow = [Vector3(0, 0.05, -0.48), Vector3(-0.35, 0, 0), Vector3(0.23, 0.12, 0)]
		elif combo == 2:
			wind = [Vector3(0.32, 0.08, -0.12), Vector3(0, -0.15, 0), Vector3(-0.05, -0.3, 0)]
			impact = [Vector3(0.18, 0.16, -0.82), Vector3(0, 0, 0), Vector3(0.13, 0.12, 0)]
			follow = [Vector3(0.15, 0.12, -0.88), Vector3(-0.02, 0.08, 0), Vector3(0.16, 0.18, 0)]
		elif combo == 1:
			wind = [Vector3(-0.22, -0.02, -0.35), Vector3(-0.25, 0.9, 0.5), Vector3(0.08, 0.35, 0.06)]
			impact = [Vector3(0.12, 0.22, -0.55), Vector3(0.3, -0.1, 0.1), Vector3(0, -0.1, 0)]
			follow = [Vector3(0.4, 0.5, -0.1), Vector3(1.0, -0.95, -0.5), Vector3(-0.06, -0.5, -0.07)]
		else:
			wind = [Vector3(0.42, 0.48, -0.05), Vector3(1.0, -1.0, -0.55), Vector3(-0.05, -0.45, -0.06)]
			impact = [Vector3(0.05, 0.2, -0.56), Vector3(0.1, 0.1, -0.2), Vector3(0.05, 0.15, 0)]
			follow = [Vector3(-0.25, -0.02, -0.3), Vector3(-0.25, 1.0, 0.45), Vector3(0.1, 0.5, 0.07)]
		var wind_time: float = maxf(0.035, strike_at - (0.12 if heavy else 0.09))
		var follow_time: float = minf(duration - 0.08, strike_at + (0.2 if heavy else 0.1))
		if timer < wind_time:
			sword_pose_between(ready, wind, smoothstep(0, wind_time, timer))
		elif timer < strike_at:
			sword_pose_between(wind, impact, smoothstep(wind_time, strike_at, timer))
		elif timer < follow_time:
			sword_pose_between(impact, follow, smoothstep(strike_at, follow_time, timer))
		else:
			sword_pose_between(follow, ready, smoothstep(follow_time, duration, timer))
		footwork = sin(PI * clampf(timer / duration, 0, 1)) * (0.24 if combo == 2 and not heavy else 0.14)
	elif action == "dodge":
		hand.position = Vector3(0.18, 0.18, -0.35)
		hand.rotation = Vector3(0.9, 0, -0.2)
		torso.rotation = Vector3.ZERO
	elif action == "parry":
		sword_pose_between(ready, guard, sin(PI * clampf(timer / duration, 0, 1)))
	if action != "dodge":
		visual.rotation.y = atan2(-facing.x, -facing.z) + torso.rotation.y * 0.32
	for index in planted_legs.size():
		var leg: Node3D = planted_legs[index]
		var side: float = signf(leg.position.x)
		leg.position.z = side * torso.rotation.y * 0.12 - (footwork if side > 0 else 0.0)
		var lift: float = footwork * 0.22 if side > 0 else 0.0
		leg.position.y = 0.3 + lift
		sword_feet[index].position = Vector3(leg.position.x, 0.08 + lift, leg.position.z - 0.08)
	var left_weight: float = 1.0
	if two_handed:
		left_weight = smoothstep(0, 0.1, timer) * (1.0 - smoothstep(duration - 0.14, duration, timer))
	pose_gripping_arms(two_handed, left_weight)

# Pose entries: right grip, right rotation, left grip, left rotation, torso.
func agile_pose_between(a: Array, b: Array, blend: float) -> void:
	hand.position = (a[0] as Vector3).lerp(b[0], blend)
	hand.rotation = (a[1] as Vector3).lerp(b[1], blend)
	if equipped_kind == "dagger" and is_instance_valid(offhand):
		offhand.position = (a[2] as Vector3).lerp(b[2], blend)
		offhand.rotation = (a[3] as Vector3).lerp(b[3], blend)
	torso.rotation = (a[4] as Vector3).lerp(b[4], blend)

func pose_agile_weapon() -> void:
	var dagger: bool = equipped_kind == "dagger"
	var ready: Array = [Vector3(0.44, 0.04, -0.36), Vector3(0.25, -0.25, -0.2), Vector3(-0.42, 0.15, -0.3), Vector3(0.35, 0.3, 0.2), Vector3.ZERO]
	if not dagger:
		ready = [Vector3(0.38, -0.02, -0.2), Vector3(0.05, -0.1, 0), Vector3.ZERO, Vector3.ZERO, Vector3(0, -0.18, 0)]
	agile_pose_between(ready, ready, 0)
	var step := 0.0
	var crouch := 0.0
	if action == "attack" and attack_kind == equipped_kind:
		var index: int = 0
		if special:
			# Select by animation time, independent of the damage-event cursor.
			for i in strike_times.size():
				if timer > strike_times[i] + (0.06 if dagger else 0.1) and i < strike_times.size() - 1:
					index = i + 1
		var contact: float = strike_times[index] if special else strike_at
		var start: float = 0.0 if index == 0 else strike_times[index - 1] + (0.06 if dagger else 0.1)
		var wind: Array = ready.duplicate()
		var impact: Array = ready.duplicate()
		var follow: Array = ready.duplicate()
		if dagger:
			var left: bool = (special and index % 2 == 1) or (not special and combo == 1 and not heavy)
			var crossing: bool = (special and index == 4) or (not special and combo == 2 and not heavy)
			var side: float = -1.0 if left else 1.0
			var active: int = 2 if left else 0
			var wider: float = 1.25 if special and index == 3 else 1.0
			wind[active] = Vector3(0.5 * side * wider, 0.38, -0.12)
			wind[active + 1] = Vector3(0.9, -0.9 * side, -0.4 * side)
			impact[active] = Vector3(0.12 * side, 0.16, -0.65)
			impact[active + 1] = Vector3(0.05, 0.25 * side, -0.15 * side)
			follow[active] = Vector3(-0.16 * side, 0.02, -0.48)
			follow[active + 1] = Vector3(-0.15, 1.05 * side, 0.3 * side)
			wind[4] = Vector3(-0.04, -0.28 * side, -0.03 * side)
			impact[4] = Vector3(0.05, 0.12 * side, 0)
			follow[4] = Vector3(0.08, 0.32 * side, 0.03 * side)
			if crossing:
				wind = [Vector3(0.54, 0.3, -0.22), Vector3(0.65, -1.0, -0.4), Vector3(-0.54, 0.3, -0.22), Vector3(0.65, 1.0, 0.4), Vector3(-0.04, 0, 0)]
				impact = [Vector3(0.06, 0.16, -0.64), Vector3(-0.35, 0.7, -0.35), Vector3(-0.06, 0.1, -0.61), Vector3(0.35, -0.7, 0.35), Vector3(0.12, 0, 0)]
				follow = [Vector3(-0.18, 0.05, -0.48), Vector3(-0.1, 1.0, 0.3), Vector3(0.18, 0.12, -0.46), Vector3(-0.1, -1.0, -0.3), Vector3(0.14, 0, 0)]
			if heavy:
				wind = [Vector3(0.4, -0.02, 0.04), Vector3(0, -0.1, 0), Vector3(-0.4, 0.05, 0.02), Vector3(0.3, 0.2, 0.1), Vector3(-0.08, -0.15, 0)]
				impact = [Vector3(0.18, 0.08, -0.85), Vector3.ZERO, ready[2], ready[3], Vector3(0.18, 0.1, 0)]
				follow = [Vector3(0.14, 0.06, -0.88), Vector3.ZERO, ready[2], ready[3], Vector3(0.2, 0.12, 0)]
		else:
			var sweep: bool = (special and index < 2) or (not special and not heavy and combo == 2)
			if sweep:
				var side: float = -1.0 if special and index == 1 else 1.0
				wind = [Vector3(0.3 * side, 0.08, -0.44), Vector3(0.03, -1.2 * side, 0), Vector3.ZERO, Vector3.ZERO, Vector3(-0.03, -0.4 * side, 0)]
				impact = [Vector3(0.12 * side, 0.1, -0.48), Vector3(0, 0.15 * side, 0), Vector3.ZERO, Vector3.ZERO, Vector3(0.04, 0.12 * side, 0)]
				follow = [Vector3(-0.18 * side, 0.04, -0.44), Vector3(0.03, 1.25 * side, 0), Vector3.ZERO, Vector3.ZERO, Vector3(0.06, 0.42 * side, 0)]
			else:
				var extension: float = 0.64 if heavy or special else (0.57 if combo == 1 else 0.48)
				wind = [Vector3(0.38, -0.02, 0.05), Vector3(0, -0.08, 0), Vector3.ZERO, Vector3.ZERO, Vector3(-0.06, -0.26, 0)]
				impact = [Vector3(0.28, 0.02, -extension), Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3(0.15 if heavy else 0.1, 0.1, 0)]
				follow = [Vector3(0.25, 0.02, -extension - 0.03), Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3(0.17 if heavy else 0.12, 0.14, 0)]
		var transition: Array = ready
		if special and index > 0:
			if dagger:
				var previous_side: float = -1.0 if (index - 1) % 2 == 1 else 1.0
				var previous_active: int = 2 if previous_side < 0 else 0
				transition = ready.duplicate()
				transition[previous_active] = Vector3(-0.16 * previous_side, 0.02, -0.48)
				transition[previous_active + 1] = Vector3(-0.15, 1.05 * previous_side, 0.3 * previous_side)
				transition[4] = Vector3(0.08, 0.32 * previous_side, 0.03 * previous_side)
			else:
				var previous_side: float = 1.0 if index == 1 else -1.0
				transition = [Vector3(-0.18 * previous_side, 0.04, -0.44), Vector3(0.03, 1.25 * previous_side, 0), Vector3.ZERO, Vector3.ZERO, Vector3(0.06, 0.42 * previous_side, 0)]
		var wind_time: float = maxf(start + 0.015, contact - (0.055 if dagger else 0.1))
		var follow_time: float = minf(duration - 0.08, contact + (0.06 if dagger else 0.1))
		if timer < wind_time:
			agile_pose_between(transition, wind, smoothstep(start, wind_time, timer))
		elif timer < contact:
			agile_pose_between(wind, impact, smoothstep(wind_time, contact, timer))
		elif timer < follow_time:
			agile_pose_between(impact, follow, smoothstep(contact, follow_time, timer))
		elif special and index < strike_times.size() - 1:
			agile_pose_between(follow, ready, smoothstep(follow_time, strike_times[index + 1] - 0.055, timer))
		else:
			# A short settle after the flurry's final double slash.
			var settle: float = minf(duration - 0.05, follow_time + (0.06 if special and dagger else 0.0))
			agile_pose_between(follow, ready, smoothstep(settle, duration, timer))
		var phase: float = clampf((timer - start) / maxf(0.1, (follow_time - start) * 1.5), 0, 1)
		step = sin(PI * phase) * (0.17 if dagger else 0.24)
		crouch = sin(PI * clampf(timer / duration, 0, 1)) * (0.04 if dagger else 0.025)
	elif action == "dodge":
		hand.position = Vector3(0.28, 0.08, -0.3)
		hand.rotation = Vector3(0.9, 0, -0.15)
		torso.rotation = Vector3.ZERO
		if dagger and is_instance_valid(offhand):
			offhand.position = Vector3(-0.28, 0.12, -0.3)
			offhand.rotation = Vector3(0.9, 0, 0.15)
	elif action == "parry":
		hand.position = Vector3(0.14, 0.28, -0.42)
		hand.rotation = Vector3(0.65, -0.5, -0.3)
	torso.position.y = 0.9 - crouch
	if action != "dodge":
		visual.rotation.y = atan2(-facing.x, -facing.z) + torso.rotation.y * 0.3
	for i in planted_legs.size():
		var leg: Node3D = planted_legs[i]
		var side: float = signf(leg.position.x)
		var stepping: bool = side > 0 if not special else (side > 0) == (strike_index % 2 == 0)
		leg.position.z = side * torso.rotation.y * 0.1 - (step if stepping else -step * 0.15)
		var lift: float = step * 0.2 if stepping else 0.0
		leg.position.y = 0.3 + lift
		sword_feet[i].position = Vector3(leg.position.x, 0.08 + lift, leg.position.z - 0.08)
		sword_feet[i].rotation.y = torso.rotation.y * 0.3
	pose_gripping_arms(not dagger)

func pose_arm_segment(segment: MeshInstance3D, start: Vector3, end: Vector3) -> void:
	var direction: Vector3 = end - start
	segment.position = (start + end) * 0.5
	segment.basis = Basis(Quaternion(Vector3.UP, direction.normalized()))
	segment.scale = Vector3(1, direction.length(), 1)

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
	duration = 0.62
	invincible = 0.3
	visual.rotation = Vector3.ZERO
	facing = dodge_direction
	pose_greatsword()
	cache_roll_bounds(visual)
	game.sound("dodge")
	game.pulse(global_position, AshArt.MOSS, 0.7)

func animate_attack() -> void:
	if attack_kind in ["greatsword", "sword", "dagger", "spear"]:
		return
	var contact: float = strike_times[mini(strike_index, strike_times.size() - 1)] if not strike_times.is_empty() else strike_at
	var swing: float = clampf((timer - contact + 0.12) / 0.26, 0, 1)
	if special and attack_kind == "greatsword":
		visual.rotation.y = atan2(-facing.x, -facing.z) + clampf(timer / 0.9, 0, 1) * TAU
		hand.rotation = Vector3(0, -1.0, -0.6)
	elif special and attack_kind == "spear" and strike_index < 2:
		hand.rotation.y = timer / 0.65 * TAU * 2.0
	elif (heavy and attack_kind in ["sword", "greatsword"]) or (attack_kind == "greatsword" and combo == 2):
		hand.rotation = Vector3(lerpf(-1.7, 0.6, swing), 0, 0)
	elif (attack_kind == "spear" and (heavy or (special and strike_index >= 2) or (not special and combo < 2))) or (attack_kind == "sword" and combo == 2 and not special) or (heavy and attack_kind == "dagger"):
		hand.position.z = lerpf(-0.1, -0.8, sin(swing * PI))
		hand.rotation = Vector3.ZERO
	else:
		var reverse: bool = combo == 1 or (special and strike_index % 2 == 1)
		hand.rotation.y = lerpf(-1.8 if reverse else 1.6, 1.6 if reverse else -1.8, swing)
		hand.rotation.z = -0.45 if combo != 1 else 0.45
		if is_instance_valid(offhand):
			var left_slash: bool = (special and strike_index % 2 == 1) or (not special and combo == 1)
			if left_slash or (not special and combo == 2):
				offhand.rotation.y = -hand.rotation.y
				offhand.rotation.z = -hand.rotation.z
			if left_slash:
				hand.rotation = Vector3(-0.3, -0.3, -0.12)

func switch_weapon(kind: String) -> void:
	for entry in game.run.inventory:
		if entry.kind == kind:
			game.run.equipped_uid = entry.uid
			refresh_weapon()
			game.run.changed.emit()
			game.toast("Equipped " + entry.name)
			return
	game.toast("No %s in your inventory." % kind)

func begin_attack(is_heavy: bool, is_special: bool = false) -> void:
	var entry: Dictionary = game.run.equipped()
	var weapon: Dictionary = AshData.WEAPONS[entry.kind]
	if is_special and entry.xp < 50:
		game.toast("Special unlocks at 50 weapon mastery XP.")
		return
	if is_special and special_cooldowns.get(entry.kind, 0.0) > 0:
		game.toast("%s ready in %.1fs" % [weapon.technique, special_cooldowns[entry.kind]])
		return
	var cost: float = 30.0 if is_special else weapon.cost * (2.0 if is_heavy else 1.0)
	if not spend(cost):
		return
	attack_kind = entry.kind
	if not is_heavy and not is_special:
		combo = (combo + 1) % (3 if entry.xp >= 25 else 2) if combo_grace > 0 else 0
		combo_grace = 0.8
	else:
		combo = 0
		combo_grace = 0
	heavy = is_heavy
	special = is_special
	struck = false
	buffered = false
	strike_index = 0
	strike_times.clear()
	strike_at = weapon.windup * (1.8 if heavy else 1.0)
	duration = strike_at + weapon.recovery * (1.5 if heavy else 1.0)
	if special:
		special_cooldowns[attack_kind] = weapon.cooldown
		if attack_kind == "sword":
			action = "counter"
			counter_ready = true
			duration = 1.0
		elif attack_kind == "dagger":
			strike_times.assign([0.15, 0.29, 0.43, 0.57, 0.71])
			duration = 1.0
		elif attack_kind == "spear":
			strike_times.assign([0.3, 0.65, 1.0])
			duration = 1.4
		else:
			strike_times.assign([0.65])
			duration = 1.5
	else:
		strike_times.append(strike_at)
	timer = 0
	if not (special and attack_kind == "sword"):
		action = "attack"
	if is_instance_valid(locked):
		facing = (locked.global_position - global_position).normalized()
		facing.y = 0
	else:
		facing = Vector3.FORWARD.rotated(Vector3.UP, yaw)

func strike(counter_target: Node3D = null) -> void:
	var entry: Dictionary = game.run.equipped()
	var weapon: Dictionary = AshData.WEAPONS[attack_kind]
	var base: float = weapon.special[mini(strike_index, weapon.special.size() - 1)] if special else (weapon.heavy if heavy else weapon.hits[combo])
	var damage: float = base * game.run.damage_scale * (1.0 + entry.rarity * 0.15)
	var reach: float = weapon.reach + (0.8 if special else 0.0)
	var radial: bool = (special and (attack_kind == "greatsword" or (attack_kind == "spear" and strike_index < 2))) or (heavy and attack_kind == "greatsword")
	game.slash(global_position + Vector3(0, 0.9, 0), facing, reach, radial)
	game.sound("swing")
	for foe in game.foes:
		if not is_instance_valid(foe) or foe.dead or (counter_target != null and foe != counter_target):
			continue
		var toward: Vector3 = foe.global_position - global_position
		toward.y = 0
		var arc: float = -0.3 if (not heavy and not special and attack_kind == "spear" and combo == 2) else 0.15
		if toward.length() <= reach + foe.body_radius and (radial or toward.normalized().dot(facing) > arc):
			foe.take_hit(damage, heavy or special, global_position)
			if heavy and attack_kind == "sword":
				foe.stagger(1.0 if foe.rank > 0 else 2.0)
			if (special and attack_kind == "greatsword") or (heavy and attack_kind == "spear"):
				foe.knockback = toward.normalized() * (7.0 if special else 4.0)
			shake = 0.35
			game.hitstop = 0.055 if not heavy else 0.085

func cache_roll_bounds(node: Node3D) -> void:
	roll_bounds.clear()
	_collect_roll_bounds(node, Transform3D.IDENTITY)

func _collect_roll_bounds(node: Node3D, parent_transform: Transform3D) -> void:
	for child in node.get_children():
		if child is Node3D and not child.is_queued_for_deletion() and child.visible:
			var local: Transform3D = parent_transform * child.transform
			if child is MeshInstance3D:
				var bounds: AABB = child.get_aabb()
				for i in 8:
					roll_bounds.append(local * bounds.get_endpoint(i))
			_collect_roll_bounds(child, local)

func animate_roll(phase: float) -> void:
	var tuck: float = sin(PI * phase)
	visual.position = Vector3(0, -0.95, 0)
	visual.rotation = Vector3.ZERO
	visual.scale = Vector3(1, 1 - 0.42 * tuck, 1 + 0.12 * tuck)
	roll_pivot.rotation = Vector3(0, atan2(-dodge_direction.x, -dodge_direction.z), 0)
	roll_pivot.rotate_object_local(Vector3.RIGHT, -TAU * phase)
	var lowest := 0.0
	for corner in roll_bounds:
		var point: Vector3 = roll_pivot.basis * (visual.transform * corner)
		lowest = minf(lowest, point.y)
	roll_pivot.position.y = -lowest + 0.035

func take_hit(damage: float, source: Node3D = null, parryable: bool = true) -> bool:
	if game.run.health <= 0 or invincible > 0 or not game.playing:
		return false
	if action == "counter" and counter_ready and is_instance_valid(source):
		counter_ready = false
		facing = (source.global_position - global_position).normalized()
		facing.y = 0
		strike_index = 0
		strike(source)
		action = "riposte"
		timer = 0
		duration = 0.38
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
	if not (action == "attack" and heavy):
		action = "hurt"
		timer = 0
		duration = 0.32
		buffered = false
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
