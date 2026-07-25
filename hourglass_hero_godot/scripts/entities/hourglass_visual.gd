## The hourglass, drawn. Purely visual; a child of Player so it can spin and
## shake without moving the hitbox.
extends Node2D

## Drawn size. Cosmetic — the hitbox is the CollisionShape2D on `player.tscn`,
## so change both together.
@export var body_size := Vector2(26.0, 38.0)

## Tremble amplitude at full danger, in px. Keep it to a few px.
const TREMBLE := 2.2

## The two tremble rates, in rad/s. Not a round ratio, so it never visibly loops.
const TREMBLE_RATES := Vector2(47.0, 61.3)

var _shiver := 0.0


func _process(delta: float) -> void:
	_shiver += delta
	# Shared with the HUD gauge. `Glass` is an autoload, already ticked by now.
	rotation = Glass.motion.tilt
	# Squared, so the shake only arrives at the very end.
	var fear := Game.danger()
	var amount := TREMBLE * fear * fear
	# Only the visual moves: offsetting the body would jitter it into walls.
	position = Vector2(
		sin(_shiver * TREMBLE_RATES.x),
		cos(_shiver * TREMBLE_RATES.y)) * amount
	queue_redraw()


func _draw() -> void:
	var motion := Glass.motion
	var sand_colour := Palette.sand(Game.danger())
	HourglassShape.draw_glass(self, body_size, motion.chambers(), sand_colour,
		motion.down(), motion.stream_phase)

	if Game.pad_flash > 0.0:
		var a := Game.pad_flash_ratio()
		draw_arc(Vector2.ZERO, body_size.y / 2.0 + 8.0 * (1.0 - a) + 6.0, 0.0, TAU, 24,
			Color(Palette.FLIP_PAD, a * 0.8), 2.0)
