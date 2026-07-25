## Autoload `Glass` — the hourglass's shared motion state (`Game` owns the
## rules, this owns the presentation). One instance drives both the player
## sprite and the HUD gauge so they cannot drift apart.
extends Node

## Tumble/slosh/trickle state. Read it, do not drive it.
var motion := HourglassMotion.new()

## Sideways speed in px/s; written by the player every physics frame.
var travel := 0.0

var _last_travel := 0.0


func _ready() -> void:
	Game.level_loaded.connect(_on_level_loaded)


func _process(delta: float) -> void:
	motion.update(delta, travel, travel - _last_travel)
	_last_travel = travel


func _on_level_loaded(_index: int, _level_name: String) -> void:
	# Fresh glass per level: no sway or speed carried over from the last run.
	motion = HourglassMotion.new()
	travel = 0.0
	_last_travel = 0.0
