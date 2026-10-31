class_name PlayerRider
extends Node3D
## Arcade snowboard controller: carving, airs, spins, flips, grabs, grinds,
## combos and a Tricky meter. No physics bodies: the mountain heightfield is
## the collision surface.

signal trick_landed(title: String, points: int, combo: int)
signal combo_banked(points: int, count: int)
signal crash_event(lost: int, reason: String)
signal jump_event
signal land_event(hard: bool)
signal rail_event
signal finished_event(time: float, score: int)

const GRAVITY := 23.5
const MAX_SPEED := 34.0
const BOOST_SPEED := 41.0

var course: Course
var stats := {"speed": 1.0, "spin": 1.0, "trick": 1.0, "boost": 1.0}
var rider_name := "AXEL"
var colors: Dictionary = {}

var state := "countdown"
var speed := 0.0
var heading := 0.0
var vy := 0.0
var race_time := 0.0
var score := 0
var best_combo := 0
var combo_count := 0
var combo_pending := 0
var combo_timer := 0.0
var boost := 55.0
var tricky := 0.0
var finished := false
var best_trick_title := ""
var best_trick_points := 0
var trick_count := 0

var air_yaw := 0.0
var air_pitch := 0.0
var air_time := 0.0
var grab_holds: Dictionary = {}
var current_grab := ""
var force_clean := false
var signature_used := false
var signature_name := ""
var last_ground_vy := 0.0
var crash_timer := 0.0
var crash_reason := ""
var grind_rail: Dictionary = {}
var grind_t := 0.0
var grind_points := 0.0
var grind_cooldown := 0.0
var spray: CPUParticles3D
var model: Node3D
var auto_pilot := false

var _cur_turn := 0.0
var _tuck := false
var _was_air := false


func setup(p_course: Course, p_stats: Dictionary, p_name: String, p_colors: Dictionary) -> void:
	course = p_course
	stats = p_stats.duplicate()
	rider_name = p_name
	colors = p_colors.duplicate()
	heading = 0.0
	position = Vector3(course.center_x(course.start_z), course.height(course.center_x(course.start_z), course.start_z), course.start_z)
	_build_visual()


func _build_visual() -> void:
	model = RiderModel.build(colors)
	add_child(model)

	spray = CPUParticles3D.new()
	spray.amount = 110
	spray.lifetime = 0.75
	spray.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	spray.emission_sphere_radius = 0.45
	spray.direction = Vector3(0.0, 0.8, -1.0)
	spray.spread = 38.0
	spray.gravity = Vector3(0.0, -9.0, 0.0)
	spray.initial_velocity_min = 1.5
	spray.initial_velocity_max = 5.0
	spray.scale_amount_min = 0.4
	spray.scale_amount_max = 1.2
	spray.position = Vector3(0.0, 0.12, -0.55)
	spray.emitting = false
	spray.local_coords = false
	var flake := BoxMesh.new()
	flake.size = Vector3(0.11, 0.11, 0.11)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.94, 0.97, 1.0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flake.material = mat
	spray.mesh = flake
	spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(spray)


func begin() -> void:
	if state == "countdown":
		state = "riding"
		speed = 6.0
		last_ground_vy = 0.0


func forward() -> Vector3:
	return Vector3(sin(heading), 0.0, cos(heading))


func display_score() -> int:
	return score + combo_pending


func bank_combo() -> void:
	if combo_count > 0 and combo_pending > 0:
		score += combo_pending
		best_combo = maxi(best_combo, combo_pending)
		combo_banked.emit(combo_pending, combo_count)
	combo_pending = 0
	combo_count = 0
	combo_timer = 0.0


func _physics_process(delta: float) -> void:
	if course == null:
		return

	_cur_turn = 0.0
	if state == "countdown":
		_animate(delta)
		return
	if state == "finished":
		_animate(delta)
		return

	race_time += delta
	grind_cooldown = maxf(0.0, grind_cooldown - delta)

	var inp := _read_input()
	_cur_turn = float(inp["turn"])
	if bool(inp["respawn"]):
		respawn()
		return

	match state:
		"riding":
			_ground_step(inp, delta)
		"air":
			_air_step(inp, delta)
		"grind":
			_grind_step(inp, delta)
		"crashed":
			_crash_step(delta)

	_update_combo(delta)
	_animate(delta)
	_update_spray()

	if position.z >= course.length - 2.0 and not finished:
		_finish()


func _read_input() -> Dictionary:
	if auto_pilot:
		return _auto_input()
	var turn := Input.get_axis("steer_left", "steer_right")
	if absf(turn) < 0.12:
		turn = 0.0
	return {
		"turn": turn,
		"tuck": Input.is_action_pressed("tuck"),
		"brake": Input.is_action_pressed("brake"),
		"jump_pressed": Input.is_action_just_pressed("jump"),
		"boost": Input.is_action_pressed("boost"),
		"grab1": Input.is_action_pressed("grab1"),
		"grab2": Input.is_action_pressed("grab2"),
		"grab3": Input.is_action_pressed("grab3"),
		"signature": Input.is_action_just_pressed("signature"),
		"respawn": Input.is_action_just_pressed("respawn"),
	}


func _auto_input() -> Dictionary:
	var air := state == "air"
	var target_x := course.center_x(minf(position.z + 34.0, course.length))
	for k in course.kickers:
		var kz := float(k.get("z", 0.0))
		if kz > position.z + 6.0 and kz < position.z + 80.0 and absf(float(k.get("x_off", 0.0))) < 5.0:
			target_x = course.center_x(kz) + float(k.get("x_off", 0.0))
			break
	var desired := atan2(target_x - position.x, 26.0)
	var turn := clampf(angle_difference(heading, desired) * 1.7, -1.0, 1.0)
	return {
		"turn": 0.0 if air else turn,
		"tuck": not air,
		"brake": false,
		"jump_pressed": false,
		"boost": false,
		"grab1": air and air_time > 0.22 and air_time < 0.62,
		"grab2": air and air_time >= 0.62,
		"grab3": false,
		"signature": air and tricky >= 100.0,
		"respawn": false,
	}


func _ground_step(inp: Dictionary, delta: float) -> void:
	var turn := float(inp["turn"])
	var tuck: bool = inp["tuck"]
	var brake: bool = inp["brake"]
	var boosting: bool = inp["boost"] and boost > 1.0
	_tuck = tuck

	var n := course.normal_at(position.x, position.z)
	var sin_theta := sqrt(maxf(0.0, 1.0 - n.y * n.y))
	var down := Vector3(n.x, 0.0, n.z)
	if down.length_squared() > 0.000001:
		down = down.normalized()
	var fwd := forward()
	var align := fwd.dot(down)

	speed += GRAVITY * sin_theta * align * 1.12 * delta
	speed += (3.4 if tuck else 1.35) * delta
	speed -= (13.5 if brake else 1.05) * delta
	var drag := 0.0018 if tuck else 0.0031
	speed -= drag * speed * speed * delta
	speed -= absf(turn) * speed * (0.18 + 0.32 * clampf(speed / MAX_SPEED, 0.0, 1.0)) * delta
	if brake:
		speed -= 6.0 * delta
	if boosting:
		speed += 9.5 * delta
		boost = maxf(0.0, boost - 25.0 * delta)

	var turn_rate := 2.4 * (1.0 - 0.52 * clampf(speed / MAX_SPEED, 0.0, 1.0))
	if brake:
		turn_rate *= 1.3
	heading += turn * turn_rate * delta
	var top_speed := (BOOST_SPEED if boosting else MAX_SPEED) * float(stats["speed"])
	speed = clampf(speed, 0.0, top_speed)

	var old_y := position.y
	position.x += fwd.x * speed * delta
	position.z += fwd.z * speed * delta
	var half := course.width * 0.5 - 8.0
	position.x = clampf(position.x, -half, half)

	var ground := course.height(position.x, position.z)
	if old_y - ground > 0.55:
		# The snow fell away: launched off a lip or roller.
		_enter_air(clampf(last_ground_vy, 0.0, 17.0))
		position.y = old_y
	else:
		position.y = ground
		var gvy := (ground - old_y) / maxf(delta, 0.0001)
		last_ground_vy = lerpf(last_ground_vy, clampf(gvy, -6.0, 26.0), 0.6)
		if float(inp["jump_pressed"]) > 0.0:
			jump_event.emit()
			_enter_air(6.4 + speed * 0.1)


func _enter_air(launch_vy: float) -> void:
	state = "air"
	vy = launch_vy
	air_time = 0.0
	air_yaw = 0.0
	air_pitch = 0.0
	grab_holds.clear()
	current_grab = ""
	force_clean = false
	signature_used = false
	signature_name = ""
	_was_air = true
	if spray:
		spray.restart()


func _air_step(inp: Dictionary, delta: float) -> void:
	air_time += delta
	_tuck = false
	var turn := float(inp["turn"])
	vy -= GRAVITY * delta
	var fwd := forward()

	# Spins and flips.
	air_yaw += turn * 430.0 * float(stats["spin"]) * delta
	var flip_dir := 0.0
	if inp["tuck"]:
		flip_dir += 1.0
	if inp["brake"]:
		flip_dir -= 1.0
	air_pitch += flip_dir * 340.0 * delta
	heading += turn * 0.4 * delta

	speed -= (0.8 + 0.01 * speed * speed) * delta
	if inp["boost"] and boost > 1.0:
		boost = maxf(0.0, boost - 16.0 * delta)
		speed = minf(speed + 1.8 * delta, BOOST_SPEED)

	_update_grabs(inp, delta)

	if inp["signature"] and tricky >= 100.0 and not signature_used:
		_do_signature()

	position.x += fwd.x * speed * delta
	position.z += fwd.z * speed * delta
	position.y += vy * delta
	var half := course.width * 0.5 - 6.0
	position.x = clampf(position.x, -half, half)

	if _try_grind():
		return

	var ground := course.height(position.x, position.z)
	if position.y <= ground:
		position.y = ground
		_land()


func _update_grabs(inp: Dictionary, delta: float) -> void:
	var g := ""
	if inp["grab1"]:
		g = "INDY"
	elif inp["grab2"]:
		g = "MELON"
	elif inp["grab3"]:
		g = "TAIL"
	if g != "":
		grab_holds[g] = float(grab_holds.get(g, 0.0)) + delta
		current_grab = g
	else:
		current_grab = ""


func _do_signature() -> void:
	tricky = 0.0
	signature_used = true
	force_clean = true
	var names := ["TORNADO", "MOONSPIN", "PAPER PLANE", "COSMIC SLIDE", "DOUBLE RAINBOW"]
	signature_name = String(names[randi() % names.size()]) + " 1080"
	air_yaw += 1080.0
	air_pitch += 360.0
	air_time = maxf(air_time, 0.9)
	boost = minf(100.0, boost + 18.0)


func _land() -> void:
	var yaw_err := _angle_error(air_yaw, 360.0)
	var pitch_err := _angle_error(air_pitch, 360.0)
	var clean := force_clean or (yaw_err < 65.0 and pitch_err < 60.0)

	if not clean:
		_start_crash("SLOPPY LANDING")
		return

	var parts: Array[String] = []
	var base := 0
	var grab_count := 0
	var spin_abs := absf(air_yaw)
	if not force_clean:
		if spin_abs >= 170.0:
			var deg := int(round(spin_abs / 180.0)) * 180
			parts.append(str(deg))
			base += int(spin_abs / 180.0) * 115
		var flip_abs := absf(air_pitch)
		if flip_abs >= 320.0:
			var flips := maxi(1, int(round(flip_abs / 360.0)))
			var dir := "BACK" if air_pitch < 0.0 else "FRONT"
			parts.append(dir + "FLIP" + ("" if flips == 1 else " x" + str(flips)))
			base += flips * 540
		for key in grab_holds.keys():
			var hold := float(grab_holds[key])
			if hold >= 0.16:
				parts.append(String(key))
				base += 110 + int(minf(hold, 1.5) * 170.0)
				grab_count += 1
	else:
		parts.append(signature_name)
		base = 6000
		grab_count = 1

	if grab_count > 1:
		base = int(float(base) * 1.3)
	if spin_abs >= 330.0 and grab_count > 0 and not force_clean:
		base = int(float(base) * 1.35)

	var perfect := (not force_clean) and yaw_err < 14.0 and pitch_err < 14.0 and base > 0
	if perfect:
		base = int(float(base) * 1.15)
		parts.push_front("PERFECT")

	var tweaked := false
	if not force_clean and grab_count > 0 and (spin_abs >= 330.0 or absf(air_pitch) >= 320.0):
		for key in grab_holds.keys():
			if float(grab_holds[key]) >= 0.8:
				tweaked = true
				break
	if tweaked:
		base = int(float(base) * 1.18)
		if perfect:
			parts.insert(1, "TWEAKED")
		else:
			parts.push_front("TWEAKED")

	var title := " ".join(parts)
	if title == "":
		title = "AIR"
	if base <= 0:
		base = 25

	var hard_land := air_time > 0.55
	_add_trick(title, base)
	state = "riding"
	vy = 0.0
	speed = maxf(speed, 8.0)
	last_ground_vy = 0.0
	air_yaw = 0.0
	air_pitch = 0.0
	air_time = 0.0
	grab_holds.clear()
	current_grab = ""
	force_clean = false
	signature_used = false
	_was_air = false
	land_event.emit(hard_land)


func _add_trick(title: String, base: int) -> void:
	combo_count += 1
	trick_count += 1
	var mult := minf(1.0 + 0.35 * float(combo_count - 1), 5.0)
	var gained := int(float(base) * mult * float(stats["trick"]))
	if gained > best_trick_points:
		best_trick_points = gained
		best_trick_title = title
	combo_pending += gained
	combo_timer = 7.0
	boost = minf(100.0, boost + float(gained) * 0.075 * float(stats["boost"]))
	tricky = minf(100.0, tricky + float(gained) * 0.06)
	trick_landed.emit(title, gained, combo_count)


func _angle_error(angle: float, step: float) -> float:
	var r := fposmod(angle, step)
	return minf(r, step - r)


func _start_crash(reason: String) -> void:
	var lost := combo_pending
	combo_pending = 0
	combo_count = 0
	combo_timer = 0.0
	crash_reason = reason
	crash_timer = 1.35
	state = "crashed"
	vy = 0.0
	speed *= 0.25
	air_yaw = 0.0
	air_pitch = 0.0
	grab_holds.clear()
	crash_event.emit(lost, reason)


func _crash_step(delta: float) -> void:
	crash_timer -= delta
	speed = move_toward(speed, 0.0, 14.0 * delta)
	var fwd := forward()
	position.x += fwd.x * speed * delta
	position.z += fwd.z * speed * delta
	position.y = course.height(position.x, position.z)
	if crash_timer <= 0.0:
		state = "riding"
		speed = maxf(speed, 7.0)
		last_ground_vy = 0.0
		model.rotation = Vector3.ZERO


func _try_grind() -> bool:
	if state != "air" or grind_cooldown > 0.0 or vy > 4.0:
		return false
	for r in course.rails:
		var p0: Vector3 = r["p0"]
		var p1: Vector3 = r["p1"]
		var ab := p1 - p0
		var len_sq := ab.length_squared()
		if len_sq < 0.01:
			continue
		var t := clampf((position - p0).dot(ab) / len_sq, 0.0, 1.0)
		var closest := p0 + ab * t
		var horiz := Vector2(position.x - closest.x, position.z - closest.z).length()
		var dy := position.y - closest.y
		if horiz < 1.9 and dy > -1.0 and dy < 2.8:
			_enter_grind(r, t)
			return true
	return false


func _enter_grind(r: Dictionary, t: float) -> void:
	state = "grind"
	grind_rail = r
	grind_t = t
	grind_points = 0.0
	vy = 0.0
	speed = maxf(speed, 11.0)
	air_yaw = 0.0
	air_pitch = 0.0
	grab_holds.clear()
	force_clean = false
	signature_used = false
	var p0: Vector3 = r["p0"]
	var p1: Vector3 = r["p1"]
	var dir := (p1 - p0).normalized()
	heading = atan2(dir.x, dir.z)
	position = p0.lerp(p1, t) + Vector3(0.0, 0.12, 0.0)
	rail_event.emit()


func _grind_step(inp: Dictionary, delta: float) -> void:
	var p0: Vector3 = grind_rail["p0"]
	var p1: Vector3 = grind_rail["p1"]
	var total := float(grind_rail["len"])
	var dir := (p1 - p0).normalized()
	speed = maxf(10.0, speed - 2.2 * delta)
	grind_t += (speed * delta) / total
	grind_points += speed * delta * 4.0
	position = p0.lerp(p1, clampf(grind_t, 0.0, 1.0)) + Vector3(0.0, 0.12, 0.0)
	heading = atan2(dir.x, dir.z)

	if float(inp["jump_pressed"]) > 0.0:
		_exit_grind(true)
	elif grind_t >= 1.0:
		_exit_grind(false)


func _exit_grind(with_jump: bool) -> void:
	var r: Dictionary = grind_rail
	var p1: Vector3 = r["p1"]
	if grind_points > 40.0:
		_add_trick("RAIL GRIND", int(grind_points))
	grind_rail = {}
	grind_cooldown = 0.45
	state = "air"
	vy = 7.5 if with_jump else 1.0
	air_time = 0.0
	air_yaw = 0.0
	air_pitch = 0.0
	grab_holds.clear()
	force_clean = false
	signature_used = false
	if with_jump:
		jump_event.emit()
	else:
		position = p1 + Vector3(0.0, 0.4, 0.0)


func _update_combo(delta: float) -> void:
	if combo_count > 0 and state != "air":
		combo_timer -= delta
		if combo_timer <= 0.0:
			bank_combo()


func force_finish() -> void:
	if not finished:
		_finish()


func _finish() -> void:
	if finished:
		return
	if state == "air":
		position.y = course.height(position.x, position.z)
	if state == "grind":
		grind_rail = {}
	bank_combo()
	finished = true
	state = "finished"
	speed = 0.0
	finished_event.emit(race_time, score)


func respawn() -> void:
	if finished:
		return
	var z := clampf(position.z + 2.0, course.start_z, course.length - 5.0)
	var x := course.center_x(z)
	position = Vector3(x, course.height(x, z) + 0.1, z)
	heading = 0.0
	state = "riding"
	speed = 9.0
	vy = 0.0
	air_yaw = 0.0
	air_pitch = 0.0
	crash_timer = 0.0
	last_ground_vy = 0.0
	model.rotation = Vector3.ZERO


func _animate(delta: float) -> void:
	if model == null:
		return
	rotation.y = heading
	var lean_target := -_cur_turn * 0.3
	if state == "riding":
		lean_target = -_cur_turn * 0.4
	elif state == "air":
		lean_target = 0.0
	model.rotation.z = lerp_angle(model.rotation.z, lean_target, clampf(delta * 9.0, 0.0, 1.0))

	match state:
		"air":
			model.rotation.y = deg_to_rad(air_yaw)
			model.rotation.x = deg_to_rad(-air_pitch)
		"grind":
			model.rotation.y = 0.0
			model.rotation.x = 0.0
		"crashed":
			model.rotation.y += delta * 9.0
			model.rotation.x += delta * 6.0
		_:
			model.rotation.y = lerp_angle(model.rotation.y, 0.0, clampf(delta * 12.0, 0.0, 1.0))
			model.rotation.x = lerp_angle(model.rotation.x, 0.0, clampf(delta * 12.0, 0.0, 1.0))

	if state == "riding" and _tuck:
		model.position.y = lerpf(model.position.y, -0.04, clampf(delta * 8.0, 0.0, 1.0))
	else:
		model.position.y = lerpf(model.position.y, 0.0, clampf(delta * 8.0, 0.0, 1.0))


func _update_spray() -> void:
	if spray == null:
		return
	var active := false
	if state == "riding":
		active = speed > 9.0
		spray.emitting = active
		spray.direction = Vector3(0.0, 0.7, -1.0).rotated(Vector3.UP, heading)
	elif state == "grind":
		spray.emitting = true
	else:
		spray.emitting = false
