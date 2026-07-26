## The hourglass on the title screen: the painted sprite from `art/sprites`, with
## the game's own sand behind its transparent cavity, draining and turning on a
## clock of its own.
##
## It does NOT use `HourglassMotion`. That class reads the run out of `Game` — the
## sand, the chamber count, which way gravity points — and the menu is not a run.
## Everything below is a menu-local number.
class_name MenuGlass
extends Control

## How many screen px one art px covers. MUST stay a whole number: at anything
## fractional the doubled texels straddle pixels and the 1-px frame tears, the same
## rule `Backdrop.ART_SCALE` carries for the city.
const SCALE := 2

const DRAIN_TIME := 5.0
const TURN_TIME := 0.45

## The idle rock, in px and Hz.
const BOB := 2.0
const BOB_RATE := 0.25

## How opaque the inside of the glass is. Short of solid: the city still shows
## faintly through it, which is what keeps it glass and not a painted bottle.
const CAVITY_ALPHA := 0.82

var _time := 0.0


func _ready() -> void:
	# Per-node rather than a project default; see `terrain.gd`.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size = HourglassSprite.TRIM.size * SCALE


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var cycle := DRAIN_TIME + TURN_TIME
	var t := fmod(_time, cycle)
	var turning := t >= DRAIN_TIME
	# The half turn carries the full bulb to the top, so the tilt snapping back to 0
	# at the end of the cycle is the same picture as the tilt at PI: no seam.
	var top := 0.0 if turning else 1.0 - t / DRAIN_TIME
	var tilt := PI * (t - DRAIN_TIME) / TURN_TIME if turning else 0.0

	# Turned left-for-right through the same quarter turn as the player's glass, to
	# keep the light down its left side; see `hourglass_visual.gd`.
	var facing := -1.0 if cos(tilt) < 0.0 else 1.0
	var down := Vector2.DOWN.rotated(-tilt)
	if facing < 0.0:
		down.x = -down.x

	var glass_size := HourglassSprite.TRIM.size * SCALE
	var centre := size * 0.5 + Vector2(0.0, BOB * sin(_time * TAU * BOB_RATE))
	draw_set_transform(centre, tilt, Vector2(facing, 1.0))
	# The cavity is transparent so a level shows through it. Here that would be
	# rooftops, which read as blue liquid, so the glass is given an inside first.
	for i in 2:
		HourglassShape.fill(self, HourglassSprite.bulb(glass_size, i),
			Color(Palette.UI_INK, CAVITY_ALPHA))
	HourglassSprite.draw(self, glass_size,
		PackedFloat32Array([top, 1.0 - top]), Palette.SAND_FULL, down, 0.0, turning)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
