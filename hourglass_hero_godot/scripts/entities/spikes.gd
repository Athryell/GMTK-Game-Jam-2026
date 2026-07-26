@tool
## Spikes: a static hazard that kills on contact, within its own plane only.
class_name Spikes
extends PlaneArea

## Which way the teeth point — `UP` is a floor of spikes, `DOWN` a ceiling.
enum Facing { UP, DOWN, LEFT, RIGHT }

const TEXTURE: Texture2D = preload("res://art/sprites/spike.png")

## One tooth, in px, square — the art is 16×16 and is drawn one art px to one
## world px, like the hourglass, the clock and the brick. Nothing stretches it:
## the band's rectangle says how much corridor to fill, never how big a tooth is.
const TOOTH_SIZE := 16.0

## How deep the killing slab is, measured from the band's base, in px.
##
## MUST stay under 13 — the art leaves 3 rows empty above the painted tip, so a
## 16 px tooth only reaches 13 px out of the base. Absolute rather than the
## fraction of the band's depth it used to be: the teeth no longer grow with the
## rectangle, so a fraction would march out past them the moment a band was
## drawn deeper than 24.
const LETHAL_DEPTH := 10.0

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
	draw_set_transform_matrix(_stamp_frame())
	# White is the sprite's own colours untouched; `_shade` only ghosts the alpha.
	var tint := _shade(Color.WHITE)
	var start := _margin()
	for i in _teeth():
		draw_texture_rect(TEXTURE,
			Rect2(start + i * TOOTH_SIZE, 0.0, TOOTH_SIZE, TOOTH_SIZE), false, tint)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## That frame in node space. The stamp is exactly one tooth deep, so a band drawn
## deeper than a tooth is corridor behind the teeth rather than a bigger tooth.
func _stamp_frame() -> Transform2D:
	match facing:
		Facing.UP:
			return Transform2D(Vector2.RIGHT, Vector2.DOWN, Vector2(0.0, size.y - TOOTH_SIZE))
		Facing.DOWN:
			return Transform2D(Vector2.RIGHT, Vector2.UP, Vector2(0.0, TOOTH_SIZE))
		Facing.LEFT:
			return Transform2D(Vector2.DOWN, Vector2.RIGHT, Vector2(size.x - TOOTH_SIZE, 0.0))
		_:
			return Transform2D(Vector2.DOWN, Vector2.LEFT, Vector2(TOOTH_SIZE, 0.0))


## `[teeth_run_along_x, base_edge]` on the pointing axis.
func _axis() -> Array:
	match facing:
		Facing.UP: return [true, size.y]
		Facing.DOWN: return [true, 0.0]
		Facing.LEFT: return [false, size.x]
		_: return [false, 0.0]


## How many WHOLE teeth fit along the band. Rounded down, never up: a part tooth
## at the end is a tooth at the wrong size, which is the one thing this is here
## to prevent.
func _teeth() -> int:
	return maxi(1, int(floorf(_span() / TOOTH_SIZE)))


## Half the length the whole teeth leave over, so the run sits centred in the
## band instead of piling the remainder against one end.
func _margin() -> float:
	return maxf(_span() - _teeth() * TOOTH_SIZE, 0.0) / 2.0


func _span() -> float:
	return size.x if _axis()[0] else size.y


func _set_facing(value: Facing) -> void:
	facing = value
	_apply_size()


## The hitbox is the lethal slab against the band's base — see `LETHAL_DEPTH`.
##
## It spans the RUN of teeth, not the whole band. Whole teeth rarely fill the
## rectangle exactly, and a hitbox covering the leftover would kill on bare
## ground at the ends of every row that is not a multiple of 16.
func _apply_size() -> void:
	queue_redraw()
	if not is_node_ready():
		return
	var along_x: bool = _axis()[0]
	var base: float = _axis()[1]
	var rect := _shape.shape as RectangleShape2D
	var inward := -LETHAL_DEPTH / 2.0 if base > 0.0 else LETHAL_DEPTH / 2.0
	var run := _teeth() * TOOTH_SIZE
	var centre := _margin() + run / 2.0
	if along_x:
		rect.size = Vector2(run, LETHAL_DEPTH)
		_shape.position = Vector2(centre, base + inward)
	else:
		rect.size = Vector2(LETHAL_DEPTH, run)
		_shape.position = Vector2(base + inward, centre)
