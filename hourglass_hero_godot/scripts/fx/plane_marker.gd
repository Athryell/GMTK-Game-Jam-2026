## The dashed line that says which plane a solid belongs to, and how much that
## matters this instant.
##
## The strength cuts, it does not fade. A flip is one frame in the fiction — the
## world you are in changes on the beat of the jump — and a line easing between
## two levels lays a quarter second of "neither" over the frame the player is
## reading to find out where the ground went. The stone under it changes on that
## same frame, so anything slower reads as the marker lagging its own slab.
class_name PlaneMarker
extends RefCounted

## The plane the next jump lands in. The strongest the line ever gets, and still
## short of full: the stone under it is a ghost, and a line drawn harder than the
## thing it is drawn around stops being that thing's edge.
const OFFERED := 0.65
## Resting strength on a plane you are already standing in. Low enough to read as
## trim on stone you have been given, high enough that the slab still says which
## world it came from.
const HELD := 0.3

var alpha := 0.0


## Sets the marker's strength for the state its host is now in. `bound` is false
## for a `BOTH` solid: it belongs to no plane, so it has nothing to say and never
## draws.
func aim(bound: bool, active: bool, next: bool) -> void:
	if not bound:
		alpha = 0.0
	elif next:
		alpha = OFFERED
	elif active:
		alpha = HELD
	else:
		alpha = 0.0


## Lays the marker down around `points`, the solid's own silhouette.
func draw(canvas: CanvasItem, points: PackedVector2Array, plane: Planes.Kind) -> void:
	if alpha <= 0.0:
		return
	Outline.dashes(canvas, points, Palette.marker(plane, alpha),
		Tuning.cfg.next_outline_gap)
