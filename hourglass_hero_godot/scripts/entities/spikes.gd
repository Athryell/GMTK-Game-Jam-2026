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
const TOOTH_SIZE := 16.0
## Fraction of the band's depth that actually kills, measured from the base.
## The tips are visual overhang: you die once you are properly into the teeth,
## not when you brush a point. Spikes that kill on their outline feel cheap.
const LETHAL_DEPTH := 0.75

@export var facing: Facing = Facing.UP: set = _set_facing


func _init() -> void:
	size = Vector2(120.0, 24.0)
	light_tint = Palette.MONSTER
	light_radius = 110.0
	light_energy = 0.55


func _touched(_player: Player) -> void:
	Game.kill()


func _draw() -> void:
	var colour := _shade(Palette.MONSTER)
	for tooth in _teeth():
		HourglassShape.fill(self, tooth, colour)


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


## One triangle per tooth, base flat on the band's back edge, tip on the front.
func _teeth() -> Array[PackedVector2Array]:
	var along_x: bool = _axis()[0]
	var base: float = _axis()[1]
	var tip: float = _axis()[2]
	var span := size.x if along_x else size.y
	var count := maxi(1, int(round(span / TOOTH_SIZE)))
	var step := span / float(count)

	var out: Array[PackedVector2Array] = []
	for i in count:
		var a := i * step
		var b := a + step
		var mid := a + step / 2.0
		if along_x:
			out.append(PackedVector2Array([
				Vector2(a, base), Vector2(b, base), Vector2(mid, tip)]))
		else:
			out.append(PackedVector2Array([
				Vector2(base, a), Vector2(base, b), Vector2(tip, mid)]))
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
