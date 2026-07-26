@tool
## Spring: launches along the direction it points WITHOUT flipping or changing
## plane, so it gives distance but no refuel. An Area2D, not a solid.
class_name Spring
extends PlaneArea

## Which way the plate throws you. The push is absolute, not relative to gravity:
## what is drawn is what happens, world over or not.
enum Facing { UP, DOWN, LEFT, RIGHT }

## Indexed by [enum Facing].
const PUSH: Array[Vector2] = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]

## FOOT and PLATE are fractions of the pad's DEPTH — its size along the push
## axis. TRAVEL is not: it is a fraction of the gap left over,
## `(depth - foot - plate) * TRAVEL`.
const FOOT := 0.14
const PLATE := 0.30
const TRAVEL := 0.62

## Post width and inset from each end, as fractions of the pad's WIDTH — its size
## across the push axis.
const POST := 0.045
const POST_INSET := 0.08

@export var facing: Facing = Facing.UP: set = _set_facing

## Impulse, in px/s. At 0 it takes `spring_power` from the tuning panel.
@export_range(0.0, 3000.0, 10.0) var power := 0.0

var _compress := 0.0 ## 1 on impact, decays back to 0.


func _init() -> void:
	# Origin is the TOP-LEFT corner: a pad on a floor sits at the floor's top
	# minus its own height. A wall pad wants the two swapped, e.g. 14 x 56.
	size = Vector2(56.0, 14.0)
	light_tint = Palette.SPRING
	light_radius = 120.0
	light_energy = 0.9


func _process(delta: float) -> void:
	if _compress <= 0.0:
		return
	_compress = maxf(0.0, _compress - delta * Tuning.cfg.spring_recovery_speed)
	queue_redraw()


func _touched(player: Player) -> void:
	# Only on the way in: leaving the pad the way it pushes must not fire it again.
	var push := PUSH[facing]
	if player.velocity.dot(push) > 0.0:
		return
	player.bounce(power if power > 0.0 else Tuning.cfg.spring_power, push)
	_compress = 1.0
	Audio.sfx("bounce")
	queue_redraw()


func _set_facing(value: Facing) -> void:
	facing = value
	queue_redraw()


## `across` runs along the plate, `depth` inwards from the face that pushes, so
## the drawing is authored once and turned here instead of four times.
func _pad_rect(across: float, depth: float, across_len: float, depth_len: float) -> Rect2:
	match facing:
		Facing.DOWN:
			return Rect2(across, size.y - depth - depth_len, across_len, depth_len)
		Facing.LEFT:
			return Rect2(depth, across, depth_len, across_len)
		Facing.RIGHT:
			return Rect2(size.x - depth - depth_len, across, depth_len, across_len)
		_:
			return Rect2(across, depth, across_len, depth_len)


## Only the plate moves on impact, so the closing gap reads as compression.
func _paint() -> void:
	var colour := _shade(Palette.SPRING)
	var sideways := facing == Facing.LEFT or facing == Facing.RIGHT
	var depth := size.x if sideways else size.y
	var width := size.y if sideways else size.x

	var foot := maxf(2.0, depth * FOOT)
	var plate := maxf(4.0, depth * PLATE)
	var face := (depth - foot - plate) * TRAVEL * _compress

	# The two slabs only: a line round each post would read as more springs.
	var foot_box := _pad_rect(0.0, depth - foot, width, foot)
	var plate_box := _pad_rect(0.0, face, width, plate)
	Outline.rect(self, foot_box, colour.a)
	Outline.rect(self, plate_box, colour.a)

	draw_rect(foot_box, colour.darkened(0.55))
	var post := maxf(3.0, width * POST)
	var inset := width * POST_INSET
	for across in [inset, width - inset - post]:
		draw_rect(_pad_rect(across, face + plate, post, depth - foot - face - plate),
			colour.darkened(0.38))
	draw_rect(plate_box, colour)
	draw_rect(_pad_rect(0.0, face, width, 2.0), colour.lightened(0.45))
