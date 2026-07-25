## The game's colours. Entities never hard-code one, they ask here.
##
## Hue budget, four families and no fifth: the world is COOL (cyan front, violet
## back, desaturated for scenery), time is WARM gold (sand, door, flip-pad),
## danger is magenta-red, spring is mint.
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
# Four depths per plane, far to near, each a desaturated version of the plane hue.

const FRONT_SKY := Color("102941") ## Backdrop gradient, top.
const FRONT_FLOOR := Color("050c15") ## Backdrop gradient, bottom.
const FRONT_FAR := Color("14304a") ## Far wall.
const FRONT_NEAR := Color("1b3e5c") ## Near wall.

const BACK_SKY := Color("201540") ## Backdrop gradient, top.
const BACK_FLOOR := Color("0a0614") ## Backdrop gradient, bottom.
const BACK_FAR := Color("281b4d") ## Far wall.
const BACK_NEAR := Color("362566") ## Near wall.


## A solid's colour. A `BOTH` solid takes the hue of the player's current plane.
static func solid(plane: Planes.Kind, current: Planes.Kind) -> Color:
	var effective := current if plane == Planes.Kind.BOTH else plane
	return FRONT_SOLID if effective == Planes.Kind.FRONT else BACK_SOLID


## Faded when the entity lives in the other plane. A function, not a constant,
## because the alpha is read live from `Tuning`.
static func ghost(base: Color, active: bool) -> Color:
	if active:
		return base
	return Color(base.r, base.g, base.b, Tuning.cfg.ghost_alpha)


## The sand's colour at a given `Game.danger()`. Shared by sprite, HUD and light.
static func sand(danger: float) -> Color:
	return SAND_FULL.lerp(SAND_LOW, danger)


## The four room depths for a plane, in order: sky, floor, far wall, near wall.
static func room(plane: Planes.Kind) -> Array[Color]:
	if plane == Planes.Kind.BACK:
		return [BACK_SKY, BACK_FLOOR, BACK_FAR, BACK_NEAR]
	return [FRONT_SKY, FRONT_FLOOR, FRONT_FAR, FRONT_NEAR]
