## Polygon test: the geometry the drawn ground and its shadow both stand on,
## with nothing rendered and no game running.
##
##   godot --headless tests/polygon_test.tscn
##
## Screen space throughout — y grows DOWNWARD — which is easy to get backwards
## and impossible to see once it is wrong: a floor lit along its underside still
## looks like a floor in a screenshot.
extends Node

var _failures := 0

## A unit square, wound clockwise on screen: top-left, top-right, bottom-right,
## bottom-left. Not a `const` — a packed array is built by a constructor call,
## which the parser cannot fold.
static var SQUARE_CW := PackedVector2Array([
	Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0),
])


func _ready() -> void:
	_winding()
	_normals()
	_growth()
	_resizing()
	_finish()


## Clockwise on screen is positive. Everything else here is turned by this sign,
## so if it flips, every polygon in the game turns inside out at once.
func _winding() -> void:
	_check("a clockwise square winds positive",
		Polygons.winding(SQUARE_CW) > 0.0)
	var anticlockwise := SQUARE_CW.duplicate()
	anticlockwise.reverse()
	_check("reversing the points flips the winding",
		Polygons.winding(anticlockwise) < 0.0)


## The normals must point OUT of the square whichever way round it is wound.
func _normals() -> void:
	var anticlockwise := SQUARE_CW.duplicate()
	anticlockwise.reverse()
	for points in [SQUARE_CW, anticlockwise]:
		var wind := Polygons.winding(points)
		var facing: Array[bool] = []
		for i in points.size():
			var a: Vector2 = points[i]
			var b: Vector2 = points[(i + 1) % points.size()]
			facing.append(Polygons.faces_up(a, b, wind))
		_check("exactly one side of a square faces the sky (wind %d)" % int(wind),
			facing.count(true) == 1, "%d did" % facing.count(true))

	# A ramp is a floor; a wall is not, and neither is the same ramp upside down.
	var wind := Polygons.winding(SQUARE_CW)
	_check("a gentle ramp counts as a floor",
		Polygons.faces_up(Vector2(0.0, 30.0), Vector2(80.0, 4.0), wind))
	_check("a vertical face does not",
		not Polygons.faces_up(Vector2(0.0, 0.0), Vector2(0.0, 40.0), wind))
	_check("a ceiling does not",
		not Polygons.faces_up(Vector2(40.0, 0.0), Vector2(0.0, 0.0), wind))


## The offset that gives a shadow its penumbra. A long thin floor must grow by
## the same amount on all four sides.
func _growth() -> void:
	var floor_slab := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(960.0, 0.0), Vector2(960.0, 38.0), Vector2(0.0, 38.0)])
	var grown := Polygons.grow(floor_slab, 2.0)
	var box := Rect2(grown[0], Vector2.ZERO)
	for point in grown:
		box = box.expand(point)
	_check("growing a 960x38 slab by 2 widens it by 4",
		is_equal_approx(box.size.x, 964.0), "it is %.2f wide" % box.size.x)
	_check("growing a 960x38 slab by 2 heightens it by 4",
		is_equal_approx(box.size.y, 42.0), "it is %.2f tall" % box.size.y)
	_check("a degenerate polygon is returned untouched",
		Polygons.grow(PackedVector2Array([Vector2.ZERO, Vector2.ONE]), 2.0).size() == 2)

## Typing a size into the inspector: the ground must land on exactly that box,
## keep the corner it was placed by, and keep the shape of a slope.
func _resizing() -> void:
	var slab := PackedVector2Array([
		Vector2(40.0, 100.0), Vector2(240.0, 100.0),
		Vector2(240.0, 160.0), Vector2(40.0, 160.0)])
	var wider := Polygons.resize(slab, Vector2(400.0, 30.0))
	var box := Polygons.bounds(wider)
	_check("a resized slab measures what was typed",
		box.size.is_equal_approx(Vector2(400.0, 30.0)), "it is %v" % box.size)
	_check("and it grows away from the corner it was placed by",
		box.position.is_equal_approx(Vector2(40.0, 100.0)), "it starts at %v" % box.position)

	# A ramp is the case a plain rectangle cannot catch: its slope has to survive.
	var ramp := PackedVector2Array([
		Vector2(0.0, 40.0), Vector2(80.0, 0.0), Vector2(80.0, 80.0), Vector2(0.0, 80.0)])
	var doubled := Polygons.resize(ramp, Vector2(160.0, 160.0))
	_check("doubling a ramp keeps its gradient",
		is_equal_approx((doubled[1].y - doubled[0].y) / (doubled[1].x - doubled[0].x),
			(ramp[1].y - ramp[0].y) / (ramp[1].x - ramp[0].x)))

	# Dragging the LEFT side of that same slab: the right side must not budge.
	var pulled := Polygons.fit(slab, Rect2(Vector2(180.0, 100.0), Vector2(60.0, 60.0)))
	_check("pulling one side leaves the opposite one where it was",
		is_equal_approx(Polygons.bounds(pulled).end.x, 240.0),
		"it ends at %.2f" % Polygons.bounds(pulled).end.x)

	# The one shape with no height to scale from: a flat line stays flat rather
	# than blowing up on a division by zero.
	var flat := PackedVector2Array([
		Vector2.ZERO, Vector2(100.0, 0.0), Vector2(50.0, 0.0)])
	_check("an axis with no length to scale is left alone",
		Polygons.bounds(Polygons.resize(flat, Vector2(200.0, 60.0))).size
			.is_equal_approx(Vector2(200.0, 0.0)))


# ----- Harness ---------------------------------------------------------------

func _check(what: String, passed: bool, detail := "") -> void:
	if passed:
		print("ok   %s" % what)
		return
	_failures += 1
	print("FAIL %s%s" % [what, "" if detail.is_empty() else " (%s)" % detail])


func _finish() -> void:
	if _failures == 0:
		print("All checks passed.")
	else:
		print("%d check(s) failed." % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
