class_name RiderModel
extends RefCounted
## Procedural low-poly snowboarder built from primitives.
## The model faces +Z, with its feet at y = 0.

static func build(colors: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "RiderModel"

	var jacket: Color = colors.get("jacket", Color(1.0, 0.36, 0.10))
	var pants: Color = colors.get("pants", Color(0.10, 0.14, 0.22))
	var board_col: Color = colors.get("board", Color(0.12, 0.80, 0.92))
	var accent: Color = colors.get("accent", Color(1.0, 0.85, 0.20))
	var skin: Color = colors.get("skin", Color(0.85, 0.65, 0.50))
	var hat: Color = colors.get("hat", Color(0.90, 0.20, 0.25))

	var mat_jacket := _mat(jacket, 0.75)
	var mat_pants := _mat(pants, 0.85)
	var mat_board := _mat(board_col, 0.35)
	var mat_accent := _mat(accent, 0.5)
	var mat_skin := _mat(skin, 0.8)
	var mat_hat := _mat(hat, 0.85)
	var mat_dark := _mat(Color(0.06, 0.07, 0.10), 0.5)
	var mat_metal := _mat(Color(0.7, 0.75, 0.82), 0.25)
	mat_metal.metallic = 0.8

	# Board with lifted nose and tail.
	var board := _box(root, Vector3(0.4, 0.07, 1.72), Vector3(0.0, 0.07, 0.0), Vector3.ZERO, mat_board)
	board.name = "Board"
	_box(root, Vector3(0.4, 0.07, 0.38), Vector3(0.0, 0.13, 0.84), Vector3(deg_to_rad(-20.0), 0.0, 0.0), mat_board)
	_box(root, Vector3(0.4, 0.07, 0.38), Vector3(0.0, 0.13, -0.84), Vector3(deg_to_rad(20.0), 0.0, 0.0), mat_board)
	_box(root, Vector3(0.1, 0.02, 1.2), Vector3(0.0, 0.11, 0.0), Vector3.ZERO, mat_accent)

	# Boots and legs.
	_box(root, Vector3(0.26, 0.22, 0.4), Vector3(0.17, 0.2, 0.16), Vector3.ZERO, mat_dark)
	_box(root, Vector3(0.26, 0.22, 0.4), Vector3(-0.17, 0.2, -0.14), Vector3.ZERO, mat_dark)
	_box(root, Vector3(0.2, 0.52, 0.24), Vector3(0.17, 0.5, 0.1), Vector3(deg_to_rad(16.0), 0.0, deg_to_rad(-5.0)), mat_pants)
	_box(root, Vector3(0.2, 0.52, 0.24), Vector3(-0.17, 0.5, -0.1), Vector3(deg_to_rad(-10.0), 0.0, deg_to_rad(5.0)), mat_pants)

	# Body.
	var torso := _box(root, Vector3(0.54, 0.62, 0.34), Vector3(0.0, 1.0, 0.0), Vector3(deg_to_rad(8.0), 0.0, 0.0), mat_jacket)
	torso.name = "Torso"
	_box(root, Vector3(0.56, 0.12, 0.36), Vector3(0.0, 0.73, -0.02), Vector3.ZERO, mat_accent)

	# Arms held out for balance.
	var arm_l := _box(root, Vector3(0.15, 0.56, 0.18), Vector3(-0.4, 1.02, 0.04), Vector3(deg_to_rad(-12.0), 0.0, deg_to_rad(28.0)), mat_jacket)
	arm_l.name = "ArmL"
	var arm_r := _box(root, Vector3(0.15, 0.56, 0.18), Vector3(0.4, 1.02, 0.04), Vector3(deg_to_rad(-12.0), 0.0, deg_to_rad(-28.0)), mat_jacket)
	arm_r.name = "ArmR"
	_box(root, Vector3(0.16, 0.16, 0.18), Vector3(-0.53, 0.77, 0.09), Vector3.ZERO, mat_dark)
	_box(root, Vector3(0.16, 0.16, 0.18), Vector3(0.53, 0.77, 0.09), Vector3.ZERO, mat_dark)

	# Head, beanie and goggles.
	var head := SphereMesh.new()
	head.radius = 0.2
	head.height = 0.4
	head.radial_segments = 7
	head.rings = 5
	head.material = mat_skin
	var head_mi := MeshInstance3D.new()
	head_mi.mesh = head
	head_mi.position = Vector3(0.0, 1.5, 0.02)
	root.add_child(head_mi)

	var beanie := CylinderMesh.new()
	beanie.top_radius = 0.16
	beanie.bottom_radius = 0.22
	beanie.height = 0.2
	beanie.radial_segments = 8
	beanie.rings = 1
	beanie.material = mat_hat
	var beanie_mi := MeshInstance3D.new()
	beanie_mi.mesh = beanie
	beanie_mi.position = Vector3(0.0, 1.64, 0.02)
	root.add_child(beanie_mi)

	var pom := SphereMesh.new()
	pom.radius = 0.075
	pom.height = 0.15
	pom.radial_segments = 6
	pom.rings = 3
	pom.material = mat_accent
	var pom_mi := MeshInstance3D.new()
	pom_mi.mesh = pom
	pom_mi.position = Vector3(0.0, 1.76, 0.02)
	root.add_child(pom_mi)

	var goggles := _box(root, Vector3(0.31, 0.1, 0.08), Vector3(0.0, 1.53, 0.18), Vector3.ZERO, mat_dark)
	goggles.name = "Goggles"
	var lens := _box(root, Vector3(0.27, 0.06, 0.02), Vector3(0.0, 1.53, 0.225), Vector3.ZERO, mat_accent)
	lens.name = "Lens"

	# Scarf tail.
	_box(root, Vector3(0.16, 0.5, 0.06), Vector3(-0.12, 1.25, -0.24), Vector3(deg_to_rad(18.0), 0.0, deg_to_rad(-14.0)), mat_accent)

	root.set_meta("arm_l", arm_l)
	root.set_meta("arm_r", arm_r)
	root.set_meta("torso", torso)
	root.set_meta("board", board)
	return root


static func _mat(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = 0.0
	return mat


static func _box(parent: Node3D, size: Vector3, pos: Vector3, rot: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func default_colors(index: int) -> Dictionary:
	var palettes := [
		{"jacket": Color(0.95, 0.28, 0.08), "pants": Color(0.08, 0.11, 0.2), "board": Color(0.12, 0.8, 0.92), "accent": Color(1.0, 0.82, 0.18), "skin": Color(0.85, 0.64, 0.48), "hat": Color(0.1, 0.6, 0.8)},
		{"jacket": Color(0.92, 0.15, 0.5), "pants": Color(0.16, 0.1, 0.24), "board": Color(0.95, 0.82, 0.12), "accent": Color(0.2, 0.9, 1.0), "skin": Color(0.55, 0.35, 0.25), "hat": Color(0.95, 0.9, 0.95)},
		{"jacket": Color(0.2, 0.55, 0.95), "pants": Color(0.9, 0.9, 0.94), "board": Color(1.0, 0.4, 0.1), "accent": Color(0.1, 0.85, 0.8), "skin": Color(0.78, 0.58, 0.42), "hat": Color(0.12, 0.16, 0.26)},
		{"jacket": Color(0.16, 0.75, 0.4), "pants": Color(0.1, 0.14, 0.18), "board": Color(0.85, 0.2, 0.65), "accent": Color(1.0, 0.9, 0.3), "skin": Color(0.42, 0.28, 0.2), "hat": Color(0.98, 0.5, 0.15)},
		{"jacket": Color(0.65, 0.3, 0.95), "pants": Color(0.9, 0.85, 0.8), "board": Color(0.1, 0.9, 0.55), "accent": Color(1.0, 0.5, 0.2), "skin": Color(0.8, 0.62, 0.5), "hat": Color(0.1, 0.1, 0.15)},
		{"jacket": Color(0.95, 0.75, 0.15), "pants": Color(0.15, 0.2, 0.3), "board": Color(0.95, 0.25, 0.2), "accent": Color(0.2, 0.95, 0.9), "skin": Color(0.6, 0.42, 0.3), "hat": Color(0.85, 0.15, 0.2)},
	]
	return palettes[index % palettes.size()]
