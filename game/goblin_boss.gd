class_name GoblinBoss
extends "res://game/goblin_foe.gd"

const ATTACKS := ["club", "caster", "missile"]
var attack_index := 0

func _ready() -> void:
	kind = "club"
	set("combat_scale", 1.5)
	super._ready()
	name = "GoblinBoss"
	title = "The Gilded Hexlord"
	family = "iron"
	rank = 2
	max_health = (520.0 + arena_level * 45.0) * 0.5
	health = max_health
	body_radius = 0.82
	var collider: CollisionShape3D = get_node("BodyCollider")
	var capsule: CapsuleShape3D = collider.shape
	capsule.radius = body_radius
	capsule.height = 3.7
	collider.position.y = 1.85
	visual.scale = Vector3.ONE * 1.7
	bar_root.position.y = 4.5
	bar_root.scale = Vector3.ONE * 1.4
	marker.material_override = AshArt.material(GOBLIN_ART.VIOLET, false, 1.2)
	_add_boss_details()
	_add_magic_effects()
	cooldown = 1.0

func _add_boss_details() -> void:
	var torso: Node3D = parts.torso
	var head: Node3D = parts.head
	# The club body gains the caster's robe and hat, missile armor, and a heavy crown.
	AshArt.cylinder(torso, Vector3(0, 0.72, 0.05), 0.62, 0.33, 0.58, GOBLIN_ART.PURPLE, 8)
	for side in [-1, 1]:
		AshArt.box(torso, Vector3(side * 0.37, 1.17, -0.22), Vector3(0.23, 0.48, 0.21), GOBLIN_ART.ORANGE)
		AshArt.cylinder(head, Vector3(side * 0.32, 0.39, 0.02), 0.12, 0.0, 0.47, AshArt.GOLD, 5)
	AshArt.cylinder(head, Vector3(0, 0.39, 0), 0.65, 0.3, 0.3, GOBLIN_ART.PURPLE, 8)
	GOBLIN_ART.cone(head, Vector3(0.08, 0.82, 0), 0.48, 0.75, GOBLIN_ART.PURPLE, 7).rotation.z = -0.22
	AshArt.ring(head, 0.5, AshArt.GOLD, 0.065).position.y = 0.29
	var gem := GOBLIN_ART.ellipsoid(torso, Vector3(0, 1.24, -0.49), Vector3(0.28, 0.32, 0.15), GOBLIN_ART.VIOLET, 1.5)
	gem.name = "CasterGem"
	var cannon := Node3D.new()
	cannon.name = "BossCannon"
	parts.left_arm.add_child(cannon)
	cannon.position = Vector3(-0.17, -0.69, -0.25)
	AshArt.cylinder(cannon, Vector3(0, 0, -0.55), 0.32, 0.32, 1.25, GOBLIN_ART.BOOT, 8).rotation.x = PI * 0.5
	AshArt.cylinder(cannon, Vector3(0, 0, -1.12), 0.41, 0.41, 0.17, GOBLIN_ART.ORANGE, 8).rotation.x = PI * 0.5
	GOBLIN_ART.ellipsoid(cannon, Vector3(0, 0, -1.3), Vector3(0.22, 0.22, 0.18), Color("ce4746"), 1.1)
	parts["cannon"] = cannon
	var missile_rack := Node3D.new()
	missile_rack.name = "MissileRack"
	torso.add_child(missile_rack)
	for side in [-1, 1]:
		AshArt.cylinder(missile_rack, Vector3(side * 0.32, 1.45, 0.37), 0.16, 0.16, 0.62, GOBLIN_ART.ORANGE, 6).rotation.x = PI * 0.5
		GOBLIN_ART.cone(missile_rack, Vector3(side * 0.32, 1.45, -0.03), 0.16, 0.27, Color("ce4746"), 6).rotation.x = -PI * 0.5

func _add_magic_effects() -> void:
	for i in range(20):
		var arc := AshArt.box(self, Vector3.ZERO, Vector3(0.2, 0.07, 0.07), GOBLIN_ART.VIOLET)
		arc.material_override = AshArt.material(GOBLIN_ART.VIOLET, false, 2.0)
		arc.visible = false
		lightning.append(arc)
	for i in range(12):
		var spark := Sprite3D.new()
		spark.name = "BossElectricity%d" % i
		spark.texture = ELECTRIC_TEXTURE
		spark.pixel_size = 0.0014
		spark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		spark.shaded = false
		spark.visible = false
		add_child(spark)
		lightning_sprites.append(spark)

func _physics_process(delta: float) -> void:
	var previous_state := state
	super._physics_process(delta)
	if dead:
		return
	visual.scale = Vector3.ONE * 1.7 * (1.0 + flash * 0.22)
	if previous_state == "recover" and state == "idle":
		attack_index = (attack_index + 1) % ATTACKS.size()
		kind = ATTACKS[attack_index]
		cooldown = 0.7

func _begin_goblin_attack() -> void:
	super._begin_goblin_attack()
	if kind == "club":
		attack_radius = 4.2
	elif kind == "caster":
		attack_radius = 4.5
		windup = 1.1
	else:
		windup = 0.95

func _execute_goblin_attack(toward: Vector3, distance: float) -> void:
	if kind == "club":
		game.slash(global_position + Vector3(0, 1.7, 0), -visual.global_basis.z, 4.2, false, AshArt.GOLD)
		game.sound("swing")
		if distance < 4.2 and toward.normalized().dot(-visual.global_basis.z) > 0.15:
			game.player.take_hit(26 + arena_level * 2, self)
	elif kind == "caster":
		game.pulse(global_position, GOBLIN_ART.VIOLET, 4.5)
		game.sound("slam")
		if distance < 4.5:
			game.player.take_hit(22 + arena_level * 2, self)
	else:
		_aim_cannon()
		var cannon: Node3D = parts.cannon
		var muzzle := cannon.to_global(Vector3(0, 0, -1.37))
		var toward_player: Vector3 = (game.player.global_position + Vector3(0, 0.9, 0) - muzzle).normalized()
		for angle in [-0.13, 0.0, 0.13]:
			var missile = GOBLIN_MISSILE.new()
			missile.game = game
			missile.source = self
			missile.direction = toward_player.rotated(Vector3.UP, angle)
			game.effects.add_child(missile)
			missile.global_position = muzzle + Vector3(angle * 1.2, 0, 0)
		game.sound("swing")

func _aim_cannon() -> void:
	if not parts.has("cannon"):
		return
	var cannon: Node3D = parts.cannon
	var target: Vector3 = game.player.global_position + Vector3(0, 0.9, 0)
	if cannon.global_position.distance_squared_to(target) > 0.01:
		cannon.look_at(target, Vector3.UP)

func _update_lightning() -> void:
	if kind != "caster":
		for arc in lightning:
			arc.visible = false
		for spark in lightning_sprites:
			spark.visible = false
		return
	var active := state == "attack" and timer >= MAGIC_HIT_START and timer <= MAGIC_HIT_END
	for i in lightning.size():
		var arc := lightning[i]
		arc.visible = active
		if active:
			var angle := TAU * float(i) / float(lightning.size())
			arc.position = Vector3(cos(angle) * 4.4, 0.12, sin(angle) * 4.4)
			arc.rotation.y = -angle
	for i in lightning_sprites.size():
		var spark := lightning_sprites[i]
		spark.visible = active
		if active:
			var angle := TAU * float(i) / float(lightning_sprites.size()) + timer * 0.3
			spark.position = Vector3(cos(angle) * 4.25, 0.78 + sin(timer * 30.0 + i) * 0.12, sin(angle) * 4.25)
			spark.modulate.a = 0.7 + absf(sin(timer * 24.0 + i)) * 0.3
