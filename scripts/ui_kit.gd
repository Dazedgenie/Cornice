class_name UiKit
extends RefCounted
## Shared visual language for the menus and HUD.

const INK := Color(0.025, 0.04, 0.08)
const PAPER := Color(0.94, 0.97, 1.0)
const MUTED := Color(0.64, 0.72, 0.84)
const ACCENT := Color(1.0, 0.36, 0.10)
const CYAN := Color(0.16, 0.86, 0.95)
const GOLD := Color(1.0, 0.82, 0.24)

static var _font: Font = null


static func display_font() -> Font:
	if _font == null:
		if ResourceLoader.exists("res://fonts/display.ttf"):
			_font = load("res://fonts/display.ttf")
		if _font == null:
			_font = ThemeDB.fallback_font
	return _font


static func label(parent: Node, text: String, font_size: int, color: Color, pos: Vector2, box: Vector2, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", display_font())
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.75))
	l.add_theme_constant_override("outline_size", maxi(1, int(font_size * 0.1)))
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.position = pos
	l.size = box
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


static func panel(parent: Node, rect: Rect2, bg: Color, border: Color, radius := 8, border_width := 1) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p


static func button(parent: Node, text: String, rect: Rect2, accent: Color, font_size := 22) -> Button:
	var b := Button.new()
	b.text = text
	b.position = rect.position
	b.size = rect.size
	b.focus_mode = Control.FOCUS_ALL
	b.clip_text = true
	b.add_theme_font_override("font", display_font())
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", PAPER)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	b.add_theme_constant_override("outline_size", 0)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.05, 0.08, 0.14, 0.88)
	normal.border_color = Color(0.22, 0.28, 0.40, 0.9)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 16.0
	normal.content_margin_right = 16.0

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.10, 0.14, 0.24, 0.95)
	hover.border_color = accent

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = accent
	pressed.border_color = Color(1.0, 1.0, 1.0, 0.85)

	var focus := normal.duplicate() as StyleBoxFlat
	focus.bg_color = Color(0.08, 0.12, 0.20, 0.95)
	focus.border_color = CYAN

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.06, 0.08, 0.12, 0.6)

	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", focus)
	b.add_theme_stylebox_override("disabled", disabled)
	parent.add_child(b)
	return b


static func color_rect(parent: Node, rect: Rect2, color: Color) -> ColorRect:
	var c := ColorRect.new()
	c.position = rect.position
	c.size = rect.size
	c.color = color
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c


static func format_score(value: int) -> String:
	var s := str(absi(value))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return (("-" if value < 0 else "") + s + out)


static func format_time(seconds: float) -> String:
	var total_ms := int(maxf(0.0, seconds) * 1000.0)
	var m := total_ms / 60000
	var s := (total_ms / 1000) % 60
	var ms := total_ms % 1000
	return "%d:%02d.%03d" % [m, s, ms]


static func ordinal(n: int) -> String:
	var suffix := "TH"
	if n % 100 < 11 or n % 100 > 13:
		match n % 10:
			1:
				suffix = "ST"
			2:
				suffix = "ND"
			3:
				suffix = "RD"
	return str(n) + suffix
