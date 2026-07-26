## Lifecycle conductor: loads the current level, spawns the player, frames the
## camera, and advances on death / level clear.
extends Node2D

const PLAYER_SCENE := preload("res://scenes/entities/player.tscn")
const MENU_SCENE := "res://scenes/ui/main_menu.tscn"

## One track per background, in the order the backgrounds are reached. An empty
## name here would be deliberate silence rather than a missing entry; every
## background has its own track now, so there are none.
const LEVEL_TRACKS: Array[String] = [
	"return_8_bit", "techno_polka", "game_8_bit", "colors_everywhere"]

@onready var _level_root: Node2D = $LevelRoot
@onready var _camera: CameraRig = $Camera2D
@onready var _backdrop: Backdrop = $Backdrop
@onready var _shadows: CastShadows = $CastShadows
@onready var _world_light: CanvasModulate = $WorldLight
@onready var _transition: Transition = $Transition

var _level: Level
var _player: Player
## Countdown to the next level / retry. Zero while playing.
var _advance_timer := 0.0
## Whether the load that follows should open the curtain. A retry never closed
## it, and must not fade in on nothing.
var _entering_level := false


func _ready() -> void:
	Game.status_changed.connect(_on_status_changed)
	Game.flow_changed.connect(_on_flow_changed)
	Tuning.changed.connect(_apply_world_light)
	_apply_world_light()
	Game.start_level(Game.level_index)
	# The menu hands over on a hard cut; come out of the dark like any other level.
	_transition.close(0.0)
	_entering_level = true
	_load_current_level()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("menu"):
		get_tree().change_scene_to_file(MENU_SCENE)
		return

	if Input.is_action_just_pressed("restart"):
		Game.restart()
		_transition.clear()
		_load_current_level()
		return

	if _advance_timer > 0.0:
		_advance_timer -= delta
		if _advance_timer <= 0.0:
			_advance()

	# Must run after the camera has moved this frame, or the walls judder.
	_backdrop.sync(_camera.global_position)


# ----- Loading ---------------------------------------------------------------

func _load_current_level() -> void:
	if Game.level_scenes.is_empty():
		return
	for child in _level_root.get_children():
		child.queue_free()

	_level = Game.level_scenes[Game.level_index].instantiate() as Level
	_level_root.add_child(_level)
	_apply_level_rules()

	_player = PLAYER_SCENE.instantiate() as Player
	# Child of the level, not the root, so a reload wipes it with everything else.
	_level.add_child(_player)
	_player.global_position = _level.spawn.global_position
	# Both edges: a gravity pad can send you out through the top.
	_player.death_top = -Tuning.cfg.fall_death_margin
	_player.death_bottom = _level.world_size.y + Tuning.cfg.fall_death_margin

	_shadows.configure(_level)

	_camera.target = _player
	_camera.frame(_level.world_size)
	_camera.snap()
	# After the snap: where the art is planted depends on what the camera frames.
	_backdrop.configure(_level, Game.level_index, _camera.view_bottom())
	_backdrop.sync(_camera.global_position)

	# The music belongs to the background, so a track lasts exactly as long as the
	# place it plays in. `play_music` ignores a repeat, so walking from one level
	# to the next inside a background does not restart it; only crossing into the
	# next one swaps the track.
	var track := LEVEL_TRACKS[clampi(Backdrop.group_for_level(Game.level_index),
		0, LEVEL_TRACKS.size() - 1)]
	if track.is_empty():
		Audio.stop_music()
	else:
		Audio.play_music(track)
	Game.announce_level(_level.level_name)

	# After the announce, so the level's name is on the HUD as it comes into view.
	if _entering_level:
		_entering_level = false
		_transition.open(Tuning.cfg.level_fade)


## Applied here, not in `Game.start_level`, which runs before the level exists.
func _apply_level_rules() -> void:
	Game.clock_running = not _level.clock_starts_on_move
	Game.jump_locked_first_life = _level.jump_locked_first_life
	Game.set_gravity(1.0)
	var top := _level.sand_start_override if _level.sand_start_override > 0.0 \
		else Tuning.cfg.sand_start
	Game.arm_glass(_level.chambers, top)


func _apply_world_light() -> void:
	var v := Tuning.cfg.world_light
	_world_light.color = Color(v, v, minf(v * 1.14, 1.0))


func _advance() -> void:
	if Game.status == Game.Status.DEAD:
		Game.restart()
	else:
		Game.next_level()
		# Run is over; nothing left to load, so the curtain has to lift on the
		# victory screen instead.
		if Game.status == Game.Status.VICTORY:
			_entering_level = false
			_transition.open(Tuning.cfg.level_fade)
			return
	_load_current_level()


## An inversion zone reverses the sand rather than gravity, but it is sold to
## the player as gravity, so it borrows the pads' pair of sounds.
func _on_flow_changed(flow: float) -> void:
	Audio.sfx("gravity_up" if flow < 0.0 else "gravity_down")


func _on_status_changed(status: Game.Status) -> void:
	match status:
		# Must disarm, or a manual `R` gets followed by a second restart.
		Game.Status.PLAY:
			_advance_timer = 0.0
		Game.Status.LEVEL_CLEAR:
			_advance_timer = Tuning.cfg.level_clear_delay
			_entering_level = true
			# Never longer than the delay, or the swap happens in plain sight.
			_transition.close(minf(Tuning.cfg.level_fade, Tuning.cfg.level_clear_delay))
		Game.Status.DEAD:
			_advance_timer = Tuning.cfg.death_delay
