## Autoload `Audio` — everything the game plays, and how loud.
##
## Sounds are found by NAME, never by reference: `Audio.sfx("jump")` plays
## `res://audio/sfx/jump.ogg`. Dropping a file into the folder is the whole
## registration step — the same bargain `scenes/levels/` already gets, for the
## same reason. A list someone has to remember to update is a list that goes
## stale, and the failure is silent.
##
## A name with no file behind it is not an error: it warns ONCE and plays
## nothing. That is what lets the call sites be wired now and the audio arrive
## later, in any order, without the game ever refusing to run.
##
## Volume is not kept here. It lives on the AudioServer's buses (Master, Music,
## SFX), which is what makes it one line for a slider to move and one line for
## anything else to read. This owns the mapping from a 0..1 slider to decibels,
## and the settings file that survives a restart.
extends Node

const SFX_DIR := "res://audio/sfx"
const MUSIC_DIR := "res://audio/music"

## Looked for in this order, so a hand-authored .wav can shadow an exported .ogg
## of the same name without anything to configure.
const EXTENSIONS := ["ogg", "wav", "mp3"]

## The buses, in the order a settings UI should show them. Master first because
## it is the one that means "all of it".
const BUSES := ["Master", "Music", "SFX"]

## Simultaneous one-shots. Past this the oldest voice is reused — a hard cap is
## what stops a spike of deaths from turning into a wall of noise, and stealing
## the OLDEST is the only choice a player never notices.
const SFX_VOICES := 12

## Below this a slider reads as off, and the bus is muted outright rather than
## left at a very small gain — `linear_to_db(0)` is -inf, which is not a number
## an AudioServer accepts.
const SILENCE := 0.001

const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "audio"

## A bus's volume moved. The settings UI listens so two sliders onto the same
## bus can never disagree.
signal volume_changed(bus: String, linear: float)

var _sfx_players: Array[AudioStreamPlayer] = []
var _next_voice := 0

var _music_player: AudioStreamPlayer
## What `play_music` was last asked for. Guards the common case of asking for
## the track that is already playing — restarting it would be audible.
var _music_track := ""
var _music_fade: Tween

## Full path → AudioStream, and null for "looked, not there". Caching the misses
## is the point: it costs one warning instead of one per frame.
var _cache: Dictionary = {}


func _ready() -> void:
	# Autoloads are paused last and we want menus to keep their sound, but more
	# importantly a death jingle must not be cut off by the freeze that follows it.
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

## A one-shot. `pitch_jitter` spreads the pitch randomly by ±that fraction:
## footsteps and landings played at exactly one pitch turn into a machine gun
## after the third repeat, and a few percent of scatter is all it takes to stop.
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


## Starts a looping track, crossfading from whatever was playing. Asking for the
## track already playing does nothing, so a level reload does not restart the
## music under the player.
func play_music(track: String, fade := 0.8) -> void:
	if track == _music_track and _music_player.playing:
		return
	var stream := _stream(MUSIC_DIR, track)
	if stream == null:
		# Remember the ask anyway: without this, every reload of a level whose
		# track is missing warns again through a cold `_music_track`.
		_music_track = track
		return
	_music_track = track
	_swap_music(stream, fade)


func stop_music(fade := 0.8) -> void:
	_music_track = ""
	_swap_music(null, fade)


## Fades the current track out, puts `stream` in its place, fades back up. One
## player rather than two: a true crossfade needs both tracks audible at once,
## which for a game with one track playing at a time is machinery nobody hears.
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
		# Music has to loop and the importer does not turn that on by itself.
		# Doing it here rather than asking every track for the right .import
		# setting is one less thing to get wrong per file.
		found.loop = dir == MUSIC_DIR

	_cache[key] = found
	return found


# ----- Volume ----------------------------------------------------------------

## `linear` is 0..1, the number a slider holds. Decibels are what the mixer
## wants, and the conversion living here is what keeps every UI that touches
## volume from having to know about them.
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
# Under user://, not res://: an exported build cannot write to its own data, and
# a player's volume is theirs rather than the project's.

func _load_settings() -> void:
	var file := ConfigFile.new()
	if file.load(SETTINGS_PATH) != OK:
		return
	for bus in BUSES:
		if file.has_section_key(SETTINGS_SECTION, bus):
			# Straight to the bus: routing through `set_volume` would emit and
			# re-save once per bus while loading.
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
	# Load first so this never clobbers settings another part of the game owns.
	file.load(SETTINGS_PATH)
	for bus in BUSES:
		file.set_value(SETTINGS_SECTION, bus, get_volume(bus))
	file.save(SETTINGS_PATH)
