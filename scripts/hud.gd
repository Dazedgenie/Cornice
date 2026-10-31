class_name RaceHUD
extends CanvasLayer
## All in-race UI: placement, timer, score, combo, boost/tricky bars, trick
## popups, standings, countdown, pause and results.

var player: PlayerRider
var course: Course
var game: Node
var rivals: Array = []
var mode := 0

var root: Control
var place_label: Label
var time_label: Label
var score_label: Label
var combo_label: Label
var speed_label: Label
var boost_fill: ColorRect
var tricky_fill: ColorRect
var boost_label: Label
var tricky_label: Label
var message_label: Label
var crash_label: Label
var popup_root: Control
var standings_labels: Array[Label] = []
var standings_box: Panel
var trick_box: Panel
var target_medal_label: Label
var target_score_label: Label
var target_hint: Label
var target_fill: ColorRect
var results_root: Control
var pause_root: Control

var _refresh_timer := 0.0
var _banner_hold := 0.0
var _crash_hold := 0.0
var _current_place := 1


func setup(p_player: PlayerRider, p_course: Course, p_game: Node, p_rivals: Array, p_mode := 0) -> void:
	player = p_player
	course = p_course
	game = p_game
	rivals = p_rivals
	mode = p_mode
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_refresh_standings()


func _build() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Placement and race clock.
	place_label = UiKit.label(root, "1ST", 56, UiKit.GOLD, Vector2(34, 18), Vector2(250, 66))
	time_label = UiKit.label(root, "0:00.000", 24, UiKit.PAPER, Vector2(38, 82), Vector2(320, 30))

	# Score and combo, top centre.
	score_label = UiKit.label(root, "SCORE 0", 40, UiKit.PAPER, Vector2(380, 16), Vector2(520, 48), HORIZONTAL_ALIGNMENT_CENTER)
	combo_label = UiKit.label(root, "", 20, UiKit.CYAN, Vector2(380, 60), Vector2(520, 28), HORIZONTAL_ALIGNMENT_CENTER)

	# Standings, top right.
	standings_box = UiKit.panel(root, Rect2(1004, 22, 246, 196), Color(0.02, 0.04, 0.08, 0.66), Color(0.5, 0.6, 0.75, 0.18), 8, 1)
	UiKit.label(standings_box, "STANDINGS", 16, UiKit.MUTED, Vector2(14, 6), Vector2(220, 24))
	for i in 6:
		var l := UiKit.label(standings_box, "", 17, UiKit.PAPER, Vector2(14, 32 + i * 26), Vector2(216, 24))
		standings_labels.append(l)

	# Trick Attack medal target replaces standings in that mode.
	trick_box = UiKit.panel(root, Rect2(1004, 22, 246, 196), Color(0.02, 0.04, 0.08, 0.66), Color(0.5, 0.6, 0.75, 0.18), 8, 1)
	UiKit.label(trick_box, "MEDAL TARGET", 16, UiKit.MUTED, Vector2(14, 6), Vector2(218, 24))
	target_hint = UiKit.label(trick_box, "NEXT MEDAL", 12, UiKit.MUTED, Vector2(14, 32), Vector2(218, 18))
	target_medal_label = UiKit.label(trick_box, "BRONZE", 32, UiKit.GOLD, Vector2(14, 50), Vector2(218, 36))
	target_score_label = UiKit.label(trick_box, "6,000", 24, UiKit.PAPER, Vector2(14, 84), Vector2(218, 28))
	UiKit.label(trick_box, "TO NEXT", 11, UiKit.MUTED, Vector2(14, 114), Vector2(218, 16))
	UiKit.color_rect(trick_box, Rect2(14, 136, 218, 12), Color(0.02, 0.04, 0.08, 0.85))
	target_fill = UiKit.color_rect(trick_box, Rect2(15, 137, 0, 10), UiKit.GOLD)
	UiKit.label(trick_box, "BANK COMBOS TO CLIMB", 10, UiKit.MUTED, Vector2(14, 156), Vector2(218, 16), HORIZONTAL_ALIGNMENT_CENTER)
	standings_box.visible = mode == 0
	trick_box.visible = mode == 1

	# Speed, bottom left.
	var speed_panel := UiKit.panel(root, Rect2(28, 596, 244, 92), Color(0.02, 0.04, 0.08, 0.74), Color(0.5, 0.6, 0.75, 0.2), 8, 1)
	UiKit.color_rect(speed_panel, Rect2(0, 0, 244, 3), UiKit.CYAN)
	speed_label = UiKit.label(speed_panel, "0", 68, UiKit.PAPER, Vector2(14, -6), Vector2(150, 98))
	UiKit.label(speed_panel, "KM/H", 20, UiKit.MUTED, Vector2(154, 34), Vector2(76, 30))

	# Boost and tricky meters.
	UiKit.panel(root, Rect2(356, 626, 500, 68), Color(0.02, 0.04, 0.08, 0.66), Color(0.5, 0.6, 0.75, 0.16), 6, 1)
	boost_label = UiKit.label(root, "BOOST", 16, UiKit.CYAN, Vector2(368, 636), Vector2(96, 20), HORIZONTAL_ALIGNMENT_RIGHT)
	UiKit.color_rect(root, Rect2(470, 640, 382, 13), Color(0.02, 0.04, 0.08, 0.75))
	boost_fill = UiKit.color_rect(root, Rect2(471, 641, 380, 11), UiKit.CYAN)
	tricky_label = UiKit.label(root, "TRICKY", 16, UiKit.GOLD, Vector2(368, 664), Vector2(96, 20), HORIZONTAL_ALIGNMENT_RIGHT)
	UiKit.color_rect(root, Rect2(470, 668, 382, 13), Color(0.02, 0.04, 0.08, 0.75))
	tricky_fill = UiKit.color_rect(root, Rect2(471, 669, 0, 11), UiKit.GOLD)

	var hint := "A/D CARVE   W TUCK   S BRAKE   SPACE JUMP   J/K/L GRABS   SHIFT BOOST   E TRICKY   R RESPAWN   ESC PAUSE"
	UiKit.label(root, hint, 14, Color(0.82, 0.87, 0.95, 0.85), Vector2(0, 696), Vector2(1280, 20), HORIZONTAL_ALIGNMENT_CENTER)

	# Big centred messages (countdown / GO).
	message_label = UiKit.label(root, "", 94, UiKit.PAPER, Vector2(340, 220), Vector2(600, 150), HORIZONTAL_ALIGNMENT_CENTER)
	message_label.pivot_offset = message_label.size * 0.5
	message_label.modulate.a = 0.0

	crash_label = UiKit.label(root, "", 30, UiKit.ACCENT, Vector2(340, 380), Vector2(600, 44), HORIZONTAL_ALIGNMENT_CENTER)
	crash_label.modulate.a = 0.0

	popup_root = Control.new()
	popup_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(popup_root)

	_build_results()
	_build_pause()


func _build_results() -> void:
	results_root = Control.new()
	results_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	results_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	results_root.visible = false
	root.add_child(results_root)


func _build_pause() -> void:
	pause_root = Control.new()
	pause_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_root.visible = false
	root.add_child(pause_root)
	UiKit.color_rect(pause_root, Rect2(0, 0, 1280, 720), Color(0.01, 0.02, 0.05, 0.62))
	var panel := UiKit.panel(pause_root, Rect2(380, 200, 520, 320), Color(0.03, 0.05, 0.10, 0.96), Color(1, 1, 1, 0.18), 10, 1)
	UiKit.label(panel, "PAUSED", 68, UiKit.PAPER, Vector2(0, 24), Vector2(520, 80), HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.label(panel, "ESC   RESUME", 22, UiKit.CYAN, Vector2(0, 120), Vector2(520, 30), HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.label(panel, "R   RESTART RUN", 22, UiKit.PAPER, Vector2(0, 158), Vector2(520, 30), HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.label(panel, "M   QUIT TO MENU", 22, UiKit.PAPER, Vector2(0, 196), Vector2(520, 30), HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.label(panel, "N   MUTE AUDIO", 22, UiKit.MUTED, Vector2(0, 234), Vector2(520, 30), HORIZONTAL_ALIGNMENT_CENTER)


func _process(delta: float) -> void:
	if player == null:
		return
	if not get_tree().paused:
		speed_label.text = str(int(round(player.speed * 3.6)))
		score_label.text = "SCORE  " + UiKit.format_score(player.display_score())
		if mode == 1:
			var left := float(game.trick_time_left) if game != null else 0.0
			place_label.text = _clock(left)
			place_label.add_theme_color_override("font_color", UiKit.ACCENT if left <= 10.0 else UiKit.GOLD)
			time_label.text = "TRICK ATTACK   " + UiKit.format_time(player.race_time)
		else:
			time_label.text = UiKit.format_time(player.race_time)

		if player.combo_count > 0:
			combo_label.text = "COMBO x%d   %s PTS" % [player.combo_count, UiKit.format_score(player.combo_pending)]
			combo_label.add_theme_color_override("font_color", UiKit.GOLD if player.combo_count >= 3 else UiKit.CYAN)
		else:
			combo_label.text = ""

		boost_fill.size = Vector2(380.0 * clampf(player.boost / 100.0, 0.0, 1.0), 11.0)
		tricky_fill.size = Vector2(380.0 * clampf(player.tricky / 100.0, 0.0, 1.0), 11.0)
		boost_label.text = "BOOST" if player.boost > 1.0 else "EMPTY"
		if player.tricky >= 100.0:
			tricky_label.text = "E TRICKY!"
			tricky_label.add_theme_color_override("font_color", UiKit.GOLD)
		else:
			tricky_label.text = "TRICKY"
			tricky_label.add_theme_color_override("font_color", UiKit.GOLD.darkened(0.15))

		_refresh_timer -= delta
		if _refresh_timer <= 0.0:
			_refresh_timer = 0.22
			if mode == 1:
				_update_trick_target()
			else:
				_refresh_standings()

	if _banner_hold > 0.0:
		_banner_hold -= delta
	elif message_label.modulate.a > 0.0:
		message_label.modulate.a = maxf(0.0, message_label.modulate.a - delta * 3.2)

	if _crash_hold > 0.0:
		_crash_hold -= delta
	elif crash_label.modulate.a > 0.0:
		crash_label.modulate.a = maxf(0.0, crash_label.modulate.a - delta * 2.2)


func _clock(seconds: float) -> String:
	var total := int(ceil(maxf(0.0, seconds)))
	return "%d:%02d" % [int(total / 60.0), total % 60]


func _update_trick_target() -> void:
	if game == null or not game.has_method("get_trick_target"):
		return
	var info: Dictionary = game.get_trick_target(player.display_score())
	var medal_name := String(info.get("name", "BRONZE"))
	var progress := clampf(float(info.get("progress", 0.0)), 0.0, 1.0)
	target_medal_label.text = medal_name
	target_score_label.text = UiKit.format_score(int(info.get("score", 0)))
	target_hint.text = "MAX MEDAL" if progress >= 1.0 and medal_name == "PLATINUM" else "NEXT MEDAL"
	var col := UiKit.GOLD
	match medal_name:
		"BRONZE":
			col = Color(0.86, 0.55, 0.32)
		"SILVER":
			col = Color(0.82, 0.89, 0.97)
		"PLATINUM":
			col = UiKit.CYAN
	target_medal_label.add_theme_color_override("font_color", col)
	target_fill.color = col
	target_fill.size = Vector2(218.0 * progress, 10.0)


func _refresh_standings() -> void:
	if mode == 1:
		return
	var entries: Array = []
	if game != null and game.has_method("get_standings"):
		entries = game.get_standings()
	if entries.is_empty():
		return
	for i in standings_labels.size():
		if i < entries.size():
			var e: Dictionary = entries[i]
			var is_player: bool = e.get("is_player", false)
			var label_text := "%d   %s" % [i + 1, String(e.get("name", "---"))]
			if e.get("finished", false):
				label_text += "    FIN"
			standings_labels[i].text = label_text
			standings_labels[i].add_theme_color_override("font_color", UiKit.ACCENT if is_player else UiKit.PAPER)
			if is_player:
				_current_place = i + 1
		else:
			standings_labels[i].text = ""
	place_label.text = UiKit.ordinal(_current_place)
	place_label.add_theme_color_override("font_color", UiKit.GOLD if _current_place == 1 else UiKit.PAPER)


func show_banner(text: String, color: Color, hold := 0.9) -> void:
	message_label.text = text
	message_label.add_theme_color_override("font_color", color)
	message_label.modulate.a = 1.0
	message_label.scale = Vector2(1.35, 1.35)
	_banner_hold = hold
	var tw := create_tween()
	tw.tween_property(message_label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func on_trick(title: String, points: int, combo: int) -> void:
	var color := UiKit.GOLD if combo >= 3 else UiKit.PAPER
	var l := UiKit.label(popup_root, "%s   +%s" % [title, UiKit.format_score(points)], 28, color, Vector2(290, 330), Vector2(700, 44), HORIZONTAL_ALIGNMENT_CENTER)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 78.0, 1.25)
	tw.tween_property(l, "modulate:a", 0.0, 1.25).set_delay(0.35)
	tw.chain().tween_callback(l.queue_free)
	_crash_hold = 0.0


func on_combo_banked(points: int, count: int) -> void:
	var l := UiKit.label(popup_root, "COMBO x%d BANKED   +%s" % [count, UiKit.format_score(points)], 26, UiKit.GOLD, Vector2(290, 390), Vector2(700, 40), HORIZONTAL_ALIGNMENT_CENTER)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 50.0, 1.1)
	tw.tween_property(l, "modulate:a", 0.0, 1.1).set_delay(0.25)
	tw.chain().tween_callback(l.queue_free)


func on_crash(lost: int, reason: String) -> void:
	var text := "BAILED!"
	if lost > 0:
		text += "   -" + UiKit.format_score(lost)
	if reason != "":
		text += "   " + reason
	crash_label.text = text
	crash_label.modulate.a = 1.0
	_crash_hold = 1.6


func show_results(data: Dictionary) -> void:
	for child in results_root.get_children():
		child.queue_free()
	for child in popup_root.get_children():
		child.queue_free()
	results_root.visible = true
	root.move_child(results_root, root.get_child_count() - 1)
	message_label.modulate.a = 0.0
	crash_label.modulate.a = 0.0
	_banner_hold = 0.0
	_crash_hold = 0.0

	UiKit.color_rect(results_root, Rect2(0, 0, 1280, 720), Color(0.01, 0.02, 0.05, 0.68))
	var panel := UiKit.panel(results_root, Rect2(300, 108, 680, 504), Color(0.03, 0.05, 0.10, 0.97), Color(1, 1, 1, 0.16), 12, 1)
	UiKit.color_rect(panel, Rect2(0, 0, 680, 5), UiKit.ACCENT)
	var trick_run := String(data.get("mode", "")) == "trick"
	UiKit.label(panel, "TRICK ATTACK COMPLETE" if trick_run else "RUN COMPLETE", 20, UiKit.MUTED, Vector2(0, 20), Vector2(680, 26), HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.label(panel, String(data.get("course", "")), 18, UiKit.CYAN, Vector2(0, 46), Vector2(680, 24), HORIZONTAL_ALIGNMENT_CENTER)

	if trick_run:
		var medal_color := Color(data.get("medal_color", UiKit.GOLD))
		UiKit.label(panel, String(data.get("medal", "SEND IT")), 92, medal_color, Vector2(0, 58), Vector2(680, 112), HORIZONTAL_ALIGNMENT_CENTER)
		var rows := [
			["RUN TIME", UiKit.format_time(float(data.get("time", 0.0)))],
			["SCORE", UiKit.format_score(int(data.get("score", 0)))],
			["BEST COMBO", UiKit.format_score(int(data.get("best_combo", 0)))],
			["BEST TRICK", UiKit.format_score(int(data.get("best_trick_points", 0)))],
			["PERSONAL BEST", UiKit.format_score(int(data.get("best", 0)))],
		]
		var row_y := 172
		for row in rows:
			UiKit.label(panel, row[0], 17, UiKit.MUTED, Vector2(90, row_y), Vector2(260, 30))
			UiKit.label(panel, row[1], 23, UiKit.PAPER, Vector2(350, row_y), Vector2(240, 30), HORIZONTAL_ALIGNMENT_RIGHT)
			row_y += 34
		if bool(data.get("new_best", false)):
			UiKit.label(panel, "NEW PERSONAL BEST", 18, UiKit.CYAN, Vector2(0, 340), Vector2(680, 24), HORIZONTAL_ALIGNMENT_CENTER)
		var best_trick := String(data.get("best_trick", ""))
		if best_trick != "":
			UiKit.label(panel, "BEST TRICK   " + best_trick, 13, UiKit.MUTED, Vector2(40, 364), Vector2(600, 20), HORIZONTAL_ALIGNMENT_CENTER)
		var next_medal := String(data.get("next_medal", ""))
		if next_medal != "":
			UiKit.label(panel, "NEXT MEDAL   %s   %s" % [next_medal, UiKit.format_score(int(data.get("next_score", 0)))], 16, UiKit.CYAN, Vector2(0, 390), Vector2(680, 26), HORIZONTAL_ALIGNMENT_CENTER)
		else:
			UiKit.label(panel, "MAX MEDAL REACHED", 16, UiKit.GOLD, Vector2(0, 390), Vector2(680, 26), HORIZONTAL_ALIGNMENT_CENTER)
		UiKit.label(panel, "R   RETRY        M   MENU", 22, UiKit.ACCENT, Vector2(0, 424), Vector2(680, 34), HORIZONTAL_ALIGNMENT_CENTER)
		UiKit.label(panel, "MEDALS   BRONZE 6K   ·   SILVER 12K   ·   GOLD 20K   ·   PLATINUM 32K", 11, UiKit.MUTED, Vector2(0, 470), Vector2(680, 20), HORIZONTAL_ALIGNMENT_CENTER)
	else:
		UiKit.label(panel, UiKit.ordinal(int(data.get("place", 1))), 100, UiKit.GOLD, Vector2(0, 66), Vector2(680, 120), HORIZONTAL_ALIGNMENT_CENTER)
		var rows := [
			["TIME", UiKit.format_time(float(data.get("time", 0.0)))],
			["SCORE", UiKit.format_score(int(data.get("score", 0)))],
			["BEST COMBO", UiKit.format_score(int(data.get("best_combo", 0)))],
			["PERSONAL BEST", UiKit.format_score(int(data.get("best", 0)))],
		]
		var y := 194
		for row in rows:
			UiKit.label(panel, row[0], 19, UiKit.MUTED, Vector2(90, y), Vector2(260, 32))
			UiKit.label(panel, row[1], 26, UiKit.PAPER, Vector2(350, y), Vector2(240, 32), HORIZONTAL_ALIGNMENT_RIGHT)
			y += 42
		if bool(data.get("new_best", false)):
			UiKit.label(panel, "NEW PERSONAL BEST", 20, UiKit.CYAN, Vector2(0, 358), Vector2(680, 28), HORIZONTAL_ALIGNMENT_CENTER)
		UiKit.label(panel, "R   RETRY        M   MENU", 24, UiKit.ACCENT, Vector2(0, 400), Vector2(680, 40), HORIZONTAL_ALIGNMENT_CENTER)
		UiKit.label(panel, "Final standings include riders still on course (estimated).", 12, UiKit.MUTED, Vector2(0, 462), Vector2(680, 22), HORIZONTAL_ALIGNMENT_CENTER)


func show_pause(visible_state: bool) -> void:
	pause_root.visible = visible_state
	if visible_state:
		root.move_child(pause_root, root.get_child_count() - 1)
