extends SceneTree

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var game: Node = load("res://game/goblin_test.tscn").instantiate()
	root.add_child(game)
	for i in 3:
		await physics_frame
	assert(game.playing and game.foes.size() == 4)
	assert(game.foes[0].kind == "club")
	assert(game.foes[1].kind == "caster")
	assert(game.foes[2].kind == "missile")
	assert(game.foes[3].title == "The Gilded Hexlord")
	game.player.invincible = 100.0
	for foe in game.foes:
		assert(foe.parts.has("left_arm") and foe.parts.has("right_leg"))
		foe._begin_goblin_attack()
	for i in 24:
		await physics_frame
	var club: AshFoe = game.foes[0]
	var caster: AshFoe = game.foes[1]
	var gunner: AshFoe = game.foes[2]
	assert(club.parts.right_arm.rotation.z > 0.5, "Club winds up at the side")
	assert(not caster.marker.visible and not caster.lightning_sprites[0].visible, "Magic effects stay hidden during windup")
	assert(caster.lightning_sprites[0].texture.get_image().get_pixel(0, 0).a < 0.1, "Electricity sprite has transparent corners")
	var cannon: Node3D = gunner.parts.weapon
	var aim: Vector3 = (game.player.global_position + Vector3(0, 0.9, 0) - cannon.global_position).normalized()
	assert((-cannon.global_basis.z).dot(aim) > 0.98, "Cannon points at the player")
	for i in 31:
		await physics_frame
	assert(club.club_smear.visible and not club.attack_done, "Smear warns before club damage")
	for i in 4:
		await physics_frame
	var club_weapon: Node3D = club.parts.weapon
	var club_tip: Vector3 = club.visual.to_local(club_weapon.to_global(Vector3(0, -0.05, -1.8)))
	assert(club.parts.right_arm.rotation.x > 0.8, "Arm reaches forward at swing midpoint")
	assert(club_tip.z < -1.6, "Longer club reaches farther in front")
	assert((-club_weapon.global_basis.z).dot(-club.visual.global_basis.z) > 0.7, "Club is perpendicular to the goblin front")
	for i in 11:
		await physics_frame
	assert(club.parts.right_arm.rotation.y > 0.0, "Club sweeps horizontally across the body")
	assert(club.club_smear.visible and club.club_smear_mesh.get_surface_count() > 0, "Club smear follows the damaging sweep")
	assert(club.club_smear_mesh.get_aabb().size.length() > 2.0, "Gold smear spans the larger swing")
	assert(caster.marker.visible and caster.lightning_sprites[0].visible, "Magic ring and sprites show during the hit window")
	for i in 40:
		await physics_frame
	assert(not caster.marker.visible and not caster.lightning_sprites[0].visible, "Magic effects end after the hit window")
	assert(game.foes[0].attack_done)
	assert(game.foes[1].attack_done)
	assert(game.foes[2].attack_done)
	game.foes[0].take_hit(10000, true, Vector3.ZERO)
	assert(game.foes[0].dead and game.foes[0].state == "die")
	for i in 50:
		await physics_frame
	assert(not is_instance_valid(game.foes[0]))
	print("Goblin models, all three attacks, and death animation passed")
	quit()
