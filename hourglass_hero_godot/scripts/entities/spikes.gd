@tool
## Spikes: a static hazard that kills on contact, within its own plane only.
##
## A monster that does not walk — same contract, same signals, different head.
## It exists to say "do not jump here" in a way the player can see. A low ceiling
## would forbid the jump; spikes show why it is forbidden, and that teaches.
##
## The node's origin is the TOP-LEFT corner of the band, like every other solid.
class_name Spikes
extends Area2D

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

@export var size := Vector2(120.0, 24.0): set = _set_size
@export var plane: Planes.Kind = Planes.Kind.BOTH: set = _set_plane
@export var facing: Facing = Facing.UP: set = _set_facing

@onready var _shape: CollisionShape2D = $CollisionShape2D

var _active := true


func _ready() -> void:
	_apply_size()
	collision_mask = Layers.PLAYER
	if Engine.is_editor_hint():
		return
	Game.plane_changed.connect(_on_plane_changed)
	body_entered.connect(_on_body_entered)
	_on_plane_changed(Game.plane)


func _on_body_entered(body: Node2D) -> void:
	if _active and body is Player:
		Game.kill()


func _draw() -> void:
	var colour := Palette.MONSTER if _active or Engine.is_editor_hint() \
		else Color(Palette.MONSTER, Tuning.cfg.ghost_alpha)
	for tooth in _teeth():
		draw_colored_polygon(tooth, colour)
		# `draw_colored_polygon` has no antialiasing flag, so the slanted edges
		# are redrawn as a stroke in the fill's own colour — the same trick
		# `HourglassShape._fill` uses to stop diagonals staircasing.
		var closed := tooth.duplicate()
		closed.append(tooth[0])
		draw_polyline(closed, colour, 1.0, true)


## One triangle per tooth, base flat on the band's back edge, tip on the front.
func _teeth() -> Array[PackedVector2Array]:
	var along_x := facing == Facing.UP or facing == Facing.DOWN
	var span := size.x if along_x else size.y
	var count := maxi(1, int(round(span / TOOTH_SIZE)))
	var step := span / float(count)

	# `base` and `tip` are the two coordinates on the pointing axis.
	var base := 0.0
	var tip := 0.0
	match facing:
		Facing.UP: base = size.y; tip = 0.0
		Facing.DOWN: base = 0.0; tip = size.y
		Facing.LEFT: base = size.x; tip = 0.0
		Facing.RIGHT: base = 0.0; tip = size.x

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


func _on_plane_changed(current: Planes.Kind) -> void:
	_active = Planes.is_active(plane, current)
	monitoring = _active
	queue_redraw()


func _set_size(value: Vector2) -> void:
	size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
	_apply_size()


func _set_plane(value: Planes.Kind) -> void:
	plane = value
	queue_redraw()


func _set_facing(value: Facing) -> void:
	facing = value
	_apply_size()


## The hitbox is the lethal slab against the band's base — see `LETHAL_DEPTH`.
func _apply_size() -> void:
	queue_redraw()
	if not is_node_ready():
		return
	var rect := _shape.shape as RectangleShape2D
	match facing:
		Facing.UP:
			rect.size = Vector2(size.x, size.y * LETHAL_DEPTH)
			_shape.position = Vector2(size.x / 2.0, size.y - rect.size.y / 2.0)
		Facing.DOWN:
			rect.size = Vector2(size.x, size.y * LETHAL_DEPTH)
			_shape.position = Vector2(size.x / 2.0, rect.size.y / 2.0)
		Facing.LEFT:
			rect.size = Vector2(size.x * LETHAL_DEPTH, size.y)
			_shape.position = Vector2(size.x - rect.size.x / 2.0, size.y / 2.0)
		Facing.RIGHT:
			rect.size = Vector2(size.x * LETHAL_DEPTH, size.y)
			_shape.position = Vector2(rect.size.x / 2.0, size.y / 2.0)
