extends SceneTree

var checks := 0
var failures := 0

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
	await physics_frame
	game.ui.show_inventory()
	var player = game.player
	var foe = game.foes[0]
	for other in game.foes:
		other.position = Vector3(10, 0, -10)
	player.position = Vector3(0, 0, 4)
	foe.position = Vector3(0, 0, 3)
	foe.health = 10000
	foe.max_health = 10000
	for kind in ["sword", "dagger", "greatsword", "spear"]:
		player.switch_weapon(kind)
		var entry: Dictionary = game.run.equipped()
		var weapon: Dictionary = AshData.WEAPONS[kind]
		check(entry.kind == kind, "Weapon selection: " + kind)
		entry.xp = 0
		player.special_cooldowns.clear()
		player.stamina = 100
		player.action = "idle"
		player.begin_attack(false, true)
		check(player.stamina == 100, "Special locked below 50 XP: " + kind)
		player.combo_grace = 0
		for i in 3:
			player.stamina = 100
			player.begin_attack(false)
			check(player.combo == i % 2, "Two-hit combo before mastery: " + kind)
			player.combo_grace = 0.8
		entry.xp = 25
		player.combo_grace = 0
		for i in 3:
			player.stamina = 100
			player.begin_attack(false)
			foe.state = "idle"
			var before: float = foe.health
			player.strike()
			check(is_equal_approx(before - foe.health, float(weapon.hits[i])), "Exact combo damage: %s hit %d" % [kind, i])
			check(player.stamina == 100 - weapon.cost, "Light stamina: " + kind)
			player.combo_grace = 0.8
		player.stamina = 100
		player.begin_attack(true)
		check(player.stamina == 100 - 2 * weapon.cost, "Double heavy stamina: " + kind)
		foe.state = "idle"
		var before: float = foe.health
		player.strike()
		check(is_equal_approx(before - foe.health, float(weapon.heavy)), "Exact heavy damage: " + kind)
		if kind == "sword":
			check(foe.stagger_duration == 2.0, "Regular Guardbreaker stagger")
			for rank in [1, 2]:
				foe.rank = rank
				player.strike()
				check(foe.stagger_duration == 1.0, "Boss/miniboss Guardbreaker stagger")
			foe.rank = 0
		entry.xp = 50
		player.stamina = 100
		player.begin_attack(false, true)
		check(player.stamina == 70, "Special stamina: " + kind)
		check(player.special_cooldowns[kind] == weapon.cooldown, "Special cooldown: " + kind)
		before = foe.health
		foe.state = "idle"
		if kind == "sword":
			player.invincible = 0
			player.take_hit(10, foe)
			check(not player.counter_ready, "Counter consumed on incoming attack")
		else:
			for i in weapon.special.size():
				foe.state = "idle"
				player.strike_index = i
				player.strike()
		var expected: float = 0
		for damage in weapon.special:
			expected += damage
		check(foe.health < before, "Special connects: " + kind)
		check(is_equal_approx(before - foe.health, expected), "Exact special total: " + kind)
		player.action = "idle"
		player.stamina = 100
		player.begin_attack(false, true)
		check(player.stamina == 100, "Cooldown prevents repeat special: " + kind)
		if kind == "greatsword":
			player.action = "idle"
			player.pose_greatsword()
			check(player.hand.rotation.x > 2.5, "Greatsword rests backward over shoulder")
			for attack_type in ["light", "heavy", "special"]:
				player.special_cooldowns.clear()
				player.stamina = 100
				player.begin_attack(attack_type == "heavy", attack_type == "special")
				var expected_contact: float = 0.65 if attack_type == "special" else (0.828 if attack_type == "heavy" else 0.46)
				check(is_equal_approx(player.strike_times[0], expected_contact), "Greatsword impact timing preserved: " + attack_type)
				for sample in range(11):
					player.timer = player.duration * sample / 10.0
					player.pose_greatsword()
					for arm in 2:
						var grip: Vector3 = player.hand.transform * Vector3(0, 0, 0.19 if arm == 0 else 0.015)
						check(player.greatsword_arms[arm * 3 + 2].position.distance_to(grip) < 0.001, "Both hands follow greatsword grip: " + attack_type)

		for direction in [Vector3.FORWARD, Vector3.RIGHT, Vector3.BACK, Vector3(-1, 0, -1).normalized()]:
			player.stamina = 100
			player.begin_dodge(direction)
			for frame in range(21):
				player.animate_roll(frame / 20.0)
				var minimum := 100.0
				for corner in player.roll_bounds:
					var point: Vector3 = player.roll_pivot.transform * (player.visual.transform * corner)
					minimum = minf(minimum, point.y)
				check(minimum >= 0.034, "Roll floor clearance: " + kind)
		player.roll_pivot.transform = Transform3D.IDENTITY
		player.visual.transform = Transform3D.IDENTITY
	player.switch_weapon("sword")
	player.action = "idle"
	player.pose_greatsword()
	var ready_hand: Transform3D = player.hand.transform
	var ready_body: Vector3 = player.torso.rotation
	for phase in [0, 1, 2, 3]:
		player.stamina = 100
		game.run.equipped().xp = 50
		player.begin_attack(phase == 3)
		player.combo = mini(phase, 2)
		var contact: float = player.strike_at
		var torso_motion := 0.0
		for frame in range(21):
			player.timer = player.duration * frame / 20.0
			player.pose_greatsword()
			torso_motion = maxf(torso_motion, player.torso.rotation.distance_to(ready_body))
			var grip: Vector3 = player.hand.transform * Vector3(0, 0, 0.015)
			check(player.greatsword_arms[5].position.distance_to(grip) < 0.001, "Sword right hand stays on grip")
			if phase == 3 and player.timer >= 0.1 and player.timer <= player.duration - 0.14:
				var left_grip: Vector3 = player.hand.transform * Vector3(0, 0, 0.19)
				check(player.greatsword_arms[2].position.distance_to(left_grip) < 0.001, "Guardbreaker uses both hands")
			for foot in player.sword_feet:
				check(foot.position.y >= 0.07999, "Sword footwork stays above floor")
		check(player.hand.position.distance_to(ready_hand.origin) < 0.001, "Sword attack returns to ready stance")
		player.timer = contact
		player.pose_greatsword()
		check(torso_motion > 0.05, "Sword attack moves torso")
		check(is_equal_approx(player.strike_at, contact), "Sword pose does not change impact timing")
	player.action = "counter"
	player.timer = 0.4
	player.pose_greatsword()
	check(player.hand.position.distance_to(ready_hand.origin) > 0.1, "Riposte presents a defensive guard")
	player.timer = 1.0
	player.pose_greatsword()
	check(player.hand.position.distance_to(ready_hand.origin) < 0.001, "Untriggered Riposte returns smoothly to ready")
	player.action = "riposte"
	player.duration = 0.38
	player.timer = 0.15
	player.pose_greatsword()
	check(absf(player.visual.rotation.y - atan2(-player.facing.x, -player.facing.z)) < 0.4, "Riposte uses controlled movement without spinning")
	player.timer = player.duration
	player.pose_greatsword()
	check(player.hand.position.distance_to(ready_hand.origin) < 0.001, "Riposte counter recovers to ready")
	for kind in ["dagger", "spear"]:
		player.action = "idle"
		player.switch_weapon(kind)
		player.pose_greatsword()
		var rest: Transform3D = player.hand.transform
		for variant in range(5):
			player.stamina = 100
			player.special_cooldowns.clear()
			game.run.equipped().xp = 50
			player.begin_attack(variant == 3, variant == 4)
			if variant < 3:
				player.combo = variant
			var impact_times: Array = player.strike_times.duplicate()
			var motion := 0.0
			for sample in range(31):
				player.timer = player.duration * sample / 30.0
				player.pose_greatsword()
				motion = maxf(motion, player.torso.rotation.length())
				var right_grip: Vector3 = player.hand.transform * Vector3(0, 0, 0.015)
				var left_grip: Vector3 = player.offhand.transform * Vector3(0, 0, 0.015) if kind == "dagger" else player.hand.transform * Vector3(0, 0, -0.4)
				check(player.greatsword_arms[5].position.distance_to(right_grip) < 0.001, "Right weapon grip: " + kind)
				check(player.greatsword_arms[2].position.distance_to(left_grip) < 0.001, "Left weapon grip: " + kind)
				check(absf(player.visual.rotation.y - atan2(-player.facing.x, -player.facing.z)) < 0.5, "Controlled body rotation without spinning: " + kind)
				for foot in player.sword_feet:
					check(foot.position.y >= 0.07999, "Agile footwork clearance: " + kind)
			check(player.hand.position.distance_to(rest.origin) < 0.001, "Agile attack returns to ready: " + kind)
			check(motion > 0.05, "Agile attack uses torso: " + kind)
			check(player.strike_times == impact_times, "Animation preserves damage event timing: " + kind)
			if variant == 4:
				check(player.strike_times.size() == (5 if kind == "dagger" else 3), "Special strike count: " + kind)
	print("COMBAT CHECK: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
