class_name World
extends Node3D
## Builds the mountain: terrain mesh, forest, rocks, course markers, rails and snow.

var course: Course
var theme: Dictionary
var snowfall: CPUParticles3D
var terrain_material: StandardMaterial3D


func build(p_course: Course, p_theme: Dictionary) -> void:
	course = p_course
	theme = p_theme
	_build_environment()
	_build_terrain()
	_build_forest()
	_build_rocks()
	_build_flags()
	_build_gates()
	_build_rails()
	_build_snowfall()


func set_focus(focus: Vector3) -> void:
	if snowfall:
		snowfall.global_position = focus + Vector3(0.0, 14.0, 22.0)


func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = theme["sky_top"]
	sky_mat.sky_horizon_color = theme["sky_horizon"]
	sky_mat.sky_curve = 0.18
	sky_mat.ground_bottom_color = theme["ground"]
	sky_mat.ground_horizon_color = theme["sky_horizon"]
	sky_mat.ground_curve = 0.08
	sky_mat.sun_angle_max = 18.0
	sky_mat.sun_curve = 0.08
	sky_mat.sky_energy_multiplier = 1.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = float(theme["ambient"])
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_light_color = theme["fog"]
	env.fog_density = float(theme["fog_density"])
	env.fog_sky_affect = 0.55
	env.fog_aerial_perspective = 0.35
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = theme["sun"]
	sun.light_energy = float(theme["sun_energy"])
	sun.rotation_degrees = theme["sun_rot"]
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 170.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.shadow_bias = 0.04
	sun.shadow_blur = 1.4
	add_child(sun)

	# A soft fill light so the low-poly faces stay readable.
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.55, 0.68, 1.0)
	fill.light_energy = 0.22 if not theme["night"] else 0.35
	fill.rotation_degrees = Vector3(-24.0, 210.0, 0.0)
	fill.shadow_enabled = false
	add_child(fill)


func _build_terrain() -> void:
	terrain_material = StandardMaterial3D.new()
	terrain_material.vertex_color_use_as_albedo = true
	terrain_material.roughness = 1.0
	terrain_material.metallic = 0.0
	terrain_material.specular = 0.0

	var step := 6.0
	var x0 := -course.width * 0.5
	var cols := int(round(course.width / step))
	var step_x := course.width / float(cols)
	var z_end := course.length + 130.0
	var rows := int(round(z_end / step))
	var step_z := z_end / float(rows)

	# One shared height grid keeps physics and visuals perfectly aligned and fast.
	var points := PackedVector3Array()
	points.resize((cols + 1) * (rows + 1))
	for r in range(rows + 1):
		var z := float(r) * step_z
		for c in range(cols + 1):
			var x := x0 + float(c) * step_x
			points[r * (cols + 1) + c] = Vector3(x, course.height(x, z), z)

	var rows_per_chunk := 26
	var row := 0
	while row < rows:
		var row_end := mini(row + rows_per_chunk, rows)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for r in range(row, row_end):
			for c in range(cols):
				var i00 := r * (cols + 1) + c
				var p00 := points[i00]
				var p10 := points[i00 + 1]
				var p01 := points[i00 + cols + 1]
				var p11 := points[i00 + cols + 2]
				_add_terrain_tri(st, p00, p10, p11)
				_add_terrain_tri(st, p00, p11, p01)
		var mesh := st.commit()
		if mesh == null:
			row = row_end
			continue
		mesh.surface_set_material(0, terrain_material)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(mi)
		row = row_end


func _add_terrain_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.y < 0.0:
		n = -n
	var center := (a + b + c) / 3.0
	var col := _terrain_color(center.x, center.z, center.y, n)
	st.set_color(col)
	st.set_normal(n)
	st.add_vertex(a)
	st.set_color(col)
	st.set_normal(n)
	st.add_vertex(b)
	st.set_color(col)
	st.set_normal(n)
	st.add_vertex(c)


func _terrain_color(x: float, z: float, y: float, n: Vector3) -> Color:
	var d := absf(x - course.center_x(z))
	var steep := 1.0 - clampf(n.y, 0.0, 1.0)
	var rough := course.noise.get_noise_2d(x * 0.11 + 13.0, z * 0.11) * 0.5 + 0.5
	var col: Color = (theme["snow"] as Color).lerp(theme["snow_deep"], clampf(rough, 0.0, 1.0))
	col = col.lerp(theme["rock"], smoothstep(0.08, 0.30, steep))
	if d < 44.0:
		var groom := 1.0 - smoothstep(27.0, 44.0, d)
		col = col.lerp(theme["groom"], groom * 0.4)
		var stripe := 0.5 + 0.5 * sin(z * 0.23)
		col = col.darkened(0.03 * stripe * groom)
		var corduroy := 0.5 + 0.5 * sin((x - course.center_x(z)) * 1.35)
		col = col.darkened(0.03 * corduroy * groom)
	var alt := smoothstep(240.0, 430.0, y)
	col = col.lerp(theme["snow"], alt * 0.3)
	# Facet jitter: makes the flat-shaded low-poly triangles read on white snow.
	var facet := absf(sin(x * 12.9898 + z * 78.233) * 43758.5453)
	facet -= floor(facet)
	col = col.darkened(facet * 0.1)
	return col


func _build_forest() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = course.seed + 17
	var bases: Array[Transform3D] = []
	var greens: Array[Color] = []
	var wanted := int(theme["tree_count"])
	var tries := 0
	while bases.size() < wanted and tries < wanted * 6:
		tries += 1
		var z := rng.randf_range(20.0, course.length + 100.0)
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var dist := rng.randf_range(58.0, 155.0)
		var x := course.center_x(z) + side * dist
		if absf(x) > course.width * 0.5 - 12.0:
			continue
		var y := course.height(x, z)
		var s := rng.randf_range(0.75, 1.7)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(s, s, s))
		bases.append(Transform3D(basis, Vector3(x, y, z)))
		greens.append((theme["tree"] as Color).lerp(Color(0.18, 0.42, 0.28), rng.randf() * 0.4))

	var trunk_mat := _make_material(Color(0.27, 0.19, 0.14), 0.95, true)
	var canopy_mat := _make_material(Color.WHITE, 0.9, true)
	var snow_mat := _make_material(Color.WHITE, 0.85, true)

	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.16
	trunk.bottom_radius = 0.3
	trunk.height = 2.4
	trunk.radial_segments = 5
	trunk.rings = 1
	trunk.material = trunk_mat

	var canopy := CylinderMesh.new()
	canopy.top_radius = 0.0
	canopy.bottom_radius = 1.9
	canopy.height = 5.2
	canopy.radial_segments = 6
	canopy.rings = 1
	canopy.material = canopy_mat

	var cap := CylinderMesh.new()
	cap.top_radius = 0.0
	cap.bottom_radius = 1.25
	cap.height = 2.0
	cap.radial_segments = 6
	cap.rings = 1
	cap.material = snow_mat

	var trunk_xf: Array[Transform3D] = []
	var canopy_xf: Array[Transform3D] = []
	var cap_xf: Array[Transform3D] = []
	var trunk_cols: Array[Color] = []
	var cap_cols: Array[Color] = []
	for i in bases.size():
		var base := bases[i]
		var s := base.basis.get_scale().x
		trunk_xf.append(Transform3D(base.basis, base.origin + Vector3(0.0, 1.2 * s, 0.0)))
		canopy_xf.append(Transform3D(base.basis, base.origin + Vector3(0.0, 5.0 * s, 0.0)))
		cap_xf.append(Transform3D(base.basis, base.origin + Vector3(0.0, 6.6 * s, 0.0)))
		trunk_cols.append(Color(0.6, 0.7, 0.6))
		cap_cols.append(theme["tree_snow"])

	_add_multimesh(trunk, trunk_xf, trunk_cols, true)
	_add_multimesh(canopy, canopy_xf, greens, true)
	_add_multimesh(cap, cap_xf, cap_cols, false)


func _add_multimesh(mesh: PrimitiveMesh, xforms: Array[Transform3D], colors: Array[Color], shadows: bool) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, colors[i % colors.size()])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _build_rocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = course.seed + 99
	var mat := _make_material(Color.WHITE, 0.95, true)
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 1.0
	rock_mesh.height = 2.0
	rock_mesh.radial_segments = 6
	rock_mesh.rings = 3
	rock_mesh.material = mat
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for i in 90:
		var z := rng.randf_range(30.0, course.length + 80.0)
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var dist := rng.randf_range(42.0, 150.0)
		var x := course.center_x(z) + side * dist
		if absf(x) > course.width * 0.5 - 8.0:
			continue
		var sx := rng.randf_range(1.0, 3.4)
		var sy := rng.randf_range(0.8, 2.0)
		var sz := rng.randf_range(1.0, 3.0)
		var y := course.height(x, z) + sy * 0.25
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(sx, sy, sz))
		xforms.append(Transform3D(basis, Vector3(x, y, z)))
		colors.append((theme["rock"] as Color).lightened(rng.randf_range(-0.08, 0.16)))
	_add_multimesh(rock_mesh, xforms, colors, true)


func _build_flags() -> void:
	var pole_mat := _make_material(Color(0.22, 0.23, 0.27), 0.6, false)
	var flag_mat := _make_material(Color.WHITE, 0.6, false)
	flag_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var pole := CylinderMesh.new()
	pole.top_radius = 0.07
	pole.bottom_radius = 0.09
	pole.height = 3.1
	pole.radial_segments = 4
	pole.material = pole_mat

	var flag := BoxMesh.new()
	flag.size = Vector3(1.25, 0.72, 0.05)
	flag.material = flag_mat

	var pole_xf: Array[Transform3D] = []
	var flag_xf: Array[Transform3D] = []
	var cols: Array[Color] = []
	var z := 30.0
	var idx := 0
	while z < course.length - 20.0:
		for side_v in [-1.0, 1.0]:
			var side := float(side_v)
			var x := course.center_x(z) + side * 31.0
			var y := course.height(x, z)
			pole_xf.append(Transform3D(Basis(), Vector3(x, y + 1.5, z)))
			flag_xf.append(Transform3D(Basis(), Vector3(x - side * 0.69, y + 2.6, z)))
			cols.append((theme["accent"] as Color) if idx % 2 == 0 else (theme["accent2"] as Color))
		z += 48.0
		idx += 1
	var pole_cols: Array[Color] = [Color(0.7, 0.7, 0.7)]
	_add_multimesh(pole, pole_xf, pole_cols, false)
	_add_multimesh(flag, flag_xf, cols, false)


func _build_gates() -> void:
	_gate(64.0, "START", theme["accent2"])
	_gate(course.length + 3.0, "FINISH", theme["accent"])


func _gate(z: float, text: String, color: Color) -> void:
	var cx := course.center_x(z)
	var gy := course.height(cx, z)
	var post_mat := _make_material(Color(0.09, 0.11, 0.15), 0.55, false)
	var banner_mat := _make_material(color, 0.55, false)
	banner_mat.emission_enabled = true
	banner_mat.emission = color
	banner_mat.emission_energy_multiplier = 0.35

	for side_v in [-1.0, 1.0]:
		var side := float(side_v)
		var post := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.55, 7.4, 0.55)
		pm.material = post_mat
		post.mesh = pm
		post.position = Vector3(cx + side * 13.5, gy + 3.5, z)
		add_child(post)

	var banner := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(28.0, 3.0, 0.4)
	bm.material = banner_mat
	banner.mesh = bm
	banner.position = Vector3(cx, gy + 6.8, z)
	add_child(banner)

	var label := Label3D.new()
	label.text = text
	label.font_size = 128
	label.pixel_size = 0.018
	label.outline_size = 28
	label.modulate = Color(1.0, 1.0, 1.0)
	label.outline_modulate = Color(0.03, 0.05, 0.09, 1.0)
	label.position = Vector3(cx, gy + 6.75, z - 0.32)
	label.rotation.y = PI
	add_child(label)


func _build_rails() -> void:
	var rail_mat := _make_material(theme["accent2"], 0.3, false)
	rail_mat.metallic = 0.7
	rail_mat.emission_enabled = true
	rail_mat.emission = theme["accent2"]
	rail_mat.emission_energy_multiplier = 0.55
	var post_mat := _make_material(Color(0.12, 0.14, 0.18), 0.55, false)

	for r in course.rails:
		var p0: Vector3 = r["p0"]
		var p1: Vector3 = r["p1"]
		var mid := (p0 + p1) * 0.5
		var dir := (p1 - p0).normalized()
		var length := p0.distance_to(p1)

		var beam := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.26, 0.26, length)
		bm.material = rail_mat
		beam.mesh = bm
		beam.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), mid)
		add_child(beam)

		var posts := int(maxf(2.0, floor(length / 12.0)))
		for i in range(posts + 1):
			var t := float(i) / float(posts)
			var p := p0.lerp(p1, t)
			var ground := course.height(p.x, p.z)
			var h := maxf(0.2, p.y - ground)
			if h < 0.3:
				continue
			var post := MeshInstance3D.new()
			var pm := BoxMesh.new()
			pm.size = Vector3(0.14, h, 0.14)
			pm.material = post_mat
			post.mesh = pm
			post.position = Vector3(p.x, ground + h * 0.5, p.z)
			add_child(post)


func _build_snowfall() -> void:
	snowfall = CPUParticles3D.new()
	snowfall.amount = 160
	snowfall.lifetime = 7.0
	snowfall.preprocess = 4.0
	snowfall.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snowfall.emission_box_extents = Vector3(38.0, 9.0, 38.0)
	snowfall.direction = Vector3(0.4, -1.0, 0.15)
	snowfall.spread = 18.0
	snowfall.gravity = Vector3(0.4, -1.6, 0.2)
	snowfall.initial_velocity_min = 1.2
	snowfall.initial_velocity_max = 3.4
	snowfall.scale_amount_min = 0.5
	snowfall.scale_amount_max = 1.4
	snowfall.color = Color(0.95, 0.97, 1.0, 0.9)
	var flake := BoxMesh.new()
	flake.size = Vector3(0.14, 0.14, 0.14)
	var flake_mat := _make_material(Color.WHITE, 0.9, false)
	flake_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flake.material = flake_mat
	snowfall.mesh = flake
	snowfall.local_coords = false
	snowfall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(snowfall)


func _make_material(color: Color, roughness: float, use_vertex_color: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.vertex_color_use_as_albedo = use_vertex_color
	return mat
