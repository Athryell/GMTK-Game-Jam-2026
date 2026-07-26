@tool
## Spikes: a static hazard that kills on contact, within its own plane only.
class_name Spikes
extends PlaneArea

## Which way the teeth point — `UP` is a floor of spikes, `DOWN` a ceiling.
enum Facing { UP, DOWN, LEFT, RIGHT }

const TEXTURE: Texture2D = preload("res://art/sprites/spike.png")

## Empty rows above the tip in the art. The stamp is grown by it so the painted
## tip, not the sprite's top edge, lands on `TOOTH_DEPTH`.
const ART_TIP := 3.0 / 16.0

## Target width of one tooth, in px; the count is rounded so the row ends flush.
const TOOTH_SIZE := 16.0

## Fraction of the band's depth the teeth are drawn over, from the base. The
## author's rectangle sets the corridor, so draw less of it rather than shrink it.
const TOOTH_DEPTH := 0.62

## Fraction of the band's depth that kills, from the base. MUST stay below
## `TOOTH_DEPTH`, or the hitbox reaches past the drawn tips.
const LETHAL_DEPTH := 0.50

@export var facing: Facing = Facing.UP: set = _set_facing


func _init() -> void:
	size = Vector2(120.0, 24.0)
	light_tint = Palette.MONSTER
	light_radius = 110.0
	light_energy = 0.55


func _ready() -> void:
	# See `terrain.gd` for why this is per-node rather than a project default.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	super()


func _touched(_player: Player) -> void:
	Game.kill()


## One stamp per tooth, in a frame where `x` runs along the band and `y` from the
## sprite's outer edge in towards the base, so the four facings differ only by it.
func _paint() -> void:
	var along_x: bool = _axis()[0]
	var span := size.x if along_x else size.y
	var count := maxi(1, int(round(span / TOOTH_SIZE)))
	var step := span / float(count)
	var stamp := absf(_tip() - _axis()[1]) / (1.0 - ART_TIP)

	draw_set_transform_matrix(_stamp_frame(stamp))
	# White is the sprite's own colours untouched; `_shade` only ghosts the alpha.
	var tint := _shade(Color.WHITE)
	for i in count:
		draw_texture_rect(TEXTURE, Rect2(i * step, 0.0, step, stamp), false, tint)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## That frame in node space, for a stamp `depth` px deep.
func _stamp_frame(depth: float) -> Transform2D:
	match facing:
		Facing.UP:
			return Transform2D(Vector2.RIGHT, Vector2.DOWN, Vector2(0.0, size.y - depth))
		Facing.DOWN:
			return Transform2D(Vector2.RIGHT, Vector2.UP, Vector2(0.0, depth))
		Facing.LEFT:
			return Transform2D(Vector2.DOWN, Vector2.RIGHT, Vector2(size.x - depth, 0.0))
		_:
			return Transform2D(Vector2.DOWN, Vector2.LEFT, Vector2(depth, 0.0))


## `[teeth_run_along_x, base_edge, far_edge]` on the pointing axis. `far_edge`
## is the far side of the box, not the tips — see `_tip()`.
func _axis() -> Array:
	match facing:
		Facing.UP: return [true, size.y, 0.0]
		Facing.DOWN: return [true, 0.0, size.y]
		Facing.LEFT: return [false, size.x, 0.0]
		_: return [false, 0.0, size.x]


## Where the tips land: `TOOTH_DEPTH` of the way from the base to the far edge.
func _tip() -> float:
	return lerpf(_axis()[1], _axis()[2], TOOTH_DEPTH)


func _set_facing(value: Facing) -> void:
	facing = value
	_apply_size()


## The hitbox is the lethal slab against the band's base — see `LETHAL_DEPTH`.
func _apply_size() -> void:
	queue_redraw()
	if not is_node_ready():
		return
	var along_x: bool = _axis()[0]
	var base: float = _axis()[1]
	var rect := _shape.shape as RectangleShape2D
	var depth := (size.y if along_x else size.x) * LETHAL_DEPTH
	var inward := -depth / 2.0 if base > 0.0 else depth / 2.0
	if along_x:
		rect.size = Vector2(size.x, depth)
		_shape.position = Vector2(size.x / 2.0, base + inward)
	else:
		rect.size = Vector2(depth, size.y)
		_shape.position = Vector2(base + inward, size.y / 2.0)
