## Title screen and level select. The grid is built from `Game.level_scenes` and
## coloured by how far the player has got; the card under it names whichever chip
## has focus, so the levels fit across the frame without carrying their titles.
extends Control

const GAME_SCENE := "res://scenes/main.tscn"

## Chips across the grid. Nine at 44 px holds 45 levels in five rows with no
## scrollbar, and the levels folder is scanned at runtime — so this is the one
## number to change if the game ever outgrows the space.
const COLUMNS := 9

## Indexed by `LevelChip.State`, so the order is the enum's.
const STATE_WORDS: Array[String] = ["LOCKED", "OPEN", "NEXT UP", "CLEARED"]

const EXIT_FADE := 0.22

@onready var _grid: GridContainer = $Right/Levels
@onready var _play: Button = $Left/Play
@onready var _quit: Button = $Left/Quit
@onready var _cheat: Button = $Right/Cheat
@onready var _unlocked: Label = $Right/Unlocked
@onready var _detail_bar: ColorRect = $Right/DetailBar
@onready var _detail_number: Label = $Right/Detail/Rows/Top/Number
@onready var _detail_name: Label = $Right/Detail/Rows/Top/Name
@onready var _detail_state: Label = $Right/Detail/Rows/Bottom/State
@onready var _veil: Transition = $Transition

var _chips: Array[LevelChip] = []
## Set once a level has been chosen, so a second press during the fade cannot
## start a second run.
var _leaving := false


func _ready() -> void:
	_grid.columns = COLUMNS
	_play.pressed.connect(_on_play_pressed)
	_quit.pressed.connect(get_tree().quit)
	_cheat.button_pressed = Game.cheat_mode
	_cheat.toggled.connect(_on_cheat_toggled)
	_build_chips()
	_apply_states()
	_show(Game.resume_index())
	_play.grab_focus()
	Audio.play_music("menu")


func _build_chips() -> void:
	for i in Game.level_scenes.size():
		var chip := LevelChip.create(i)
		# `bind(i)` captures the index now, not the loop variable's final value.
		chip.pressed.connect(_start.bind(i))
		chip.focus_entered.connect(_show.bind(i))
		chip.mouse_entered.connect(_show.bind(i))
		_grid.add_child(chip)
		_chips.append(chip)


## Called again whenever cheat mode is toggled, which opens and closes locks with
## the menu still up.
func _apply_states() -> void:
	var open := 0
	for chip in _chips:
		chip.apply(LevelChip.state_for(
			chip.index, Game.levels_reached, Game.is_unlocked(chip.index)))
		if not chip.disabled:
			open += 1
	_unlocked.text = "%d / %d UNLOCKED" % [open, _chips.size()]
	_cheat.text = "%s CHEAT MODE — UNLOCK EVERY LEVEL" \
		% ("[x]" if Game.cheat_mode else "[ ]")
	# The level the card is describing may have changed state under it.
	_show(_carded_index())


## Driven by focus AND by hover, so the keyboard and the mouse never disagree about
## which level is being described.
func _show(index: int) -> void:
	if index < 0 or index >= _chips.size():
		return
	var state := _chips[index].state
	_detail_number.text = "%02d" % (index + 1)
	_detail_name.text = Game.level_names[index].to_upper()
	_detail_state.text = STATE_WORDS[int(state)]
	var colour := state_colour(state)
	_detail_state.add_theme_color_override("font_color", colour)
	_detail_bar.color = colour


## Which level the card is showing, read back off the card itself so a recolour
## does not move it somewhere else.
func _carded_index() -> int:
	return clampi(_detail_number.text.to_int() - 1, 0, maxi(_chips.size() - 1, 0))


static func state_colour(state: LevelChip.State) -> Color:
	match state:
		LevelChip.State.CLEARED:
			return Palette.UI_GOLD
		LevelChip.State.NEXT:
			return Palette.UI_ACCENT
		LevelChip.State.LOCKED:
			return Palette.TEXT_DIM
		_:
			return Palette.GLASS


func _on_cheat_toggled(on: bool) -> void:
	Game.set_cheat_mode(on)
	_apply_states()


func _on_play_pressed() -> void:
	# Resumes at the furthest level unlocked rather than level 1.
	_start(Game.resume_index())


func _start(index: int) -> void:
	if _leaving or Game.level_scenes.is_empty():
		return
	_leaving = true
	Game.start_run(index)
	_veil.close(EXIT_FADE)
	await get_tree().create_timer(EXIT_FADE).timeout
	get_tree().change_scene_to_file(GAME_SCENE)
