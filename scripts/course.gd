class_name Course
extends RefCounted
## A procedurally defined mountain course.
##
## Everything (mesh, physics, props) is generated from the same height function,
## so the snow you see is exactly the snow you ride on.

var id := 0
var display_name := "ALPINE RUSH"
var subtitle := ""
var difficulty := "ROOKIE"
var seed := 1337
var length := 2300.0
var width := 380.0
var drop := 400.0
var path_amp := 26.0
var path_amp2 := 11.0
var path_freq := 0.0034
var path_freq2 := 0.0091
var theme := 0
var start_z := 14.0
var kickers: Array = []
var rails: Array = []
var noise := FastNoiseLite.new()

const START_CLEAR := 90.0


func configure(cfg: Dictionary) -> void:
	id = int(cfg.get("id", 0))
	display_name = String(cfg.get("name", display_name))
	subtitle = String(cfg.get("subtitle", ""))
	difficulty = String(cfg.get("difficulty", "ROOKIE"))
	seed = int(cfg.get("seed", seed))
	length = float(cfg.get("length", length))
	drop = float(cfg.get("drop", drop))
	path_amp = float(cfg.get("path_amp", path_amp))
	path_amp2 = float(cfg.get("path_amp2", path_amp2))
	theme = int(cfg.get("theme", 0))
	start_z = float(cfg.get("start_z", start_z))

	noise.seed = seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3

	kickers = (cfg.get("kickers", []) as Array).duplicate(true)

	rails.clear()
	for r in (cfg.get("rails", []) as Array):
		var z := float(r.get("z", 100.0))
		var l := float(r.get("len", 50.0))
		var off := float(r.get("x_off", 0.0))
		var h := float(r.get("h", 2.0))
		var x0 := center_x(z) + off
		var x1 := center_x(z + l) + off
		var p0 := Vector3(x0, height(x0, z) + h, z)
		var p1 := Vector3(x1, height(x1, z + l) + h, z + l)
		rails.append({"p0": p0, "p1": p1, "len": maxf(1.0, p0.distance_to(p1))})


func center_x(z: float) -> float:
	var t := clampf(z / length, 0.0, 1.0)
	var fade := smoothstep(0.0, 0.05, t)
	var raw := sin(z * path_freq + 0.6) * path_amp + sin(z * path_freq2 + 2.1) * path_amp2
	return raw * fade


func base_height(z: float) -> float:
	var t := clampf(z / length, 0.0, 1.0)
	var h := drop * (1.0 - (0.58 * t + 0.42 * pow(t, 1.55)))
	h += 2.4 * sin(z * 0.014) + 1.2 * sin(z * 0.036 + 1.3)
	return h


func height(x: float, z: float) -> float:
	var cx := center_x(z)
	var d := absf(x - cx)
	var h := base_height(z)

	# Wide groomed half-pipe valley: gentle at the centre, rising to the tree line.
	h += 0.0026 * d * d

	# Lumpy off-piste snow, kept away from the race line so it stays fast.
	var mask := smoothstep(26.0, 80.0, d)
	h += noise.get_noise_2d(x, z) * 9.5 * mask
	h += noise.get_noise_2d(x * 3.5 + 41.0, z * 3.5) * 0.22

	# Distant ridge walls.
	var far := smoothstep(118.0, 200.0, d)
	h += far * (70.0 + noise.get_noise_2d(x * 0.35, z * 0.35) * 55.0)

	# Kicker ramps: smooth rise then a hard lip.
	for k in kickers:
		var kz := float(k.get("z", 0.0))
		var kl := maxf(4.0, float(k.get("len", 20.0)))
		var kw := maxf(4.0, float(k.get("w", 16.0)))
		var kh := float(k.get("h", 4.0))
		var rel := z - kz
		if rel > -1.0 and rel < kl + 2.6:
			var kx := center_x(kz) + float(k.get("x_off", 0.0))
			var across := 1.0 - smoothstep(kw * 0.5, kw * 0.5 + 2.5, absf(x - kx))
			if across > 0.001:
				var f := 0.0
				if rel < kl:
					var t := clampf(maxf(rel, 0.0) / kl, 0.0, 1.0)
					f = t * t * (3.0 - 2.0 * t)
				else:
					f = 1.0 - (rel - kl) / 2.6
				h += kh * f * across
	return h


func normal_at(x: float, z: float) -> Vector3:
	var e := 0.9
	var hl := height(x - e, z)
	var hr := height(x + e, z)
	var hb := height(x, z - e)
	var hf := height(x, z + e)
	return Vector3(hl - hr, 2.0 * e, hb - hf).normalized()


func kicker_at(z: float) -> Dictionary:
	for k in kickers:
		if absf(z - float(k.get("z", 0.0))) < 1.0:
			return k
	return {}


static func course_defs() -> Array:
	return [
		{
			"id": 0,
			"name": "ALPINE RUSH",
			"subtitle": "BLUEBIRD GROOMERS - FRIENDLY FLOW",
			"difficulty": "ROOKIE",
			"seed": 1337,
			"length": 2300.0,
			"drop": 400.0,
			"theme": 0,
			"path_amp": 26.0,
			"path_amp2": 11.0,
			"start_z": 14.0,
			"kickers": [
				{"z": 150.0, "w": 20.0, "len": 18.0, "h": 3.2, "x_off": 0.0},
				{"z": 320.0, "w": 22.0, "len": 22.0, "h": 4.6, "x_off": 0.0},
				{"z": 610.0, "w": 18.0, "len": 20.0, "h": 5.2, "x_off": -16.0},
				{"z": 940.0, "w": 24.0, "len": 24.0, "h": 5.8, "x_off": 10.0},
				{"z": 1250.0, "w": 20.0, "len": 22.0, "h": 5.4, "x_off": 0.0},
				{"z": 1580.0, "w": 20.0, "len": 22.0, "h": 5.8, "x_off": 18.0},
				{"z": 1900.0, "w": 24.0, "len": 24.0, "h": 6.2, "x_off": -8.0},
				{"z": 2160.0, "w": 24.0, "len": 22.0, "h": 4.4, "x_off": 0.0},
			],
			"rails": [
				{"z": 730.0, "len": 58.0, "x_off": 12.0, "h": 2.0},
				{"z": 1400.0, "len": 64.0, "x_off": -12.0, "h": 2.0},
				{"z": 2020.0, "len": 52.0, "x_off": 0.0, "h": 2.2},
			],
		},
		{
			"id": 1,
			"name": "MIDNIGHT MOGULS",
			"subtitle": "NEON NIGHT RUN - SHARP AND STEEP",
			"difficulty": "PRO",
			"seed": 424242,
			"length": 2450.0,
			"drop": 470.0,
			"theme": 1,
			"path_amp": 34.0,
			"path_amp2": 15.0,
			"start_z": 14.0,
			"kickers": [
				{"z": 170.0, "w": 20.0, "len": 18.0, "h": 3.4, "x_off": 0.0},
				{"z": 300.0, "w": 20.0, "len": 22.0, "h": 4.8, "x_off": 0.0},
				{"z": 560.0, "w": 18.0, "len": 20.0, "h": 5.6, "x_off": 16.0},
				{"z": 820.0, "w": 22.0, "len": 24.0, "h": 6.4, "x_off": -12.0},
				{"z": 1120.0, "w": 20.0, "len": 22.0, "h": 6.0, "x_off": 0.0},
				{"z": 1420.0, "w": 18.0, "len": 20.0, "h": 6.8, "x_off": 20.0},
				{"z": 1720.0, "w": 22.0, "len": 24.0, "h": 6.2, "x_off": -18.0},
				{"z": 2020.0, "w": 24.0, "len": 24.0, "h": 7.0, "x_off": 0.0},
				{"z": 2280.0, "w": 22.0, "len": 22.0, "h": 5.0, "x_off": 10.0},
			],
			"rails": [
				{"z": 670.0, "len": 62.0, "x_off": 14.0, "h": 2.2},
				{"z": 1250.0, "len": 70.0, "x_off": -14.0, "h": 2.2},
				{"z": 1860.0, "len": 66.0, "x_off": 8.0, "h": 2.4},
			],
		},
		{
			"id": 2,
			"name": "GLACIER FURY",
			"subtitle": "SUNSET BIG MOUNTAIN - WIDE OPEN",
			"difficulty": "EXPERT",
			"seed": 90210,
			"length": 2650.0,
			"drop": 520.0,
			"theme": 2,
			"path_amp": 40.0,
			"path_amp2": 18.0,
			"start_z": 14.0,
			"kickers": [
				{"z": 180.0, "w": 22.0, "len": 20.0, "h": 3.8, "x_off": 0.0},
				{"z": 340.0, "w": 24.0, "len": 24.0, "h": 5.4, "x_off": 0.0},
				{"z": 640.0, "w": 22.0, "len": 24.0, "h": 7.0, "x_off": -20.0},
				{"z": 980.0, "w": 26.0, "len": 26.0, "h": 7.6, "x_off": 14.0},
				{"z": 1320.0, "w": 24.0, "len": 24.0, "h": 6.8, "x_off": 0.0},
				{"z": 1600.0, "w": 22.0, "len": 22.0, "h": 7.4, "x_off": 22.0},
				{"z": 1900.0, "w": 26.0, "len": 26.0, "h": 7.8, "x_off": -16.0},
				{"z": 2200.0, "w": 24.0, "len": 24.0, "h": 7.0, "x_off": 0.0},
				{"z": 2480.0, "w": 24.0, "len": 22.0, "h": 5.4, "x_off": 0.0},
			],
			"rails": [
				{"z": 760.0, "len": 70.0, "x_off": -16.0, "h": 2.4},
				{"z": 1450.0, "len": 74.0, "x_off": 16.0, "h": 2.4},
				{"z": 2100.0, "len": 70.0, "x_off": 0.0, "h": 2.6},
			],
		},
	]


static func get_theme(index: int) -> Dictionary:
	var themes := [
		{
			"name": "ALPINE",
			"sky_top": Color(0.16, 0.42, 0.78),
			"sky_horizon": Color(0.80, 0.89, 0.99),
			"ground": Color(0.55, 0.64, 0.80),
			"sun": Color(1.0, 0.96, 0.87),
			"sun_energy": 1.5,
			"sun_rot": Vector3(-42.0, 34.0, 0.0),
			"ambient": 0.6,
			"fog": Color(0.68, 0.79, 0.93),
			"fog_density": 0.0012,
			"snow": Color(0.80, 0.86, 0.96),
			"snow_deep": Color(0.47, 0.59, 0.82),
			"rock": Color(0.24, 0.26, 0.34),
			"tree": Color(0.09, 0.26, 0.20),
			"tree_snow": Color(0.90, 0.95, 1.0),
			"accent": Color(1.0, 0.36, 0.10),
			"accent2": Color(0.13, 0.80, 0.92),
			"groom": Color(0.88, 0.94, 1.0),
			"night": false,
			"tree_count": 540,
		},
		{
			"name": "MIDNIGHT",
			"sky_top": Color(0.02, 0.04, 0.12),
			"sky_horizon": Color(0.15, 0.20, 0.42),
			"ground": Color(0.04, 0.06, 0.14),
			"sun": Color(0.66, 0.78, 1.0),
			"sun_energy": 0.9,
			"sun_rot": Vector3(-38.0, 214.0, 0.0),
			"ambient": 0.5,
			"fog": Color(0.10, 0.14, 0.30),
			"fog_density": 0.0016,
			"snow": Color(0.72, 0.78, 0.95),
			"snow_deep": Color(0.30, 0.38, 0.62),
			"rock": Color(0.10, 0.12, 0.20),
			"tree": Color(0.05, 0.13, 0.16),
			"tree_snow": Color(0.74, 0.82, 1.0),
			"accent": Color(1.0, 0.16, 0.56),
			"accent2": Color(0.20, 0.88, 1.0),
			"groom": Color(0.72, 0.80, 1.0),
			"night": true,
			"tree_count": 470,
		},
		{
			"name": "GLACIER",
			"sky_top": Color(0.18, 0.09, 0.28),
			"sky_horizon": Color(0.98, 0.55, 0.38),
			"ground": Color(0.28, 0.14, 0.24),
			"sun": Color(1.0, 0.63, 0.38),
			"sun_energy": 1.4,
			"sun_rot": Vector3(-12.0, 128.0, 0.0),
			"ambient": 0.62,
			"fog": Color(0.78, 0.48, 0.50),
			"fog_density": 0.0012,
			"snow": Color(0.88, 0.80, 0.88),
			"snow_deep": Color(0.52, 0.44, 0.68),
			"rock": Color(0.24, 0.16, 0.24),
			"tree": Color(0.12, 0.08, 0.17),
			"tree_snow": Color(0.96, 0.86, 0.92),
			"accent": Color(1.0, 0.80, 0.20),
			"accent2": Color(1.0, 0.30, 0.20),
			"groom": Color(0.99, 0.88, 0.93),
			"night": false,
			"tree_count": 300,
		},
	]
	return themes[index % themes.size()]
