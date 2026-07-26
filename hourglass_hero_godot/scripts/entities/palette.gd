## The game's colours. Entities never hard-code one, they ask here.
##
## Hue budget, four families and no fifth: the world takes a plane hue (cyan,
## violet, lime, terracotta, desaturated for scenery), time is WARM gold (sand,
## door, flip-pad), danger is magenta-red, spring is mint.
class_name Palette
extends RefCounted

# ----- Solids ----------------------------------------------------------------

## One hue per plane, in the order a level reaches them.
const PLANE_SOLIDS: Array[Color] = [
	Color("4cc9f0"), ## P0 — cyan, the game's identity, unchanged.
	Color("b57bff"), ## P1 — violet.
	Color("7fe04c"), ## P2 — lime.
	Color("f0764c"), ## P3 — terracotta.
]
## Strength of the tint `marker` hands out, before the marker's own alpha.
const MARKER_ALPHA := 0.6
const SPRING := Color("5fe6c0") ## Spring: launches without flipping.
const FLIP_PAD := Color("ffc971") ## Flip-pad: refuels without changing plane.
const MONSTER := Color("ff4d6d")
const DOOR := Color("ffd166")

## What the brick is tinted, one entry per background. Stone belongs to the
## PLACE, not to the plane: it is lit by the sky behind it.
const BRICK_TINTS: Array[Color] = [
	Color("ff874a"), ## Backgrounds 1 — warm brick, at the top of its value.
	Color("ea7562"), ## 2 — the same brick, gone rosy.
	Color("5856a8"), ## 3 — cold blue-violet stone, the darkest of the four.
	Color("efab5a"), ## 4 — pale sandstone.
]

## How far the tints above are lifted before they reach the tile. Not the knob
## for "brighter": past about 1.5 the mortar highlights saturate and flatten,
## taking the relief with them. Raise the tints themselves instead.
const BRICK_GAIN := 1.5

# ----- The hourglass ---------------------------------------------------------

const GLASS := Color("eef2ff") ## Hourglass frame.
const SAND_FULL := Color("ffb03a")
const SAND_LOW := Color("ff4d6d")
## The one colour that leaves the warm family, and the only sign that a feather's
## jump is in hand.
const SAND_CHARGED := Color("3fb8ff")

# ----- Text ------------------------------------------------------------------

const TEXT_DIM := Color("9aa6c4")

# ----- The room --------------------------------------------------------------

## Four depths per plane, far to near: sky, floor, far wall, near wall — each a
## desaturated version of the plane hue.
##
## `Array[Array]` rather than `Array[PackedColorArray]`: a `PackedColorArray(…)`
## is a constructor call, which a `const` cannot hold.
const PLANE_ROOMS: Array[Array] = [
	[Color("102941"), Color("050c15"), Color("14304a"), Color("1b3e5c")],
	[Color("201540"), Color("0a0614"), Color("281b4d"), Color("362566")],
	[Color("184111"), Color("081505"), Color("1b4a13"), Color("225c18")],
	[Color("412711"), Color("150c05"), Color("4a2c13"), Color("5c3718")],
]


## A solid's colour. A `BOTH` solid takes the hue of the player's current plane.
static func solid(plane: Planes.Kind, current: Planes.Kind) -> Color:
	var effective := current if plane == Planes.Kind.BOTH else plane
	return PLANE_SOLIDS[clampi(int(effective), 0, PLANE_SOLIDS.size() - 1)]


## The hue `PlaneMarker` dashes a plane-bound solid in.
static func marker(plane: Planes.Kind, alpha: float) -> Color:
	var tint := PLANE_SOLIDS[clampi(int(plane), 0, PLANE_SOLIDS.size() - 1)]
	return Color(tint.r, tint.g, tint.b, MARKER_ALPHA * alpha)


## The brick tint of a theme, so stone and skyline always change together.
## Lifted by `BRICK_GAIN` because a modulate is a MULTIPLY and the tile averages
## 47% grey.
static func bricks(group: int) -> Color:
	var tint := BRICK_TINTS[clampi(group, 0, BRICK_TINTS.size() - 1)]
	# Rebuilt rather than scaled: `Color * float` takes the alpha with it, and
	# the alpha is `ghost`'s to set.
	return Color(tint.r * BRICK_GAIN, tint.g * BRICK_GAIN, tint.b * BRICK_GAIN)


## Faded when the entity lives in another plane, and less faded in the one a jump
## would land in.
static func ghost(base: Color, active: bool, next := false) -> Color:
	if active:
		return base
	var alpha: float = Tuning.cfg.ghost_alpha
	if next:
		alpha = lerpf(alpha, 1.0, Tuning.cfg.ghost_next_lift)
	return Color(base.r, base.g, base.b, alpha)


## The sand's colour at a given `Game.danger()`. Shared by the HUD gauge and the
## player's lamp; the glass itself takes `glass_sand`.
static func sand(danger: float, charged := false) -> Color:
	var full := SAND_CHARGED if charged else SAND_FULL
	return full.lerp(SAND_LOW, danger)


## What the GLASS itself is filled with. No danger ramp — that reads on the
## screen edge and on the gauge.
static func glass_sand(charged: bool) -> Color:
	return SAND_CHARGED if charged else SAND_FULL


## The four room depths for a plane, in order: sky, floor, far wall, near wall.
static func room(plane: Planes.Kind) -> Array[Color]:
	var ramp: Array = PLANE_ROOMS[clampi(int(plane), 0, PLANE_ROOMS.size() - 1)]
	var depths: Array[Color] = [ramp[0], ramp[1], ramp[2], ramp[3]]
	return depths
