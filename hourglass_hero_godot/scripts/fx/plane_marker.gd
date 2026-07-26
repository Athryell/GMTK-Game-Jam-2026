## The dashed line that says which plane a solid belongs to, and how much that
## matters this instant.
##
## One of these per solid, because the fade is per solid. The marker does not
## blink off the frame a jump lands: the slab you just took keeps a quiet line
## around it, and a slab the jump passed over walks its own line down to nothing.
## What moves is the strength, never the geometry — the dashes sit on the same
## pixels the whole way, so a fade reads as a fade rather than as a slab shifting.
class_name PlaneMarker
extends RefCounted

## Full strength: the plane the next jump lands in.
const OFFERED := 1.0
## Resting strength on a plane you are already standing in. Low enough to read as
## trim on stone you have been given, high enough that the slab still says which
## world it came from.
const HELD := 0.3
## Fade rate. Exponential, so the last of it is always the slowest part.
const FADE := 9.0
## Below this the line is nothing but a dark smear on the ink, so it is snapped
## off rather than left to crawl towards zero.
const EPSILON := 0.004

var alpha := 0.0
var _target := 0.0


## Where the marker is headed. `bound` is false for a `BOTH` solid: it belongs to
## no plane, so it has nothing to say and never draws.
func aim(bound: bool, active: bool, next: bool) -> void:
	if not bound:
		_target = 0.0
	elif next:
		_target = OFFERED
	elif active:
		_target = HELD
	else:
		_target = 0.0


## Puts the marker where it belongs with no fade, for the first frame of a level:
## a line that dawns on you as the level opens reads as something happening.
func settle() -> void:
	alpha = _target


## Steps the fade. True while it is still moving — that is, while the host has to
## keep redrawing itself.
func advance(delta: float) -> bool:
	if alpha == _target:
		return false
	alpha = lerpf(alpha, _target, 1.0 - exp(-FADE * delta))
	if absf(_target - alpha) < EPSILON:
		alpha = _target
	return true


## Lays the marker down around `points`, the solid's own silhouette.
func draw(canvas: CanvasItem, points: PackedVector2Array, plane: Planes.Kind) -> void:
	if alpha <= 0.0:
		return
	Outline.dashes(canvas, points, Palette.marker(plane, alpha),
		Tuning.cfg.next_outline_gap)
