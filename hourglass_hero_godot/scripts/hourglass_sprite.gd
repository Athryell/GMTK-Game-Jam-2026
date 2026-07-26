## The hourglass as painted art rather than drawn geometry: the sprite from
## `art/sprites/hourglass.aseprite`, with the game's own sand poured in behind it.
##
## Only the frame is painted. The cavity inside the outline is TRANSPARENT in the
## art, so the sand — which has to move, and so cannot be painted — is drawn
## first and shows through it. Anything the art paints inside the cavity lands on
## top of the sand rather than under it; the current export paints nothing there,
## so the sand reads flat.
##
## Two chambers only. The art is one two-bulb glass; a three- or four-lobed
## rosette is a different object and `HourglassShape` still draws those.
class_name HourglassSprite
extends RefCounted

const TEXTURE: Texture2D = preload("res://art/sprites/hourglass.png")

## The part of the canvas the glass actually occupies, and what gets mapped onto
## the caller's `size`. The art is trimmed to its own bounds, so this is the whole
## 32×64 canvas — but keep it going through here rather than reading the texture
## size: the moment a margin comes back, this is the one line that has to change.
const TRIM := Rect2(0.0, 0.0, 32.0, 64.0)

## The inside of each bulb, in the art's own pixel coordinates, upper first.
##
## Traced off the outline in the .aseprite rather than authored here, then taken
## out to the convex hull — `draw_colored_polygon` only fills a convex shape
## honestly, and the glass narrows into its throat with a corner that is not.
##
## They stop two rows short of each other, leaving the pinch of the throat itself
## unfilled. That costs nothing — the falling thread is drawn straight through it
## and is wider than the hole — and it is what keeps the hull off the one corner
## it cannot round honestly, where the funnel turns into the throat and the
## outline has the least width to hide an overshoot under.
##
## Measured off the alpha of `hourglass.png`, not typed by hand: the cavity is
## the transparent region the outline encloses, taken row by row and pushed out
## to the convex hull. Rasterised back afterwards, and no filled pixel lands
## outside the glass on either bulb — that check is what makes the two rows
## above the right number rather than a guess.
const BULBS: Array[Array] = [
	[
		Vector2(4.0, 7.0), Vector2(28.0, 7.0), Vector2(28.0, 12.0),
		Vector2(27.0, 19.0), Vector2(25.0, 25.0), Vector2(22.0, 28.0),
		Vector2(17.0, 31.0), Vector2(15.0, 31.0), Vector2(10.0, 28.0),
		Vector2(7.0, 25.0), Vector2(5.0, 19.0), Vector2(4.0, 12.0),
	],
	[
		Vector2(4.0, 52.0), Vector2(5.0, 45.0), Vector2(7.0, 39.0),
		Vector2(10.0, 36.0), Vector2(15.0, 33.0), Vector2(17.0, 33.0),
		Vector2(22.0, 36.0), Vector2(25.0, 39.0), Vector2(27.0, 45.0),
		Vector2(28.0, 52.0), Vector2(28.0, 57.0), Vector2(4.0, 57.0),
	],
]

## One bulb's area in art px². Both come out the same, which is the reason the
## glass can be filled from a single 0-to-1 number per chamber. Held as a
## constant rather than measured every frame: the outline never changes, and
## area scales with the drawing, so the caller's `size` is all that is missing.
## Must be remeasured if [constant BULBS] is ever retraced, or a chamber the game
## calls full stops looking it.
const BULB_AREA := 467.0


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
		HourglassShape.fill_grains(canvas, HourglassShape.thread_quad(
			seg[0], seg[1], maxf(size.x * 0.055, 1.0)), sand)

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
