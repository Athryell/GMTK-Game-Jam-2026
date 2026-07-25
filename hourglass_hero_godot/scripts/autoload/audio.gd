## Autoload `Audio` — sound playback and bus volumes.
## Every sound is an AudioStreamPlayer inside `sound_bank.tscn`, named after the
## id the game asks for. Stream, volume, pitch and bus are set on that player in
## the Inspector; nothing here overrides them. A name with no player warns once
## and plays nothing. Volume lives on the AudioServer buses, not here.
extends Node

const SOUND_BANK := preload("res://audio/sound_bank.tscn")

## Bus names — must match the buses in the project's audio bus layout.
const BUSES := ["Master", "Music", "SFX"]

## Below this the bus is muted outright: `linear_to_db(0)` is -inf.
const SILENCE := 0.001

const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "audio"

## A bus's volume moved; lets several volume UIs stay in sync.
signal volume_changed(bus: String, linear: float)

var _sfx_bank: Node
var _music_bank: Node

var _music_player: AudioStreamPlayer
## What `play_music` was last asked for; avoids restarting the current track.
var _music_track := ""
var _music_fade: Tween
## The bank's volume for the current track; the fade tweens back up to it.
var _music_volume_db := 0.0

## Names already complained about, so a miss warns once rather than every frame.
var _warned: Dictionary = {}


func _ready() -> void:
	# Keep playing while the tree is paused (menus, death freeze).
	process_mode = Node.PROCESS_MODE_ALWAYS

	var bank := SOUND_BANK.instantiate()
	add_child(bank)
	_sfx_bank = bank.get_node_or_null("Sfx")
	_music_bank = bank.get_node_or_null("Music")

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	_music_player.name = "Music"
	add_child(_music_player)

	_load_settings()


# ----- Playing ---------------------------------------------------------------

## A one-shot, played exactly as the bank has it set up.
func sfx(sound_name: String) -> void:
	var player := _bank_player(_sfx_bank, "Sfx", sound_name)
	if player == null:
		return
	if not player.playing:
		player.play()
		return
	# Already ringing. Play a copy so the running voice is not cut off, and keep
	# the bank player as the template — the Inspector stays the only place these
	# values live, and there is no pool size to guess at.
	var voice := player.duplicate() as AudioStreamPlayer
	add_child(voice)
	voice.finished.connect(voice.queue_free)
	voice.play()


## Starts a looping track, fading from whatever was playing. Re-asking for the
## current track does nothing. The bank player is not played: one track at a
## time has to fade, so its stream and volume are borrowed by the player here.
func play_music(track: String, fade := 0.8) -> void:
	if track == _music_track and _music_player.playing:
		return
	var player := _bank_player(_music_bank, "Music", track)
	# Remember the ask even on a miss, so it does not warn again on every reload.
	_music_track = track
	if player == null or player.stream == null:
		return
	_music_volume_db = player.volume_db
	_music_player.pitch_scale = player.pitch_scale
	_swap_music(player.stream, fade)


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
		# The importer does not set looping, and a track that stops mid-run is
		# worse than one that repeats.
		if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
			stream.loop = true
		_music_player.stream = stream
		_music_player.play()

	if fade <= 0.0 or not _music_player.playing:
		_music_player.volume_db = _music_volume_db
		start.call()
		return

	_music_fade = create_tween()
	_music_fade.tween_property(_music_player, "volume_db", linear_to_db(SILENCE), fade * 0.5)
	_music_fade.tween_callback(start)
	_music_fade.tween_property(_music_player, "volume_db", _music_volume_db, fade * 0.5)


## The bank player for a name, or null.
func _bank_player(container: Node, kind: String, sound_name: String) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = null
	if container != null:
		player = container.get_node_or_null(NodePath(sound_name)) as AudioStreamPlayer
	if player == null:
		var key := "%s/%s" % [kind, sound_name]
		if not _warned.has(key):
			_warned[key] = true
			push_warning("Audio: no player named '%s' in the sound bank" % key)
	return player


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
