class_name RiderDefs
extends RefCounted
## Playable riders: colour kits plus small stat differences.

static func all() -> Array:
	return [
		{
			"name": "AXEL",
			"tag": "ALL ROUNDER",
			"desc": "Balanced speed, spins and boost. The one to beat.",
			"stats": {"speed": 1.0, "spin": 1.0, "trick": 1.0, "boost": 1.0},
			"colors": RiderModel.default_colors(0),
		},
		{
			"name": "ROXY",
			"tag": "SPIN MACHINE",
			"desc": "Faster spins and bigger trick payouts, a touch slower in a tuck.",
			"stats": {"speed": 0.97, "spin": 1.3, "trick": 1.12, "boost": 1.0},
			"colors": RiderModel.default_colors(1),
		},
		{
			"name": "JETT",
			"tag": "SPEED FREAK",
			"desc": "Top-end speed and harder carves. Tricks pay a little less.",
			"stats": {"speed": 1.07, "spin": 0.92, "trick": 0.95, "boost": 0.9},
			"colors": RiderModel.default_colors(2),
		},
		{
			"name": "KODA",
			"tag": "BOOST JUNKIE",
			"desc": "Tricks fill the boost tank faster. Send it, then send it again.",
			"stats": {"speed": 1.0, "spin": 1.0, "trick": 1.0, "boost": 1.4},
			"colors": RiderModel.default_colors(3),
		},
	]


static func rival_defs() -> Array:
	return [
		{"name": "VEX", "speed": 31.4, "lateral": -12.0, "start_z": 12.0, "phase": 0.0, "colors": RiderModel.default_colors(4)},
		{"name": "MILA", "speed": 30.8, "lateral": -5.0, "start_z": 15.0, "phase": 1.7, "colors": RiderModel.default_colors(5)},
		{"name": "DIESEL", "speed": 32.0, "lateral": 6.0, "start_z": 11.0, "phase": 3.1, "colors": RiderModel.default_colors(2)},
		{"name": "NOVA", "speed": 30.4, "lateral": 13.0, "start_z": 13.5, "phase": 4.4, "colors": RiderModel.default_colors(3)},
		{"name": "TALON", "speed": 31.0, "lateral": 18.0, "start_z": 10.0, "phase": 5.6, "colors": RiderModel.default_colors(1)},
	]
