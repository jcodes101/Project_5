extends Node3D

const EFFECT = preload("res://game/effect.gd")
const GOBLIN_FOE = preload("res://game/goblin_foe.gd")
const GOBLIN_BOSS = preload("res://game/goblin_boss.gd")
var run: AshRun
var player: AshKnight
var arena: AshArena
var ui: AshInterface
var rng := RandomNumberGenerator.new()
var foes: Array[AshFoe] = []
var pickups: Array[Node3D] = []
var shop_stock: Array[Dictionary] = []
var effects: Node3D
var arena_number := 1
var biomes: Array[String] = ["crypt", "briar", "forge"]
var playing := false
var transitioning := false
var cleared := false
var ambush := false
var hitstop := 0.0
var prompt_target: Dictionary = {}
var sound_streams: Dictionary = {}
var music: AudioStreamPlayer

func _ready() -> void:
	install_inputs()
	run = AshRun.new()
	add_child(run)
	run.reset(1)
	build_environment()
	player = AshKnight.new()
	player.name = "Pilgrim"
	add_child(player)
	ui = AshInterface.new()
	add_child(ui)
	run.message.connect(toast)
	rng.seed = 1
	load_room("combat")
	ui.show_title()
	ui.refresh()
	load_audio()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			start_run(int(argument.trim_prefix("--seed=")))

func install_inputs() -> void:
	for number in range(1, 5):
		var shortcut := "weapon_%d" % number
		if not InputMap.has_action(shortcut):
			InputMap.add_action(shortcut)
		var key := InputEventKey.new()
		key.physical_keycode = KEY_1 + number - 1
		InputMap.action_add_event(shortcut, key)
	var keys := {"forward": [KEY_W, KEY_UP], "back": [KEY_S, KEY_DOWN], "left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "dodge": [KEY_SPACE], "parry": [KEY_F], "interact": [KEY_E], "inventory": [KEY_TAB], "pause": [KEY_ESCAPE], "lock": [KEY_Q], "heal": [KEY_R], "special": [KEY_C]}
	for action_name in keys:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		for code in keys[action_name]:
			var event := InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action_name, event)
	for pair in [["light", MOUSE_BUTTON_LEFT], ["heavy", MOUSE_BUTTON_RIGHT], ["lock", MOUSE_BUTTON_MIDDLE]]:
		if not InputMap.has_action(pair[0]):
			InputMap.add_action(pair[0])
		var mouse := InputEventMouseButton.new()
		mouse.button_index = pair[1]
		InputMap.action_add_event(pair[0], mouse)

func build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("171711")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a8ac8e")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("353d2f")
	env.fog_light_energy = 0.5
	env.fog_density = 0.012
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-49, -35, 0)
	moon.light_color = Color("b3b99b")
	moon.light_energy = 0.75
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 55
	add_child(moon)
	var layer := CanvasLayer.new()
	layer.layer = -1
	add_child(layer)
	var overlay := ColorRect.new()
	layer.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := ShaderMaterial.new()
	shader.shader = load("res://game/retro.gdshader")
	overlay.material = shader

func start_run(chosen_seed: int = -1) -> void:
	var next_seed := chosen_seed if chosen_seed >= 0 else int(Time.get_unix_time_from_system()) % 1000000
	player.special_cooldowns.clear()
	run.reset(next_seed)
	rng.seed = next_seed
	biomes = ["crypt", "briar", "forge"]
	for i in range(biomes.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp := biomes[i]
		biomes[i] = biomes[j]
		biomes[j] = temp
	arena_number = 1
	playing = true
	transitioning = false
	ui.clear_modal()
	load_room("combat")
	ui.refresh()
	sound("heal", -8)

func load_room(kind: String) -> void:
	for foe in foes:
		if is_instance_valid(foe):
			foe.queue_free()
	foes.clear()
	for pickup in pickups:
		if is_instance_valid(pickup):
			pickup.queue_free()
	pickups.clear()
	if is_instance_valid(arena):
		arena.queue_free()
	if is_instance_valid(effects):
		effects.queue_free()
	effects = Node3D.new()
	add_child(effects)
	cleared = false
	ambush = false
	prompt_target = {}
	hitstop = 0
	player.locked = null
	player.global_position = Vector3(0, 0.15, 10)
	player.velocity = Vector3.ZERO
	player.stamina = 100
	player.invincible = 1.0
	player.action = "idle"
	player.visual.rotation = Vector3.ZERO
	player.facing = Vector3.FORWARD
	player.reset_camera()
	player.refresh_weapon()
	var biome := biomes[(arena_number - 1) % 3] if arena_number < 5 else "crypt"
	arena = AshArena.new()
	add_child(arena)
	arena.build(self, kind, biome, arena_number)
	if kind == "combat":
		spawn_encounter()
	elif kind == "shop":
		shop_stock.clear()
		shop_stock.append(AshData.item("flask"))
		shop_stock.append(AshData.item("shard"))
		for weapon_kind in ["dagger", "greatsword", "spear"]:
			shop_stock.append(AshData.item(weapon_kind, mini(4, arena_number / 2 + rng.randi_range(0, 1))))
	elif kind == "mystery":
		call_deferred("resolve_mystery")
	ui.announce(arena.room_title, arena.room_subtitle)
	update_objective()

func spawn_encounter() -> void:
	if arena_number == 5:
		spawn_boss(Vector3(0, 0.1, -7))
		return
	var primary: String = {"crypt": "club", "briar": "caster", "forge": "missile"}[arena.biome]
	var secondary: String = {"club": "caster", "caster": "missile", "missile": "club"}[primary]
	var kinds: Array[String] = [primary, secondary]
	if arena_number >= 3:
		kinds.append(primary if arena_number == 3 else secondary)
	var positions := [Vector3(-4.5, 0.1, -4), Vector3(4.5, 0.1, -8), Vector3(0, 0.1, -10)]
	for i in kinds.size():
		var at: Vector3 = positions[i] + Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8))
		spawn_goblin(kinds[i], at)

func spawn_goblin(kind: String, at: Vector3) -> AshFoe:
	var foe: AshFoe = GOBLIN_FOE.new()
	foe.kind = kind
	foe.arena_level = arena_number
	foe.position = at
	add_child(foe)
	foes.append(foe)
	return foe

func spawn_boss(at: Vector3) -> AshFoe:
	var boss: AshFoe = GOBLIN_BOSS.new()
	boss.arena_level = arena_number
	boss.position = at
	add_child(boss)
	foes.append(boss)
	return boss

func enemy_defeated(foe: AshFoe) -> void:
	run.kills += 1
	run.currency += (100 + arena_number * 20) if foe.rank > 0 else (30 + arena_number * 8)
	run.grant_mastery(5)
	if foe.rank > 0 or rng.randf() < 0.6:
		spawn_pickup(AshData.loot(rng, foe.family, foe.rank == 2 or (foe.rank == 1 and arena_number == 4)), foe.global_position)
	run.changed.emit()
	var living := 0
	for other in foes:
		if is_instance_valid(other) and not other.dead:
			living += 1
	if living == 0 and not cleared:
		clear_encounter()
	update_objective()

func clear_encounter() -> void:
	cleared = true
	sound("clear")
	if arena_number == 5 and not ambush:
		call_deferred("finish_run", true)
		return
	if ambush:
		arena.show_exits(["combat"])
		toast("The grave releases you. Gather what remains.")
	else:
		var pool := ["rest", "shop", "mystery"]
		pool.remove_at(rng.randi_range(0, 2))
		if rng.randf() < 0.5:
			pool.reverse()
		arena.show_exits(pool)
		toast("ARENA CLEARED  ·  Collect your spoils and choose a doorway")
	update_objective()

func resolve_mystery(forced_outcome: int = -1) -> void:
	var outcome := forced_outcome if forced_outcome >= 0 else rng.randi_range(0, 4)
	match outcome:
		0:
			toast("AN UNWELCOME VIGIL  ·  The grave calls its guardians.")
			ambush = true
			cleared = false
			arena.doors.clear()
			for gate in arena.door_nodes:
				gate.position.y = 0
			spawn_goblin("club", Vector3(-3, 0.1, -4))
			spawn_goblin("caster", Vector3(3, 0.1, -6))
		1, 3:
			var stat: String = ["Vitality", "Strength", "Swiftness"][rng.randi_range(0, 2)]
			run.upgrade(stat, 0.9 if outcome == 1 else 1.1)
			toast(("CURSED  ·  " if outcome == 1 else "BLESSED  ·  ") + stat + (" falls by 10%." if outcome == 1 else " rises by 10%."))
		2:
			var eligible: Array[int] = []
			for i in run.inventory.size():
				if run.inventory[i].uid != run.equipped_uid:
					eligible.append(i)
			if not eligible.is_empty() and rng.randf() < 0.5:
				var index: int = eligible[rng.randi_range(0, eligible.size() - 1)]
				var title: String = run.inventory[index].name
				run.inventory.remove_at(index)
				toast("ROBBED  ·  The grave claimed your " + title + ".")
			else:
				var lost := int(ceil(run.currency * 0.25))
				run.currency -= lost
				toast("ROBBED  ·  %d embers vanish into the earth." % lost)
			run.changed.emit()
		4:
			spawn_pickup(AshData.loot(rng, "briar"), Vector3(0, 0.1, -1.5))
			toast("A FINAL OFFERING  ·  A pilgrim's remains hold a forgotten relic.")
	if not ambush and arena.room_kind == "mystery":
		arena.show_exits(["combat"])
	update_objective()

func spawn_pickup(entry: Dictionary, at: Vector3) -> Node3D:
	var pickup := Node3D.new()
	effects.add_child(pickup)
	pickup.global_position = Vector3(at.x, 0.12, at.z)
	pickup.set_meta("item", entry)
	var color: Color = AshData.COLORS[entry.rarity]
	var crystal := AshArt.cylinder(pickup, Vector3(0, 0.42, 0), 0.18, 0, 0.7, color, 4)
	crystal.material_override = AshArt.material(color, false, 1.0)
	AshArt.ring(pickup, 0.33, color)
	var light := OmniLight3D.new()
	pickup.add_child(light)
	light.light_color = color
	light.light_energy = 0.7
	light.omni_range = 2.6
	light.position.y = 0.5
	pickups.append(pickup)
	return pickup

func drop_inventory(index: int) -> void:
	if index < 0 or index >= run.inventory.size():
		return
	var entry: Dictionary = run.inventory[index]
	if entry.uid == run.equipped_uid:
		toast("Equip another weapon before dropping this one.")
		return
	var dropped := entry.duplicate(true)
	dropped.amount = 1
	dropped.uid = str(Time.get_ticks_usec())
	spawn_pickup(dropped, player.global_position + player.facing * 1.2)
	run.consume(index)

func buy_item(index: int) -> void:
	if index < 0 or index >= shop_stock.size():
		toast("Choose an offering first.")
		return
	var entry := shop_stock[index]
	var price := AshData.price(entry)
	if run.currency < price:
		toast("Not enough embers.")
		return
	var bought := entry.duplicate(true)
	bought.uid = str(Time.get_ticks_usec()) + str(randi())
	if run.add_item(bought):
		run.currency -= price
		run.changed.emit()
		toast("Purchased " + entry.name)
		sound("heal", -8)

func sell_item(index: int) -> void:
	if index < 0 or index >= run.inventory.size():
		return
	var entry := run.inventory[index]
	if entry.uid == run.equipped_uid:
		toast("Equip another weapon before selling this one.")
		return
	run.currency += int(AshData.price(entry) * 0.5)
	run.consume(index)
	toast("The merchant takes his share.")

func interact() -> void:
	if prompt_target.is_empty() or player.action != "idle":
		return
	match prompt_target.kind:
		"pickup":
			var pickup: Node3D = prompt_target.node
			if is_instance_valid(pickup) and run.add_item(pickup.get_meta("item")):
				toast("Collected " + str(pickup.get_meta("item").name))
				pickups.erase(pickup)
				pickup.queue_free()
				sound("menu")
		"shop": ui.show_inventory(true)
		"bed", "bench", "fire":
			if arena.rest_used:
				toast("Your one mercy has been spent. The path waits.")
			elif prompt_target.kind == "fire":
				ui.show_rest()
			else:
				if prompt_target.kind == "bed":
					run.heal(run.max_health * 0.5)
					toast("A quiet dream restores half your maximum vitality.")
				else:
					run.grant_mastery(20)
					toast("Your weapon remembers. +20 mastery XP.")
				arena.rest_used = true
				pulse(player.global_position, AshArt.GOLD, 2.0)
				sound("heal")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and playing and not transitioning:
		if ui.is_open():
			ui.clear_modal()
		else:
			ui.show_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory") and playing and not transitioning:
		if ui.mode == "inventory" or ui.mode == "shop":
			ui.clear_modal()
		elif not ui.is_open() and player.action == "idle":
			ui.show_inventory()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and playing and not ui.is_open():
		interact()

func _process(delta: float) -> void:
	hitstop = maxf(0, hitstop - delta)
	if not playing or ui.is_open() or transitioning:
		return
	player.global_position.x = clampf(player.global_position.x, -14.5, 14.5)
	player.global_position.z = clampf(player.global_position.z, -17.0, 17.2)
	prompt_target = {}
	var nearest := 2.0
	for pickup in pickups:
		if not is_instance_valid(pickup):
			continue
		pickup.rotation.y += delta
		var distance := player.global_position.distance_to(pickup.global_position)
		if distance < nearest:
			nearest = distance
			prompt_target = {"kind": "pickup", "node": pickup, "label": "Collect " + str(pickup.get_meta("item").name)}
	for interaction in arena.interactions:
		var distance: float = player.global_position.distance_to(interaction.pos)
		if distance < nearest:
			nearest = distance
			prompt_target = interaction
	ui.prompt.text = "[ E ]  " + prompt_target.label if not prompt_target.is_empty() else ""
	for door in arena.doors:
		if absf(player.global_position.x - door.pos.x) < 1.5 and player.global_position.z < -15.6:
			transition_room(door.kind)
			break

func transition_room(kind: String) -> void:
	if transitioning:
		return
	transitioning = true
	var tween := create_tween()
	tween.tween_property(ui.fade, "color:a", 1.0, 0.3)
	await tween.finished
	if kind == "combat":
		arena_number += 1
	load_room(kind)
	var fade_in := create_tween()
	fade_in.tween_property(ui.fade, "color:a", 0.0, 0.6)
	await fade_in.finished
	transitioning = false

func update_objective() -> void:
	var living := 0
	for foe in foes:
		if is_instance_valid(foe) and not foe.dead:
			living += 1
	var task := ("1 foe remains" if living == 1 else "%d foes remain" % living) if living > 0 else ("Choose a lit doorway" if arena.room_kind == "combat" else "A moment between battles")
	ui.objective.text = "ARENA  %d / 5\n%s\n%s" % [arena_number, arena.room_title, task]

func finish_run(won: bool) -> void:
	if not playing:
		return
	playing = false
	player.locked = null
	ui.show_result(won)
	sound("clear" if won else "death")

func toast(text: String) -> void:
	if is_instance_valid(ui):
		ui.toast(text)

func pulse(at: Vector3, color: Color, size_value: float) -> void:
	var effect := EFFECT.new()
	effect.game = self
	effect.radius = size_value
	effects.add_child(effect)
	effect.global_position = at + Vector3(0, 0.07, 0)
	effect.graphic = AshArt.ring(effect, 1.0, color, 0.04)

func slash(at: Vector3, direction: Vector3, size_value: float, special_attack: bool = false, color: Color = AshArt.GOLD) -> void:
	var effect := EFFECT.new()
	effect.game = self
	effect.mode = "slash"
	effect.radius = size_value
	effect.life = 0.22
	effects.add_child(effect)
	effect.global_position = at
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, AshArt.material(color, false, 1.0))
	var arc := TAU if special_attack else PI * 0.8
	var center := atan2(-direction.x, -direction.z)
	for i in 25:
		var angle := center - arc * 0.5 + arc * i / 24
		for distance in [0.85, 1.0]:
			mesh.surface_add_vertex(Vector3(-sin(angle) * distance, 0, -cos(angle) * distance))
	mesh.surface_end()
	effect.graphic = AshArt.mesh_node(effect, mesh, Vector3.ZERO, AshArt.material(color, false, 0.8))

func damage_number(at: Vector3, amount: int) -> void:
	var effect := EFFECT.new()
	effect.game = self
	effect.mode = "number"
	effect.life = 0.8
	effects.add_child(effect)
	effect.global_position = at
	var text := Label3D.new()
	effect.add_child(text)
	text.text = str(amount)
	text.font_size = 50
	text.pixel_size = 0.009
	text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	text.no_depth_test = true
	text.modulate = AshArt.GOLD
	text.outline_modulate = AshArt.BLACK
	effect.graphic = text

func spawn_bolt(at: Vector3, direction: Vector3, source: Node3D, amount: float) -> void:
	var effect := EFFECT.new()
	effect.game = self
	effect.mode = "bolt"
	effect.life = 4.0
	effect.direction = direction
	effect.source = source
	effect.damage = amount
	effects.add_child(effect)
	effect.global_position = at
	effect.graphic = AshArt.cylinder(effect, Vector3.ZERO, 0.22, 0, 0.75, AshArt.BLOOD, 4)
	effect.graphic.rotation.x = PI / 2
	effect.graphic.material_override = AshArt.material(AshArt.BLOOD, false, 1.0)

func load_audio() -> void:
	# The headless dummy audio driver does not retire short-lived WAV playbacks.
	# Rendering runs still exercise the full sound path.
	if DisplayServer.get_name() == "headless":
		return
	for key in ["swing", "hit", "hurt", "dodge", "parry", "heal", "menu", "warning", "slam", "clear", "death"]:
		var path: String = "res://audio/" + key + ".wav"
		if ResourceLoader.exists(path):
			sound_streams[key] = load(path)
	if ResourceLoader.exists("res://audio/atmosphere.wav"):
		music = AudioStreamPlayer.new()
		add_child(music)
		var stream: AudioStreamWAV = load("res://audio/atmosphere.wav")
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		music.stream = stream
		music.volume_db = -20
		music.play()

func sound(key: String, volume: float = -3) -> void:
	if not sound_streams.has(key):
		return
	var voice := AudioStreamPlayer.new()
	add_child(voice)
	voice.stream = sound_streams[key]
	voice.volume_db = volume
	voice.pitch_scale = randf_range(0.94, 1.06)
	voice.finished.connect(voice.queue_free)
	voice.play()
