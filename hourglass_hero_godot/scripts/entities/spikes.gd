@tool
## Spikes: a static hazard that kills on contact, within its own plane only.
##
## A monster that does not walk — same contract, same signals, different head.
## It exists to say "do not jump here" in a way the player can see. A low ceiling
## would forbid the jump; spikes show why it is forbidden, and that teaches.
class_name Spikes
extends PlaneArea

## Which way the teeth point — i.e. which side the player comes from. `UP` is a
## floor of spikes, `DOWN` a ceiling of them.
enum Facing { UP, DOWN, LEFT, RIGHT }

## Target width of one tooth, in px. The band fits a whole number of teeth into
## its length, so the row always ends flush with the band's edge.
##
## Held at 16 deliberately. Narrower teeth read as delicate on a short band and
## as a comb on a long one, and the longest band in the game is 880px — at 11px
## that is eighty teeth, the bevel below collapses into a single tone, and the
## row goes back to being the flat stripe this shape exists to stop being.
const TOOTH_SIZE := 16.0

## How much of the band's depth the teeth actually occupy, measured from the
## base. Short teeth in a tall box: the level author's rectangle is load-bearing
## — at a ceiling it sets the corridor the player squeezes through — so the way
## to make spikes lighter is to draw less of it, never to shrink it.
const TOOTH_DEPTH := 0.62

## Fraction of the band's depth that actually kills, measured from the base.
## The tips are visual overhang: you die once you are properly into the teeth,
## not when you brush a point. Spikes that kill on their outline feel cheap.
##
## MUST stay below `TOOTH_DEPTH`. Above it the kill zone reaches past the drawn
## tips and the band starts killing through empty air, which is the same unfair
## death read from the other side.
const LETHAL_DEPTH := 0.50

## How far the lit and shadow faces sit either side of the base colour. One
## tooth split down its spine reads as a solid object; a single fill reads as a
## paper cut-out, which is what the flat version looked like.
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
		HourglassShape.fill(self, tooth[0], lit)
		HourglassShape.fill(self, tooth[1], dark)


## Which way this band points, as numbers: whether the teeth run along x, and
## the two coordinates on the pointing axis — the flat back edge, and the tips.
##
## One source for both the drawing and the hitbox. They used to be two `match`
## blocks over the same enum, which is how you end up with spikes whose teeth
## and whose lethal slab face opposite ways, with nothing on screen to show it.
func _axis() -> Array:
	match facing:
		Facing.UP: return [true, size.y, 0.0]
		Facing.DOWN: return [true, 0.0, size.y]
		Facing.LEFT: return [false, size.x, 0.0]
		_: return [false, 0.0, size.x]


## Where the tips land: `TOOTH_DEPTH` of the way from the back edge to the far
## one, so the teeth stop short of the box the level declares.
func _tip() -> float:
	return lerpf(_axis()[1], _axis()[2], TOOTH_DEPTH)


## Two half-triangles per tooth — the lit face then the shadow face, split down
## the spine from base to tip. Returned as halves rather than as whole teeth
## because the split IS the shape: there is no caller that wants one triangle.
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
	# The slab hangs off the base edge, into the band.
	var depth := (size.y if along_x else size.x) * LETHAL_DEPTH
	var inward := -depth / 2.0 if base > 0.0 else depth / 2.0
	if along_x:
		rect.size = Vector2(size.x, depth)
		_shape.position = Vector2(size.x / 2.0, base + inward)
	else:
		rect.size = Vector2(depth, size.y)
		_shape.position = Vector2(base + inward, size.y / 2.0)
