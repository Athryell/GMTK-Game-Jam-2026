## Title screen and level select. Buttons are built from `Game.level_scenes`
## and gated by `Game.is_unlocked()`.
extends Control

const GAME_SCENE := "res://scenes/main.tscn"

@onready var _grid: GridContainer = $Layout/Levels
@onready var _quit: Button = $Layout/Actions/Quit
@onready var _play: Button = $Layout/Actions/Play


func _ready() -> void:
	_play.pressed.connect(_on_play_pressed)
	_quit.pressed.connect(get_tree().quit)
	_build_level_buttons()
	_play.grab_focus()
	Audio.play_music("menu")


func _build_level_buttons() -> void:
	for i in Game.level_scenes.size():
		var button := Button.new()
		button.text = "%d — %s" % [i + 1, Game.level_names[i]]
		button.custom_minimum_size = Vector2(190.0, 40.0)
		button.disabled = not Game.is_unlocked(i)
		# `bind(i)` captures the index now, not the loop variable's final value.
		button.pressed.connect(_start.bind(i))
		_grid.add_child(button)


func _on_play_pressed() -> void:
	# Resumes at the furthest level reached rather than level 1.
	_start(clampi(Game.levels_reached, 0, maxi(Game.level_scenes.size() - 1, 0)))


func _start(index: int) -> void:
	if Game.level_scenes.is_empty():
		return
	Game.start_level(index)
	get_tree().change_scene_to_file(GAME_SCENE)
