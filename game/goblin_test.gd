extends "res://game/game.gd"

func _ready() -> void:
	super._ready()
	start_run(4405)
	ui.announce("GOBLIN TEST", "Club, caster, missile goblins, and the Gilded Hexlord.")

func spawn_encounter() -> void:
	if not playing:
		return
	for entry in [["club", Vector3(-6, 0.1, -4)], ["caster", Vector3(0, 0.1, -6)], ["missile", Vector3(6, 0.1, -4)]]:
		var foe: AshFoe = GOBLIN_FOE.new()
		foe.kind = entry[0]
		foe.arena_level = 1
		foe.position = entry[1]
		add_child(foe)
		foes.append(foe)
	var boss: AshFoe = GOBLIN_BOSS.new()
	boss.arena_level = 1
	boss.position = Vector3(0, 0.1, -12)
	add_child(boss)
	foes.append(boss)
