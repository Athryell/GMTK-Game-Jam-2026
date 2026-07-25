## Autoload `Audio` — sound playback and bus volumes.
## Sounds are resolved by name from the folders below; a missing file warns once
## and plays nothing. Volume lives on the AudioServer buses, not here.
extends Node

const SFX_DIR := "res://audio/sfx"
const MUSIC_DIR := "res://audio/music"

## Tried in this order; first hit wins.
const EXTENSIONS := ["ogg", "wav", "mp3"]

## Bus names — must match the buses in the project's audio bus layout.
const BUSES := ["Master", "Music", "SFX"]

## Simultaneous one-shots; past this the oldest voice is reused.
const SFX_VOICES := 12

## Below this the bus is muted outright: `linear_to_db(0)` is -inf.
const SILENCE := 0.001

const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "audio"

## A bus's volume moved; lets several volume UIs stay in sync.
signal volume_changed(bus: String, linear: float)

var _sfx_players: Array[AudioStreamPlayer] = []
var _next_voice := 0

var _music_player: AudioStreamPlayer
## What `play_music` was last asked for; avoids restarting the current track.
var _music_track := ""
var _music_fade: Tween

## Full path → AudioStream; misses are cached as null so they warn only once.
var _cache: Dictionary = {}


func _ready() -> void:
	# Keep playing while the tree is paused (menus, death freeze).
	process_mode = Node.PROCESS_MODE_ALWAYS

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	_music_player.name = "Music"
	add_child(_music_player)

	for i in SFX_VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		player.name = "Sfx%d" % i
		add_child(player)
		_sfx_players.append(player)

	_load_settings()


# ----- Playing ---------------------------------------------------------------

## A one-shot. `pitch_jitter` randomises pitch by ±that fraction.
func sfx(sound_name: String, volume_db := 0.0, pitch_jitter := 0.0) -> void:
	var stream := _stream(SFX_DIR, sound_name)
	if stream == null:
		return
	var player := _sfx_players[_next_voice]
	_next_voice = (_next_voice + 1) % _sfx_players.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.play()


## Starts a looping track, fading from whatever was playing. Re-asking for the
## current track does nothing.
func play_music(track: String, fade := 0.8) -> void:
	if track == _music_track and _music_player.playing:
		return
	var stream := _stream(MUSIC_DIR, track)
	if stream == null:
		# Remember the ask so a missing track does not warn again on every reload.
		_music_track = track
		return
	_music_track = track
	_swap_music(stream, fade)


func stop_music(fade := 0.8) -> void:
	_music_track = ""
	_swap_music(null, fade)


## Fades the current track out, swaps in `stream`, fades back up (single player,
## so not a true crossfade).
func _swap_music(stream: AudioStream, fade: float) -> void:
	if _music_fade != null and _music_fade.is_valid():
		_music_fade.kill()

	var start := func() -> void:
		if stream == null:
			_music_player.stop()
			return
		_music_player.stream = stream
		_music_player.play()

	if fade <= 0.0 or not _music_player.playing:
		_music_player.volume_db = 0.0
		start.call()
		return

	_music_fade = create_tween()
	_music_fade.tween_property(_music_player, "volume_db", linear_to_db(SILENCE), fade * 0.5)
	_music_fade.tween_callback(start)
	_music_fade.tween_property(_music_player, "volume_db", 0.0, fade * 0.5)


## The stream behind a name, or null. Both the hit and the miss are cached.
func _stream(dir: String, sound_name: String) -> AudioStream:
	var key := "%s/%s" % [dir, sound_name]
	if _cache.has(key):
		return _cache[key]

	var found: AudioStream = null
	for ext in EXTENSIONS:
		var path := "%s.%s" % [key, ext]
		if ResourceLoader.exists(path):
			found = load(path) as AudioStream
			break
	if found == null:
		push_warning("Audio: nothing named '%s' in %s (tried .%s)"
			% [sound_name, dir, ", .".join(EXTENSIONS)])
	elif found is AudioStreamOggVorbis or found is AudioStreamMP3:
		# The importer does not set looping; music must loop, sfx must not.
		found.loop = dir == MUSIC_DIR

	_cache[key] = found
	return found


# ----- Volume ----------------------------------------------------------------

## `linear` is 0..1 (slider units); converted to dB here.
func set_volume(bus: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		push_warning("Audio: no bus named '%s'" % bus)
		return
	linear = clampf(linear, 0.0, 1.0)
	var silent := linear < SILENCE
	AudioServer.set_bus_mute(index, silent)
	if not silent:
		AudioServer.set_bus_volume_db(index, linear_to_db(linear))
	volume_changed.emit(bus, linear)
	_save_settings()


func get_volume(bus: String) -> float:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return 0.0
	if AudioServer.is_bus_mute(index):
		return 0.0
	return clampf(db_to_linear(AudioServer.get_bus_volume_db(index)), 0.0, 1.0)


# ----- Settings --------------------------------------------------------------
# Under user://: an exported build cannot write to res://.

func _load_settings() -> void:
	var file := ConfigFile.new()
	if file.load(SETTINGS_PATH) != OK:
		return
	for bus in BUSES:
		if file.has_section_key(SETTINGS_SECTION, bus):
			# `_apply`, not `set_volume`: that would emit and re-save per bus.
			_apply(bus, float(file.get_value(SETTINGS_SECTION, bus)))


func _apply(bus: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	linear = clampf(linear, 0.0, 1.0)
	var silent := linear < SILENCE
	AudioServer.set_bus_mute(index, silent)
	if not silent:
		AudioServer.set_bus_volume_db(index, linear_to_db(linear))


func _save_settings() -> void:
	var file := ConfigFile.new()
	# Load first so other sections of the settings file are preserved.
	file.load(SETTINGS_PATH)
	for bus in BUSES:
		file.set_value(SETTINGS_SECTION, bus, get_volume(bus))
	file.save(SETTINGS_PATH)
