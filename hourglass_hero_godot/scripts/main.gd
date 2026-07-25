## Lifecycle conductor: loads the current level, spawns the player, frames the
## camera, and advances on death / level clear.
extends Node2D

const PLAYER_SCENE := preload("res://scenes/entities/player.tscn")
const MENU_SCENE := "res://scenes/ui/main_menu.tscn"

@onready var _level_root: Node2D = $LevelRoot
@onready var _camera: CameraRig = $Camera2D
@onready var _backdrop: Backdrop = $Backdrop
# Must sit between Backdrop and LevelRoot in the tree, so slabs draw over their
# own shadows.
@onready var _shadows: CastShadows = $CastShadows
@onready var _world_light: CanvasModulate = $WorldLight

var _level: Level
var _player: Player
## Countdown to the next level / retry. Zero while playing.
var _advance_timer := 0.0


func _ready() -> void:
	Game.status_changed.connect(_on_status_changed)
	Tuning.changed.connect(_apply_world_light)
	_apply_world_light()
	# `start_level` arms the state (sand, plane, status); `_load_current_level`
	# only instantiates the scene. Index comes from the menu, 0 when run standalone.
	Game.start_level(Game.level_index)
	_load_current_level()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("menu"):
		get_tree().change_scene_to_file(MENU_SCENE)
		return

	if Input.is_action_just_pressed("restart"):
		Game.restart()
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
	# Both edges: a gravity pad can send you out through the top just as easily.
	_player.death_top = -Tuning.cfg.fall_death_margin
	_player.death_bottom = _level.world_size.y + Tuning.cfg.fall_death_margin

	_backdrop.configure(_level.world_size)
	_shadows.configure(_level)
	_shadows.lamp = _player

	_camera.target = _player
	_camera.frame(_level.world_size)
	_camera.snap()
	_backdrop.sync(_camera.global_position)

	# `play_music` ignores a track already playing, so this does not restart it.
	Audio.play_music("level")
	Game.announce_level(_level.level_name)


## Per-level rule overrides. Applied here, not in `Game.start_level`, which runs
## before the level scene exists.
func _apply_level_rules() -> void:
	Game.double_jump = _level.double_jump
	# Every level starts the right way up; only a pad inside it turns the world.
	Game.set_gravity(1.0)
	var top := _level.sand_start_override if _level.sand_start_override > 0.0 \
		else Tuning.cfg.sand_start
	Game.arm_glass(_level.chambers, top)


## Ambient darkness before the lights, tinted slightly blue rather than grey.
func _apply_world_light() -> void:
	var v := Tuning.cfg.world_light
	_world_light.color = Color(v, v, minf(v * 1.14, 1.0))


## Fires when `_advance_timer` runs out: retry on death, next level otherwise.
func _advance() -> void:
	if Game.status == Game.Status.DEAD:
		Game.restart()
	else:
		Game.next_level()
		# Run is over; nothing left to load.
		if Game.status == Game.Status.VICTORY:
			return
	_load_current_level()


func _on_status_changed(status: Game.Status) -> void:
	match status:
		# Must disarm, or a manual `R` gets followed by a second restart.
		Game.Status.PLAY:
			_advance_timer = 0.0
		Game.Status.LEVEL_CLEAR:
			_advance_timer = Tuning.cfg.level_clear_delay
			Audio.sfx("win")
		Game.Status.DEAD:
			_advance_timer = Tuning.cfg.death_delay
