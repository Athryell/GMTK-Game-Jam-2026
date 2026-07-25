## Title screen and level select.
##
## The level buttons are built from `Game.level_scenes`, so dropping a new
## `.tscn` into `scenes/levels/` makes it appear here on the next run — there is
## no list to maintain. Whether a level can be picked is `Game.is_unlocked()`;
## today that always says yes.
extends Control

const GAME_SCENE := "res://scenes/main.tscn"
const COLUMNS := 3

@onready var _grid: GridContainer = $Layout/Levels
@onready var _quit: Button = $Layout/Actions/Quit
@onready var _play: Button = $Layout/Actions/Play


func _ready() -> void:
	_grid.columns = COLUMNS
	_play.pressed.connect(_on_play_pressed)
	_quit.pressed.connect(get_tree().quit)
	_build_level_buttons()
	_play.grab_focus()


func _build_level_buttons() -> void:
	for child in _grid.get_children():
		child.queue_free()

	for i in Game.level_scenes.size():
		var button := Button.new()
		button.text = "%d — %s" % [i + 1, Game.level_names[i]]
		button.custom_minimum_size = Vector2(190.0, 40.0)
		button.disabled = not Game.is_unlocked(i)
		# `i` is bound now: without it every button would read the loop variable
		# after the loop ended and all of them would start the last level.
		button.pressed.connect(_start.bind(i))
		_grid.add_child(button)


func _on_play_pressed() -> void:
	# "Play" resumes at the furthest level reached rather than always level 1.
	_start(clampi(Game.levels_reached, 0, maxi(Game.level_scenes.size() - 1, 0)))


func _start(index: int) -> void:
	if Game.level_scenes.is_empty():
		return
	Game.start_level(index)
	get_tree().change_scene_to_file(GAME_SCENE)
