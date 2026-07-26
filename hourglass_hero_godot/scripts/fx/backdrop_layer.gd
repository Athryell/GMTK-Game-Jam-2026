## One painted depth of the room: a texture tiled sideways and slid against the
## camera, drawn at `Backdrop.ART_SCALE` from its authored 576×324 export.
## Sliding it against the camera is the whole parallax trick — quickly sideways,
## barely at all vertically.
class_name BackdropLayer
extends Node2D

## 1.0 moves with the world, 0.0 is pinned to the camera, above 1.0 rushes past.
var scroll := 0.35
var texture: Texture2D

## Horizontal overdraw beyond the level on every side, in world px, so a layer
## scrolling at a different rate than the camera never runs out of itself at
## the screen edges.
const MARGIN := 700.0

var _world := Vector2(960.0, 540.0)
var _floor_y := 540.0
## Camera height the vertical parallax is measured from: whatever the camera
## snapped to when this level opened. NAN until the first `sync` latches it.
var _datum_y := NAN


func _ready() -> void:
	# Painted at one art px to one world px like everything else; see
	# `terrain.gd` for why this is per-node rather than a project default. The
	# SKY behind these layers is a gradient and deliberately keeps linear.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Sizes the tile run to a level. `_draw` reads `_world`/`_floor_y` fresh each
## redraw. `floor_y` is where the ground actually sits — not always
## `world_size.y`, which only bounds how far you can fall.
func configure(world_size: Vector2, floor_y: float) -> void:
	_world = world_size
	# Snapped to a whole art px so the bottom edge lands on a texel boundary. A
	# level whose ground sits on an odd world px would otherwise plant the art
	# half a texel low, and every horizontal in it — every truss, every roofline —
	# would be sampled across that seam for the length of the level.
	_floor_y = _snap(floor_y)
	scale = Vector2.ONE * Backdrop.ART_SCALE
	# Dropped so the next `sync` re-latches against the new level's camera.
	# `main.gd` snaps the camera between this and that call, so what it latches
	# is the resting height, not the previous level's.
	_datum_y = NAN
	queue_redraw()


## Sideways at this layer's own rate; vertically at one slow rate shared by every
## depth, and measured from `_datum_y` rather than from the world origin.
##
## The datum is the whole reason this can move vertically at all. Against the
## origin the offset is `camera.y * (1 - scroll)` — hundreds of px with the
## camera anywhere near the floor, which lifts the art clean off the ground it
## is anchored to. Against the camera's resting height it is zero at rest and
## only grows as you climb, so the skyline stays planted and merely breathes.
##
## Landed on a whole art px, not on a whole world px. The camera moves in
## fractions of a px and the parallax rates are fractions of that, so an
## unsnapped layer sits between texels and stays there — nearest sampling then
## picks a side per texel and the thin work in the art crawls and drops rows as
## you walk. Snapping it means the layer moves in visible steps of one art px,
## which is what the sand and everything else in the game already do.
func sync(camera_position: Vector2) -> void:
	if is_nan(_datum_y):
		_datum_y = camera_position.y
	position = Vector2(
		_snap(camera_position.x * (1.0 - scroll)),
		_snap((camera_position.y - _datum_y) * (1.0 - Backdrop.VERTICAL_SCROLL)))


## `value` rounded to a whole art px, in world px. At an `ART_SCALE` of 1 this is
## a plain round; the point of it is every other scale.
static func _snap(value: float) -> float:
	return roundf(value / Backdrop.ART_SCALE) * Backdrop.ART_SCALE


## Ground-anchored: the art's bottom edge sits on the level's terrain, tiled
## sideways to cover the level plus overdraw. Above it is open sky — a tall,
## climbing level simply outgrows its own skyline.
func _draw() -> void:
	if texture == null:
		return
	var size := texture.get_size()
	# Whole art px on every edge. `left` is where the tile run starts, so a
	# fraction there would offset every copy across the level by part of a texel;
	# the other two only decide where the run is cut, and are rounded to keep the
	# rect honest rather than because anything depends on it.
	var left := floorf(-MARGIN / Backdrop.ART_SCALE)
	var right := ceilf((_world.x + MARGIN) / Backdrop.ART_SCALE)
	var bottom := _floor_y / Backdrop.ART_SCALE
	draw_texture_rect(texture, Rect2(left, bottom - size.y, right - left, size.y), true)
