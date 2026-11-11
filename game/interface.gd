class_name AshInterface
extends CanvasLayer

var game: Node
var root: Control
var hud: Control
var modal: Control
var mode := ""
var selected := 0
var shop_selected := -1
var health_bar: ProgressBar
var stamina_bar: ProgressBar
var mastery_bar: ProgressBar
var health_text: Label
var stamina_text: Label
var weapon_text: Label
var flask_text: Label
var coin_text: Label
var objective: Label
var compass: Label
var prompt: Label
var toast_label: Label
var toast_time := 0.0
var room_label: Label
var room_sub: Label
var room_time := 0.0
var boss_bar: ProgressBar
var boss_title: Label
var boss_root: Control
var lock_label: Label
var damage_overlay: ColorRect
var fade: ColorRect
var serif: SystemFont
var inventory_buttons: Array[Button] = []
var details: Label
var shop_details: Label
var stats_label: Label
var coin_label: Label

func _ready() -> void:
	game = get_parent()
	serif = SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "Liberation Serif", "DejaVu Serif"])
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	build_hud()
	game.run.changed.connect(refresh)

func style(bg: Color, border: Color = Color("5b5038"), width: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

func label(parent: Node, text: String, at: Vector2, size_value: Vector2, font_size: int = 18, color: Color = Color("ded4b9"), use_serif: bool = false) -> Label:
	var node := Label.new()
	parent.add_child(node)
	node.position = at
	node.size = size_value
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	if use_serif:
		node.add_theme_font_override("font", serif)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func panel(parent: Node, at: Vector2, size_value: Vector2, alpha: float = 0.95) -> Panel:
	var node := Panel.new()
	parent.add_child(node)
	node.position = at
	node.size = size_value
	node.add_theme_stylebox_override("panel", style(Color(0.07, 0.075, 0.055, alpha)))
	return node

func button(parent: Node, text: String, at: Vector2, size_value: Vector2, callback: Callable) -> Button:
	var node := Button.new()
	parent.add_child(node)
	node.position = at
	node.size = size_value
	node.text = text
	node.add_theme_font_size_override("font_size", 17)
	node.add_theme_color_override("font_color", Color("d9c9a1"))
	node.add_theme_color_override("font_hover_color", Color("f5e7bc"))
	node.add_theme_stylebox_override("normal", style(Color("22251c")))
	node.add_theme_stylebox_override("hover", style(Color("353d2f"), AshArt.GOLD))
	node.add_theme_stylebox_override("pressed", style(Color("514631"), AshArt.GOLD))
	node.add_theme_stylebox_override("focus", style(Color(0, 0, 0, 0), AshArt.GOLD, 2))
	node.pressed.connect(func() -> void:
		game.sound("menu", -8)
		callback.call())
	return node

func progress(parent: Node, at: Vector2, size_value: Vector2, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	parent.add_child(bar)
	bar.position = at
	bar.size = size_value
	bar.max_value = 100
	bar.value = 100
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := style(Color("191b15"), Color("65573d"))
	var fill := style(color, color, 0)
	for box_style in [back, fill]:
		box_style.content_margin_left = 0
		box_style.content_margin_right = 0
		box_style.content_margin_top = 0
		box_style.content_margin_bottom = 0
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", fill)
	# Set dimensions after replacing the default theme's minimum-height styles.
	bar.size = size_value
	return bar

func build_hud() -> void:
	hud = Control.new()
	root.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label(hud, "◇", Vector2(28, 18), Vector2(40, 56), 44, AshArt.GOLD, true)
	health_text = label(hud, "VITALITY", Vector2(82, 25), Vector2(300, 22), 13)
	health_bar = progress(hud, Vector2(82, 51), Vector2(287, 13), AshArt.BLOOD)
	stamina_bar = progress(hud, Vector2(82, 75), Vector2(238, 9), Color("78814f"))
	stamina_text = label(hud, "STAMINA", Vector2(330, 66), Vector2(95, 20), 11, Color("aaa88e"))
	compass = label(hud, "W    ·    N    ·    E", Vector2(485, 26), Vector2(310, 25), 14, AshArt.GOLD)
	compass.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coin_text = label(hud, "", Vector2(1040, 26), Vector2(205, 28), 20, AshArt.GOLD, true)
	coin_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	objective = label(hud, "", Vector2(900, 64), Vector2(345, 95), 14)
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weapon_text = label(hud, "", Vector2(40, 577), Vector2(390, 30), 23, Color("ded4b9"), true)
	mastery_bar = progress(hud, Vector2(40, 616), Vector2(220, 4), AshArt.GOLD)
	mastery_bar.max_value = 50
	flask_text = label(hud, "", Vector2(40, 632), Vector2(400, 30), 14)
	label(hud, "LMB  Light   /   RMB  Heavy   /   SPACE  Dodge   /   F  Parry   /   Q  Lock   /   C  Special", Vector2(0, 680), Vector2(1280, 25), 13, Color("b8b39b")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label(hud, "WASD  Move   ·   Mouse  Look   ·   TAB  Inventory   ·   ESC  Pause", Vector2(770, 638), Vector2(475, 25), 12, Color("b8b39b")).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prompt = label(hud, "", Vector2(250, 527), Vector2(780, 40), 19, AshArt.GOLD)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label = label(root, "", Vector2(200, 142), Vector2(880, 55), 19, AshArt.GOLD, true)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	room_label = label(hud, "", Vector2(80, 250), Vector2(1120, 70), 47, Color("e0cfaa"), true)
	room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	room_sub = label(hud, "", Vector2(80, 323), Vector2(1120, 35), 18, AshArt.GOLD, true)
	room_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_root = Control.new()
	hud.add_child(boss_root)
	boss_title = label(boss_root, "", Vector2(355, 573), Vector2(650, 30), 24, Color("ded4b9"), true)
	boss_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_bar = progress(boss_root, Vector2(355, 612), Vector2(570, 12), AshArt.BLOOD)
	boss_root.visible = false
	lock_label = label(hud, "◇", Vector2.ZERO, Vector2(32, 32), 27, AshArt.GOLD)
	lock_label.visible = false
	damage_overlay = ColorRect.new()
	root.add_child(damage_overlay)
	damage_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_overlay.color = Color(0.5, 0.04, 0.02, 0)
	damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade = ColorRect.new()
	root.add_child(fade)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0.05, 0.05, 0.035, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE

func is_open() -> bool:
	return mode != ""

func clear_modal(next_mode: String = "") -> void:
	if is_instance_valid(modal):
		modal.queue_free()
		modal = null
	mode = next_mode
	if mode == "":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		hud.visible = true
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		modal = Control.new()
		root.add_child(modal)
		modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var shade := ColorRect.new()
		modal.add_child(shade)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shade.color = Color(0.035, 0.04, 0.025, 0.76)

func show_title() -> void:
	clear_modal("title")
	hud.visible = false
	label(modal, "A DARK FANTASY ROGUELITE", Vector2(78, 154), Vector2(600, 30), 14, AshArt.GOLD)
	label(modal, "THE ASHEN\nBOUGH", Vector2(72, 209), Vector2(740, 195), 76, Color("e1d3b3"), true)
	label(modal, "Carry the ember. Break the crown.", Vector2(79, 422), Vector2(650, 35), 24, AshArt.GOLD, true)
	button(modal, "BEGIN THE PILGRIMAGE     →", Vector2(80, 496), Vector2(365, 55), func() -> void: game.start_run())
	button(modal, "How to survive", Vector2(80, 565), Vector2(210, 43), show_help)
	label(modal, "Original low-poly dark fantasy  /  Made in Godot", Vector2(80, 657), Vector2(700, 25), 13, Color("938e78"))
	var card := panel(modal, Vector2(879, 229), Vector2(310, 327), 0.88)
	label(card, "THE PILGRIMAGE", Vector2(24, 22), Vector2(260, 30), 23, AshArt.GOLD, true)
	label(card, "I — V\n\nFive arenas. Four crossroads.\nOne forgotten king.\n\nRead the windup. Keep your\nstamina. Let greed decide\nwhich door you take.", Vector2(24, 75), Vector2(270, 245), 18)

func show_help() -> void:
	var previous := mode
	clear_modal("help")
	var card := panel(modal, Vector2(190, 90), Vector2(900, 540))
	label(card, "Learn to outlast the dark", Vector2(32, 22), Vector2(820, 55), 36, AshArt.GOLD, true)
	label(card, "WASD  Move     Mouse  Look     Q / Middle mouse  Lock on\n\nLMB  Light attack     RMB  Heavy attack     SPACE  Dodge\nF  Parry     R  Drink ember draught     C  Mastery special\nE  Interact / collect     TAB  Inventory     ESC  Pause\n\nRed ground marks an incoming strike. Dodge through its impact,\nor face your foe and parry just before it lands. Heavy attacks\nbreak poise. Stamina regenerates when you leave an opening.\n\nAfter combat, collect your loot and walk through a lit doorway.\nAt rest sites, choose ONE: healing, a stat upgrade, or mastery.\nDeath ends the run. Defeat the fifth arena's king to win.", Vector2(34, 96), Vector2(835, 360), 18)
	button(card, "Return", Vector2(32, 474), Vector2(210, 43), func() -> void:
		if previous == "title": show_title()
		else: show_pause())

func show_pause() -> void:
	clear_modal("pause")
	var card := panel(modal, Vector2(440, 185), Vector2(400, 370))
	label(card, "A moment of stillness", Vector2(25, 25), Vector2(360, 45), 29, AshArt.GOLD, true)
	button(card, "Resume", Vector2(30, 100), Vector2(340, 48), func() -> void: clear_modal())
	button(card, "How to survive", Vector2(30, 164), Vector2(340, 48), show_help)
	button(card, "New pilgrimage", Vector2(30, 228), Vector2(340, 48), func() -> void: game.start_run())
	label(card, "Seed %d" % game.run.seed_value, Vector2(30, 301), Vector2(340, 25), 14, Color("99947e"))

func show_inventory(shop: bool = false) -> void:
	clear_modal("shop" if shop else "inventory")
	selected = clampi(selected, 0, maxi(0, game.run.inventory.size() - 1))
	inventory_buttons.clear()
	var card := panel(modal, Vector2(80, 70), Vector2(1120, 580))
	label(card, "The Candle Merchant" if shop else "A Pilgrim's Burden", Vector2(30, 18), Vector2(800, 55), 37, AshArt.GOLD, true)
	coin_label = label(card, "", Vector2(830, 35), Vector2(260, 32), 20, AshArt.GOLD)
	coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label(card, "YOUR SATCHEL  /  12 SLOTS", Vector2(30, 87), Vector2(470, 25), 13, Color("9e9c84"))
	for i in 12:
		var slot := button(card, "", Vector2(30 + (i % 3) * 170, 125 + (i / 3) * 70), Vector2(158, 60), func() -> void:
			selected = i
			shop_selected = -1
			refresh_inventory())
		slot.add_theme_font_size_override("font_size", 13)
		inventory_buttons.append(slot)
	details = label(card, "", Vector2(30, 420), Vector2(485, 100), 14)
	button(card, "Equip / Use", Vector2(30, 530), Vector2(155, 35), func() -> void:
		game.run.use_item(selected)
		game.player.refresh_weapon()
		refresh_inventory())
	button(card, "Drop one", Vector2(198, 530), Vector2(145, 35), func() -> void:
		game.drop_inventory(selected)
		refresh_inventory())
	if shop:
		button(card, "Sell one · 50%", Vector2(355, 530), Vector2(155, 35), func() -> void:
			game.sell_item(selected)
			refresh_inventory())
		label(card, "THE MERCHANT'S OFFERINGS", Vector2(560, 87), Vector2(510, 25), 13, Color("9e9c84"))
		for i in game.shop_stock.size():
			var entry: Dictionary = game.shop_stock[i]
			var offer := button(card, "%s  ·  %s\n%d embers" % [entry.name, AshData.RARITIES[entry.rarity], AshData.price(entry)], Vector2(560, 125 + i * 63), Vector2(525, 55), func() -> void:
				shop_selected = i
				refresh_inventory())
			offer.add_theme_font_size_override("font_size", 15)
		shop_details = label(card, "Select an offering, then Buy.", Vector2(560, 445), Vector2(510, 75), 13)
		button(card, "Buy selected", Vector2(560, 530), Vector2(200, 35), func() -> void:
			game.buy_item(shop_selected)
			refresh_inventory())
	else:
		label(card, "THE PATH OF MASTERY", Vector2(570, 90), Vector2(500, 30), 23, AshArt.GOLD, true)
		label(card, "Each weapon remembers its battles.\n\n5 XP for every defeated enemy\n25 XP · third light strike becomes a finisher\n50 XP · C unleashes a sweeping special\n\nEmber Draughts restore vitality.\nMastery Shards grant 20 weapon XP.\n\nCollect loot within 2 metres.\nWeapons take one slot; other items stack to 5.\nEquip another weapon before dropping or selling\nthe one in your hand.", Vector2(570, 144), Vector2(505, 320), 16)
		stats_label = label(card, "", Vector2(570, 475), Vector2(510, 44), 15, AshArt.GOLD)
	button(card, "Leave" if shop else "Close · TAB", Vector2(900, 530), Vector2(185, 35), func() -> void: clear_modal())
	refresh_inventory()

func refresh_inventory() -> void:
	if mode != "inventory" and mode != "shop":
		return
	coin_label.text = "%d embers" % game.run.currency
	for i in inventory_buttons.size():
		var slot := inventory_buttons[i]
		if i >= game.run.inventory.size():
			slot.text = "— empty —"
			slot.modulate = Color("777965")
			continue
		var entry: Dictionary = game.run.inventory[i]
		var prefix := "◆ " if entry.uid == game.run.equipped_uid else ""
		slot.text = "%s%s\n%s%s" % [prefix, entry.name, AshData.RARITIES[entry.rarity], " ×" + str(entry.amount) if entry.amount > 1 else ""]
		slot.modulate = AshData.COLORS[entry.rarity]
		slot.add_theme_stylebox_override("normal", style(Color("353d2f") if selected == i else Color("22251c"), AshArt.GOLD if selected == i else Color("5b5038")))
	details.text = AshData.describe(game.run.inventory[selected]) if selected < game.run.inventory.size() else "Select an item in your satchel."
	if mode == "shop":
		if shop_selected >= 0 and shop_selected < game.shop_stock.size():
			var entry: Dictionary = game.shop_stock[shop_selected]
			var description := AshData.describe(entry).split("\n")
			shop_details.text = "%s · %s\n%s\n%s" % [entry.name, AshData.RARITIES[entry.rarity], description[1], description[2]]
		else:
			shop_details.text = "Select an offering, then Buy.\nPrices rise 25 embers with every rarity tier."
	else:
		stats_label.text = "Vitality %d   ·   Strength ×%.2f   ·   Swiftness ×%.2f" % [game.run.max_health, game.run.damage_scale, game.run.speed_scale]

func show_rest() -> void:
	clear_modal("rest")
	var card := panel(modal, Vector2(370, 150), Vector2(540, 420))
	label(card, "Tend the ember", Vector2(30, 22), Vector2(480, 55), 36, AshArt.GOLD, true)
	label(card, "Choose a stat to improve by 20%.\nThis spends your one rest-site choice.", Vector2(30, 94), Vector2(480, 65), 18)
	var names := ["Vitality", "Strength", "Swiftness"]
	for i in names.size():
		var stat: String = names[i]
		button(card, stat + "   +20%", Vector2(30, 180 + i * 57), Vector2(480, 45), func() -> void:
			game.run.upgrade(stat)
			game.arena.rest_used = true
			game.toast(stat + " strengthened by the ember.")
			game.sound("heal")
			clear_modal())
	button(card, "Leave the fire", Vector2(30, 358), Vector2(480, 35), func() -> void: clear_modal())

func show_result(won: bool) -> void:
	clear_modal("result")
	hud.visible = false
	label(modal, "CROWN BROKEN" if won else "YOU FELL", Vector2(0, 217), Vector2(1280, 100), 72, AshArt.GOLD if won else AshArt.BLOOD, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label(modal, "An ember survives the age of ash." if won else "The dark remembers. Begin again.", Vector2(0, 331), Vector2(1280, 42), 25, Color("c5ba9c"), true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var seconds := int((Time.get_ticks_msec() - game.run.started_at) / 1000)
	label(modal, "Arena %d / 5    ·    %d foes defeated    ·    %d:%02d    ·    Seed %d" % [game.arena_number, game.run.kills, seconds / 60, seconds % 60, game.run.seed_value], Vector2(100, 401), Vector2(1080, 35), 18).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button(modal, "Begin a new pilgrimage", Vector2(450, 488), Vector2(380, 54), func() -> void: game.start_run())
	button(modal, "Retry this seed", Vector2(500, 561), Vector2(280, 40), func() -> void: game.start_run(game.run.seed_value))

func toast(text: String) -> void:
	toast_label.text = text
	toast_time = 4.0
	toast_label.move_to_front()

func announce(title: String, subtitle: String) -> void:
	room_label.text = title
	room_sub.text = subtitle
	room_time = 4.2

func refresh() -> void:
	if not is_instance_valid(game.run):
		return
	health_bar.max_value = game.run.max_health
	health_bar.value = game.run.health
	health_text.text = "VITALITY   %d / %d" % [game.run.health, game.run.max_health]
	coin_text.text = "✦  %d embers" % game.run.currency
	var entry: Dictionary = game.run.equipped()
	if not entry.is_empty():
		weapon_text.text = entry.name
		mastery_bar.value = entry.xp
	var count := 0
	for item_entry in game.run.inventory:
		if item_entry.kind == "flask":
			count += item_entry.amount
	flask_text.text = "[ R ]  Ember Draught  ×%d     ·     Mastery %d XP" % [count, entry.get("xp", 0)]
	if mode == "inventory" or mode == "shop":
		refresh_inventory()

func _process(delta: float) -> void:
	toast_time = maxf(0, toast_time - delta)
	toast_label.modulate.a = minf(1, toast_time)
	if is_instance_valid(game.player):
		stamina_bar.value = game.player.stamina
		damage_overlay.color.a = game.player.hit_flash * 0.5
		var heading := fposmod(rad_to_deg(game.player.yaw), 360)
		compass.text = "·    %s    ·" % (["N", "W", "S", "E"][int((heading + 45) / 90) % 4])
		lock_label.visible = is_instance_valid(game.player.locked) and not is_open()
		if lock_label.visible:
			lock_label.position = game.player.camera.unproject_position(game.player.locked.global_position + Vector3(0, 1.5, 0)) - Vector2(16, 16)
	if game.playing and not is_open():
		room_time = maxf(0, room_time - delta)
		room_label.modulate.a = minf(1, room_time) * minf(1, (4.2 - room_time) * 2)
		room_sub.modulate.a = room_label.modulate.a
	var boss: AshFoe = null
	for foe in game.foes:
		if is_instance_valid(foe) and foe.rank > 0 and not foe.dead:
			boss = foe
			break
	boss_root.visible = boss != null and game.playing
	if boss != null:
		boss_title.text = boss.title + ("  ·  UNBOUND" if boss.enraged else "")
		boss_bar.value = boss.health / boss.max_health * 100
