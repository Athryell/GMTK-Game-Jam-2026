## The hourglass, drawn: two bulbs, sand pouring from one to the other, and a
## tumble on every flip.
##
## Purely visual — no game rules here. A child of Player so it can spin without
## dragging the collision box around with it.
extends Node2D

## Drawn size of the glass. Purely cosmetic — the hitbox is the
## CollisionShape2D on `player.tscn`, so widen both if you widen one.
@export var body_size := Vector2(26.0, 38.0)

## The tumble, the slosh and the trickle's wobble. The HUD gauge keeps its own.
var _motion := HourglassMotion.new()
var _last_speed := 0.0


func _process(delta: float) -> void:
	# Setting off, stopping and turning around all shove the sand, the way a
	# glass of syrup slops when you start carrying it. Read off the parent
	# because that is the body actually moving; this node only spins.
	var body := get_parent() as CharacterBody2D
	var speed := body.velocity.x if body != null else 0.0
	var shove := speed - _last_speed
	_last_speed = speed

	_motion.update(delta, speed, shove)
	rotation = _motion.tilt
	queue_redraw()


func _draw() -> void:
	var sand_colour := Palette.SAND_FULL.lerp(Palette.SAND_LOW, Game.danger())
	# Same routine that draws the HUD gauge: one hourglass, two sizes.
	HourglassShape.draw_glass(self, body_size, _motion.chambers(), sand_colour,
		_motion.down(), _motion.stream_phase)

	# Orange burst when a flip-pad has just refuelled us.
	if Game.pad_flash > 0.0:
		var a := Game.pad_flash_ratio()
		draw_arc(Vector2.ZERO, body_size.y / 2.0 + 8.0 * (1.0 - a) + 6.0, 0.0, TAU, 24,
			Color(Palette.FLIP_PAD, a * 0.8), 2.0)
