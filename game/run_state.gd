class_name AshRun
extends Node

signal changed
signal message(text: String)

var health := 100.0
var max_health := 100.0
var damage_scale := 1.0
var speed_scale := 1.0
var currency := 100
var inventory: Array[Dictionary] = []
var equipped_uid := ""
var kills := 0
var seed_value := 0
var started_at := 0

func reset(run_seed: int) -> void:
	seed_value = run_seed
	health = 100.0
	max_health = 100.0
	damage_scale = 1.0
	speed_scale = 1.0
	currency = 100
	kills = 0
	started_at = int(Time.get_ticks_msec())
	inventory.clear()
	var sword := AshData.item("sword")
	inventory.append(sword)
	equipped_uid = sword.uid
	var flask := AshData.item("flask")
	flask.amount = 3
	inventory.append(flask)
	changed.emit()

func equipped() -> Dictionary:
	for entry in inventory:
		if entry.uid == equipped_uid:
			return entry
	return {}

func can_add(entry: Dictionary) -> bool:
	if inventory.size() < 12:
		return true
	if not AshData.WEAPONS.has(entry.kind):
		for stored in inventory:
			if stored.kind == entry.kind and stored.rarity == entry.rarity and stored.amount < 5:
				return true
	return false

func add_item(entry: Dictionary) -> bool:
	if not AshData.WEAPONS.has(entry.kind):
		for stored in inventory:
			if stored.kind == entry.kind and stored.rarity == entry.rarity and stored.amount < 5:
				stored.amount += 1
				changed.emit()
				return true
	if inventory.size() >= 12:
		message.emit("Inventory full. Use, sell, or drop an item.")
		return false
	inventory.append(entry)
	changed.emit()
	return true

func use_item(index: int) -> void:
	if index < 0 or index >= inventory.size():
		return
	var entry := inventory[index]
	if AshData.WEAPONS.has(entry.kind):
		equipped_uid = entry.uid
		message.emit("Equipped " + entry.name)
	elif entry.kind == "flask":
		if health >= max_health:
			message.emit("Your vitality is already full.")
			return
		heal(35.0 + entry.rarity * 8.0)
		consume(index)
		message.emit("The ember restores your vitality.")
	else:
		grant_mastery(20)
		consume(index)
	changed.emit()

func consume(index: int) -> void:
	inventory[index].amount -= 1
	if inventory[index].amount <= 0:
		inventory.remove_at(index)
	changed.emit()

func quick_heal() -> bool:
	for i in inventory.size():
		if inventory[i].kind == "flask" and health < max_health:
			use_item(i)
			return true
	message.emit("No draught needed or none remaining.")
	return false

func heal(amount: float) -> void:
	health = minf(max_health, health + amount)
	changed.emit()

func grant_mastery(amount: int) -> void:
	var weapon := equipped()
	if weapon.is_empty():
		return
	var old: int = weapon.xp
	weapon.xp += amount
	if old < 50 and weapon.xp >= 50:
		message.emit("MASTERY AWAKENED  ·  Press C for your special attack")
	elif old < 25 and weapon.xp >= 25:
		message.emit("COMBO UNLOCKED  ·  Chain three light attacks")
	changed.emit()

func upgrade(stat: String, factor: float = 1.2) -> void:
	match stat:
		"Vitality":
			var difference := max_health * (factor - 1.0)
			max_health *= factor
			health = clampf(health + difference, 1.0, max_health)
		"Strength": damage_scale *= factor
		"Swiftness": speed_scale *= factor
	changed.emit()
