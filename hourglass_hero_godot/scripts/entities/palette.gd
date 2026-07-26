## The game's colours. Entities never hard-code one, they ask here.
##
## Hue budget, four families and no fifth: the world takes a plane hue (cyan,
## violet, lime, terracotta, desaturated for scenery), time is WARM gold (sand,
## door, flip-pad), danger is magenta-red, spring is mint.
##
## The terracotta sits close to the danger red. What keeps them apart is the
## ORDER: a level only reaches P3 if it has four chambers, and there they differ
## by register — solids are large, matte and unlit, spikes and monsters are
## small, saturated, and carry a light.
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
## Strength of the tint `marker` hands out, before the marker's own fade. Under
## 1 on purpose: the dashes sit on top of whatever is behind the slab, and a
## line you can see the city through is a line that belongs to the world rather
## than to the HUD.
const MARKER_ALPHA := 0.6
const SPRING := Color("5fe6c0") ## Spring: launches without flipping.
const FLIP_PAD := Color("ffc971") ## Flip-pad: refuels without changing plane.
const MONSTER := Color("ff4d6d")
const DOOR := Color("ffd166")

## What the brick a platform and the ground are built from is tinted, one entry
## per background. Stone belongs to the PLACE, not to the plane: it is lit by
## the sky behind it, so it changes when that does. Which plane a solid sits in
## is still read off its alpha — solid is the one you can stand on.
const BRICK_TINTS: Array[Color] = [
	Color("ff874a"), ## Backgrounds 1 — warm brick, at the top of its value.
	Color("ea7562"), ## 2 — the same brick, gone rosy.
	Color("5856a8"), ## 3 — cold blue-violet stone, the darkest of the four.
	Color("efab5a"), ## 4 — pale sandstone.
]

## How far the tints above are lifted before they reach the tile.
##
## This is not the knob for "brighter" any more. Past about 1.5 the tile's top
## few percent of texels — the mortar highlights — saturate against the widest
## tint channel and flatten out, taking the relief with them. Raise the tints
## themselves instead: they clip the same way, but a brighter, more saturated
## tint spends the headroom on colour rather than on washing the courses out.
const BRICK_GAIN := 1.5

# ----- The hourglass ---------------------------------------------------------

const GLASS := Color("eef2ff") ## Hourglass frame.
const SAND_FULL := Color("ffb03a")
const SAND_LOW := Color("ff4d6d")

# ----- Text ------------------------------------------------------------------

const TEXT_DIM := Color("9aa6c4")

# ----- The room --------------------------------------------------------------

## Four depths per plane, far to near: sky, floor, far wall, near wall — each a
## desaturated version of the plane hue, so the room recolours itself when you
## turn the glass without ever competing with a solid. P0 and P1 are the ramps
## that shipped, kept to the byte; P2 and P3 were built to match them.
##
## `Array[Array]` rather than `Array[PackedColorArray]`: a `PackedColorArray(…)`
## is a constructor call, and a `const` may only hold an expression the parser
## can fold. A nested array literal of `Color`s folds; the packed form does not.
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


## The hue `PlaneMarker` dashes a plane-bound solid in, so which world a slab
## belongs to stays readable while the stone still looks like every other stone.
## `alpha` is the marker's own fade.
static func marker(plane: Planes.Kind, alpha: float) -> Color:
	var tint := PLANE_SOLIDS[clampi(int(plane), 0, PLANE_SOLIDS.size() - 1)]
	return Color(tint.r, tint.g, tint.b, MARKER_ALPHA * alpha)


## The brick tint a level is built in, grouped exactly as the backgrounds are so
## the stone and the skyline always change on the same level.
##
## Lifted by `BRICK_GAIN`, because a modulate is a MULTIPLY: the tile averages
## 47% grey, so handing it the colour raw lays the stone at half the colour.
static func bricks(level_index: int) -> Color:
	@warning_ignore("integer_division") # Grouping, not measurement — the floor is the point.
	var group := level_index / Backdrop.LEVELS_PER_BACKGROUND
	var tint := BRICK_TINTS[clampi(group, 0, BRICK_TINTS.size() - 1)]
	# Rebuilt rather than scaled: `Color * float` takes the alpha with it, and
	# the alpha is `ghost`'s to set.
	return Color(tint.r * BRICK_GAIN, tint.g * BRICK_GAIN, tint.b * BRICK_GAIN)


## Faded when the entity lives in another plane, and less faded in the one a jump
## would land in: the world you are choosing steps out of the pack before you
## commit to it. A function, not a constant, because the alpha is read live.
static func ghost(base: Color, active: bool, next := false) -> Color:
	if active:
		return base
	var alpha: float = Tuning.cfg.ghost_alpha
	if next:
		alpha = lerpf(alpha, 1.0, Tuning.cfg.ghost_next_lift)
	return Color(base.r, base.g, base.b, alpha)


## The sand's colour at a given `Game.danger()`. Shared by sprite, HUD and light.
static func sand(danger: float) -> Color:
	return SAND_FULL.lerp(SAND_LOW, danger)


## The four room depths for a plane, in order: sky, floor, far wall, near wall.
static func room(plane: Planes.Kind) -> Array[Color]:
	var ramp: Array = PLANE_ROOMS[clampi(int(plane), 0, PLANE_ROOMS.size() - 1)]
	var depths: Array[Color] = [ramp[0], ramp[1], ramp[2], ramp[3]]
	return depths
