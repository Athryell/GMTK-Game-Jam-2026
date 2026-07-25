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
const SPRING := Color("5fe6c0") ## Spring: launches without flipping.
const FLIP_PAD := Color("ffc971") ## Flip-pad: refuels without changing plane.
const MONSTER := Color("ff4d6d")
const DOOR := Color("ffd166")

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
