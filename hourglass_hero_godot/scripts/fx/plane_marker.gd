@tool
## The dashed line that says which plane a solid belongs to, and how much that
## matters this instant.
##
## `@tool` because the editor refuses to instantiate a non-tool script: without
## it, `PlaneMarker.new()` in `Platform` and `Terrain` comes back null.
##
## The strength cuts, it does not fade: the stone changes on the frame the flip
## lands, and a line easing after it reads as lagging its own slab.
class_name PlaneMarker
extends RefCounted

## The plane the next jump lands in. Still short of full — the stone under it is
## a ghost, and a line drawn harder than the shape it rings stops being its edge.
const OFFERED := 0.65
## Resting strength on the plane you are standing in: trim, not a signal.
const HELD := 0.3

var alpha := 0.0


## `bound` is false for a `BOTH` solid: it belongs to no plane, so it has nothing
## to say and never draws.
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
