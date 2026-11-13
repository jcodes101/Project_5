extends "res://game/game.gd"

const BOSS = preload("res://game/goblin_boss.gd")

func _ready() -> void:
	super._ready()
	start_run(4410)
	ui.announce("THE GILDED HEXLORD", "Club sweep, hex circle, and a three missile volley.")

func spawn_encounter() -> void:
	if not playing:
		return
	var boss: AshFoe = BOSS.new()
	boss.arena_level = 1
	boss.position = Vector3(0, 0.1, -7)
	add_child(boss)
	foes.append(boss)
