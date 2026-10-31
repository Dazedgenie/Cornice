class_name MenuVista
extends Node3D
## Slow, moody title-screen diorama: a rider on a snow mound with a low-poly
## mountain range behind, drifting camera and falling snow.

var env: Environment
var sky_mat: ProceduralSkyMaterial
var sun: DirectionalLight3D
var fill: DirectionalLight3D
var cam: Camera3D
var rider_root: Node3D
var rider_model: Node3D
var ground_mat: StandardMaterial3D
var far_mat: StandardMaterial3D
var rock_mat: StandardMaterial3D
var snow_mat: StandardMaterial3D
var tree_mat: StandardMaterial3D
var theme_index := 0
var time := 0.0


func build(course_index: int, rider_index: int) -> void:
	_build_environment()
	_build_scenery()
	_build_camera()
	apply_theme(course_index)
	show_rider(rider_index)


func _build_environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_density = 0.0004
	env.fog_sky_affect = 0.4
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.light_energy = 1.3
	sun.rotation_degrees = Vector3(-34.0, 28.0, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)

	fill = DirectionalLight3D.new()
	fill.light_color = Color(0.5, 0.66, 1.0)
	fill.light_energy = 0.45
	fill.rotation_degrees = Vector3(-20.0, 210.0, 0.0)
	add_child(fill)


func _build_scenery() -> void:
	ground_mat = _mat(Color(1.0, 1.0, 1.0), 0.98)
	ground_mat.vertex_color_use_as_albedo = true
	rock_mat = _mat(Color(0.3, 0.33, 0.42), 0.95)
	snow_mat = _mat(Color(0.95, 0.97, 1.0), 0.85)
	tree_mat = _mat(Color(0.08, 0.2, 0.18), 0.9)

	_build_snowfield()

	far_mat = _mat(Color(0.76, 0.84, 0.96), 1.0)
	var far_ground := MeshInstance3D.new()
	var far_plane := PlaneMesh.new()
	far_plane.size = Vector2(4000.0, 4000.0)
	far_plane.material = far_mat
	far_ground.mesh = far_plane
	far_ground.position = Vector3(0.0, -1.2, 0.0)
	far_ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(far_ground)

	var rng := RandomNumberGenerator.new()
	rng.seed = 90210

	var rock := CylinderMesh.new()
	rock.top_radius = 0.0
	rock.bottom_radius = 1.0
	rock.height = 1.0
	rock.radial_segments = 7
	rock.rings = 1
	rock.material = rock_mat

	var cap := CylinderMesh.new()
	cap.top_radius = 0.0
	cap.bottom_radius = 1.0
	cap.height = 1.0
	cap.radial_segments = 7
	cap.rings = 1
	cap.material = snow_mat

	for i in 19:
		var angle := lerpf(-1.15, 1.15, float(i) / 18.0) + rng.randf_range(-0.04, 0.04)
		var dist := rng.randf_range(900.0, 1450.0)
		var x := sin(angle) * dist
		var z := -cos(angle) * dist
		var h := rng.randf_range(200.0, 360.0)
		var r := rng.randf_range(160.0, 320.0)
		var base_y := -14.0
		var yaw := rng.randf_range(0.0, TAU)

		var peak := MeshInstance3D.new()
		peak.mesh = rock
		peak.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(r, h, r)), Vector3(x, base_y + h * 0.5, z))
		peak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(peak)

		var cap_h := h * 0.33
		var cap_r := r * 0.36
		var snowcap := MeshInstance3D.new()
		snowcap.mesh = cap
		snowcap.transform = Transform3D(Basis(Vector3.UP, yaw + 0.3).scaled(Vector3(cap_r, cap_h, cap_r)), Vector3(x, base_y + h - cap_h * 0.5, z))
		snowcap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(snowcap)

	# Foothills.
	var hill := SphereMesh.new()
	hill.radius = 1.0
	hill.height = 1.0
	hill.radial_segments = 7
	hill.rings = 4
	hill.material = snow_mat
	for i in 14:
		var a := rng.randf_range(-1.2, 1.2)
		var d := rng.randf_range(45.0, 120.0)
		var mi := MeshInstance3D.new()
		mi.mesh = hill
		mi.transform = Transform3D(Basis().scaled(Vector3(rng.randf_range(14.0, 34.0), rng.randf_range(3.0, 9.0), rng.randf_range(14.0, 34.0))), Vector3(sin(a) * d, -2.0, -cos(a) * d))
		add_child(mi)

	# A few pines for scale.
	var pine := CylinderMesh.new()
	pine.top_radius = 0.0
	pine.bottom_radius = 1.0
	pine.height = 1.0
	pine.radial_segments = 5
	pine.rings = 1
	pine.material = tree_mat
	for i in 34:
		var a := rng.randf_range(-1.25, 1.25)
		var d := rng.randf_range(42.0, 110.0)
		var s := rng.randf_range(3.0, 7.5)
		var mi := MeshInstance3D.new()
		mi.mesh = pine
		mi.transform = Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(s * 0.45, s, s * 0.45)), Vector3(sin(a) * d, s * 0.5 - 0.4, -cos(a) * d))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)

	# Hero peak framed behind the rider.
	var hero_x := 60.0
	var hero_z := -1100.0
	var hero_h := 340.0
	var hero_r := 300.0
	var hero_yaw := 0.55
	var hero := MeshInstance3D.new()
	hero.mesh = rock
	hero.transform = Transform3D(Basis(Vector3.UP, hero_yaw).scaled(Vector3(hero_r, hero_h, hero_r)), Vector3(hero_x, -14.0 + hero_h * 0.5, hero_z))
	hero.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(hero)
	var hero_cap_h := hero_h * 0.33
	var hero_cap_r := hero_r * 0.36
	var hero_cap := MeshInstance3D.new()
	hero_cap.mesh = cap
	hero_cap.transform = Transform3D(Basis(Vector3.UP, hero_yaw + 0.3).scaled(Vector3(hero_cap_r, hero_cap_h, hero_cap_r)), Vector3(hero_x, -14.0 + hero_h - hero_cap_h * 0.5, hero_z))
	hero_cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(hero_cap)

	# The rider's little snow mound.
	var mound := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 1.0
	sphere.radial_segments = 9
	sphere.rings = 5
	sphere.material = snow_mat
	mound.mesh = sphere
	mound.transform = Transform3D(Basis().scaled(Vector3(2.4, 1.3, 2.0)), Vector3(0.0, -0.15, 4.2))
	add_child(mound)

	rider_root = Node3D.new()
	rider_root.position = Vector3(0.0, 1.15, 4.2)
	add_child(rider_root)

	# Light drifting snow.
	var snow := CPUParticles3D.new()
	snow.amount = 90
	snow.lifetime = 8.0
	snow.preprocess = 5.0
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow.emission_box_extents = Vector3(22.0, 8.0, 18.0)
	snow.direction = Vector3(0.3, -1.0, 0.1)
	snow.spread = 22.0
	snow.gravity = Vector3(0.2, -0.9, 0.0)
	snow.initial_velocity_min = 0.4
	snow.initial_velocity_max = 1.4
	snow.scale_amount_min = 0.5
	snow.scale_amount_max = 1.3
	var flake := BoxMesh.new()
	flake.size = Vector3(0.07, 0.07, 0.07)
	var flake_mat := _mat(Color(1.0, 1.0, 1.0), 0.8)
	flake_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flake.material = flake_mat
	snow.mesh = flake
	snow.position = Vector3(0.0, 13.0, 4.0)
	snow.local_coords = false
	snow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(snow)


func _build_camera() -> void:
	cam = Camera3D.new()
	cam.fov = 54.0
	cam.near = 0.1
	cam.far = 1200.0
	cam.current = true
	cam.position = Vector3(0.0, 3.3, 8.6)
	add_child(cam)
	cam.look_at(Vector3(0.0, 1.9, 0.0), Vector3.UP)


func apply_theme(index: int) -> void:
	theme_index = index
	var theme := Course.get_theme(index)
	var horizon: Color = (theme["sky_horizon"] as Color).lerp(theme["sky_top"], 0.38)
	sky_mat.sky_top_color = theme["sky_top"]
	sky_mat.sky_horizon_color = horizon
	sky_mat.ground_bottom_color = theme["ground"]
	sky_mat.ground_horizon_color = horizon
	sky_mat.sun_angle_max = 20.0
	sky_mat.sun_curve = 0.1
	sun.light_color = theme["sun"]
	sun.light_energy = float(theme["sun_energy"]) * 0.9
	sun.rotation_degrees = theme["sun_rot"]
	env.ambient_light_energy = float(theme["ambient"])
	env.fog_light_color = (theme["fog"] as Color).lerp(theme["sky_top"], 0.2)
	fill.light_energy = 0.35 if theme["night"] else 0.3
	rock_mat.albedo_color = (theme["rock"] as Color).darkened(0.34)
	snow_mat.albedo_color = (theme["snow"] as Color).lightened(0.22)
	far_mat.albedo_color = (theme["snow_deep"] as Color).lerp(theme["fog"], 0.45)
	tree_mat.albedo_color = theme["tree"]


func show_rider(index: int) -> void:
	if rider_model != null:
		rider_model.queue_free()
		rider_model = null
	var riders := RiderDefs.all()
	var colors: Dictionary = riders[index % riders.size()].get("colors", {})
	rider_model = RiderModel.build(colors)
	rider_root.add_child(rider_model)


func _process(delta: float) -> void:
	time += delta
	if cam != null:
		cam.position = Vector3(sin(time * 0.17) * 0.5, 3.3 + sin(time * 0.31) * 0.10, 8.6)
		cam.look_at(Vector3(0.0, 1.9, 0.0), Vector3.UP)
	if rider_root != null:
		rider_root.rotation.y = time * 0.28


func _build_snowfield() -> void:
	var cells := 54
	var size := 560.0
	var step := size / float(cells)
	var start := -size * 0.5
	var noise := FastNoiseLite.new()
	noise.seed = 21
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.02
	noise.fractal_octaves = 3

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in cells:
		for ix in cells:
			var x0 := start + float(ix) * step
			var z0 := start + float(iz) * step
			var x1 := x0 + step
			var z1 := z0 + step
			var p00 := _field_point(x0, z0, noise)
			var p10 := _field_point(x1, z0, noise)
			var p01 := _field_point(x0, z1, noise)
			var p11 := _field_point(x1, z1, noise)
			_field_tri(st, p00, p10, p11)
			_field_tri(st, p00, p11, p01)
	var mesh := st.commit()
	if mesh != null:
		mesh.surface_set_material(0, ground_mat)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


func _field_point(x: float, z: float, noise: FastNoiseLite) -> Vector3:
	var rider_dist := Vector2(x, z - 4.2).length()
	var damp := smoothstep(6.0, 22.0, rider_dist)
	var y := -0.4 + noise.get_noise_2d(x, z) * 0.85 * damp
	return Vector3(x, y, z)


func _field_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.y < 0.0:
		n = -n
	var center := (a + b + c) / 3.0
	var jitter := absf(sin(center.x * 12.9898 + center.z * 78.233) * 43758.5453)
	jitter -= floor(jitter)
	var col := Color(0.84, 0.90, 0.99).lerp(Color(0.62, 0.73, 0.91), clampf(0.35 - center.y * 0.35, 0.0, 1.0))
	col = col.darkened(jitter * 0.06)
	st.set_color(col)
	st.set_normal(n)
	st.add_vertex(a)
	st.set_color(col)
	st.set_normal(n)
	st.add_vertex(b)
	st.set_color(col)
	st.set_normal(n)
	st.add_vertex(c)


func _mat(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat
