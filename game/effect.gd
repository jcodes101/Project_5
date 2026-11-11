extends Node3D

var life := 0.5
var elapsed := 0.0
var mode := "pulse"
var radius := 1.0
var direction := Vector3.FORWARD
var damage := 15.0
var source: Node3D
var game: Node
var graphic: Node3D

func _process(delta: float) -> void:
	if not game.playing or game.ui.is_open():
		return
	elapsed += delta
	if mode == "bolt":
		var previous := global_position
		global_position += direction * 8.0 * delta
		graphic.rotation.z += delta * 8
		var query := PhysicsRayQueryParameters3D.create(previous, global_position, 1)
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			queue_free()
			return
		if global_position.distance_to(game.player.global_position + Vector3(0, 0.9, 0)) < 0.75:
			game.player.take_hit(damage, source)
			queue_free()
	elif mode == "number":
		position.y += delta * 1.2
		graphic.modulate.a = 1.0 - elapsed / life
	else:
		graphic.scale = Vector3.ONE * lerpf(0.15, radius, elapsed / life)
		graphic.position.y += delta * 0.12
		if mode == "slash":
			graphic.rotation.y += delta * 12
	if elapsed >= life:
		queue_free()
