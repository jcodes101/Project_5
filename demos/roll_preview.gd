extends Node3D

# Isolated visual prototype; does not change the game's player controller.
var rolling: Node3D
var elapsed := 0.0
var labels: Label
var clearance := 0.04

func box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> void:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	part.material_override = mat
	part.position = at
	parent.add_child(part)

func mannequin(at: Vector3, phase: float) -> Node3D:
	var actor := Node3D.new()
	add_child(actor)
	actor.position = at
	var pivot := Node3D.new()
	actor.add_child(pivot)
	box(pivot, Vector3.ZERO, Vector3(0.58, 0.72, 0.35), Color("618c91"))
	box(pivot, Vector3(0, 0.58, 0), Vector3(0.35, 0.36, 0.35), Color("dfbd7c"))
	for side in [-1, 1]:
		box(pivot, Vector3(side * 0.18, -0.63, 0), Vector3(0.23, 0.55, 0.3), Color("47656f"))
		box(pivot, Vector3(side * 0.4, 0, -0.15), Vector3(0.19, 0.6, 0.23), Color("dfbd7c"))
	pose(pivot, phase)
	return actor

func pose(pivot: Node3D, phase: float) -> void:
	var tuck := sin(PI * phase)
	pivot.scale = Vector3(1, 1 - 0.48 * tuck, 1 + 0.25 * tuck)
	pivot.rotation.x = -TAU * phase
	# Compute every box corner in the rolled pose, then lift just enough to
	# keep the entire visual above the floor. Collision stays upright in-game.
	pivot.position.y = 0
	var lowest := 0.0
	for child in pivot.get_children():
		var half: Vector3 = child.mesh.size * 0.5
		for x in [-1, 1]:
			for y in [-1, 1]:
				for z in [-1, 1]:
					var corner: Vector3 = pivot.transform * (child.position + half * Vector3(x, y, z))
					lowest = minf(lowest, corner.y)
	pivot.position.y = -lowest + clearance

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("17232d"))
	box(self, Vector3(0, -0.12, 0), Vector3(16, 0.24, 10), Color("283b49"))
	for i in 5:
		var at := Vector3((i - 2) * 2.5, 0, -2)
		mannequin(at, i / 4.0)
		var text := Label3D.new()
		text.text = ["READY", "TUCK", "ROTATE", "UNFOLD", "RECOVER"][i]
		text.position = at + Vector3(0, 2.4, 0)
		text.font_size = 42
		text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(text)
	rolling = mannequin(Vector3(0, 0, 2.2), 0)
	rolling.rotation.y = PI / 2
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0, 8, 14)
	camera.look_at(Vector3(0, 0.6, -0.5))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 16
	camera.current = true
	var light := DirectionalLight3D.new()
	add_child(light)
	light.rotation_degrees = Vector3(-55, -25, 0)
	light.light_energy = 1.6
	light.shadow_enabled = true
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("abc5dc")
	env.environment.ambient_light_energy = 0.6
	add_child(env)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	labels = Label.new()
	canvas.add_child(labels)
	labels.position = Vector2(32, 24)
	labels.add_theme_font_size_override("font_size", 24)
	labels.text = "ROLL STUDY | Original block mannequin\nCenter pivot / tucked body / floor clearance\nAnimated example below - loops automatically"

func _process(delta: float) -> void:
	elapsed = fmod(elapsed + delta, 2.4)
	var phase := clampf((elapsed - 0.5) / 0.7, 0, 1)
	pose(rolling.get_child(0), phase)
	rolling.position.x = lerpf(-2.5, 2.5, phase)
