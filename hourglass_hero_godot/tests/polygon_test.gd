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
	_boxes()
	_winding()
	_normals()
	_growth()
	_finish()


## The plane tag hangs its chip off the polygon's first corner, so the order of
## the four points a hitbox is turned into is load-bearing, not cosmetic.
func _boxes() -> void:
	var box := Polygons.rect(Rect2(Vector2(4.0, 9.0), Vector2(32.0, 16.0)))
	_check("a rect starts at its top-left corner", box[0] == Vector2(4.0, 9.0))
	_check("a rect winds clockwise on screen", Polygons.winding(box) > 0.0)
	_check("a unit rect is the unit square",
		Polygons.rect(Rect2(Vector2.ZERO, Vector2.ONE)) == SQUARE_CW)


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
