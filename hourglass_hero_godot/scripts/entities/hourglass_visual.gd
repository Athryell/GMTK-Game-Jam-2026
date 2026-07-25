## The hourglass, drawn: two bulbs, sand pouring from one to the other, and a
## tumble on every flip.
##
## Purely visual — no game rules here. A child of Player so it can spin without
## dragging the collision box around with it.
extends Node2D

## Drawn size of the glass. Purely cosmetic — the hitbox is the
## CollisionShape2D on `player.tscn`, so widen both if you widen one.
@export var body_size := Vector2(26.0, 38.0)

func _process(_delta: float) -> void:
	# The motion is `Glass`'s, not ours — the HUD gauge reads the very same one,
	# which is what keeps the two glasses sloshing together. `Glass` is an
	# autoload, so it has already ticked by the time we get here.
	rotation = Glass.motion.tilt
	queue_redraw()


func _draw() -> void:
	var motion := Glass.motion
	var sand_colour := Palette.SAND_FULL.lerp(Palette.SAND_LOW, Game.danger())
	# Same routine, same motion as the HUD gauge: one hourglass, two sizes.
	HourglassShape.draw_glass(self, body_size, motion.chambers(), sand_colour,
		motion.down(), motion.stream_phase)

	# Orange burst when a flip-pad has just refuelled us.
	if Game.pad_flash > 0.0:
		var a := Game.pad_flash_ratio()
		draw_arc(Vector2.ZERO, body_size.y / 2.0 + 8.0 * (1.0 - a) + 6.0, 0.0, TAU, 24,
			Color(Palette.FLIP_PAD, a * 0.8), 2.0)
