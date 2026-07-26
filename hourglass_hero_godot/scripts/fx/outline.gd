## A dark line around a drawn shape, always OUTSIDE it — never under it, or a
## ghosted entity would composite over the ink and drag towards black.
class_name Outline
extends RefCounted

const WIDTH := 1.0
const INK := Color("0d0a14")


## The ink at the host's own alpha, so a ghost's outline fades as far as it does.
static func ink(alpha := 1.0) -> Color:
	return Color(INK.r, INK.g, INK.b, INK.a * alpha)


## A ring around `points`, one convex quad an edge. `Polygons.grow` mitres, so
## both quads at a corner read the same offset vertex and meet along it exactly.
static func polygon(canvas: CanvasItem, points: PackedVector2Array, alpha := 1.0) -> void:
	var count := points.size()
	if count < 3:
		return
	var out := Polygons.grow(points, WIDTH)
	var colour := ink(alpha)
	for i in count:
		var j := (i + 1) % count
		canvas.draw_colored_polygon(PackedVector2Array([
			points[i], points[j], out[j], out[i]]), colour)


## Size of one block of the dashed marker below, in px. Nothing in the art is
## smaller, so the marker reads as part of the same pixel grid.
const CELL := 4.0
## Blocks drawn, then blocks skipped, along the run. Both counted in `CELL`s.
const DASH_ON := 2
const DASH_OFF := 2


## A dashed line `distance` px outside the ink, blocked onto the `CELL` grid so a
## ramp comes out as a staircase rather than as a smooth diagonal: the walk
## follows the silhouette, the grid decides where the corners land.
static func dashes(canvas: CanvasItem, points: PackedVector2Array,
		colour: Color, distance: float) -> void:
	var count := points.size()
	if count < 3:
		return
	var ring := Polygons.grow(points, WIDTH + distance)
	var cells := PackedVector2Array()
	for i in count:
		var a := ring[i]
		var b := ring[(i + 1) % count]
		# Half a cell a step, so the walk cannot skip a cell it only clips.
		var steps := maxi(1, int(ceil(a.distance_to(b) / (CELL * 0.5))))
		for s in steps:
			var p := a.lerp(b, float(s) / float(steps))
			var cell := (p / CELL).floor() * CELL
			if cells.is_empty() or cells[cells.size() - 1] != cell:
				cells.append(cell)
	var period := DASH_ON + DASH_OFF
	# A cell the walk reached twice would be drawn twice, and come out brighter
	# than the dash beside it.
	var drawn := {}
	for i in cells.size():
		if i % period >= DASH_ON or drawn.has(cells[i]):
			continue
		drawn[cells[i]] = true
		canvas.draw_rect(Rect2(cells[i], Vector2(CELL, CELL)), colour)


## A ring around `rect`. Cut so the corners belong to the horizontal pair: a
## ghost's ink over ink comes out darker than the sides it joins.
static func rect(canvas: CanvasItem, box: Rect2, alpha := 1.0) -> void:
	if box.size.x <= 0.0 or box.size.y <= 0.0:
		return
	var colour := ink(alpha)
	var wide := box.size.x + WIDTH * 2.0
	canvas.draw_rect(Rect2(box.position.x - WIDTH, box.position.y - WIDTH,
		wide, WIDTH), colour)
	canvas.draw_rect(Rect2(box.position.x - WIDTH, box.end.y, wide, WIDTH), colour)
	canvas.draw_rect(Rect2(box.position.x - WIDTH, box.position.y,
		WIDTH, box.size.y), colour)
	canvas.draw_rect(Rect2(box.end.x, box.position.y, WIDTH, box.size.y), colour)


## A ring around a disc, stroked at `radius + WIDTH / 2` so the line lands
## between `radius` and `radius + WIDTH`. Segments follow the radius.
static func circle(canvas: CanvasItem, centre: Vector2, radius: float, alpha := 1.0) -> void:
	if radius <= 0.0:
		return
	canvas.draw_arc(centre, radius + WIDTH * 0.5, 0.0, TAU,
		maxi(12, int(radius * 2.0)), ink(alpha), WIDTH)
