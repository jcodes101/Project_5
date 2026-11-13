extends SceneTree

var failures := 0
var checks := 0

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(description)

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	var game = load("res://game/game.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.start_run(719)
	game.player.set_physics_process(false)
	for target in game.foes.duplicate():
		target.queue_free()
	game.foes.clear()
	await physics_frame
	for boss in [false, true]:
		var foe: AshFoe = game.spawn_boss(Vector3(0, 0.1, 2)) if boss else game.spawn_goblin("club", Vector3(0, 0.1, 2))
		foe.set_physics_process(false)
		foe.health = 10000
		foe.max_health = 10000
		var player: AshKnight = game.player
		player.position = Vector3(0, 0.1, 4)
		player.yaw = 0
		for kind in ["spear", "greatsword"]:
			player.switch_weapon(kind)
			game.run.equipped().xp = 50
			player.special_cooldowns.clear()
			player.stamina = 100
			player.begin_attack(kind == "spear", kind == "greatsword")
			player.strike()
			check(foe.knockback.length() > 0, "%s applies knockback to boss=%s" % [kind, boss])
			var before := foe.position
			game.hitstop = 0
			foe._physics_process(1.0 / 60.0)
			check(foe.position.z < before.z, "Goblin movement consumes weapon knockback")
			foe.position = Vector3(0, 0.1, 2)
		player.switch_weapon("sword")
		player.stamina = 100
		player.begin_attack(true)
		player.strike()
		check(is_equal_approx(foe.stagger_duration, 1.0 if boss else 2.0), "Guardbreaker honors goblin rank")
		player.special_cooldowns.clear()
		game.run.equipped().xp = 50
		player.stamina = 100
		player.invincible = 0
		player.begin_attack(false, true)
		var health_before: float = game.run.health
		var foe_before := foe.health
		player.take_hit(20, foe)
		check(game.run.health == health_before and foe.health < foe_before and player.action == "riposte", "Riposte counters goblin attacks")
		game.foes.erase(foe)
		foe.queue_free()
		await physics_frame
	print("WEAPON GOBLIN INTEGRATION: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
