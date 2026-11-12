extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func screenshot(filename: String) -> void:
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/" + filename + ".png")

func capture() -> void:
	var game: Node = load("res://game/game.tscn").instantiate()
	root.add_child(game)
	await create_timer(1.0).timeout
	await screenshot("title")
	game.start_run(719)
	game.player.invincible = 100
	game.player.global_position = Vector3(0, 0.1, 4)
	game.player.reset_camera()
	game.ui.room_time = 0
	await create_timer(1.2).timeout
	await screenshot("gameplay")
	game.ui.show_inventory()
	await screenshot("inventory")
	game.ui.clear_modal()
	game.load_room("shop")
	game.ui.show_inventory(true)
	game.ui.shop_selected = 2
	game.ui.refresh_inventory()
	await screenshot("shop")
	game.ui.clear_modal()
	game.load_room("rest")
	game.player.global_position = Vector3(0, 0.1, 3)
	game.player.reset_camera()
	game.ui.room_time = 0
	await screenshot("rest-room")
	game.ui.show_rest()
	await screenshot("rest-menu")
	game.ui.clear_modal()
	game.arena_number = 5
	game.load_room("combat")
	game.player.invincible = 100
	game.player.global_position = Vector3(0, 0.1, 0)
	game.player.reset_camera()
	game.player.locked = game.foes[0]
	game.ui.room_time = 0
	await create_timer(1.5).timeout
	await screenshot("boss")
	game.finish_run(true)
	await screenshot("result")
	print("Captured title, gameplay, inventory, shop, rest, boss, and result images in .godot")
	quit()
