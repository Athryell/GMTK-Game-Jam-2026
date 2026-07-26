## The hourglass, drawn. Purely visual; a child of Player so it can spin and
## shake without moving the hitbox.
extends Node2D

## Drawn size. Cosmetic — the hitbox is the CollisionShape2D on `player.tscn`,
## so change both together. Exactly [constant HourglassSprite.TRIM]'s size, so
## the painted glass is drawn one art px to one world px.
@export var body_size := Vector2(32.0, 60.0)

## Tremble amplitude at full danger, in px. Keep it to a few px.
const TREMBLE := 2.2

## The two tremble rates, in rad/s. Not a round ratio, so it never visibly loops.
const TREMBLE_RATES := Vector2(47.0, 61.3)

## How fast the glass swings round when the world turns over, in rad/s.
const UPSET_RATE := 11.0

var _shiver := 0.0
## Where the half-turn currently is, in radians: chases `PI` while the world is
## upside down, 0 while it is not. Eased rather than snapped.
var _upset := 0.0


func _ready() -> void:
	# See `terrain.gd` for why this is per-node rather than a project default.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	_shiver += delta
	# Half a turn while gravity is inverted, so the sand pools the way it falls.
	var upside_down: float = PI if get_parent().pull < 0.0 else 0.0
	_upset = move_toward(_upset, upside_down, UPSET_RATE * delta)
	rotation = Glass.motion.sprite_tilt() + _upset
	# Squared, so the shake only arrives at the very end.
	var fear := Game.danger()
	var amount := TREMBLE * fear * fear
	# Only the visual moves: offsetting the body would jitter it into walls.
	position = Vector2(
		sin(_shiver * TREMBLE_RATES.x),
		cos(_shiver * TREMBLE_RATES.y)) * amount
	scale.x = -1.0 if _mirrored() else 1.0
	queue_redraw()


## Whether the art is showing its back, and so has to be flipped left-for-right
## to keep its face on. A no-op on the current export, which has no highlights
## left in it; the sand behind it is not symmetric, and the light may come back.
##
## Read off the rotation rather than counted off the jumps, so it cannot drift
## out of step with what is on screen. `cos` crosses zero a quarter of the way
## through the half turn, with the glass edge-on and the swap least visible.
func _mirrored() -> bool:
	return cos(rotation) < 0.0


func _draw() -> void:
	var motion := Glass.motion
	# Gold whatever is left: running out reads on the screen edge and the gauge.
	var sand_colour := Palette.glass_sand(Game.feathered)
	var down := motion.sprite_down()
	# Mirroring the node mirrors the glass's own frame with it, so world-down has
	# to be carried across too or the sand sloshes against the way you are moving.
	if _mirrored():
		down.x = -down.x
	HourglassSprite.draw(self, body_size, motion.sprite_fills(), sand_colour,
		down, motion.invert(), Game.flip_anim > 0.0)

	if Game.pad_flash > 0.0:
		var a := Game.pad_flash_ratio()
		draw_arc(Vector2.ZERO, body_size.y / 2.0 + 8.0 * (1.0 - a) + 6.0, 0.0, TAU, 24,
			Color(Palette.FLIP_PAD, a * 0.8), 2.0)
