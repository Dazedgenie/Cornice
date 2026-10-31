class_name ChaseCamera
extends Camera3D
## Speed-reactive chase camera with terrain avoidance and landing shake.

var player: PlayerRider
var course: Course
var shake := 0.0
var _initialised := false


func setup(p_player: PlayerRider, p_course: Course) -> void:
	player = p_player
	course = p_course
	near = 0.15
	far = 1300.0
	fov = 74.0
	current = true
	global_position = player.global_position - player.forward() * 6.0 + Vector3(0.0, 3.0, 0.0)


func add_shake(amount: float) -> void:
	shake = minf(shake + amount, 1.2)


func _process(delta: float) -> void:
	if player == null or course == null:
		return
	var fwd := player.forward()
	var spd := clampf(player.speed, 0.0, 45.0)
	var back := 5.2 + spd * 0.07
	var up := 2.5 + spd * 0.02
	var target := player.global_position + Vector3(0.0, 1.05, 0.0) + fwd * 2.2
	var desired := player.global_position - fwd * back + Vector3(0.0, up, 0.0)

	var ground := course.height(desired.x, desired.z) + 1.3
	desired.y = maxf(desired.y, ground)

	var pos_weight := 1.0 - exp(-7.5 * delta)
	global_position = global_position.lerp(desired, pos_weight)

	var look_dir := (target + fwd * 6.5) - global_position
	if look_dir.length() > 0.01:
		var desired_basis := Basis.looking_at(look_dir.normalized(), Vector3.UP)
		var current_q := global_transform.basis.get_rotation_quaternion()
		var desired_q := desired_basis.get_rotation_quaternion()
		global_transform.basis = Basis(current_q.slerp(desired_q, clampf(delta * 7.0, 0.0, 1.0)))

	if shake > 0.0:
		var s := shake * shake
		global_position += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * s * 0.35
		shake = maxf(0.0, shake - delta * 2.4)

	var target_fov := 69.0 + spd * 0.5 + (7.0 if player.boost > 0.0 and Input.is_action_pressed("boost") else 0.0)
	fov = lerpf(fov, clampf(target_fov, 67.0, 100.0), clampf(delta * 3.0, 0.0, 1.0))
