class_name GoblinMissile
extends Node3D

const GOBLIN_ART = preload("res://game/goblin_art.gd")

var game: Node
var source: Node3D
var direction := Vector3.FORWARD
var speed := 10.0
var age := 0.0
var body: Node3D

func _ready() -> void:
	body = Node3D.new()
	add_child(body)
	AshArt.cylinder(body, Vector3.ZERO, 0.17, 0.17, 0.58, GOBLIN_ART.ORANGE, 7).rotation.x = PI * 0.5
	AshArt.cylinder(body, Vector3(0, 0, 0.2), 0.22, 0.22, 0.08, AshArt.GOLD, 7).rotation.x = PI * 0.5
	GOBLIN_ART.cone(body, Vector3(0, 0, -0.39), 0.17, 0.28, Color("c34440"), 7).rotation.x = -PI * 0.5
	for side in [-1, 1]:
		AshArt.box(body, Vector3(side * 0.19, 0, 0.21), Vector3(0.17, 0.06, 0.25), GOBLIN_ART.ORANGE)
	body.rotation.y = atan2(-direction.x, -direction.z)

func _physics_process(delta: float) -> void:
	if not game.playing or game.ui.is_open():
		return
	age += delta
	var previous := global_position
	global_position += direction * speed * delta
	body.rotation.z += delta * 9.0
	var query := PhysicsRayQueryParameters3D.create(previous, global_position, 1)
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		_burst(false)
	elif global_position.distance_to(game.player.global_position + Vector3(0, 0.9, 0)) < 0.7:
		_burst(true)
	elif age > 4.0:
		queue_free()

func _burst(hit_player: bool) -> void:
	game.pulse(global_position, GOBLIN_ART.ORANGE, 1.3)
	game.sound("slam", -10)
	if hit_player:
		game.player.take_hit(16 + source.arena_level * 2, source)
	queue_free()
