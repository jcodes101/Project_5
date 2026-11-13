extends SceneTree

const MISSILE = preload("res://game/goblin_missile.gd")

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var game: Node = load("res://game/goblin_boss_test.tscn").instantiate()
	root.add_child(game)
	for i in 3:
		await physics_frame
	assert(game.playing and game.foes.size() == 1)
	var boss: AshFoe = game.foes[0]
	assert(boss.title == "The Gilded Hexlord" and is_equal_approx(boss.max_health, 282.5))
	assert(boss.parts.has("cannon") and boss.lightning_sprites.size() == 12)
	assert(boss.club_smear != null and boss.visual.scale.x > 1.5)
	game.player.invincible = 100.0
	for style in ["club", "caster", "missile"]:
		assert(boss.kind == style)
		boss._begin_goblin_attack()
		var saw_hit := false
		var saw_effect := false
		for i in 170:
			await physics_frame
			if boss.attack_done:
				saw_hit = true
			if style == "club" and boss.club_smear.visible:
				saw_effect = boss.club_smear_mesh.get_surface_count() > 0
			elif style == "caster" and boss.marker.visible and boss.lightning_sprites[0].visible:
				saw_effect = boss.attack_radius > 4.0
			elif style == "missile" and boss.attack_done:
				var count := 0
				for effect in game.effects.get_children():
					if effect.get_script() == MISSILE:
						count += 1
				saw_effect = saw_effect or count >= 3
			if boss.kind != style:
				break
		assert(saw_hit and saw_effect, "Boss completes " + style + " attack with its effect")
	assert(boss.kind == "club", "Boss cycles back to club after all three attacks")
	boss.take_hit(10000, true, Vector3.ZERO)
	assert(boss.dead and boss.state == "die")
	for i in 55:
		await physics_frame
	assert(not is_instance_valid(boss))
	print("Boss model, club sweep, magic circle, missile volley, and death passed")
	quit()
