## What a glass with N chambers is, before anything is drawn or any sand moves.
##
## Every rule the multi-chamber glass has follows from one sentence: chamber `i`
## points at angle `i * TAU / N`, clockwise from straight up. Which chambers
## drain, which receive, which are sealed, and who pours into whom all fall out
## of that, so there is no table to keep in sync with the picture.
##
## Meaningful for two to four chambers: above four more than one chamber drains
## at a time and the sand economy stops being defined. The cap lives on
## `Level.chambers`, where a designer can see it.
class_name ChamberLayout
extends RefCounted

## What a chamber does with sand, decided by where it points.
enum Role {
	UPPER, ## Points above the neck. It drains.
	LOWER, ## Points below it. It receives.
	LEVEL, ## Points along the horizon. Sealed: it neither drains nor receives.
}

## The slack in every comparison here: how far off the horizon a chamber has to
## point before it counts as draining, and how close two falls have to be before
## they count as tied. Only ever tripped by floating-point noise — the smallest
## real values are `sin(PI / N)` and `TAU / N`.
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
## straight down as it sees it, empty for a chamber that does not drain. A tie
## splits the fall evenly, which is the whole of the three-chamber glass.
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
