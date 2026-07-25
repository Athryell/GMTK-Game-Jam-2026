@tool
## Spring: launches the player upwards WITHOUT flipping the hourglass and
## without changing plane. Free height and reach, but no refuel — the exception
## that decouples "jumping" from "refuelling".
##
## It is an Area2D rather than a solid: you don't bump into it sideways, you
## walk into its column and get launched, exactly like the JS prototype.
class_name Spring
extends PlaneArea

## Proportions of the pad's height, base to top: the foot it stands on, the
## plate you land on, and how far that plate travels on impact. The rest is the
## gap the posts cross — which is the part that visibly closes.
const FOOT := 0.14
const PLATE := 0.30
const TRAVEL := 0.62

## Post width and how far each post sits in from its end, as fractions of the
## pad's width. Proportional rather than fixed px so a narrow pad and a wide one
## read as the same object at two sizes, instead of as two different objects.
const POST := 0.045
const POST_INSET := 0.08

## Impulse, in px/s. At 0 it takes `spring_power` from the tuning panel.
@export_range(0.0, 3000.0, 10.0) var power := 0.0

var _compress := 0.0 ## Visual cue: the spring squashes, then springs back.


func _init() -> void:
	# A pad reads as furniture, and furniture that stands as tall — or spreads as
	# wide — as the thing it launches competes with it. The player is 26 wide, so
	# this is roughly two of them: enough to aim at, small enough to stay scenery.
	#
	# Whatever size a level picks, remember the origin is the TOP-LEFT corner:
	# a pad resting on a floor sits at the floor's top minus its own height, not
	# at the floor's top.
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
	# Only bounce when coming down onto it: passing up through it from below
	# must not re-launch.
	if player.velocity.y < 0.0:
		return
	player.bounce(power if power > 0.0 else Tuning.cfg.spring_power)
	_compress = 1.0
	queue_redraw()


## A plate riding on two fixed posts. On impact the plate travels down and the
## posts stay put, so the compression is read from the gap closing rather than
## from the pad changing shape — the silhouette holds still on the one frame the
## player actually sees. The old slab squashed its whole body instead, which on
## that frame turned into a shapeless smear.
func _draw() -> void:
	var colour := _shade(Palette.SPRING)
	var foot := maxf(2.0, size.y * FOOT)
	var plate := maxf(4.0, size.y * PLATE)
	var top := (size.y - foot - plate) * TRAVEL * _compress

	draw_rect(Rect2(Vector2(0.0, size.y - foot), Vector2(size.x, foot)),
		colour.darkened(0.55))
	# Inset from the ends, so the plate reads as resting ON the posts rather
	# than as one block with a stripe down it.
	var post := maxf(3.0, size.x * POST)
	var inset := size.x * POST_INSET
	for x in [inset, size.x - inset - post]:
		draw_rect(Rect2(Vector2(x, top + plate),
			Vector2(post, size.y - foot - top - plate)), colour.darkened(0.38))
	draw_rect(Rect2(Vector2(0.0, top), Vector2(size.x, plate)), colour)
	# The lip that says "this face". It is the only bright edge on the pad.
	draw_rect(Rect2(Vector2(0.0, top), Vector2(size.x, 2.0)), colour.lightened(0.45))
