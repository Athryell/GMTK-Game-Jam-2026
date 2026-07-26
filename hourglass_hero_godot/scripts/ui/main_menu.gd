## Title screen and level select. Buttons are built from `Game.level_scenes`
## and gated by `Game.is_unlocked()`.
extends Control

const GAME_SCENE := "res://scenes/main.tscn"

@onready var _grid: GridContainer = $Layout/LevelScroll/Levels
@onready var _quit: Button = $Layout/Actions/Quit
@onready var _play: Button = $Layout/Actions/Play
@onready var _cheat: CheckBox = $Layout/Cheat

var _buttons: Array[Button] = []


func _ready() -> void:
	_play.pressed.connect(_on_play_pressed)
	_quit.pressed.connect(get_tree().quit)
	_cheat.set_pressed_no_signal(Game.cheat_mode)
	_cheat.toggled.connect(_on_cheat_toggled)
	_build_level_buttons()
	_play.grab_focus()
	Audio.play_music("menu")


func _build_level_buttons() -> void:
	for i in Game.level_scenes.size():
		var button := Button.new()
		button.text = "%d — %s" % [i + 1, Game.level_names[i]]
		button.custom_minimum_size = Vector2(190.0, 34.0)
		# `bind(i)` captures the index now, not the loop variable's final value.
		button.pressed.connect(_start.bind(i))
		_grid.add_child(button)
		_buttons.append(button)
	_apply_locks()


func _apply_locks() -> void:
	for i in _buttons.size():
		_buttons[i].disabled = not Game.is_unlocked(i)


func _on_cheat_toggled(on: bool) -> void:
	Game.set_cheat_mode(on)
	_apply_locks()


func _on_play_pressed() -> void:
	# Resumes at the furthest level unlocked rather than level 1.
	_start(Game.resume_index())


func _start(index: int) -> void:
	if Game.level_scenes.is_empty():
		return
	Game.start_run(index)
	get_tree().change_scene_to_file(GAME_SCENE)
