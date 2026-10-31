class_name RivalRider
extends Node3D
## Simple AI boarder. Follows the course, leans on kickers and hams it up with
## spins, with light rubber-banding so the pack stays close.

var course: Course
var rider_name := "RIVAL"
var base_speed := 20.0
var speed := 0.0
var heading := 0.0
var lateral := 0.0
var phase := 0.0
var state := "riding"
var vy := 0.0
var last_ground_vy := 0.0
var spin := 0.0
var spin_speed := 0.0
var active := false
var finished := false
var finish_time := 0.0
var elapsed := 0.0
var player: PlayerRider
var model: Node3D
var colors: Dictionary
var lean := 0.0


func setup(p_course: Course, cfg: Dictionary) -> void:
	course = p_course
	rider_name = String(cfg.get("name", "RIVAL"))
	base_speed = float(cfg.get("speed", 20.0))
	lateral = float(cfg.get("lateral", 0.0))
	phase = float(cfg.get("phase", 0.0))
	colors = (cfg.get("colors", {}) as Dictionary).duplicate()
	var start_z := float(cfg.get("start_z", course.start_z))
	var x := course.center_x(start_z) + lateral
	position = Vector3(x, course.height(x, start_z), start_z)
	model = RiderModel.build(colors)
	add_child(model)


func _physics_process(delta: float) -> void:
	if not active or finished or course == null:
		return
	elapsed += delta

	var gap := 0.0
	if player != null:
		gap = player.position.z - position.z
	var target_speed := base_speed + clampf(gap * 0.03, -2.8, 3.2)

	if state == "riding":
		speed = lerpf(speed, target_speed, clampf(delta * 1.7, 0.0, 1.0))
		var old_y := position.y
		var desired_x := course.center_x(position.z) + lateral + sin(position.z * 0.02 + phase) * 3.4
		position.x = move_toward(position.x, desired_x, 8.0 * delta)
		position.z += speed * delta
		var ground := course.height(position.x, position.z)
		if old_y - ground > 0.62:
			state = "air"
			vy = clampf(last_ground_vy, 3.0, 15.0)
			spin = 0.0
			spin_speed = 360.0 if randf() < 0.55 else 720.0
		else:
			position.y = ground
			last_ground_vy = lerpf(last_ground_vy, (ground - old_y) / maxf(delta, 0.0001), 0.5)
	else:
		speed = lerpf(speed, target_speed, clampf(delta * 0.8, 0.0, 1.0))
		vy -= 23.0 * delta
		position.z += speed * cos(heading) * delta
		position.x += speed * sin(heading) * 0.4 * delta
		position.y += vy * delta
		spin += spin_speed * delta
		if spin >= 360.0:
			spin = 0.0
			spin_speed = 0.0
		var ground := course.height(position.x, position.z)
		if position.y <= ground:
			position.y = ground
			state = "riding"
			spin = 0.0
			spin_speed = 0.0

	var look_z := position.z + 3.0
	var desired_x_next := course.center_x(look_z) + lateral
	var target_heading := atan2(desired_x_next - position.x, 3.0)
	heading = lerp_angle(heading, target_heading, clampf(delta * 4.0, 0.0, 1.0))
	rotation.y = heading
	model.rotation.y = deg_to_rad(spin)
	lean = lerp_angle(lean, clampf((desired_x_next - position.x) * 0.06, -0.35, 0.35), clampf(delta * 6.0, 0.0, 1.0))
	model.rotation.z = -lean

	if position.z >= course.length - 2.0:
		finished = true
		finish_time = elapsed
