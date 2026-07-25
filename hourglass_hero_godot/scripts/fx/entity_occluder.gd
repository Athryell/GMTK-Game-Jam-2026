## The shadow an entity casts, which knows on its own when to stop casting.
##
## Same trick as [EntityLight], for the same reason: every entity already
## answers "am I in the player's plane?" identically, so this asks the question
## itself instead of being wired into each host. A ghost is a thing in the other
## plane — it must not throw a shadow into this one, or the world would be full
## of darkness cast by geometry you cannot touch.
##
## ONLY THE PLAYER'S LAMP CASTS, and that is a deliberate limit rather than a
## missing feature. The lights on doors, pads, springs and hazards sit inside
## the very rectangle they belong to, so a pad that cast shadows would occlude
## itself and go black. They opt out by leaving `shadow_enabled` false, which
## makes a light ignore occluders entirely — those entities are things that
## GLOW, not lamps in a room, and the game reads better with one moving source
## throwing long shadows off the terrain than with five fighting each other.
class_name EntityOccluder
extends LightOccluder2D

## Matches the player lamp's `shadow_item_cull_mask`. Named rather than left as
## a bare 1, because 0 and 1 here mean "casts" and "does not", not a quantity.
const SHADOW_MASK := 1

var plane: Planes.Kind = Planes.Kind.BOTH


## Builds and attaches a rectangular occluder covering `host`'s footprint.
##
## Entity origins are top-left corners, so the polygon starts at zero rather
## than at `-size / 2`.
static func attach(host: Node2D, entity_plane: Planes.Kind, size: Vector2) -> EntityOccluder:
	var shape := OccluderPolygon2D.new()
	shape.polygon = PackedVector2Array([
		Vector2.ZERO,
		Vector2(size.x, 0.0),
		size,
		Vector2(0.0, size.y),
	])
	shape.closed = true
	# Both faces. Culled to one, a platform would stop the light from above and
	# let it straight through from below, so standing under a floor would light
	# the ceiling you are hanging from.
	shape.cull_mode = OccluderPolygon2D.CULL_DISABLED

	var node := EntityOccluder.new()
	node.plane = entity_plane
	node.occluder = shape
	host.add_child(node)
	return node


func _ready() -> void:
	Game.plane_changed.connect(_on_plane_changed)
	_on_plane_changed(Game.plane)


func _on_plane_changed(current: Planes.Kind) -> void:
	# Masked out rather than hidden: this says which lights we block, which is
	# the thing actually being switched.
	occluder_light_mask = SHADOW_MASK if Planes.is_active(plane, current) else 0
