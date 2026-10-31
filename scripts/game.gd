extends Node3D
## Race orchestrator: menus, race setup, countdown, standings, results and save data.

const SAVE_PATH := "user://summit_trick.cfg"
const TRICK_TIME := 120.0

var trick_medals: Array = [
	{"name": "BRONZE", "score": 6000, "color": Color(0.86, 0.55, 0.32)},
	{"name": "SILVER", "score": 12000, "color": Color(0.82, 0.89, 0.97)},
	{"name": "GOLD", "score": 20000, "color": Color(1.0, 0.82, 0.24)},
	{"name": "PLATINUM", "score": 32000, "color": Color(0.45, 0.95, 1.0)},
]

var course_defs: Array = []
var best_scores: Dictionary = {}
var trick_best_scores: Dictionary = {}
var selected_course := 0
var selected_rider := 0
var mode := 0
var music_volume := AudioDirector.DEFAULT_MUSIC_VOLUME
var trick_time_left := 0.0
var trick_finished := false
var _time_warned := false

var menu: MenuScreen
var vista: MenuVista
var race_root: Node3D
var world: World
var player: PlayerRider
var rivals: Array[RivalRider] = []
var hud: RaceHUD
var chase: ChaseCamera
var course: Course
var theme: Dictionary
var audio: AudioDirector

var race_state := "menu"
var countdown_time := 0.0
var _last_count := 4
var _resume_state := "racing"
var test_mode := false
var test_elapsed := 0.0
var _last_report := 0
var _save_timer: Timer
var _settings_dirty := false
var shot_mode := false
var _shot_time := 0.0
var _shot_stage := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_title("SUMMIT TRICK")
	_setup_input()
	course_defs = Course.course_defs()
	audio = AudioDirector.new()
	audio.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(audio)
	_load_progress()
	audio.set_music_volume(music_volume)
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.35
	_save_timer.timeout.connect(_save_progress)
	add_child(_save_timer)
	tree_exiting.connect(_flush_settings)
	if _has_arg("--mode=race"):
		mode = 0
	elif _has_arg("--trick") or _has_arg("--mode=trick"):
		mode = 1

	if _has_arg("--auto-race"):
		test_mode = true
		for arg in OS.get_cmdline_args():
			if arg.begins_with("--course="):
				selected_course = clampi(int(arg.get_slice("=", 1)), 0, course_defs.size() - 1)
		selected_rider = 0
		print("AUTOTEST starting course=%d rider=%d mode=%s" % [selected_course, selected_rider, _mode_name()])
		call_deferred("_start_race", selected_course, selected_rider, mode)
	else:
		shot_mode = _has_arg("--shot")
		call_deferred("_open_menu")


func _mode_name() -> String:
	return "TRICK ATTACK" if mode == 1 else "RACE"


func _has_arg(arg: String) -> bool:
	return arg in OS.get_cmdline_args() or arg in OS.get_cmdline_user_args()


func _setup_input() -> void:
	var keys := {
		"steer_left": [KEY_A, KEY_LEFT],
		"steer_right": [KEY_D, KEY_RIGHT],
		"tuck": [KEY_W, KEY_UP],
		"brake": [KEY_S, KEY_DOWN],
		"jump": [KEY_SPACE],
		"boost": [KEY_SHIFT],
		"grab1": [KEY_J],
		"grab2": [KEY_K],
		"grab3": [KEY_L],
		"signature": [KEY_E],
		"respawn": [KEY_R],
		"pause": [KEY_ESCAPE],
	}
	for action in keys.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)

	_add_joy_axis("steer_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis("steer_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_axis("tuck", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_add_joy_axis("boost", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add_joy_button("jump", JOY_BUTTON_A)
	_add_joy_button("grab1", JOY_BUTTON_X)
	_add_joy_button("grab2", JOY_BUTTON_Y)
	_add_joy_button("grab3", JOY_BUTTON_RIGHT_SHOULDER)
	_add_joy_button("signature", JOY_BUTTON_LEFT_SHOULDER)
	_add_joy_button("respawn", JOY_BUTTON_BACK)
	_add_joy_button("pause", JOY_BUTTON_START)


func _add_joy_axis(action: String, axis: int, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)


func _add_joy_button(action: String, button: int) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _open_menu() -> void:
	if race_state == "menu" and menu != null:
		return
	race_state = "menu"
	get_tree().paused = false
	audio.set_paused(false)
	audio.play_menu()
	_clear_race()

	if vista == null:
		vista = MenuVista.new()
		add_child(vista)
		vista.build(selected_course, selected_rider)
	if menu != null:
		menu.queue_free()
	menu = MenuScreen.new()
	add_child(menu)
	menu.setup(course_defs, RiderDefs.all(), selected_course, selected_rider, best_scores, trick_best_scores, mode, music_volume)
	menu.start_requested.connect(_on_start_requested)
	menu.preview_changed.connect(_on_preview_changed)
	menu.music_volume_changed.connect(_on_music_volume_changed)


func _on_music_volume_changed(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	audio.set_music_volume(music_volume)
	_settings_dirty = true
	if _save_timer != null:
		_save_timer.start()


func _flush_settings() -> void:
	if _settings_dirty:
		_save_progress()


func _on_preview_changed(course_index: int, rider_index: int) -> void:
	selected_course = course_index
	selected_rider = rider_index
	if vista != null:
		vista.apply_theme(course_index)
		vista.show_rider(rider_index)


func _on_start_requested(course_index: int, rider_index: int, play_mode: int) -> void:
	selected_course = course_index
	selected_rider = rider_index
	_start_race(course_index, rider_index, play_mode)


func _start_race(course_index: int, rider_index: int, play_mode := 0) -> void:
	selected_course = course_index
	selected_rider = rider_index
	mode = clampi(play_mode, 0, 1)
	get_tree().paused = false
	audio.set_paused(false)
	if menu != null:
		menu.queue_free()
		menu = null
	if vista != null:
		vista.queue_free()
		vista = null
	_clear_race()

	var def: Dictionary = course_defs[course_index]
	course = Course.new()
	course.configure(def)
	theme = Course.get_theme(int(def.get("theme", 0)))

	race_root = Node3D.new()
	race_root.name = "Race"
	add_child(race_root)

	world = World.new()
	race_root.add_child(world)
	world.build(course, theme)

	var riders := RiderDefs.all()
	var rider: Dictionary = riders[rider_index]
	player = PlayerRider.new()
	player.name = "Player"
	race_root.add_child(player)
	player.setup(course, rider["stats"], String(rider["name"]), rider["colors"])
	player.auto_pilot = test_mode

	rivals.clear()
	if mode == 0:
		for i in RiderDefs.rival_defs().size():
			var cfg: Dictionary = RiderDefs.rival_defs()[i]
			var r := RivalRider.new()
			race_root.add_child(r)
			r.setup(course, cfg)
			r.player = player
			rivals.append(r)

	chase = ChaseCamera.new()
	race_root.add_child(chase)
	chase.setup(player, course)

	hud = RaceHUD.new()
	add_child(hud)
	hud.setup(player, course, self, rivals, mode)

	player.trick_landed.connect(hud.on_trick)
	player.combo_banked.connect(hud.on_combo_banked)
	player.crash_event.connect(hud.on_crash)
	player.finished_event.connect(_on_player_finished)
	player.jump_event.connect(_on_jump)
	player.land_event.connect(_on_land)
	player.rail_event.connect(_on_rail)
	player.crash_event.connect(_on_crash)

	trick_time_left = TRICK_TIME
	trick_finished = false
	_time_warned = false
	world.set_focus(player.position)
	race_state = "countdown"
	countdown_time = 3.05
	_last_count = 4
	player.state = "countdown"
	audio.start_race(mode)
	_save_progress()


func _process(delta: float) -> void:
	if shot_mode:
		_shot_step(delta)
	if get_tree().paused:
		return
	if race_state == "menu" or player == null:
		return

	if test_mode:
		test_elapsed += delta
		if test_elapsed > 260.0:
			print("AUTOTEST TIMEOUT state=%s z=%.1f speed=%.1f" % [player.state, player.position.z, player.speed])
			get_tree().quit(2)
			return

	if world != null:
		world.set_focus(player.position)
	audio.set_speed(player.speed, player.state == "riding" or player.state == "grind")

	if race_state == "countdown":
		countdown_time -= delta
		var n := int(ceil(countdown_time))
		if n != _last_count and n >= 1 and n <= 3:
			_last_count = n
			hud.show_banner(str(n), UiKit.PAPER, 0.8)
			audio.play("beep", 1.0, -4.0)
		if countdown_time <= 0.0:
			race_state = "racing"
			player.begin()
			for r in rivals:
				r.active = true
			hud.show_banner("DROP IN!", UiKit.ACCENT, 1.0)
			audio.play("go", 1.0, -2.0)
		return

	if race_state != "racing":
		return

	if mode == 1 and not trick_finished:
		trick_time_left = maxf(0.0, trick_time_left - delta)
		if trick_time_left <= 10.0 and not _time_warned:
			_time_warned = true
			hud.show_banner("10 SECONDS", UiKit.GOLD, 0.9)
			audio.play("beep", 1.15, -4.0)
		if trick_time_left <= 0.0:
			trick_finished = true
			player.force_finish()

	if Input.is_action_just_pressed("boost") and player.boost > 4.0:
		audio.play("boost", randf_range(0.95, 1.05), -6.0)
	if Input.is_action_just_pressed("signature") and player.tricky >= 100.0:
		hud.show_banner("TRICKY!", UiKit.GOLD, 1.0)

	if test_mode and int(test_elapsed / 8.0) != _last_report:
		_last_report = int(test_elapsed / 8.0)
		print("AUTOTEST t=%.1f z=%.1f x=%.1f speed=%.1f state=%s score=%d combo=%d place=%d" % [
			player.race_time, player.position.z, player.position.x, player.speed, player.state,
			player.display_score(), player.combo_count, _player_place()
		])


func _shot_step(delta: float) -> void:
	_shot_time += delta
	match _shot_stage:
		0:
			if race_state == "menu" and _shot_time > 3.0:
				_shot_stage = 1
				_shot_time = 0.0
				await _capture(_shot_prefix() + "01_menu")
				_start_race(0, 0, mode)
		1:
			if race_state == "racing":
				player.auto_pilot = true
				if _shot_time > 7.0:
					_shot_stage = 2
					_shot_time = 0.0
					await _capture(_shot_prefix() + "02_race")
		2:
			if race_state == "racing" and player.state == "air" and player.air_time > 0.4:
				_shot_stage = 3
				_shot_time = 0.0
				await _capture(_shot_prefix() + "03_air")
			elif _shot_time > 25.0:
				_shot_stage = 3
				_shot_time = 0.0
		3:
			if race_state == "racing" and player.combo_pending > 0 and _shot_time > 0.6:
				_shot_stage = 4
				_shot_time = 0.0
				await _capture(_shot_prefix() + "04_trick")
			elif _shot_time > 25.0:
				_shot_stage = 4
				_shot_time = 0.0
		4:
			if race_state == "results":
				_shot_stage = 5
				_shot_time = 0.0
				await _capture(_shot_prefix() + "05_results")
			elif _shot_time > 100.0:
				_shot_stage = 5
				_shot_time = 0.0
		5:
			if _shot_time > 1.0:
				get_tree().quit()


func _shot_prefix() -> String:
	return "trick_" if mode == 1 else ""


func _capture(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var dir := ProjectSettings.globalize_path("res://artifacts")
	DirAccess.make_dir_recursive_absolute(dir)
	var err := img.save_png("res://artifacts/%s.png" % tag)
	print("SHOT ", tag, " err=", err)


func _player_place() -> int:
	var entries := get_standings()
	for i in entries.size():
		if entries[i].get("is_player", false):
			return i + 1
	return 1


func get_standings() -> Array:
	var entries: Array = []
	if player == null:
		return entries
	entries.append({
		"name": player.rider_name,
		"z": player.position.z,
		"is_player": true,
		"finished": player.finished,
		"finish_time": player.race_time,
	})
	for r in rivals:
		entries.append({
			"name": r.rider_name,
			"z": r.position.z,
			"is_player": false,
			"finished": r.finished,
			"finish_time": r.finish_time,
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["finished"] and b["finished"]:
			return float(a["finish_time"]) < float(b["finish_time"])
		if a["finished"] != b["finished"]:
			return bool(a["finished"])
		return float(a["z"]) > float(b["z"])
	)
	return entries


func _on_player_finished(time: float, score: int) -> void:
	if race_state == "results":
		return
	if mode == 1:
		_finish_trick_attack(time, score)
		return
	race_state = "results"
	var previous_best := int(best_scores.get(course.id, 0))
	var new_best := score > previous_best
	if new_best:
		best_scores[course.id] = score

	var entries: Array = [{
		"name": player.rider_name,
		"time": time,
		"is_player": true,
	}]
	for r in rivals:
		var t := r.finish_time
		if not r.finished or t <= 0.0:
			t = time + maxf(0.2, (course.length - r.position.z) / maxf(r.speed, 6.0))
		entries.append({"name": r.rider_name, "time": t, "is_player": false})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["time"]) < float(b["time"]))
	var place := 1
	for i in entries.size():
		if entries[i].get("is_player", false):
			place = i + 1

	if new_best:
		_save_progress()
	audio.play("finish", 1.0, -4.0)

	var data := {
		"place": place,
		"total": entries.size(),
		"time": time,
		"score": score,
		"best_combo": player.best_combo,
		"best": maxi(previous_best, score),
		"new_best": new_best,
		"course": course.display_name,
	}
	hud.show_results(data)

	if test_mode:
		print("AUTOTEST RESULT place=%d/%d time=%.2f score=%d best_combo=%d best=%d" % [
			place, entries.size(), time, score, player.best_combo, best_scores.get(course.id, 0)
		])
		get_tree().quit(0)


func _finish_trick_attack(time: float, score: int) -> void:
	race_state = "results"
	trick_finished = true
	var previous_best := int(trick_best_scores.get(course.id, 0))
	var new_best := score > previous_best
	if new_best:
		trick_best_scores[course.id] = score
		_save_progress()

	var medal_info := get_trick_medal(score)
	var earned: Dictionary = medal_info["earned"]
	var next: Dictionary = medal_info["next"]
	var medal_name := "SEND IT"
	var medal_color := UiKit.MUTED
	if not earned.is_empty():
		medal_name = String(earned["name"])
		medal_color = Color(earned["color"])

	audio.play("finish", 1.0, -4.0)
	var data := {
		"mode": "trick",
		"course": course.display_name,
		"time": time,
		"score": score,
		"best_combo": player.best_combo,
		"best_trick": player.best_trick_title,
		"best_trick_points": player.best_trick_points,
		"best": maxi(previous_best, score),
		"new_best": new_best,
		"medal": medal_name,
		"medal_color": medal_color,
		"next_medal": String(next.get("name", "")),
		"next_score": int(next.get("score", 0)),
	}
	hud.show_results(data)

	if test_mode:
		print("AUTOTEST RESULT mode=trick medal=%s time=%.2f score=%d best_combo=%d best_trick=%s/%d best=%d" % [
			medal_name, time, score, player.best_combo, player.best_trick_title, player.best_trick_points,
			int(trick_best_scores.get(course.id, 0))
		])
		get_tree().quit(0)


func get_trick_medal(score: int) -> Dictionary:
	var earned: Dictionary = {}
	var next: Dictionary = {}
	for m in trick_medals:
		if score >= int(m["score"]):
			earned = m
		elif next.is_empty():
			next = m
	return {"earned": earned, "next": next}


func get_trick_target(score: int) -> Dictionary:
	var info := get_trick_medal(score)
	var next: Dictionary = info["next"]
	if next.is_empty():
		var top: Dictionary = trick_medals[trick_medals.size() - 1]
		return {"name": String(top["name"]), "score": int(top["score"]), "progress": 1.0}
	var floor_score := 0
	for m in trick_medals:
		if int(m["score"]) <= score:
			floor_score = int(m["score"])
	var span := maxf(1.0, float(int(next["score"]) - floor_score))
	var progress := clampf(float(score - floor_score) / span, 0.0, 1.0)
	return {"name": String(next["name"]), "score": int(next["score"]), "progress": progress}


func _on_jump() -> void:
	audio.play("jump", randf_range(0.9, 1.1), -5.0)


func _on_land(hard: bool) -> void:
	audio.play("land", randf_range(0.92, 1.05), -2.0 if hard else -6.0)
	if chase != null:
		chase.add_shake(0.55 if hard else 0.22)


func _on_rail() -> void:
	audio.play("rail", randf_range(0.95, 1.05), -7.0)


func _on_crash(lost: int, reason: String) -> void:
	audio.play("crash", randf_range(0.9, 1.05), -2.0)
	if chase != null:
		chase.add_shake(1.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		var jb := event as InputEventJoypadButton
		if jb.pressed and jb.button_index == JOY_BUTTON_START:
			if race_state == "results":
				_open_menu()
			elif race_state == "countdown" or race_state == "racing" or race_state == "paused":
				_toggle_pause()
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := (event as InputEventKey).keycode

	if race_state == "menu":
		if key == KEY_ESCAPE:
			get_tree().quit()
		return
	if race_state != "countdown" and race_state != "racing" and race_state != "paused" and race_state != "results":
		return

	if key == KEY_ESCAPE:
		if race_state == "results":
			_open_menu()
		else:
			_toggle_pause()
	elif key == KEY_R:
		if race_state == "results" or race_state == "paused":
			_restart()
	elif key == KEY_M:
		if race_state == "paused" or race_state == "results":
			_open_menu()
	elif key == KEY_N:
		audio.toggle_mute()


func _toggle_pause() -> void:
	if get_tree().paused:
		get_tree().paused = false
		race_state = _resume_state
		hud.show_pause(false)
		audio.set_paused(false)
	else:
		_resume_state = race_state
		race_state = "paused"
		get_tree().paused = true
		hud.show_pause(true)
		audio.set_paused(true)


func _restart() -> void:
	get_tree().paused = false
	audio.set_paused(false)
	_start_race(selected_course, selected_rider, mode)


func _clear_race() -> void:
	if hud != null:
		hud.queue_free()
		hud = null
	if race_root != null:
		race_root.queue_free()
		race_root = null
	player = null
	world = null
	chase = null
	rivals.clear()


func _load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		for i in course_defs.size():
			best_scores[i] = int(cfg.get_value("best", "course_%d" % i, 0))
			trick_best_scores[i] = int(cfg.get_value("best", "trick_course_%d" % i, 0))
		selected_rider = clampi(int(cfg.get_value("settings", "rider", 0)), 0, 3)
		selected_course = clampi(int(cfg.get_value("settings", "course", 0)), 0, 2)
		mode = clampi(int(cfg.get_value("settings", "mode", 0)), 0, 1)
		music_volume = clampf(float(cfg.get_value("settings", "music_volume", AudioDirector.DEFAULT_MUSIC_VOLUME)), 0.0, 1.0)
	else:
		music_volume = AudioDirector.DEFAULT_MUSIC_VOLUME
		for i in course_defs.size():
			best_scores[i] = 0
			trick_best_scores[i] = 0


func _save_progress() -> void:
	var cfg := ConfigFile.new()
	for i in course_defs.size():
		cfg.set_value("best", "course_%d" % i, int(best_scores.get(i, 0)))
		cfg.set_value("best", "trick_course_%d" % i, int(trick_best_scores.get(i, 0)))
	cfg.set_value("settings", "rider", selected_rider)
	cfg.set_value("settings", "course", selected_course)
	cfg.set_value("settings", "mode", mode)
	cfg.set_value("settings", "music_volume", music_volume)
	cfg.save(SAVE_PATH)
	_settings_dirty = false
	if _save_timer != null:
		_save_timer.stop()
