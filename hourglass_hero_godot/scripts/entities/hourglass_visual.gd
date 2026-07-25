## The hourglass, drawn: two bulbs, sand pouring from one to the other, and a
## tumble on every flip.
##
## Purely visual — no game rules here. A child of Player so it can spin without
## dragging the collision box around with it.
extends Node2D

## Drawn size of the glass. Purely cosmetic — the hitbox is the
## CollisionShape2D on `player.tscn`, so widen both if you widen one.
@export var body_size := Vector2(26.0, 38.0)

## How far the glass shakes when the sand is all but gone, in px.
##
## Small on purpose. This has to read as nerves, not as damage: past two or
## three pixels it stops looking like a held breath and starts looking like the
## renderer is broken.
const TREMBLE := 2.2

## The two rates the tremble is built from, in rad/s. Deliberately not a round
## ratio — beat against each other they never repeat inside a run, so the shake
## stays nervous instead of settling into a visible loop.
const TREMBLE_RATES := Vector2(47.0, 61.3)

var _shiver := 0.0


func _process(delta: float) -> void:
	_shiver += delta
	# The motion is `Glass`'s, not ours — the HUD gauge reads the very same one,
	# which is what keeps the two glasses sloshing together. `Glass` is an
	# autoload, so it has already ticked by the time we get here.
	rotation = Glass.motion.tilt
	# Squared, so the shake stays out of the way through most of the warning and
	# only really arrives at the end. Linear, it creeps in the moment the gauge
	# turns and the player stops reading it as a warning at all.
	var fear := Game.danger()
	var amount := TREMBLE * fear * fear
	# Only the VISUAL is displaced. Offsetting the body would make the glass
	# jitter into walls and shake itself off ledges at the exact moment the
	# player most needs the controls to be honest.
	position = Vector2(
		sin(_shiver * TREMBLE_RATES.x),
		cos(_shiver * TREMBLE_RATES.y)) * amount
	queue_redraw()


func _draw() -> void:
	var motion := Glass.motion
	var sand_colour := Palette.sand(Game.danger())
	# Same routine, same motion as the HUD gauge: one hourglass, two sizes.
	HourglassShape.draw_glass(self, body_size, motion.chambers(), sand_colour,
		motion.down(), motion.stream_phase)

	# Orange burst when a flip-pad has just refuelled us.
	if Game.pad_flash > 0.0:
		var a := Game.pad_flash_ratio()
		draw_arc(Vector2.ZERO, body_size.y / 2.0 + 8.0 * (1.0 - a) + 6.0, 0.0, TAU, 24,
			Color(Palette.FLIP_PAD, a * 0.8), 2.0)
