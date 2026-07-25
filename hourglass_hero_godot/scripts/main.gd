## Conductor: loads the current level, drops the player into it, frames the
## camera, and moves on to death / next level.
extends Node2D

const PLAYER_SCENE := preload("res://scenes/entities/player.tscn")
const MENU_SCENE := "res://scenes/ui/main_menu.tscn"

@onready var _level_root: Node2D = $LevelRoot
@onready var _camera: Camera2D = $Camera2D
@onready var _background: ColorRect = $Background/ColorRect

var _level: Level
var _player: Player
var _clear_timer := 0.0


func _ready() -> void:
	Game.status_changed.connect(_on_status_changed)
	Game.plane_changed.connect(_on_plane_changed)
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

	_follow_player(delta)


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

	_apply_camera_limits()
	_camera.global_position = _clamped_camera_target()
	_camera.reset_smoothing()
	_on_plane_changed(Game.plane)
	Game.announce_level(_level.level_name)


## The two rules a level may bend for itself. Applied here rather than in
## `Game.start_level`, which runs before the scene exists and so has nothing to
## read them from.
func _apply_level_rules() -> void:
	Game.double_jump = _level.double_jump
	if _level.sand_start_override > 0.0:
		Game.sand = minf(_level.sand_start_override, Tuning.cfg.sand_max)


func _on_status_changed(status: Game.Status) -> void:
	if status == Game.Status.LEVEL_CLEAR:
		_clear_timer = Tuning.cfg.level_clear_delay


func _on_plane_changed(plane: Planes.Kind) -> void:
	# The backdrop shifts hue with the plane: you know where you are without
	# reading the HUD.
	var target := Palette.FRONT_BG if plane == Planes.Kind.FRONT else Palette.BACK_BG
	create_tween().tween_property(_background, "color", target, 0.18)


# ----- Camera ----------------------------------------------------------------

func _apply_camera_limits() -> void:
	var view := get_viewport_rect().size
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(maxf(_level.world_size.x, view.x))
	_camera.limit_bottom = int(maxf(_level.world_size.y, view.y))


func _clamped_camera_target() -> Vector2:
	var view := get_viewport_rect().size
	var target := _player.global_position
	# On a level smaller than the screen, centre it instead of hugging an edge.
	target.x = clampf(target.x, view.x / 2.0, maxf(_level.world_size.x - view.x / 2.0, view.x / 2.0))
	target.y = clampf(target.y, view.y / 2.0, maxf(_level.world_size.y - view.y / 2.0, view.y / 2.0))
	return target


func _follow_player(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var target := _clamped_camera_target()
	var smoothing := Tuning.cfg.camera_smoothing
	if smoothing <= 0.0:
		_camera.global_position = target
	else:
		_camera.global_position = _camera.global_position.lerp(
			target, 1.0 - exp(-smoothing * delta))
