## One level in the menu's grid: a numbered plate whose colour says whether the
## level is cleared, next up, merely open, or still locked.
##
## The four looks are theme type variations, so what a state looks like lives in
## `resources/ui_theme.tres` and nothing here paints.
class_name LevelChip
extends Button

enum State {
	LOCKED, ## Past the furthest level earned, with cheat mode off.
	OPEN, ## Reachable but never finished — only cheat mode makes these.
	NEXT, ## The one the run resumes at.
	CLEARED,
}

const SIZE := Vector2(44.0, 44.0)

var index := 0
var state: State = State.OPEN


static func create(level_index: int) -> LevelChip:
	var chip := LevelChip.new()
	chip.index = level_index
	chip.text = "%02d" % (level_index + 1)
	chip.custom_minimum_size = SIZE
	chip.focus_mode = Control.FOCUS_ALL
	return chip


## Settable after the grid is built, not just at creation: cheat mode opens and
## closes locks with the menu still up.
func apply(level_state: State) -> void:
	state = level_state
	disabled = state == State.LOCKED
	match state:
		State.CLEARED:
			theme_type_variation = &"ClearedChip"
		State.NEXT:
			theme_type_variation = &"NextChip"
		_:
			theme_type_variation = &"LevelChip"


## `reached` is `Game.levels_reached`; `unlocked` is `Game.is_unlocked`, which cheat
## mode overrides.
static func state_for(level_index: int, reached: int, unlocked: bool) -> State:
	if level_index < reached:
		return State.CLEARED
	if level_index == reached:
		return State.NEXT
	return State.OPEN if unlocked else State.LOCKED
