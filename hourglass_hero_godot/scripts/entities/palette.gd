## The game's colours.
##
## Entities never hard-code a colour: they ask here, which keeps the two planes
## readable at a glance.
##
## THE HUE BUDGET. Four families, and nothing may invent a fifth:
##
##   - The world is COOL. Solids only ever take a plane hue — cyan in front,
##     violet behind. Backgrounds and scenery are the same two hues drained of
##     saturation, so depth reads as distance rather than as another object.
##   - Time is WARM. Sand, door and flip-pad share one gold family, sitting
##     opposite cyan on the wheel. That complementary clash is what makes the
##     thing you are chasing pop out of a cool room, and it is spent on nothing
##     else.
##   - Danger is one saturated MAGENTA-RED, used by spikes, monsters and a
##     nearly-empty glass. It is the only colour allowed to be that loud.
##   - The spring is MINT: helpful furniture, not a reward. It sits in the cool
##     family on purpose — it was a candy green, which read as a third prize
##     next to the gold and split the player's attention three ways.
class_name Palette
extends RefCounted

# ----- Solids ----------------------------------------------------------------

const FRONT_SOLID := Color("4cc9f0")
const BACK_SOLID := Color("b57bff")
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
# Four depths per plane, from the far wall to the pillars that pass in front of
# you. Each is the plane's own hue with the life drained out of it, so the room
# recolours itself when you flip without ever competing with a solid.

const FRONT_SKY := Color("102941") ## Backdrop gradient, top.
const FRONT_FLOOR := Color("050c15") ## Backdrop gradient, bottom.
const FRONT_FAR := Color("14304a") ## Far wall.
const FRONT_NEAR := Color("1b3e5c") ## Near wall.

const BACK_SKY := Color("201540") ## Backdrop gradient, top.
const BACK_FLOOR := Color("0a0614") ## Backdrop gradient, bottom.
const BACK_FAR := Color("281b4d") ## Far wall.
const BACK_NEAR := Color("362566") ## Near wall.


## A solid's colour for its plane. A "BOTH" solid takes the hue of whichever
## plane the player is in, so you can always read where you are.
static func solid(plane: Planes.Kind, current: Planes.Kind) -> Color:
	var effective := current if plane == Planes.Kind.BOTH else plane
	return FRONT_SOLID if effective == Planes.Kind.FRONT else BACK_SOLID


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
	if plane == Planes.Kind.BACK:
		return [BACK_SKY, BACK_FLOOR, BACK_FAR, BACK_NEAR]
	return [FRONT_SKY, FRONT_FLOOR, FRONT_FAR, FRONT_NEAR]
