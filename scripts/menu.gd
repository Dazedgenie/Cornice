class_name MenuScreen
extends CanvasLayer
## Title screen: pick a mountain, pick a rider, drop in.

signal start_requested(course_index: int, rider_index: int, mode: int)
signal preview_changed(course_index: int, rider_index: int)
signal music_volume_changed(value: float)

var course_defs: Array = []
var rider_defs: Array = []
var bests: Dictionary = {}
var trick_bests: Dictionary = {}
var course_index := 0
var rider_index := 0
var mode := 0
var music_volume := 1.0

var course_buttons: Array[Button] = []
var rider_buttons: Array[Button] = []
var mode_buttons: Array[Button] = []
var course_info: Label
var best_label: Label
var rider_desc: Label
var mode_desc: Label
var start_button: Button
var music_slider: HSlider
var music_value_label: Label
var _starting := false


func setup(courses: Array, riders: Array, sel_course: int, sel_rider: int, best_scores: Dictionary, trick_scores: Dictionary = {}, sel_mode: int = 0, volume: float = 1.0) -> void:
	course_defs = courses
	rider_defs = riders
	course_index = clampi(sel_course, 0, course_defs.size() - 1)
	rider_index = clampi(sel_rider, 0, rider_defs.size() - 1)
	bests = best_scores
	trick_bests = trick_scores
	mode = clampi(sel_mode, 0, 1)
	music_volume = clampf(volume, 0.0, 1.0)
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_sync_selection()
	preview_changed.emit(course_index, rider_index)


func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Title: centred above the rider, flanked by the pickers.
	UiKit.label(root, "SUMMIT", 92, UiKit.PAPER, Vector2(276, 8), Vector2(360, 104), HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.label(root, "TRICK", 92, UiKit.ACCENT, Vector2(644, 8), Vector2(360, 104), HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.label(root, "CARVE  ·  SPIN  ·  GRAB  ·  GRIND  ·  STACK COMBOS", 15, UiKit.MUTED, Vector2(0, 108), Vector2(1280, 24), HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.color_rect(root, Rect2(470, 138, 340, 2), UiKit.ACCENT)

	# Mode selector between the title and the two pickers.
	var mode_panel := UiKit.panel(root, Rect2(470, 146, 340, 88), Color(0.02, 0.04, 0.08, 0.84), Color(0.55, 0.65, 0.8, 0.16), 8, 1)
	UiKit.label(mode_panel, "MODE", 13, UiKit.CYAN, Vector2(14, 4), Vector2(120, 18))
	UiKit.label(mode_panel, "T TOGGLE", 11, UiKit.MUTED, Vector2(220, 4), Vector2(106, 18), HORIZONTAL_ALIGNMENT_RIGHT)
	var mgroup := ButtonGroup.new()
	var race_mode := UiKit.button(mode_panel, "RACE", Rect2(14, 22, 148, 36), UiKit.ACCENT, 18)
	race_mode.toggle_mode = true
	race_mode.button_group = mgroup
	race_mode.pressed.connect(func() -> void: _select_mode(0))
	mode_buttons.append(race_mode)
	var trick_mode := UiKit.button(mode_panel, "TRICK ATTACK", Rect2(178, 22, 148, 36), UiKit.GOLD, 18)
	trick_mode.toggle_mode = true
	trick_mode.button_group = mgroup
	trick_mode.pressed.connect(func() -> void: _select_mode(1))
	mode_buttons.append(trick_mode)
	mode_desc = UiKit.label(mode_panel, "", 12, UiKit.MUTED, Vector2(14, 62), Vector2(312, 18), HORIZONTAL_ALIGNMENT_CENTER)

	# Audio panel (left), aligned with the mode switch.
	var audio_panel := UiKit.panel(root, Rect2(56, 146, 380, 88), Color(0.02, 0.04, 0.08, 0.84), Color(0.55, 0.65, 0.8, 0.16), 8, 1)
	UiKit.label(audio_panel, "AUDIO / MUSIC VOLUME", 13, UiKit.CYAN, Vector2(14, 4), Vector2(280, 18))
	music_value_label = UiKit.label(audio_panel, "", 13, UiKit.GOLD, Vector2(288, 4), Vector2(78, 18), HORIZONTAL_ALIGNMENT_RIGHT)

	music_slider = HSlider.new()
	music_slider.min_value = 0.0
	music_slider.max_value = 100.0
	music_slider.step = 1.0
	music_slider.set_value_no_signal(music_volume * 100.0)
	music_slider.position = Vector2(14, 38)
	music_slider.size = Vector2(352, 28)
	music_slider.focus_mode = Control.FOCUS_ALL
	music_slider.tooltip_text = "Music volume"

	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.015, 0.03, 0.06, 0.96)
	track.border_color = Color(0.55, 0.65, 0.8, 0.28)
	track.set_border_width_all(1)
	track.set_corner_radius_all(6)
	track.content_margin_top = 7.0
	track.content_margin_bottom = 7.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiKit.ACCENT
	fill.set_corner_radius_all(6)
	fill.content_margin_top = 7.0
	fill.content_margin_bottom = 7.0
	music_slider.add_theme_stylebox_override("slider", track)
	music_slider.add_theme_stylebox_override("grabber_area", fill)
	music_slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob := _slider_knob(11)
	music_slider.add_theme_icon_override("grabber", knob)
	music_slider.add_theme_icon_override("grabber_highlight", knob)
	music_slider.value_changed.connect(_on_music_volume_changed)
	audio_panel.add_child(music_slider)
	_update_music_volume_label()

	# Mountain picker (left).
	var course_panel := UiKit.panel(root, Rect2(56, 244, 400, 336), Color(0.02, 0.04, 0.08, 0.84), Color(0.55, 0.65, 0.8, 0.16), 10, 1)
	UiKit.label(course_panel, "01 / SELECT MOUNTAIN", 15, UiKit.CYAN, Vector2(18, 8), Vector2(300, 24))
	UiKit.label(course_panel, "KEYS 1-3", 12, UiKit.MUTED, Vector2(288, 8), Vector2(94, 24), HORIZONTAL_ALIGNMENT_RIGHT)

	var group := ButtonGroup.new()
	for i in course_defs.size():
		var def: Dictionary = course_defs[i]
		var b := UiKit.button(course_panel, String(def.get("name", "COURSE")), Rect2(18, 38 + i * 60, 364, 52), UiKit.ACCENT, 20)
		b.toggle_mode = true
		b.button_group = group
		b.text = String(def.get("name", ""))
		b.add_theme_font_size_override("font_size", 21)
		var idx := i
		b.pressed.connect(func() -> void: _select_course(idx))
		course_buttons.append(b)
	course_info = UiKit.label(course_panel, "", 13, UiKit.MUTED, Vector2(18, 228), Vector2(364, 44))
	course_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	best_label = UiKit.label(course_panel, "", 15, UiKit.GOLD, Vector2(18, 280), Vector2(364, 30))

	# Rider picker (right).
	var rider_panel := UiKit.panel(root, Rect2(824, 244, 400, 336), Color(0.02, 0.04, 0.08, 0.84), Color(0.55, 0.65, 0.8, 0.16), 10, 1)
	UiKit.label(rider_panel, "02 / SELECT RIDER", 15, UiKit.CYAN, Vector2(18, 8), Vector2(300, 24))
	UiKit.label(rider_panel, "Q / E", 12, UiKit.MUTED, Vector2(300, 8), Vector2(82, 24), HORIZONTAL_ALIGNMENT_RIGHT)

	var rgroup := ButtonGroup.new()
	for i in rider_defs.size():
		var r: Dictionary = rider_defs[i]
		var b := UiKit.button(rider_panel, "   " + String(r.get("name", "RIDER")), Rect2(18, 38 + i * 48, 364, 41), UiKit.CYAN, 19)
		b.toggle_mode = true
		b.button_group = rgroup
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var swatch := ColorRect.new()
		var colors: Dictionary = r.get("colors", {})
		swatch.color = colors.get("jacket", UiKit.ACCENT)
		swatch.position = Vector2(14, 10)
		swatch.size = Vector2(7, 21)
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(swatch)
		var idx := i
		b.pressed.connect(func() -> void: _select_rider(idx))
		rider_buttons.append(b)
	rider_desc = UiKit.label(rider_panel, "", 12, UiKit.MUTED, Vector2(18, 234), Vector2(364, 74))
	rider_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rider_desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	# Bottom row.
	var controls_panel := UiKit.panel(root, Rect2(56, 596, 380, 76), Color(0.02, 0.04, 0.08, 0.8), Color(0.55, 0.65, 0.8, 0.14), 8, 1)
	UiKit.label(controls_panel, "CONTROLS", 12, UiKit.CYAN, Vector2(14, 6), Vector2(200, 20))
	UiKit.label(controls_panel, "A/D CARVE  ·  W TUCK  ·  S BRAKE  ·  SPACE JUMP", 11, UiKit.MUTED, Vector2(14, 28), Vector2(352, 20))
	UiKit.label(controls_panel, "J/K/L GRABS  ·  SHIFT BOOST  ·  E TRICKY  ·  R RESPAWN", 11, UiKit.MUTED, Vector2(14, 48), Vector2(352, 20))

	start_button = UiKit.button(root, "DROP IN   [ENTER]", Rect2(470, 596, 340, 76), UiKit.ACCENT, 28)
	start_button.pressed.connect(_on_start)
	var start_normal := StyleBoxFlat.new()
	start_normal.bg_color = Color(0.09, 0.10, 0.12, 0.95)
	start_normal.border_color = UiKit.ACCENT
	start_normal.set_border_width_all(3)
	start_normal.set_corner_radius_all(8)
	var start_hover := start_normal.duplicate() as StyleBoxFlat
	start_hover.bg_color = UiKit.ACCENT
	var start_pressed := start_normal.duplicate() as StyleBoxFlat
	start_pressed.bg_color = UiKit.GOLD
	start_pressed.border_color = UiKit.PAPER
	start_button.add_theme_stylebox_override("normal", start_normal)
	start_button.add_theme_stylebox_override("hover", start_hover)
	start_button.add_theme_stylebox_override("pressed", start_pressed)
	start_button.add_theme_stylebox_override("focus", start_hover)
	start_button.add_theme_color_override("font_hover_color", UiKit.INK)
	start_button.add_theme_color_override("font_pressed_color", UiKit.INK)

	var tip_panel := UiKit.panel(root, Rect2(844, 596, 380, 76), Color(0.02, 0.04, 0.08, 0.8), Color(0.55, 0.65, 0.8, 0.14), 8, 1)
	UiKit.label(tip_panel, "RIDER NOTES", 12, UiKit.CYAN, Vector2(14, 6), Vector2(200, 20))
	UiKit.label(tip_panel, "LAND STRAIGHT TO BANK YOUR COMBO.", 11, UiKit.MUTED, Vector2(14, 28), Vector2(352, 20))
	UiKit.label(tip_panel, "FULL TRICKY METER UNLOCKS THE SIGNATURE.", 11, UiKit.MUTED, Vector2(14, 48), Vector2(352, 20))

	UiKit.label(root, "ESC QUIT   ·   T MODE   ·   BEST SCORES + MUSIC SAVED LOCALLY   ·   GAMEPAD SUPPORTED", 11, Color(0.55, 0.62, 0.74, 0.75), Vector2(0, 680), Vector2(1280, 20), HORIZONTAL_ALIGNMENT_CENTER)

	start_button.grab_focus()


func _sync_selection() -> void:
	if course_buttons.is_empty() or rider_buttons.is_empty():
		return
	for i in course_buttons.size():
		course_buttons[i].set_pressed_no_signal(i == course_index)
	for i in rider_buttons.size():
		rider_buttons[i].set_pressed_no_signal(i == rider_index)
	for i in mode_buttons.size():
		mode_buttons[i].set_pressed_no_signal(i == mode)
	_update_texts()


func _update_texts() -> void:
	var def: Dictionary = course_defs[course_index]
	var source := trick_bests if mode == 1 else bests
	var best := int(source.get(int(def.get("id", 0)), 0))
	course_info.text = String(def.get("subtitle", ""))
	best_label.text = ("TRICK BEST   " if mode == 1 else "RACE BEST   ") + UiKit.format_score(best)
	best_label.add_theme_color_override("font_color", UiKit.GOLD if best > 0 else UiKit.MUTED)
	rider_desc.text = "%s - %s" % [String(rider_defs[rider_index].get("tag", "")), String(rider_defs[rider_index].get("desc", ""))]
	mode_desc.text = "2:00 TO STACK THE BIGGEST SCORE" if mode == 1 else "FIRST TO THE FINISH LINE"


func _update_music_volume_label() -> void:
	if music_value_label == null:
		return
	music_value_label.text = "%d%%" % roundi(music_volume * 100.0)
	music_value_label.add_theme_color_override("font_color", UiKit.MUTED if music_volume > 0.001 else UiKit.GOLD)


func _on_music_volume_changed(value: float) -> void:
	music_volume = clampf(value / 100.0, 0.0, 1.0)
	_update_music_volume_label()
	music_volume_changed.emit(music_volume)


func _slider_knob(radius: int) -> ImageTexture:
	var size := radius * 2 + 2
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var center := Vector2(size * 0.5, size * 0.5)
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(center)
			if d <= radius + 0.5:
				var col := UiKit.PAPER
				if d > radius - 2.5:
					col = UiKit.CYAN
				col.a = clampf(radius + 0.5 - d, 0.0, 1.0)
				img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


func _select_mode(index: int) -> void:
	mode = clampi(index, 0, 1)
	_sync_selection()


func _select_course(index: int) -> void:
	if index < 0 or index >= course_defs.size():
		return
	course_index = index
	_sync_selection()
	preview_changed.emit(course_index, rider_index)


func _select_rider(index: int) -> void:
	if index < 0 or index >= rider_defs.size():
		return
	rider_index = index
	_sync_selection()
	preview_changed.emit(course_index, rider_index)


func _on_start() -> void:
	if _starting:
		return
	_starting = true
	start_requested.emit(course_index, rider_index, mode)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := (event as InputEventKey).keycode
	if key == KEY_ESCAPE:
		get_tree().quit()
	elif key == KEY_ENTER or key == KEY_KP_ENTER:
		_on_start()
	elif key == KEY_1:
		_select_course(0)
	elif key == KEY_2:
		_select_course(1)
	elif key == KEY_3:
		_select_course(2)
	elif key == KEY_Q:
		_select_rider((rider_index - 1 + rider_defs.size()) % rider_defs.size())
	elif key == KEY_E:
		_select_rider((rider_index + 1) % rider_defs.size())
	elif key == KEY_T:
		_select_mode(1 - mode)
