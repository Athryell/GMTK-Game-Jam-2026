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
	if Engine.is_editor_hint():
		tag(canvas, points, plane)
		return
	if alpha <= 0.0:
		return
	Outline.dashes(canvas, points, Palette.marker(plane, alpha),
		Tuning.cfg.next_outline_gap)


# ----- Editor ----------------------------------------------------------------

## In the editor there is no current plane and nothing is a ghost, so the marker
## drops the strength ramp and becomes a label: every solid says which plane it
## is on, all the time, `BOTH` included.
const TAG_GAP := 2.0
const TAG_FONT_SIZE := 10
## What each plane is written as on the badge, `Planes.Kind` order.
const TAG_NAMES: Array[String] = ["0", "1", "2", "3", "BOTH"]
## A `BOTH` solid has no hue of its own — it takes the plane it is standing in.
const TAG_BOTH := Color("eef2ff")
const TAG_PADDING := Vector2(3.0, 1.0)


## The editor-only badge: the silhouette dashed in the plane's hue, plus its
## name in a chip above the shape's top-left corner.
##
## `Tuning` is not a `@tool` autoload, so the gap is a constant here rather than
## the tunable the running game dashes at.
static func tag(canvas: CanvasItem, points: PackedVector2Array,
		plane: Planes.Kind) -> void:
	if points.size() < 3:
		return
	var colour := TAG_BOTH if plane == Planes.Kind.BOTH \
		else Palette.solid(plane, plane)
	Outline.dashes(canvas, points, colour, TAG_GAP)

	var corner := points[0]
	for point in points:
		corner = Vector2(minf(corner.x, point.x), minf(corner.y, point.y))
	var font := ThemeDB.fallback_font
	var text: String = TAG_NAMES[clampi(int(plane), 0, TAG_NAMES.size() - 1)]
	var extent := font.get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TAG_FONT_SIZE)
	var chip := Rect2(
		corner - Vector2(0.0, extent.y + TAG_PADDING.y * 2.0 + TAG_GAP + 2.0),
		extent + TAG_PADDING * 2.0)
	canvas.draw_rect(chip, Outline.ink(0.85))
	canvas.draw_string(font,
		chip.position + TAG_PADDING + Vector2(0.0, font.get_ascent(TAG_FONT_SIZE)),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TAG_FONT_SIZE, colour)
