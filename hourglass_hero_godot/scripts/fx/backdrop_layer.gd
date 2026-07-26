## One painted depth of the room: a texture tiled sideways and slid against the
## camera, drawn at `Backdrop.ART_SCALE` from its authored 576×324 export.
## Sliding it against the camera is the whole parallax trick — quickly sideways,
## barely at all vertically.
class_name BackdropLayer
extends Node2D

## 1.0 moves with the world, 0.0 is pinned to the camera, above 1.0 rushes past.
var scroll := 0.35
var texture: Texture2D

## The air in front of this depth. Drawn over this layer's own art, so it veils
## every layer behind it too.
var fog := Color.WHITE
var fog_alpha := 0.0

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
	# See `terrain.gd` for why this is per-node. The SKY behind these layers is a
	# gradient and deliberately keeps linear.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Sizes the tile run to a level. `_draw` reads `_world`/`_floor_y` fresh each
## redraw. `floor_y` is where the ground actually sits — not always
## `world_size.y`, which only bounds how far you can fall.
func configure(world_size: Vector2, floor_y: float) -> void:
	_world = world_size
	# Snapped so the bottom edge lands on a texel boundary: half a texel low, every
	# horizontal in the art is sampled across a seam for the length of the level.
	_floor_y = _snap(floor_y)
	scale = Vector2.ONE * Backdrop.ART_SCALE
	# `main.gd` snaps the camera between this and the next `sync`, so what that
	# latches is the new level's resting height.
	_datum_y = NAN
	queue_redraw()


## Sideways at this layer's own rate; vertically at one slow rate shared by every
## depth, and measured from `_datum_y` rather than from the world origin — against
## the origin the offset would lift the art clean off the ground it is anchored
## to whenever the camera sat near the floor.
##
## Landed on a whole ART px: unsnapped, the layer sits between texels and nearest
## sampling makes the thin work in the art crawl and drop rows as you walk.
func sync(camera_position: Vector2) -> void:
	if is_nan(_datum_y):
		_datum_y = camera_position.y
	var drop := camera_position.y - _datum_y
	position = Vector2(
		_snap(camera_position.x * (1.0 - scroll)),
		_snap(drop - vertical_lag(drop)))


## How far the art trails a camera that has dropped `drop` px below the datum.
## Capped at the margin the art is planted below the ground: trail any further
## and the bottom edge clears that ground, and a long fall opens a strip of bare
## sky under the skyline.
static func vertical_lag(drop: float) -> float:
	return minf(drop * Backdrop.VERTICAL_SCROLL, Backdrop.ART_DROP)


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
	# `left` is where the tile run starts, so a fraction there would offset every
	# copy across the level by part of a texel.
	var left := floorf(-MARGIN / Backdrop.ART_SCALE)
	var right := ceilf((_world.x + MARGIN) / Backdrop.ART_SCALE)
	var bottom := _floor_y / Backdrop.ART_SCALE
	draw_texture_rect(texture, Rect2(left, bottom - size.y, right - left, size.y), true)
	_draw_fog(left, right, bottom - size.y, bottom)


## A gouraud quad rather than a `draw_rect`: a rect is one flat colour, and a
## flat veil reads as a sheet of tinted glass instead of air.
func _draw_fog(left: float, right: float, top: float, bottom: float) -> void:
	if fog_alpha <= 0.0:
		return
	var high := Color(fog.r, fog.g, fog.b, fog_alpha * Backdrop.FOG_TOP)
	var low := Color(fog.r, fog.g, fog.b, fog_alpha)
	draw_polygon(
		PackedVector2Array([
			Vector2(left, top), Vector2(right, top),
			Vector2(right, bottom), Vector2(left, bottom)]),
		PackedColorArray([high, high, low, low]))
