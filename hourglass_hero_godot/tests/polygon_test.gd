## Polygon test: the geometry the drawn ground and its shadow both stand on,
## with nothing rendered and no game running.
##
##   godot --headless tests/polygon_test.tscn
##
## Screen space throughout — y grows DOWNWARD — which is the one thing that is
## easy to get backwards and impossible to see once it is wrong: a floor lit
## along its underside still looks like a floor in a screenshot.
extends Node

## Every level's ground, walked for slopes no one could climb.
const LEVELS := "res://scenes/levels"

## The steepest face `move_and_slide` will still call a floor. Godot's own
## default, and `player.gd` leaves it alone.
const FLOOR_MAX_ANGLE := 45.0

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
	_level_slopes()
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
## the same amount on all four sides — pushing every point away from the middle
## instead would grow it almost entirely along its length.
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


## Every up-facing edge of every level's ground must be climbable. A ramp one
## degree past `floor_max_angle` is not a slope, it is a wall you can see over —
## and the level it blocks is the level nobody can finish.
func _level_slopes() -> void:
	var checked := 0
	for path in _level_paths():
		var level := (load(path) as PackedScene).instantiate()
		for node in level.find_children("*", "CollisionPolygon2D", true, false):
			var points: PackedVector2Array = (node as CollisionPolygon2D).polygon
			if points.size() < 3:
				continue
			var wind := Polygons.winding(points)
			for i in points.size():
				var a: Vector2 = points[i]
				var b: Vector2 = points[(i + 1) % points.size()]
				if not Polygons.faces_up(a, b, wind):
					continue
				checked += 1
				var slope := rad_to_deg(absf((b - a).angle()))
				_check("%s: the face %s-%s is climbable" % [path.get_file(), a, b],
					slope <= FLOOR_MAX_ANGLE, "it rises at %.1f degrees" % slope)
		level.free()
	_check("some ground was actually walked", checked > 0,
		"no level has an up-facing polygon edge")


func _level_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	for name in DirAccess.get_files_at(LEVELS):
		# Exported builds rename `.tscn` to `.remap`; the editor run does not.
		if name.ends_with(".tscn"):
			paths.append("%s/%s" % [LEVELS, name])
	paths.sort()
	return paths


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
