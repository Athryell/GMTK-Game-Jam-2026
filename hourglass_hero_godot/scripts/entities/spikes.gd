@tool
## Spikes: a static hazard that kills on contact, within its own plane only.
class_name Spikes
extends PlaneArea

## Which way the teeth point — `UP` is a floor of spikes, `DOWN` a ceiling.
enum Facing { UP, DOWN, LEFT, RIGHT }

## Target width of one tooth, in px; the count is rounded so the row ends flush.
const TOOTH_SIZE := 16.0

## Fraction of the band's depth the teeth are drawn over, from the base. The
## author's rectangle sets the corridor, so draw less of it rather than shrink it.
const TOOTH_DEPTH := 0.62

## Fraction of the band's depth that kills, from the base. MUST stay below
## `TOOTH_DEPTH`, or the hitbox reaches past the drawn tips.
const LETHAL_DEPTH := 0.50

## Lighten/darken amounts for the two faces of a tooth.
const BEVEL_LIGHT := 0.22
const BEVEL_DARK := 0.36

@export var facing: Facing = Facing.UP: set = _set_facing


func _init() -> void:
	size = Vector2(120.0, 24.0)
	light_tint = Palette.MONSTER
	light_radius = 110.0
	light_energy = 0.55


func _touched(_player: Player) -> void:
	Game.kill()


func _draw() -> void:
	var lit := _shade(Palette.MONSTER.lightened(BEVEL_LIGHT))
	var dark := _shade(Palette.MONSTER.darkened(BEVEL_DARK))
	for tooth in _teeth():
		# The whole tooth, not each half: the seam is a fold in one solid.
		Outline.polygon(self, _whole(tooth), lit.a)
		HourglassShape.fill(self, tooth[0], lit)
		HourglassShape.fill(self, tooth[1], dark)


## A tooth's silhouette: the outer corner of each base and the shared tip. Read
## off the halves, so a change to `_teeth` cannot leave this drawing the old one.
static func _whole(tooth: Array) -> PackedVector2Array:
	var lit_half: PackedVector2Array = tooth[0]
	var dark_half: PackedVector2Array = tooth[1]
	return PackedVector2Array([lit_half[0], dark_half[1], lit_half[2]])


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


## One `[lit_half, dark_half]` triangle pair per tooth.
func _teeth() -> Array[Array]:
	var along_x: bool = _axis()[0]
	var base: float = _axis()[1]
	var tip := _tip()
	var span := size.x if along_x else size.y
	var count := maxi(1, int(round(span / TOOTH_SIZE)))
	var step := span / float(count)

	var out: Array[Array] = []
	for i in count:
		var a := i * step
		var b := a + step
		var mid := a + step / 2.0
		if along_x:
			out.append([
				PackedVector2Array([
					Vector2(a, base), Vector2(mid, base), Vector2(mid, tip)]),
				PackedVector2Array([
					Vector2(mid, base), Vector2(b, base), Vector2(mid, tip)])])
		else:
			out.append([
				PackedVector2Array([
					Vector2(base, a), Vector2(base, mid), Vector2(tip, mid)]),
				PackedVector2Array([
					Vector2(base, mid), Vector2(base, b), Vector2(tip, mid)])])
	return out


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
