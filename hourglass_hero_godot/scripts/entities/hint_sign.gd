@tool
## A line of tutorial text standing in the world, at the spot its sentence is
## about. The jump is not mentioned before walking has failed: a rule you have
## already broken is the one that sticks.
class_name HintSign
extends Node2D

## Seconds a sign takes to fade in or out.
const FADE_TIME := 0.5

@export_multiline var text := "": set = _set_text
## Deaths on this level before the sign appears. 0 is up from the start.
@export_range(0, 4) var after_deaths := 0
## Deaths after which it goes away again; 0 leaves it up for good. The level only
## ever wants one of these on screen.
@export_range(0, 4) var hide_after_deaths := 0

@onready var _label: Label = $Label

var _fade: Tween


func _ready() -> void:
	_label.text = text
	if Engine.is_editor_hint():
		return
	modulate.a = 0.0
	Game.status_changed.connect(_refresh.unbind(1))
	_refresh()


## Only the death toll can change what a sign says, so nothing here runs per frame.
func _refresh() -> void:
	var spent := hide_after_deaths > 0 and Game.level_deaths >= hide_after_deaths
	var wanted := 1.0 if Game.level_deaths >= after_deaths and not spent else 0.0
	if _fade != null:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", wanted, FADE_TIME)


func _set_text(value: String) -> void:
	text = value
	if is_node_ready():
		_label.text = value
