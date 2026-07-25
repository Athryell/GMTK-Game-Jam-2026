## The game's colours, carried over from the JS prototype.
##
## Entities never hard-code a colour: they ask here, which keeps the two planes
## readable at a glance.
class_name Palette
extends RefCounted

const FRONT_SOLID := Color("48cae4")
const BACK_SOLID := Color("c77dff")
const SPRING := Color("7ae582") ## Spring: launches without flipping.
const FLIP_PAD := Color("ffc971") ## Flip-pad: refuels without changing plane.
const MONSTER := Color("ff5d6c")
const DOOR := Color("ffd166")

const GLASS := Color("e7ecff") ## Hourglass frame.
const SAND_FULL := Color("ffb03a")
const SAND_LOW := Color("ff3b3b")

const TEXT := Color("eaf0fb")
const TEXT_DIM := Color("9aa6c4")

const FRONT_BG := Color("0c1a2b")
const BACK_BG := Color("1a0f28")


## A solid's colour for its plane. A "BOTH" solid takes the hue of whichever
## plane the player is in, so you can always read where you are.
static func solid(plane: Planes.Kind, current: Planes.Kind) -> Color:
	var effective := current if plane == Planes.Kind.BOTH else plane
	return FRONT_SOLID if effective == Planes.Kind.FRONT else BACK_SOLID
