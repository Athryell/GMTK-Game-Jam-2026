## The hourglass as painted art rather than drawn geometry: the sprite from
## `art/sprites/hourglass.aseprite`, with the game's own sand poured in behind it.
##
## Only the frame is painted. The cavity inside the outline is TRANSPARENT in the
## art, so the sand — which has to move, and so cannot be painted — is drawn
## first and shows through it, and the highlights down the left and the blue
## reflections down the right land on top of the sand rather than under it.
##
## Two chambers only. The art is one two-bulb glass; a three- or four-lobed
## rosette is a different object and `HourglassShape` still draws those.
class_name HourglassSprite
extends RefCounted

const TEXTURE: Texture2D = preload("res://art/sprites/hourglass.png")

## The part of the 64×64 canvas the glass actually occupies. The art is centred
## with six columns of margin either side and runs the full height, so this is
## what gets mapped onto the caller's `size` — draw the whole canvas instead and
## the glass comes out narrower than it was asked to be.
const TRIM := Rect2(6.0, 0.0, 52.0, 64.0)

## The inside of each bulb, in the art's own pixel coordinates, upper first.
##
## Traced off the outline in the .aseprite rather than authored here, then taken
## out to the convex hull — `draw_colored_polygon` only fills a convex shape
## honestly, and the glass narrows into its throat with a corner that is not.
##
## They stop a row short of the throat, and that row is the whole reason. Where
## the funnel turns into the throat the outline thins to a single pixel either
## side, and a hull carried all the way down cuts that corner and puts sand out
## through it — a bead of yellow either side of the hole, the one place on the
## glass where a pixel of overshoot has nothing to hide under. Stopping short
## leaves the throat itself unfilled, which costs nothing: the falling thread is
## drawn straight through it and is wider than the hole.
const BULBS: Array[Array] = [
	[
		Vector2(11.0, 7.0), Vector2(53.0, 7.0), Vector2(53.0, 10.0),
		Vector2(51.0, 19.0), Vector2(50.0, 22.0), Vector2(49.0, 24.0),
		Vector2(47.0, 26.0), Vector2(41.0, 29.0), Vector2(33.0, 31.0),
		Vector2(31.0, 31.0), Vector2(23.0, 29.0), Vector2(17.0, 26.0),
		Vector2(15.0, 24.0), Vector2(14.0, 22.0), Vector2(13.0, 19.0),
		Vector2(11.0, 10.0),
	],
	[
		Vector2(11.0, 54.0), Vector2(13.0, 45.0), Vector2(14.0, 42.0),
		Vector2(15.0, 40.0), Vector2(17.0, 38.0), Vector2(23.0, 35.0),
		Vector2(31.0, 33.0), Vector2(33.0, 33.0), Vector2(41.0, 35.0),
		Vector2(47.0, 38.0), Vector2(49.0, 40.0), Vector2(50.0, 42.0),
		Vector2(51.0, 45.0), Vector2(53.0, 54.0), Vector2(53.0, 57.0),
		Vector2(11.0, 57.0),
	],
]

## One bulb's area in art px². Both come out the same, which is the reason the
## glass can be filled from a single 0-to-1 number per chamber. Held as a
## constant rather than measured every frame: the outline never changes, and
## area scales with the drawing, so the caller's `size` is all that is missing.
## Must be remeasured if [constant BULBS] is ever retraced, or a chamber the game
## calls full stops looking it.
const BULB_AREA := 823.0


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
			HourglassShape.fill(canvas,
				HourglassShape.pile(bulb(size, i), down, fills[i] * capacity, invert), sand)

	# The neck the art paints sits within a pixel of the one the drawn glass
	# assumes at this size, and either end of the thread overshoots into a wooden
	# cap that covers it — so the fall needs no measurements of its own, and the
	# reversal inside an inversion zone comes along for free.
	#
	# Not while the glass is turning, though. The thread is aimed along gravity
	# while the bulbs it joins are painted onto the frame and turn with it, so
	# once the glass is far enough over the fall no longer runs between them: it
	# swings across the cavity and out through the side of the frame. The drawn
	# glass spends it against the angle of its own wall instead, which it can do
	# because it knows where its walls are; here the wall is a picture. Cutting it
	# for the length of the turn costs nothing — sand mid-tumble has nothing to
	# land in, and the glass is only over for a moment.
	if not turning and (fills[0] > 0.001 or invert >= 0.5):
		var seg := HourglassShape.trickle_segment(size, 2, 0, 1, down, invert)
		canvas.draw_line(seg[0], seg[1], sand, maxf(size.x * 0.055, 1.0), true)

	canvas.draw_texture_rect_region(TEXTURE,
		Rect2(-size * 0.5, size), TRIM)


## Bulb `index` as a polygon in the glass's own frame, scaled to `size` and
## centred on the origin — which puts the throat on it, where the drawn glass
## keeps its own.
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
