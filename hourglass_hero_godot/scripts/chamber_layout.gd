## What a glass with N chambers is, before anything is drawn or any sand moves.
##
## Every rule the multi-chamber glass has is a consequence of one sentence:
## chamber `i` points at angle `i * TAU / N`, measured clockwise from straight
## up. Which chambers drain, which receive, which are sealed shut, and who pours
## into whom all fall out of that — there is no table anywhere to keep in sync
## with the picture, which is the only reason four chambers cost about as much
## as two.
##
## Two chambers is not a special case here. It is this formula at N=2, and it
## lands on exactly the hourglass that shipped.
class_name ChamberLayout
extends RefCounted

## What a chamber does with sand, decided by where it points.
enum Role {
	UPPER, ## Points above the neck. It drains.
	LOWER, ## Points below it. It receives.
	LEVEL, ## Points along the horizon. Sealed: it neither drains nor receives.
}

## How far off the horizon a chamber's axis has to point before it counts as
## draining. Small, and only ever tripped by floating-point noise — the axes are
## exact multiples of a turn, so a side chamber's `y` is 0 to within an epsilon,
## never to within a design choice.
const HORIZON := 0.001


## Which way chamber `index` points, in the glass's own frame. Slot 0 is
## straight up and the rest follow clockwise on screen, where `y` grows downward.
static func axis(count: int, index: int) -> Vector2:
	return Vector2.UP.rotated(TAU * index / float(count))


static func role(count: int, index: int) -> Role:
	var y := axis(count, index).y
	if y < -HORIZON:
		return Role.UPPER
	if y > HORIZON:
		return Role.LOWER
	return Role.LEVEL


static func uppers(count: int) -> Array[int]:
	return _with_role(count, Role.UPPER)


static func lowers(count: int) -> Array[int]:
	return _with_role(count, Role.LOWER)


## Where chamber `index` sends its sand: the receiving chambers nearest to
## straight down as it sees it. A tie splits the fall evenly, and that tie is the
## whole of the three-chamber glass — there is no chamber opposite the top one,
## so the sand goes half into each of the two below.
##
## Empty for a chamber that does not drain.
static func targets(count: int, index: int) -> Array[int]:
	if role(count, index) != Role.UPPER:
		return []
	var falling := -axis(count, index)
	var best := INF
	var out: Array[int] = []
	for i in lowers(count):
		var angle := absf(falling.angle_to(axis(count, i)))
		if angle < best - HORIZON:
			best = angle
			out = [i]
		elif angle < best + HORIZON:
			out.append(i)
	return out


static func _with_role(count: int, wanted: Role) -> Array[int]:
	var out: Array[int] = []
	for i in count:
		if role(count, i) == wanted:
			out.append(i)
	return out
