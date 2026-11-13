extends SceneTree

var game: Node
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run_checks")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)

func frames(count: int = 2) -> void:
	for i in count:
		await physics_frame

func run_checks() -> void:
	game = load("res://game/game.tscn").instantiate()
	root.add_child(game)
	await frames()
	check(game.ui.mode == "title", "Startup opens the title screen")
	game.start_run(719)
	await frames()
	check(game.foes.size() == 2, "First arena spawns two goblins")
	check(game.arena.hazards.size() == 2, "Arena contains environmental hazards")
	check(game.arena.doors.is_empty(), "Exits remain closed during combat")
	check(game.run.health == 100 and game.player.stamina == 100, "New run initializes vitality and stamina")
	var player: AshKnight = game.player
	var initial_z := player.global_position.z
	Input.action_press("forward")
	await frames(10)
	Input.action_release("forward")
	check(player.global_position.z < initial_z - 0.3, "WASD input moves the player relative to the camera")
	Input.action_press("lock")
	await frames()
	Input.action_release("lock")
	check(is_instance_valid(player.locked), "Lock input acquires a visible foe")
	player.locked = null
	var foe: AshFoe = game.foes[0]
	player.global_position = Vector3(0, 0.1, 6)
	foe.global_position = Vector3(0, 0.1, 4)
	player.facing = Vector3.FORWARD
	player.stamina = 100
	player.begin_attack(false)
	check(player.stamina == 85, "Sword light attack spends fifteen stamina")
	var old_hp := foe.health
	player.strike()
	check(foe.health < old_hp, "Player strike damages a foe in reach and facing arc")
	player.action = "idle"
	player.stamina = 0
	player.begin_attack(true)
	check(player.action == "idle", "Exhaustion prevents an attack")
	player.stamina = 100
	player.begin_dodge(Vector3.RIGHT)
	check(player.stamina == 85 and is_equal_approx(player.invincible, 0.3), "Dodge costs fifteen and grants 0.3 seconds of invulnerability")
	var hp: float = game.run.health
	player.take_hit(20, foe)
	check(game.run.health == hp, "Dodge invulnerability prevents damage")
	player.invincible = 0
	player.parry_window = 0.25
	player.take_hit(20, foe)
	check(game.run.health == hp and foe.state == "stagger", "Facing parry prevents damage and staggers the attacker")
	check(is_equal_approx(foe.stagger_duration, 1.5), "Parry stagger lasts 1.5 seconds")
	player.parry_window = 0
	player.take_hit(20, foe)
	check(game.run.health == hp - 20, "Unprotected hit removes vitality")
	game.ui.show_inventory()
	game.ui.inventory_buttons[1].pressed.emit()
	check(game.ui.selected == 1, "Clicking an inventory slot selects that item")
	var paused_position := foe.global_position
	await frames(15)
	check(foe.global_position.is_equal_approx(paused_position), "Inventory pauses enemy simulation")
	game.ui.clear_modal()
	game.run.grant_mastery(25)
	check(game.run.equipped().xp == 25, "Mastery reaches the combo threshold")
	game.run.grant_mastery(25)
	check(game.run.equipped().xp == 50, "Mastery reaches the special threshold")
	player.action = "idle"
	player.stamina = 100
	player.begin_attack(false, true)
	check(player.stamina == 70, "Mastery special spends thirty stamina")

	game.run.reset(719)
	var new_flask := AshData.item("flask")
	game.run.add_item(new_flask)
	game.run.add_item(AshData.item("flask"))
	check(game.run.inventory[1].amount == 5, "Consumables stack to five")
	game.run.add_item(AshData.item("flask"))
	check(game.run.inventory.size() == 6 and game.run.inventory[5].amount == 1, "Sixth consumable starts a new slot")
	while game.run.inventory.size() < 12:
		game.run.add_item(AshData.item("dagger"))
	check(not game.run.add_item(AshData.item("spear")), "Full inventory rejects a new weapon")
	check(game.run.add_item(AshData.item("flask")), "Full inventory accepts an item into an existing stack")
	var carried: int = game.run.inventory.size()
	game.drop_inventory(0)
	check(game.run.inventory.size() == carried, "Equipped weapon cannot be dropped")
	game.drop_inventory(3)
	check(game.run.inventory.size() == carried - 1 and game.pickups.size() > 0, "Dropping creates a world pickup and frees a slot")
	game.run.reset(719)
	game.load_room("shop")
	await frames()
	game.run.currency = 200
	game.buy_item(0)
	check(game.run.currency == 100 and game.run.inventory[1].amount == 4, "Shop purchase transfers currency and stacks the bought item")
	game.sell_item(1)
	check(game.run.currency == 150 and game.run.inventory[1].amount == 3, "Shop sells one item for half its new value")
	game.run.currency = 0
	carried = game.run.inventory.size()
	game.buy_item(2)
	check(game.run.inventory.size() == carried and game.run.currency == 0, "Shop blocks unaffordable purchases")
	game.ui.show_inventory(true)
	check(game.ui.mode == "shop" and game.ui.inventory_buttons.size() == 12, "Shop interface renders inventory and stock")
	game.ui.clear_modal()
	for tier in 5:
		check(AshData.price(AshData.item("sword", tier)) == 100 + 25 * tier, "Rarity price tier " + str(tier))

	game.load_room("rest")
	await frames()
	game.run.health = 20
	player.action = "idle"
	game.prompt_target = {"kind": "bed"}
	game.interact()
	check(game.run.health == 70 and game.arena.rest_used, "Rest bed restores fifty percent of maximum health")
	game.prompt_target = {"kind": "bench"}
	game.interact()
	check(game.run.equipped().xp == 0, "A rest site permits only one benefit")
	game.load_room("rest")
	await frames()
	game.prompt_target = {"kind": "bench"}
	game.interact()
	check(game.run.equipped().xp == 20, "Workbench grants twenty mastery XP")
	var strength: float = game.run.damage_scale
	game.run.upgrade("Strength")
	check(is_equal_approx(game.run.damage_scale, strength * 1.2), "Campfire stat improvement is twenty percent")
	for outcome in 5:
		game.run.reset(719)
		game.load_room("rest")
		await frames()
		game.resolve_mystery(outcome)
		match outcome:
			0: check(game.ambush and game.foes.size() == 2 and game.arena.doors.is_empty(), "Mystery ambush closes progression and creates enemies")
			1: check(game.run.max_health < 100 or game.run.damage_scale < 1 or game.run.speed_scale < 1, "Mystery curse lowers a stat")
			2: check(game.run.currency == 75 or game.run.inventory.size() == 4, "Mystery robbery takes currency or an item")
			3: check(game.run.max_health > 100 or game.run.damage_scale > 1 or game.run.speed_scale > 1, "Mystery blessing raises a stat")
			4: check(game.pickups.size() == 1, "Mystery remains provide a loot pickup")
	var loot_rng := RandomNumberGenerator.new()
	loot_rng.seed = 1234
	var bins := [0, 0, 0, 0, 0]
	for i in 20000:
		bins[AshData.roll_rarity(loot_rng)] += 1
	var expected := [0.59, 0.25, 0.12, 0.03, 0.01]
	for i in 5:
		check(absf(bins[i] / 20000.0 - expected[i]) < 0.015, "Loot rarity distribution tier " + str(i))
	var boss_valid := true
	for i in 1000:
		if AshData.loot(loot_rng, "stone", true).rarity < 2:
			boss_valid = false
	check(boss_valid, "Boss loot always rolls rare or better")

	# Exercise the full main path through actual doorway detection and transitions.
	game.start_run(719)
	await frames()
	var original_biomes: Array = game.biomes.duplicate()
	for level in range(1, 6):
		check(game.arena_number == level, "Main path reaches arena " + str(level))
		var expected_foes := 1 if level == 5 else (2 if level <= 2 else 3)
		check(game.foes.size() == expected_foes, "Arena %d has the expected enemy count" % level)
		var kinds := {}
		for target in game.foes:
			check(target.has_method("_begin_goblin_attack"), "Arena %d uses a new goblin enemy" % level)
			if level < 5:
				kinds[target.kind] = true
		check(kinds.size() <= 2, "Arena %d uses at most two goblin types" % level)
		if level == 5:
			check(game.foes[0].title == "The Gilded Hexlord", "Final arena contains only the goblin boss")
			check(is_equal_approx(game.foes[0].max_health, 372.5), "Final boss health is halved")
		game.player.invincible = 100
		for target in game.foes.duplicate():
			target.take_hit(10000, true, Vector3.ZERO)
		await frames()
		if level == 5:
			check(not game.playing and game.ui.mode == "result", "Final boss defeat opens the victory result")
			break
		check(game.arena.doors.size() == 2, "Combat clear opens two branch choices")
		check(game.arena.doors[0].kind != game.arena.doors[1].kind, "Branch choices are distinct")
		await game.transition_room("rest")
		check(game.arena.room_kind == "rest" and game.arena_number == level, "Special room does not advance the arena counter")
		# Teleport inside the open trigger, then let the real game loop detect it.
		player.global_position = Vector3(-6, 0.1, -16.2)
		await create_timer(1.1).timeout
		check(game.arena.room_kind == "combat", "Walking through a special room exit enters combat")
	game.start_run(719)
	await frames()
	check(game.biomes == original_biomes, "Retrying a seed preserves the biome order")
	game.player.invincible = 0
	game.player.parry_window = 0
	game.player.take_hit(10000, null, false)
	check(not game.playing and game.ui.mode == "result", "Zero vitality ends the run")
	game.start_run(720)
	await frames()
	check(game.playing and game.arena_number == 1 and game.run.kills == 0 and game.run.health == 100, "Restart clears progress and begins a fresh run")
	print("ASHEN BOUGH: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	AshArt.materials.clear()
	await frames()
	quit(0 if failures == 0 else 1)
