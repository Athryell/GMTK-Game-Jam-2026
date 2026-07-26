## The wipe between levels: a full-screen curtain that closes on the exit and
## opens on the level that follows.
class_name Transition
extends CanvasLayer

## [constant Outline.INK], not pure black: the level goes out into the same dark
## every shape in it is drawn against.
const COLOUR := Outline.INK


@onready var _veil: ColorRect = $Veil

var _tween: Tween


func _ready() -> void:
	_veil.color = Color(COLOUR, 0.0)


## Closes over `duration`, then holds until something opens it again.
func close(duration: float) -> void:
	_fade_to(1.0, duration)


func open(duration: float) -> void:
	_fade_to(0.0, duration)


## Lifts the curtain at once — for a retry, where waiting to see the level again
## is punishment rather than polish.
func clear() -> void:
	_fade_to(0.0, 0.0)


func _fade_to(alpha: float, duration: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if duration <= 0.0:
		_veil.color = Color(COLOUR, alpha)
		return
	_tween = create_tween()
	_tween.tween_property(_veil, "color", Color(COLOUR, alpha), duration)
