## Autoload `Glass` — the hourglass as it MOVES, shared by everything that draws
## one.
##
## There is one hourglass in this game and it is drawn twice: the thing you
## steer, and the gauge in the corner. They read this same motion, so the sand
## cannot slosh one way on the player and another way in the HUD. Two springs
## fed by two signals would drift; one spring cannot.
##
## `Game` owns the rules and stays clear of presentation. This owns the
## presentation and stays clear of the rules.
extends Node

## The tumble, the slosh, the trickle's wobble. Read it, do not drive it.
var motion := HourglassMotion.new()

## How fast the glass is travelling sideways, in px/s. The player writes this
## every physics frame; it is the one input from the world.
var travel := 0.0

var _last_travel := 0.0


func _ready() -> void:
	Game.level_loaded.connect(_on_level_loaded)


func _process(delta: float) -> void:
	motion.update(delta, travel, travel - _last_travel)
	_last_travel = travel


func _on_level_loaded(_index: int, _level_name: String) -> void:
	# A fresh level means a fresh glass: no sway carried over from the last run,
	# and no stale speed left behind by a player that has been freed.
	motion = HourglassMotion.new()
	travel = 0.0
	_last_travel = 0.0
