## The masonry every solid is built from: one seamless greyscale tile, tinted at
## draw time.
##
## Greyscale on purpose. Modulating a single texture is what lets the stone
## change with the sky from level to level without a second file, and it leaves
## the ghost alpha working exactly as it did when solids were flat rectangles.
##
## Every consumer must set `texture_repeat = TEXTURE_REPEAT_ENABLED` on itself:
## the tile is 64 px and the shortest platform in the game is wider than that.
class_name Bricks
extends RefCounted

const TEXTURE: Texture2D = preload("res://art/sprites/bricks_1.png")
## The tile is square and seamless — 4 courses of 16×8 brick, offset by half a
## brick each row, so any multiple of it lines up with itself.
const TILE := 64.0

## Thickness of the lit lip along an up-facing edge, and how far it is lifted
## out of the body colour. Faint on purpose: enough to catch the top of a slab
## against the sky behind it, not so much that it reads as a painted stripe.
const LIP_WIDTH := 3.0
const LIP_LIFT := 0.15


## Fills a polygon with brick. `points` are in the canvas's own coordinates, and
## they double as the UVs once divided by the tile: courses run unbroken across
## every triangle a piece of ground is cut into, rather than restarting at each.
static func polygon(canvas: CanvasItem, points: PackedVector2Array, tint: Color) -> void:
	var uvs := PackedVector2Array()
	uvs.resize(points.size())
	for i in points.size():
		uvs[i] = points[i] / TILE
	canvas.draw_colored_polygon(points, tint, uvs, TEXTURE)
