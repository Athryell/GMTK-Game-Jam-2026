## The game's colours.
##
## Entities never hard-code a colour: they ask here, which keeps the planes
## readable at a glance.
##
## THE HUE BUDGET. Four families, and nothing may invent a fifth:
##
##   - The world takes a PLANE HUE, one of four sitting 90° apart. Backgrounds
##     and scenery are the same hue drained of saturation, so depth reads as
##     distance rather than as another object.
##   - Time is WARM. Sand, door and flip-pad share one gold family. That is what
##     makes the thing you are chasing pop out of the room, and it is spent on
##     nothing else.
##   - Danger is one saturated MAGENTA-RED, used by spikes, monsters and a
##     nearly-empty glass. It is the only colour allowed to be that loud.
##   - The spring is MINT: helpful furniture, not a reward.
##
## Four planes will not fit politely around the gold and the red — 90° apart,
## some plane always lands within 45° of one of them, and the fourth is a
## terracotta sitting 25° off the danger red. The ORDER is what contains that: a
## three-chamber level only ever reaches P2, so the terracotta is never on screen
## unless the level has four chambers, and there it separates from the red by
## register rather than by hue. Solids are large, matte and unlit; spikes and
## monsters are small, saturated, and carry a light.
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

## Four depths per plane, far to near: sky, floor, far wall, near wall. Each is
## the plane's own hue with the life drained out of it, so the room recolours
## itself when you turn the glass without ever competing with a solid.
##
## P0 and P1 are the ramps that shipped, kept to the byte — they are what the
## twelve two-plane levels look like. P2 and P3 were built to match them: the
## plane's hue at the same saturation and the same four values.
## `Array[Array]` rather than `Array[PackedColorArray]`: a `PackedColorArray(…)`
## is a constructor call, and a `const` may only hold an expression the parser
## can fold. A nested array literal of `Color`s folds; the packed form does not.
const PLANE_ROOMS: Array[Array] = [
	[Color("102941"), Color("050c15"), Color("14304a"), Color("1b3e5c")],
	[Color("201540"), Color("0a0614"), Color("281b4d"), Color("362566")],
	[Color("184111"), Color("081505"), Color("1b4a13"), Color("225c18")],
	[Color("412711"), Color("150c05"), Color("4a2c13"), Color("5c3718")],
]


## A solid's colour for its plane. A "BOTH" solid takes the hue of whichever
## plane the player is in, so you can always read where you are.
static func solid(plane: Planes.Kind, current: Planes.Kind) -> Color:
	var effective := current if plane == Planes.Kind.BOTH else plane
	return PLANE_SOLIDS[clampi(int(effective), 0, PLANE_SOLIDS.size() - 1)]


## The same colour, faded if the thing wearing it lives in the other plane.
##
## The alpha is a tuning value read live, which is why this is a function and
## not a pair of constants: every ghost in the game has to move together when
## the slider does.
static func ghost(base: Color, active: bool) -> Color:
	if active:
		return base
	return Color(base.r, base.g, base.b, Tuning.cfg.ghost_alpha)


## The sand's colour at a given `Game.danger()`, from a full glass to an empty
## one. Shared by the sprite, the HUD gauge and the light the player carries —
## three readings of one clock, which must never disagree about how bad it is.
static func sand(danger: float) -> Color:
	return SAND_FULL.lerp(SAND_LOW, danger)


## The four room depths for a plane, far to near: sky, floor, far wall, near
## wall. Returned together because every caller wants the whole set, and
## splitting them into four functions invites one being left on the old plane.
static func room(plane: Planes.Kind) -> Array[Color]:
	var ramp: Array = PLANE_ROOMS[clampi(int(plane), 0, PLANE_ROOMS.size() - 1)]
	var depths: Array[Color] = [ramp[0], ramp[1], ramp[2], ramp[3]]
	return depths
