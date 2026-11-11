extends CharacterBody3D

@export var move_speed: float = 4.0
@onready var visual: AnimatedSprite3D = $Visual

const GRAVITY: float = 24.0
const WORLD_LIMIT_X: float = 13.0
const WORLD_LIMIT_Z: float = 8.0
const KNOCKBACK_DECAY: float = 7.0

var knockback_velocity := Vector3.ZERO


func _ready() -> void:
	visual.play("idle")


func _physics_process(delta: float) -> void:
	var left := Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A)
	var right := Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D)
	var up := Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W)
	var down := Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S)
	var input := Vector2(int(right) - int(left), int(down) - int(up)).normalized()

	velocity.x = input.x * move_speed + knockback_velocity.x
	velocity.z = input.y * move_speed + knockback_velocity.z
	if is_on_floor():
		velocity.y = -0.1
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	knockback_velocity *= exp(-KNOCKBACK_DECAY * delta)

	global_position.x = clampf(global_position.x, -WORLD_LIMIT_X, WORLD_LIMIT_X)
	global_position.z = clampf(global_position.z, -WORLD_LIMIT_Z, WORLD_LIMIT_Z)
	if input.length_squared() > 0.0:
		if visual.animation != "walk":
			visual.play("walk")
		if input.x != 0.0:
			visual.flip_h = input.x > 0.0
	elif visual.animation != "idle":
		visual.play("idle")


func apply_knockback(from_position: Vector3, strength: float) -> void:
	var away := global_position - from_position
	away.y = 0.0
	if away.length_squared() < 0.001:
		away = Vector3.FORWARD
	knockback_velocity = away.normalized() * strength
