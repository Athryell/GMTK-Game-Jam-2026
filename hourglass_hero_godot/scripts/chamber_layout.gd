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
##
## Meaningful for two to four chambers. Above four a glass has more than one
## chamber draining at a time and the sand economy stops being defined; below
## two there is nowhere for the sand to fall. Nothing here enforces that — the
## cap lives on `Level.chambers`, where a designer can see it.
class_name ChamberLayout
extends RefCounted

## What a chamber does with sand, decided by where it points.
enum Role {
	UPPER, ## Points above the neck. It drains.
	LOWER, ## Points below it. It receives.
	LEVEL, ## Points along the horizon. Sealed: it neither drains nor receives.
}

## The slack in every comparison here, and it does two jobs: how far off the
## horizon a chamber has to point before it counts as draining, and how close
## two falls have to be before they count as tied.
##
## Both are only ever tripped by floating-point noise. The axes are exact
## multiples of a turn, so the smallest real `y` is `sin(PI / N)` and the
## smallest real gap between two candidate falls is `TAU / N` — both stay orders
## of magnitude above this until N is in the thousands. Retune it and you retune
## both, which is why they share a name rather than drifting apart.
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
			best = minf(best, angle)
			out.append(i)
	return out


static func _with_role(count: int, wanted: Role) -> Array[int]:
	var out: Array[int] = []
	for i in count:
		if role(count, i) == wanted:
			out.append(i)
	return out
