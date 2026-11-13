class_name GoblinArt
extends RefCounted

const SKIN := Color("638b62")
const SKIN_DARK := Color("416b4d")
const EAR_INNER := Color("a77982")
const EYE_BAG := Color("66536f")
const CLOTH := Color("57483a")
const BOOT := Color("554536")
const ORANGE := Color("bd7833")
const PURPLE := Color("7829a0")
const VIOLET := Color("b64ce0")
const IVORY := Color("dfd5ae")

static func ellipsoid(parent: Node3D, at: Vector3, size: Vector3, color: Color, glow: float = 0.0) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 8
	mesh.rings = 4
	var node := AshArt.mesh_node(parent, mesh, at, AshArt.material(color, false, glow))
	node.scale = size
	return node

static func cone(parent: Node3D, at: Vector3, bottom: float, height: float, color: Color, sides: int = 6) -> MeshInstance3D:
	return AshArt.cylinder(parent, at, bottom, 0.0, height, color, sides)

static func make(parent: Node3D, kind: String) -> Dictionary:
	var root := Node3D.new()
	root.name = "GoblinModel"
	parent.add_child(root)
	var torso := Node3D.new()
	torso.name = "Torso"
	root.add_child(torso)
	var robe := PURPLE if kind == "caster" else CLOTH
	ellipsoid(torso, Vector3(0, 1.12, 0), Vector3(0.72, 0.96, 0.49), robe)
	AshArt.box(torso, Vector3(0, 0.82, -0.31), Vector3(0.82, 0.16, 0.11), ORANGE)
	if kind == "caster":
		AshArt.cylinder(torso, Vector3(0, 0.79, 0), 0.68, 0.43, 0.7, PURPLE, 8)
		for side in [-1, 1]:
			ellipsoid(torso, Vector3(side * 0.25, 0.98, -0.46), Vector3(0.21, 0.31, 0.08), VIOLET)
	else:
		AshArt.box(torso, Vector3(0, 1.07, -0.36), Vector3(0.53, 0.45, 0.06), SKIN_DARK)
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 1.83, -0.03)
	torso.add_child(head)
	ellipsoid(head, Vector3.ZERO, Vector3(1.02, 0.76, 0.75), SKIN)
	# Long hanging nose, eye bags, brows, tusks and the broad sideways ears.
	ellipsoid(head, Vector3(0, -0.19, -0.61), Vector3(0.25, 0.68, 0.71), SKIN)
	for side in [-1, 1]:
		var ear := ellipsoid(head, Vector3(side * 0.75, 0.17, 0.01), Vector3(0.86, 0.35, 0.18), SKIN)
		ear.rotation.z = side * 0.32
		var inner := ellipsoid(head, Vector3(side * 0.82, 0.18, -0.14), Vector3(0.57, 0.18, 0.055), EAR_INNER)
		inner.rotation.z = side * 0.32
		ellipsoid(head, Vector3(side * 0.21, 0.00, -0.30), Vector3(0.31, 0.2, 0.12), EYE_BAG)
		ellipsoid(head, Vector3(side * 0.21, 0.1, -0.39), Vector3(0.19, 0.14, 0.09), IVORY, 0.25)
		var brow := AshArt.box(head, Vector3(side * 0.22, 0.22, -0.39), Vector3(0.3, 0.07, 0.09), SKIN_DARK)
		brow.rotation.z = -side * 0.18
		cone(head, Vector3(side * 0.32, -0.26, -0.36), 0.095, 0.28, IVORY, 5)
		var hoop := AshArt.ring(head, 0.13, AshArt.GOLD, 0.035)
		hoop.position = Vector3(side * 0.95, -0.07, -0.1)
		hoop.rotation.x = PI * 0.5
	if kind == "caster":
		AshArt.cylinder(head, Vector3(0, 0.39, 0), 0.58, 0.23, 0.48, PURPLE, 7)
		cone(head, Vector3(0.08, 0.84, 0), 0.42, 0.7, PURPLE, 7).rotation.z = -0.25
		AshArt.ring(head, 0.4, VIOLET, 0.055).position.y = 0.21
	else:
		AshArt.box(head, Vector3(0, 0.36, 0), Vector3(0.36, 0.12, 0.4), ORANGE)
	var arms: Array[Node3D] = []
	for side in [-1, 1]:
		var arm := Node3D.new()
		arm.name = "ArmLeft" if side < 0 else "ArmRight"
		arm.position = Vector3(side * 0.43, 1.43, 0)
		torso.add_child(arm)
		ellipsoid(arm, Vector3(side * 0.11, -0.31, 0), Vector3(0.17, 0.66, 0.17), SKIN)
		ellipsoid(arm, Vector3(side * 0.16, -0.72, -0.07), Vector3(0.48, 0.38, 0.41), SKIN)
		for finger in range(3):
			ellipsoid(arm, Vector3(side * (0.01 + finger * 0.16), -0.93, -0.2), Vector3(0.14, 0.27, 0.16), SKIN_DARK)
		AshArt.cylinder(arm, Vector3(side * 0.12, -0.5, 0), 0.17, 0.17, 0.09, AshArt.GOLD, 8)
		arms.append(arm)
	var legs: Array[Node3D] = []
	for side in [-1, 1]:
		var leg := Node3D.new()
		leg.name = "LegLeft" if side < 0 else "LegRight"
		leg.position = Vector3(side * 0.28, 0.72, 0)
		root.add_child(leg)
		ellipsoid(leg, Vector3(0, -0.28, 0), Vector3(0.16, 0.61, 0.17), SKIN_DARK)
		ellipsoid(leg, Vector3(0, -0.57, -0.19), Vector3(0.54, 0.34, 0.79), BOOT)
		AshArt.box(leg, Vector3(0, -0.52, -0.51), Vector3(0.55, 0.09, 0.22), ORANGE)
		legs.append(leg)
	var weapon := Node3D.new()
	weapon.name = "Weapon"
	arms[1].add_child(weapon)
	weapon.position = Vector3(0.18, -0.7, -0.24)
	if kind == "club":
		AshArt.cylinder(weapon, Vector3(0, -0.05, -0.58), 0.085, 0.085, 1.55, BOOT, 6).rotation.x = PI * 0.5
		ellipsoid(weapon, Vector3(0, -0.05, -1.36), Vector3(0.62, 0.54, 0.84), Color("95704b"))
		for side in [-1, 1]:
			cone(weapon, Vector3(side * 0.3, -0.03, -1.43), 0.14, 0.32, Color("9b8972"), 5).rotation.z = side * 1.1
	elif kind == "missile":
		AshArt.cylinder(weapon, Vector3(0, -0.04, -0.58), 0.3, 0.3, 1.2, BOOT, 8).rotation.x = PI * 0.5
		AshArt.cylinder(weapon, Vector3(0, -0.04, -1.14), 0.39, 0.39, 0.15, ORANGE, 8).rotation.x = PI * 0.5
		ellipsoid(weapon, Vector3(0, -0.04, -1.3), Vector3(0.22, 0.22, 0.16), Color("c73b3d"), 1.0)
	else:
		AshArt.cylinder(weapon, Vector3(0, -0.05, -0.5), 0.07, 0.09, 1.2, BOOT, 6).rotation.x = PI * 0.5
		ellipsoid(weapon, Vector3(0, -0.05, -1.13), Vector3(0.28, 0.28, 0.29), VIOLET, 1.6)
	return {"root": root, "torso": torso, "head": head, "left_arm": arms[0], "right_arm": arms[1], "left_leg": legs[0], "right_leg": legs[1], "weapon": weapon}
