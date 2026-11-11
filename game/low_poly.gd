class_name AshArt
extends RefCounted

const BLACK := Color("171711")
const MOSS := Color("353d2f")
const WOOD := Color("66533d")
const GOLD := Color("c2a46b")
const BLOOD := Color("8c302b")
static var materials: Dictionary = {}

static func material(color: Color, textured: bool = false, glow: float = 0.0) -> StandardMaterial3D:
	var key := str(color) + str(textured) + str(glow)
	if materials.has(key):
		return materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if textured:
		var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
		var rng := RandomNumberGenerator.new()
		rng.seed = 71
		for x in 32:
			for y in 32:
				var shade := rng.randf_range(0.64, 1.1)
				if y % 16 == 0 or (x + (16 if y > 16 else 0)) % 32 == 0:
					shade *= 0.4
				img.set_pixel(x, y, Color(shade, shade, shade))
		mat.albedo_texture = ImageTexture.create_from_image(img)
		mat.uv1_scale = Vector3(2, 2, 2)
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	materials[key] = mat
	return mat

static func mesh_node(parent: Node3D, mesh: Mesh, at: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	parent.add_child(node)
	return node

static func box(parent: Node3D, at: Vector3, size: Vector3, color: Color, textured: bool = false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh_node(parent, mesh, at, material(color, textured))

static func cylinder(parent: Node3D, at: Vector3, bottom: float, top: float, height: float, color: Color, sides: int = 6) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	return mesh_node(parent, mesh, at, material(color, true))

static func solid(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	parent.add_child(body)
	box(body, Vector3.ZERO, size, color, true)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	return body

static func ring(parent: Node3D, radius: float, color: Color, thickness: float = 0.035) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius + thickness
	mesh.rings = 40
	mesh.ring_segments = 4
	var node := mesh_node(parent, mesh, Vector3(0, 0.045, 0), material(color, false, 0.8))
	return node

static func flame(parent: Node3D, at: Vector3, scale_value: float = 1.0) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = at
	root.scale = Vector3.ONE * scale_value
	cylinder(root, Vector3(0, 0.18, 0), 0.2, 0.32, 0.25, WOOD)
	var fire := cylinder(root, Vector3(0, 0.56, 0), 0.23, 0.0, 0.72, GOLD, 5)
	fire.material_override = material(GOLD, false, 2.0)
	var light := OmniLight3D.new()
	root.add_child(light)
	light.position.y = 0.8
	light.light_color = Color("e6b579")
	light.light_energy = 2.4 * scale_value
	light.omni_range = 7.5 * scale_value
	light.shadow_enabled = true
	root.set_meta("light", light)
	root.set_meta("fire", fire)
	return root

static func weapon(parent: Node3D, kind: String, color: Color = GOLD) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var length_value := {"dagger": 0.65, "sword": 1.35, "greatsword": 1.85, "spear": 2.1}.get(kind, 1.35) as float
	box(root, Vector3(0, 0.02, 0), Vector3(0.1, 0.12, 0.4), WOOD)
	if kind == "spear":
		box(root, Vector3(0, 0, -0.7), Vector3(0.08, 0.08, 1.8), WOOD)
		var tip := cylinder(root, Vector3(0, 0, -1.8), 0.13, 0, 0.48, color)
		tip.rotation.x = -PI / 2
	else:
		box(root, Vector3(0, 0, -0.2), Vector3(0.46, 0.1, 0.1), color)
		box(root, Vector3(0, 0, -length_value * 0.5 - 0.2), Vector3(0.23 if kind == "greatsword" else 0.13, 0.055, length_value), color)
		var tip := cylinder(root, Vector3(0, 0, -length_value - 0.3), 0.1, 0, 0.23, color, 4)
		tip.rotation.x = -PI / 2
	return root

static func knight(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	cylinder(root, Vector3(0, 0.87, 0), 0.42, 0.27, 0.85, MOSS)
	box(root, Vector3(0, 1.1, -0.07), Vector3(0.57, 0.5, 0.38), Color("737468"), true)
	cylinder(root, Vector3(0, 1.62, 0), 0.28, 0.22, 0.48, Color("6e7065"), 5)
	box(root, Vector3(0, 1.66, -0.235), Vector3(0.3, 0.055, 0.05), BLACK)
	box(root, Vector3(0, 1.82, 0.02), Vector3(0.045, 0.12, 0.45), GOLD)
	for side in [-1, 1]:
		box(root, Vector3(side * 0.18, 0.3, 0), Vector3(0.22, 0.6, 0.27), Color("3f4037"))
		box(root, Vector3(side * 0.42, 1.12, 0), Vector3(0.26, 0.28, 0.35), Color("747465"), true)
		box(root, Vector3(side * 0.41, 0.86, 0), Vector3(0.17, 0.43, 0.19), WOOD)
	box(root, Vector3(-0.02, 0.92, 0.25), Vector3(0.58, 0.98, 0.055), Color("63352d"), true)
	return root

static func enemy(parent: Node3D, family: String, boss: bool = false) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var body_color := {"stone": Color("777469"), "briar": WOOD, "iron": Color("525449")}.get(family, WOOD) as Color
	if family == "briar":
		cylinder(root, Vector3(0, 1.0, 0), 0.5, 0.28, 1.8, body_color, 5)
		for i in 5:
			var branch := box(root, Vector3((i % 2 * 2 - 1) * (0.35 + i * 0.08), 1.3 + i * 0.18, 0), Vector3(0.17, 0.85, 0.17), body_color, true)
			branch.rotation.z = (i % 2 * 2 - 1) * 0.7
		cylinder(root, Vector3(0, 1.95, 0), 0.85, 0.12, 0.85, MOSS, 5)
	else:
		box(root, Vector3(0, 1.1, 0), Vector3(1.0, 1.1, 0.65), body_color, true)
		cylinder(root, Vector3(0, 1.87, 0), 0.37, 0.25, 0.55, body_color, 5)
		for side in [-1, 1]:
			box(root, Vector3(side * 0.3, 0.35, 0), Vector3(0.37, 0.7, 0.4), body_color, true)
			var arm := box(root, Vector3(side * 0.72, 1.05, 0), Vector3(0.32, 1.05, 0.4), body_color, true)
			arm.rotation.z = side * 0.23
		if family == "iron":
			for i in 3:
				box(root, Vector3(0, 1.3 - i * 0.18, -0.34), Vector3(0.6, 0.055, 0.05), WOOD)
		else:
			var club := box(root, Vector3(0.95, 0.76, -0.3), Vector3(0.4, 1.2, 0.45), WOOD, true)
			club.rotation.x = -0.45
	for side in [-1, 1]:
		box(root, Vector3(side * 0.12, 1.9, -0.34), Vector3(0.075, 0.075, 0.05), GOLD).material_override = material(GOLD, false, 1.8)
	if boss:
		for i in 5:
			cylinder(root, Vector3((i - 2) * 0.19, 2.35 + (0.15 if i % 2 == 0 else 0), 0), 0.09, 0, 0.6, GOLD, 4)
		root.scale = Vector3.ONE * 1.65
	return root
