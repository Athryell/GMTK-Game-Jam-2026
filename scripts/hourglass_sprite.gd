## The hourglass as painted art rather than drawn geometry: the sprite from
## `art/sprites/hourglass.aseprite`, with the game's own sand poured in behind it.
##
## Only the frame is painted: the cavity is TRANSPARENT in the art, so the sand
## is drawn first and shows through it. Anything the art paints inside the cavity
## would land on top of the sand.
##
## Two chambers only; `HourglassShape` still draws the wider rosettes.
class_name HourglassSprite
extends RefCounted

const TEXTURE: Texture2D = preload("res://art/sprites/hourglass.png")

## The part of the canvas the glass actually occupies, and what gets mapped onto
## the caller's `size`: 32×60 within a 64-tall canvas, four blank rows on top.
## Everything downstream reads the trim rather than the texture.
const TRIM := Rect2(0.0, 4.0, 32.0, 60.0)

## The inside of each bulb, in the art's own pixel coordinates, upper first.
## Measured off the alpha of `hourglass.png` and pushed out to the convex hull,
## which is all `draw_colored_polygon` fills honestly.
##
## They stop two rows short of each other, leaving the throat unfilled: that
## keeps the hull off the corner it cannot round without spilling outside the
## outline, and the falling thread is wider than the gap anyway.
const BULBS: Array[Array] = [
	[
		Vector2(4.0, 11.0), Vector2(28.0, 11.0), Vector2(28.0, 16.0),
		Vector2(27.0, 21.0), Vector2(25.0, 27.0), Vector2(22.0, 30.0),
		Vector2(17.0, 33.0), Vector2(15.0, 33.0), Vector2(10.0, 30.0),
		Vector2(7.0, 27.0), Vector2(5.0, 21.0), Vector2(4.0, 16.0),
	],
	[
		Vector2(4.0, 52.0), Vector2(5.0, 47.0), Vector2(7.0, 41.0),
		Vector2(10.0, 38.0), Vector2(15.0, 35.0), Vector2(17.0, 35.0),
		Vector2(22.0, 38.0), Vector2(25.0, 41.0), Vector2(27.0, 47.0),
		Vector2(28.0, 52.0), Vector2(28.0, 57.0), Vector2(4.0, 57.0),
	],
]

## One bulb's area in art px²; both come out the same. Must be remeasured if
## [constant BULBS] is ever retraced, or a chamber the game calls full stops
## looking it.
const BULB_AREA := 421.0

## Sand first, then the glass over it. `fills` is how full each bulb is, 0 to 1,
## upper first; `down` is gravity in the glass's own frame and `invert` how far
## the flow has turned over, both exactly as [method HourglassShape.draw_glass]
## takes them. `turning` hides the fall for the length of a jump — see below.
static func draw(canvas: CanvasItem, size: Vector2, fills: PackedFloat32Array,
		sand: Color, down: Vector2, invert := 0.0, turning := false) -> void:
	if fills.size() < 2:
		push_error("HourglassSprite: the painted glass has two bulbs, got %d" % fills.size())
		return

	var capacity := BULB_AREA * (size.x / TRIM.size.x) * (size.y / TRIM.size.y)
	for i in 2:
		if fills[i] > 0.001:
			HourglassShape.fill_grains(canvas,
				HourglassShape.pile(bulb(size, i), down, fills[i] * capacity, invert), sand)

	# The neck the art paints sits within a pixel of the one the drawn glass assumes
	# at this size, so the fall needs no measurements of its own.
	#
	# Not while the glass is turning: the thread is aimed along gravity while the
	# bulbs it joins turn with the frame, so far enough over it swings out through
	# the side of the picture. The drawn glass spends it against its own wall
	# instead, but here the wall is a painting.
	if not turning and (fills[0] > 0.001 or invert >= 0.5):
		var seg := HourglassShape.trickle_segment(size, 2, 0, 1, down, invert)
		HourglassShape.fill_grains(canvas, HourglassShape.thread_quad(
			seg[0], seg[1], maxf(size.x * 0.055, 1.0)), sand)

	canvas.draw_texture_rect_region(TEXTURE,
		Rect2(-size * 0.5, size), TRIM)


## Bulb `index` as a polygon in the glass's own frame, scaled to `size` and
## centred on the origin, where the drawn glass keeps its throat.
static func bulb(size: Vector2, index: int) -> PackedVector2Array:
	var art: Array = BULBS[index]
	var out := PackedVector2Array()
	out.resize(art.size())
	for i in art.size():
		var p: Vector2 = art[i]
		out[i] = Vector2(
			(p.x - TRIM.position.x) / TRIM.size.x * size.x - size.x * 0.5,
			(p.y - TRIM.position.y) / TRIM.size.y * size.y - size.y * 0.5)
	return out
