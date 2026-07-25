## Conductor: loads the current level, drops the player into it, fits the room
## and the camera around it, and moves on to death / next level.
##
## The camera's own behaviour lives in `CameraRig`, and the scenery's in
## `Backdrop`. What is left here is the lifecycle: who exists, when, and what
## happens next.
extends Node2D

const PLAYER_SCENE := preload("res://scenes/entities/player.tscn")
const MENU_SCENE := "res://scenes/ui/main_menu.tscn"

@onready var _level_root: Node2D = $LevelRoot
@onready var _camera: CameraRig = $Camera2D
@onready var _backdrop: Backdrop = $Backdrop
@onready var _foreground: ParallaxWall = $Foreground
@onready var _world_light: CanvasModulate = $WorldLight

var _level: Level
var _player: Player
var _clear_timer := 0.0


func _ready() -> void:
	Game.status_changed.connect(_on_status_changed)
	Tuning.changed.connect(_apply_world_light)
	_apply_world_light()
	# `start_level` arms the state (sand, plane, status); `_load_current_level`
	# only instantiates the matching scene. The index comes from the menu — it
	# stays 0 when this scene is run on its own.
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

	if Game.status == Game.Status.LEVEL_CLEAR:
		_clear_timer -= delta
		if _clear_timer <= 0.0:
			Game.next_level()
			if Game.status != Game.Status.VICTORY:
				_load_current_level()

	# After the camera has moved this frame, never before: the parallax layers
	# are placed relative to it, and reading last frame's position puts the
	# scenery one frame behind the level it sits behind — which shows up as the
	# walls juddering whenever you run.
	_backdrop.sync(_camera.global_position)
	_foreground.sync(_camera.global_position)


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
	# Added to the level rather than to the root: reloading the level wipes
	# everything in one go, with no leftover state.
	_level.add_child(_player)
	_player.global_position = _level.spawn.global_position
	_player.death_y = _level.world_size.y + Tuning.cfg.fall_death_margin

	_backdrop.configure(_level.world_size)
	_foreground.configure(_level.world_size, Palette.FOREGROUND)

	_camera.target = _player
	_camera.frame(_level.world_size)
	_camera.snap()
	_backdrop.sync(_camera.global_position)
	_foreground.sync(_camera.global_position)

	Game.announce_level(_level.level_name)


## The two rules a level may bend for itself. Applied here rather than in
## `Game.start_level`, which runs before the scene exists and so has nothing to
## read them from.
func _apply_level_rules() -> void:
	Game.double_jump = _level.double_jump
	if _level.sand_start_override > 0.0:
		Game.sand = minf(_level.sand_start_override, Tuning.cfg.sand_max)


## How dark the world sits before the lights are added. Tinted slightly blue
## rather than a flat grey: an unlit corner of a room is cold, and a neutral
## multiply makes the whole game look like someone turned the brightness down.
func _apply_world_light() -> void:
	var v := Tuning.cfg.world_light
	_world_light.color = Color(v, v, minf(v * 1.14, 1.0))


func _on_status_changed(status: Game.Status) -> void:
	if status == Game.Status.LEVEL_CLEAR:
		_clear_timer = Tuning.cfg.level_clear_delay
