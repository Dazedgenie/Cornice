class_name AudioDirector
extends Node
## Loads the CC0 soundtrack and drives all sound effects.
##
## Menu, race and Trick Attack each have their own looping track. Two
## AudioStreamPlayers crossfade between them when the game changes state. A
## dedicated Music bus carries the saved volume slider without touching SFX.

const MUSIC_TRACKS := {
	"menu": "res://audio/music_menu.ogg",
	"race": "res://audio/music_race.mp3",
	"trick": "res://audio/music_trick.mp3",
}
const FALLBACK_MUSIC := "res://audio/music.wav"
const MUSIC_BUS := "Music"
const DEFAULT_MUSIC_VOLUME := 1.0
const MUSIC_DB := {
	"menu": -19.0,
	"race": -14.0,
	"trick": -15.0,
}
const CROSSFADE := 0.8

var streams: Dictionary = {}
var music: Array[AudioStreamPlayer] = []
var active_music := 0
var current_music := ""
var wind: AudioStreamPlayer
var pool: Array[AudioStreamPlayer] = []
var pool_index := 0
var music_volume := DEFAULT_MUSIC_VOLUME
var muted := false
var _race_active := false
var _music_tween: Tween = null


func _ready() -> void:
	_load_stream("wind", "res://audio/wind.wav", true)
	_load_stream("music_fallback", FALLBACK_MUSIC, true)
	for key in MUSIC_TRACKS:
		_load_stream("music_" + key, String(MUSIC_TRACKS[key]), true)
	for n in ["trick", "land", "jump", "boost", "crash", "rail", "beep", "go", "finish"]:
		_load_stream(n, "res://audio/%s.wav" % n, false)

	wind = AudioStreamPlayer.new()
	wind.stream = streams.get("wind")
	wind.volume_db = -60.0
	add_child(wind)
	if wind.stream:
		wind.play()

	_ensure_music_bus()
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = -60.0
		p.bus = MUSIC_BUS
		add_child(p)
		music.append(p)

	set_music_volume(music_volume)

	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)


func _load_stream(key: String, path: String, loop: bool) -> void:
	if not ResourceLoader.exists(path):
		return
	var s: Resource = load(path)
	if s == null:
		return
	if loop:
		if s is AudioStreamWAV:
			var wav := s as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(wav.get_length() * float(wav.mix_rate))
		elif s is AudioStreamOggVorbis:
			var ogg := s as AudioStreamOggVorbis
			ogg.loop = true
			ogg.loop_offset = 0.0
		elif s is AudioStreamMP3:
			var mp3 := s as AudioStreamMP3
			mp3.loop = true
			mp3.loop_offset = 0.0
	streams[key] = s


func _music_stream(key: String) -> AudioStream:
	var stream_key := "music_" + key
	if streams.has(stream_key):
		return streams[stream_key] as AudioStream
	return streams.get("music_fallback") as AudioStream


func _switch_music(key: String) -> void:
	var stream := _music_stream(key)
	if stream == null:
		return

	var active := music[active_music]
	if current_music == key and active.playing:
		_fade_player(active, float(MUSIC_DB.get(key, -15.0)))
		return

	var old := active
	active_music = (active_music + 1) % music.size()
	var next := music[active_music]

	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()

	next.stop()
	next.stream = stream
	next.volume_db = -60.0
	next.play()
	current_music = key

	_music_tween = create_tween()
	_music_tween.set_parallel(true)
	_music_tween.tween_property(old, "volume_db", -60.0, CROSSFADE)
	_music_tween.tween_property(next, "volume_db", float(MUSIC_DB.get(key, -15.0)), CROSSFADE)


func _fade_player(player: AudioStreamPlayer, target_db: float) -> void:
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(player, "volume_db", target_db, CROSSFADE)


func play(key: String, pitch := 1.0, volume_db := 0.0) -> void:
	if muted or not streams.has(key):
		return
	var p := pool[pool_index]
	pool_index = (pool_index + 1) % pool.size()
	p.stream = streams[key]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


func play_menu() -> void:
	_race_active = false
	_switch_music("menu")
	if wind:
		_fade_wind(-24.0)


func start_race(mode := 0) -> void:
	_race_active = true
	_switch_music("trick" if mode == 1 else "race")
	if wind:
		_fade_wind(-16.0)


func set_speed(speed: float, grounded: bool) -> void:
	if wind == null or not _race_active:
		return
	var t := clampf(speed / 42.0, 0.0, 1.0)
	var target := lerpf(-25.0, -7.0, t)
	if not grounded:
		target -= 2.0
	wind.volume_db = lerpf(wind.volume_db, target, 0.08)
	wind.pitch_scale = lerpf(wind.pitch_scale, 0.75 + t * 0.55, 0.05)


func stop_race_audio() -> void:
	_race_active = false
	for p in music:
		var tw := create_tween()
		tw.tween_property(p, "volume_db", -60.0, CROSSFADE)
	if wind:
		_fade_wind(-60.0)


func set_paused(paused: bool) -> void:
	for p in music:
		p.stream_paused = paused
	if wind:
		wind.stream_paused = paused


func toggle_mute() -> bool:
	muted = not muted
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)
	return muted


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	var bus := _ensure_music_bus()
	if bus < 0:
		return
	AudioServer.set_bus_mute(bus, music_volume <= 0.001)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(music_volume, 0.001)))


func _ensure_music_bus() -> int:
	var bus := AudioServer.get_bus_index(MUSIC_BUS)
	if bus >= 0:
		return bus
	AudioServer.add_bus()
	bus = AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus, MUSIC_BUS)
	AudioServer.set_bus_send(bus, "Master")
	return bus


func _fade_wind(target: float) -> void:
	var tw := create_tween()
	tw.tween_property(wind, "volume_db", target, CROSSFADE)
