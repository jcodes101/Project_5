class_name AshArena
extends Node3D

var game: Node
var biome := "crypt"
var room_kind := "combat"
var level := 1
var hazards: Array[Dictionary] = []
var interactions: Array[Dictionary] = []
var door_nodes: Array[Node3D] = []
var doors: Array[Dictionary] = []
var flames: Array[Node3D] = []
var elapsed := 0.0
var hazard_tick := 0.0
var rest_used := false
var room_title := ""
var room_subtitle := ""

func build(owner_game: Node, type: String, environment_type: String, arena_number: int) -> void:
	game = owner_game
	room_kind = type
	biome = environment_type
	level = arena_number
	var stone := Color("4c4d40")
	if biome == "forge":
		stone = Color("55473a")
	elif biome == "briar":
		stone = Color("424a38")
	AshArt.solid(self, Vector3(0, -0.4, 0), Vector3(32, 0.8, 38), stone)
	for x in range(-7, 8):
		for z in range(-8, 9):
			var tile := AshArt.box(self, Vector3(x * 2.02, game.rng.randf_range(-0.01, 0.025), z * 2.02), Vector3(1.98, 0.08, 1.98), stone * game.rng.randf_range(0.75, 1.12), true)
			if game.rng.randf() < 0.1:
				tile.rotation.y = 0.04
	for side in [-1, 1]:
		AshArt.solid(self, Vector3(side * 15.4, 2.5, 0), Vector3(1.0, 5.0, 37), stone * 0.72)
		for z in range(-14, 16, 6):
			pillar(Vector3(side * 14.5, 0, z), 4.7, stone)
			var torch := AshArt.flame(self, Vector3(side * 13.9, 2.0, z), 0.8)
			flames.append(torch)
	AshArt.solid(self, Vector3(0, 2.5, 18.4), Vector3(32, 5, 1), stone * 0.65)
	for segment in [Vector3(-12, 2.7, -17.4), Vector3(0, 2.7, -17.4), Vector3(12, 2.7, -17.4)]:
		AshArt.solid(self, segment, Vector3(8, 5.4, 1), stone * 0.7)
	for x in [-6, 6]:
		arch(Vector3(x, 0, -16.8), stone)
		var gate := Node3D.new()
		add_child(gate)
		gate.position = Vector3(x, 0, -17)
		var gate_body := StaticBody3D.new()
		gate.add_child(gate_body)
		var gate_collision := CollisionShape3D.new()
		var gate_shape := BoxShape3D.new()
		gate_shape.size = Vector3(3.5, 3.6, 0.3)
		gate_collision.shape = gate_shape
		gate_collision.position.y = 1.8
		gate_body.add_child(gate_collision)
		for i in 7:
			AshArt.box(gate, Vector3((i - 3) * 0.47, 1.8, 0), Vector3(0.15, 3.6, 0.18), AshArt.WOOD, true)
		AshArt.box(gate, Vector3(0, 1, 0), Vector3(3.5, 0.2, 0.22), AshArt.WOOD, true)
		AshArt.box(gate, Vector3(0, 2.9, 0), Vector3(3.5, 0.2, 0.22), AshArt.WOOD, true)
		door_nodes.append(gate)
		flames.append(AshArt.flame(self, Vector3(x - 2.3, 1.5, -15.9)))
		flames.append(AshArt.flame(self, Vector3(x + 2.3, 1.5, -15.9)))
	# Rough overhead beams and broken colonnades frame the playable space.
	for z in [-12, 0, 12]:
		AshArt.box(self, Vector3(0, 5.7, z), Vector3(30, 0.38, 0.42), AshArt.WOOD, true)
		for side in [-1, 1]:
			var brace := AshArt.box(self, Vector3(side * 12.7, 4.7, z), Vector3(0.3, 3.0, 0.32), AshArt.WOOD, true)
			brace.rotation.z = side * -0.7
	for side in [-1, 1]:
		for z in [-8, 4]:
			pillar(Vector3(side * 10, 0, z), game.rng.randf_range(2.4, 4.6), stone)
	for i in 26:
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var at := Vector3(side * game.rng.randf_range(11.5, 14), 0.1, game.rng.randf_range(-14, 15))
		var rubble := AshArt.box(self, at, Vector3(game.rng.randf_range(0.2, 0.7), game.rng.randf_range(0.15, 0.5), game.rng.randf_range(0.3, 0.8)), stone * 0.8, true)
		rubble.rotation = Vector3(0.2, game.rng.randf() * TAU, 0.1)
	build_backdrop(stone)
	build_biome_details()
	if type == "combat":
		room_title = {"crypt": "Sepulchre of Bells", "forge": "The Cinder Foundry", "briar": "Chapel of Thorns"}[biome]
		room_subtitle = {"crypt": "The dead keep their oaths.", "forge": "Even iron learns to suffer.", "briar": "Nothing buried here stays buried."}[biome]
		if level == 5:
			room_title = "Throne of the Unremembered"
			room_subtitle = "One last crown. One last ember."
		build_hazards()
	elif type == "rest":
		room_title = "A Small Mercy"
		room_subtitle = "Choose one comfort before the dark returns."
		flames.append(AshArt.flame(self, Vector3(0, 0, -3), 1.4))
		interactions.append({"kind": "fire", "pos": Vector3(0, 0, -3), "label": "Tend the ember · improve a stat by 20%"})
		AshArt.box(self, Vector3(-4, 0.13, -2), Vector3(1.5, 0.25, 2.5), AshArt.MOSS, true)
		AshArt.box(self, Vector3(-4, 0.28, -2.8), Vector3(1.2, 0.18, 0.5), AshArt.WOOD, true)
		interactions.append({"kind": "bed", "pos": Vector3(-4, 0, -2), "label": "Rest · recover 50% maximum vitality"})
		workbench(Vector3(4, 0, -2))
		interactions.append({"kind": "bench", "pos": Vector3(4, 0, -2), "label": "Hone weapon · gain 20 mastery XP"})
		show_exits(["combat"])
	elif type == "shop":
		room_title = "The Candle Merchant"
		room_subtitle = "All things have a price. Even survival."
		workbench(Vector3(0, 0, -4))
		var merchant := AshArt.knight(self)
		merchant.position = Vector3(0, 0, -5.6)
		merchant.rotation.y = PI
		flames.append(AshArt.flame(self, Vector3(-1.3, 1.25, -4), 0.65))
		interactions.append({"kind": "shop", "pos": Vector3(0, 0, -2.5), "label": "Trade with the candle merchant"})
		show_exits(["combat"])
	else:
		room_title = "The Unmarked Grave"
		room_subtitle = "Something has been waiting for you."
		AshArt.box(self, Vector3(0, 0.3, -4), Vector3(2.5, 0.6, 3), stone, true)
		var relic := AshArt.cylinder(self, Vector3(0, 1.4, -4), 0.4, 0, 1.6, AshArt.GOLD, 4)
		relic.material_override = AshArt.material(AshArt.GOLD, false, 1.0)

func pillar(at: Vector3, height_value: float, stone: Color) -> void:
	AshArt.solid(self, at + Vector3(0, height_value * 0.5, 0), Vector3(0.95, height_value, 0.95), stone * 0.9)
	AshArt.box(self, at + Vector3(0, 0.18, 0), Vector3(1.4, 0.35, 1.4), stone, true)
	AshArt.box(self, at + Vector3(0, height_value, 0), Vector3(1.35, 0.3, 1.35), stone, true)
	for y in range(1, int(height_value)):
		AshArt.box(self, at + Vector3(0, y, 0), Vector3(1.01, 0.09, 1.01), AshArt.WOOD, true)

func arch(at: Vector3, stone: Color) -> void:
	for side in [-1, 1]:
		AshArt.solid(self, at + Vector3(side * 1.9, 1.5, 0), Vector3(0.65, 3.0, 1.1), stone)
	for i in 9:
		var angle := PI * float(i) / 8.0
		var block := AshArt.box(self, at + Vector3(cos(angle) * 1.9, 3.0 + sin(angle) * 1.9, 0), Vector3(0.78, 0.7, 1.1), stone * 1.1, true)
		block.rotation.z = angle - PI / 2
	# Dark passage with a warm receding end, visible when its gate rises.
	AshArt.box(self, at + Vector3(0, 2, -4), Vector3(3.6, 4, 0.2), AshArt.BLACK)
	for side in [-1, 1]:
		AshArt.box(self, at + Vector3(side * 1.9, 2, -2), Vector3(0.4, 4, 4), stone * 0.5, true)

func workbench(at: Vector3) -> void:
	AshArt.box(self, at + Vector3(0, 1.1, 0), Vector3(3.0, 0.22, 1.3), AshArt.WOOD, true)
	for x in [-1.2, 1.2]:
		for z in [-0.4, 0.4]:
			AshArt.box(self, at + Vector3(x, 0.5, z), Vector3(0.18, 1.0, 0.18), AshArt.WOOD, true)
	var sword := AshArt.weapon(self, "sword")
	sword.position = at + Vector3(0.7, 1.3, 0.3)
	sword.rotation.y = -0.8

func build_hazards() -> void:
	var color := AshArt.BLOOD if biome == "forge" else (Color("667047") if biome == "briar" else Color("776447"))
	for side in [-1, 1]:
		var at := Vector3(side * game.rng.randf_range(3.8, 6.8), 0.08, game.rng.randf_range(-6, 0))
		var pool := AshArt.cylinder(self, at, 2.1, 2.1, 0.045, color, 10)
		pool.material_override = AshArt.material(color, true, 0.3)
		var ring := AshArt.ring(self, 2.15, color, 0.04)
		ring.position = at + Vector3(0, 0.03, 0)
		for i in 9:
			var spike_at := at + Vector3(cos(i * TAU / 9) * 1.8, 0.2, sin(i * TAU / 9) * 1.8)
			AshArt.cylinder(self, spike_at, 0.17, 0, 0.6 if biome == "briar" else 0.2, AshArt.WOOD, 4)
		hazards.append({"pos": at, "radius": 2.1, "mesh": pool, "ring": ring})

func build_biome_details() -> void:
	for side in [-1, 1]:
		for z in [-11, -3, 6]:
			var at := Vector3(side * 12.4, 0, z)
			if biome == "crypt":
				var tomb := AshArt.box(self, at + Vector3(0, 0.85, 0), Vector3(1.15, 1.7, 0.4), Color("55564b"), true)
				tomb.rotation.z = side * 0.09
				AshArt.box(self, at + Vector3(0, 1.1, -0.24), Vector3(0.07, 0.65, 0.04), AshArt.WOOD)
				AshArt.box(self, at + Vector3(0, 1.2, -0.24), Vector3(0.45, 0.07, 0.04), AshArt.WOOD)
				AshArt.box(self, at + Vector3(0, 0.13, 1), Vector3(1.3, 0.23, 2.4), Color("414337"), true)
			elif biome == "briar":
				AshArt.cylinder(self, at + Vector3(0, 1.8, 0), 0.4, 0.15, 3.6, AshArt.WOOD, 5)
				for i in 3:
					var branch := AshArt.cylinder(self, at + Vector3(side * i * 0.3, 2 + i * 0.5, 0), 0.15, 0.0, 1.9, AshArt.WOOD, 4)
					branch.rotation.z = -side * (0.6 + i * 0.2)
				for i in 4:
					AshArt.cylinder(self, at + Vector3(game.rng.randf_range(-1, 1), 0.18, game.rng.randf_range(-1, 1)), 0.5, 0, 0.45, AshArt.MOSS, 4)
			else:
				AshArt.box(self, at + Vector3(0, 0.25, 0), Vector3(1.9, 0.5, 2), AshArt.BLACK, true)
				var coal := AshArt.box(self, at + Vector3(0, 0.53, 0), Vector3(1.5, 0.05, 1.6), AshArt.BLOOD)
				coal.material_override = AshArt.material(AshArt.BLOOD, false, 0.8)
				flames.append(AshArt.flame(self, at + Vector3(0, 0.65, 0)))
				for y in range(2, 6):
					AshArt.box(self, at + Vector3(0, y, 0), Vector3(0.07, 0.55, 0.07), AshArt.WOOD)

func build_backdrop(stone: Color) -> void:
	for i in 8:
		var at := Vector3((i - 4) * 6, 3, -24 - game.rng.randf_range(0, 6))
		AshArt.box(self, at, Vector3(3.5, game.rng.randf_range(12, 21), 3), stone * 0.45, true)
	var trunk := AshArt.cylinder(self, Vector3(0, 6, -26), 1.3, 0.35, 16, AshArt.WOOD, 5)
	trunk.rotation.z = 0.15
	for side in [-1, 1]:
		for i in 3:
			var branch := AshArt.cylinder(self, Vector3(side * (i + 1), 9 + i * 2, -26), 0.4, 0, 6, AshArt.WOOD, 4)
			branch.rotation.z = side * -0.7

func show_exits(choices: Array) -> void:
	doors.clear()
	for i in door_nodes.size():
		var gate := door_nodes[i]
		if i >= choices.size():
			continue
		var kind: String = choices[i]
		var tween := create_tween()
		tween.tween_property(gate, "position:y", 4.8, 1.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		var at := Vector3(-6 if i == 0 else 6, 0, -16.4)
		doors.append({"kind": kind, "pos": at})
		var label := Label3D.new()
		add_child(label)
		label.position = at + Vector3(0, 3.0, 0.6)
		label.text = {"rest": "A SMALL MERCY\nRest", "shop": "THE CANDLE MERCHANT\nTrade", "mystery": "THE UNMARKED GRAVE\nUnknown", "combat": "INTO THE DARK\nContinue"}[kind]
		label.font_size = 32
		label.pixel_size = 0.008
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = AshArt.GOLD
		label.outline_modulate = AshArt.BLACK
		var light := OmniLight3D.new()
		add_child(light)
		light.position = at + Vector3(0, 1.5, -0.5)
		light.light_color = AshArt.GOLD
		light.light_energy = 2.5
		light.omni_range = 6
		AshArt.ring(self, 1.0, AshArt.GOLD).position = at + Vector3(0, 0.12, 1.0)

func _process(delta: float) -> void:
	if not is_instance_valid(game):
		return
	elapsed += delta
	for i in flames.size():
		var root := flames[i]
		var light: OmniLight3D = root.get_meta("light")
		light.light_energy = (2.0 + sin(elapsed * 7.1 + i) * 0.18 + sin(elapsed * 13.7 + i) * 0.12) * root.scale.x
		var fire: MeshInstance3D = root.get_meta("fire")
		fire.scale.y = 1.0 + sin(elapsed * 11 + i) * 0.12
	if not game.playing or game.ui.is_open() or game.transitioning:
		return
	var active := biome != "crypt" or fmod(elapsed, 5.0) < 2.5
	for hazard in hazards:
		hazard.ring.visible = active
		hazard.mesh.visible = active
	hazard_tick -= delta
	if hazard_tick <= 0:
		hazard_tick = 0.85
		for hazard in hazards:
			var offset: Vector3 = game.player.global_position - hazard.pos
			offset.y = 0
			if active and offset.length() < hazard.radius:
				game.player.take_hit(8.0, null, false)
				if biome == "briar":
					game.player.stamina = maxf(0, game.player.stamina - 10)
				game.toast({"forge": "The cinders burn. Leave the red ground.", "briar": "Blight eats at your vitality.", "crypt": "The grave mist chills your bones."}[biome])
