@tool
## A solid: floor, wall, platform, static or moving, plus the flip-pad variant.
##
## The node's origin is the TOP-LEFT corner of the rectangle, not its centre.
class_name Platform
extends AnimatableBody2D

enum Kind {
	NORMAL, ## Ordinary platform.
	FLIP_PAD, ## Flips the hourglass on contact, with no jump and no plane change.
}

## Height of the flip-pad's trigger strip, sitting on the pad's top face.
const PAD_DETECT_HEIGHT := 8.0

@export var size := Vector2(120.0, 18.0): set = _set_size
@export var plane: Planes.Kind = Planes.Kind.BOTH: set = _set_plane
@export var kind: Kind = Kind.NORMAL: set = _set_kind

@export_group("Movement")
@export var move_axis: PingPong.Axis = PingPong.Axis.NONE
## Travel, in px, from the editor-placed position.
@export_range(0.0, 800.0, 1.0) var move_distance := 0.0
## Speed, in px/s.
@export_range(0.0, 400.0, 1.0) var move_speed := 0.0
## Start offset in the cycle. All movers share one clock, so equal-period
## entities are locked in step at 0.
@export_range(0.0, 1.0, 0.05) var move_phase := 0.0

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _pad_detector: Area2D = $PadDetector
@onready var _pad_detector_shape: CollisionShape2D = $PadDetector/CollisionShape2D

var _origin := Vector2.ZERO
var _elapsed := 0.0
var _active := true
## True while a jump would land the player in this plane: marked at full
## strength, still inert.
var _next := false
## The dashed line that says which plane this slab is in, and its own fade.
var _marker := PlaneMarker.new()


func _ready() -> void:
	_origin = position
	# The brick tile is 64 px and the shortest platform in the game is wider than
	# that; without repeat the whole slab is one stretched course.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	# See `terrain.gd`: nearest on the brick, linear left alone everywhere the
	# game draws a gradient.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_apply_size()
	_apply_kind()
	if Engine.is_editor_hint():
		return
	Game.plane_changed.connect(_on_plane_changed)
	Game.next_plane_changed.connect(_on_next_plane_changed)
	Tuning.changed.connect(queue_redraw)
	_pad_detector.body_entered.connect(_on_pad_body_entered)
	if kind == Kind.FLIP_PAD:
		EntityLight.attach(self, plane, size, Palette.FLIP_PAD, 150.0, 1.0)
	_on_plane_changed(Game.plane)
	_on_next_plane_changed(Game.next_plane)


func _physics_process(delta: float) -> void:
	# Otherwise platforms drift while the level is being edited.
	if Engine.is_editor_hint():
		return
	if move_axis == PingPong.Axis.NONE or move_speed <= 0.0:
		return
	_elapsed += delta
	position = _origin + PingPong.offset_vector(
		move_axis, _elapsed, move_distance, move_speed, move_phase)


## Both rects are tiled from the node's own origin, so the lit lip is struck on
## the same course as the brick underneath it rather than half a row out.
func _draw() -> void:
	var colour := _colour()
	Outline.rect(self, Rect2(Vector2.ZERO, size), colour.a)
	draw_texture_rect(Bricks.TEXTURE, Rect2(Vector2.ZERO, size), true, colour)
	if size.y >= 6.0:
		draw_texture_rect(Bricks.TEXTURE,
			Rect2(Vector2.ZERO, Vector2(size.x, Bricks.LIP_WIDTH)),
			true, colour.lightened(Bricks.LIP_LIFT))
	# Last, so the brick cannot cover it.
	_marker.draw(self, _corners(), plane)


## The rectangle as a polygon, in this node's own space, wound clockwise on
## screen — what both the shadow and the plane marker are cut from.
func _corners() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)])


## The outline this casts a shadow from. `Terrain` answers the same question with
## as many points as its ground has, and `CastShadows` cannot tell them apart.
func shadow_outline() -> PackedVector2Array:
	return _corners()


## The pad keeps its gold: it is the one platform whose colour says what it does
## rather than where it is. Everything else is masonry, tinted by the level.
func _colour() -> Color:
	var level := 0 if Engine.is_editor_hint() else Game.level_index
	var base := Palette.FLIP_PAD if kind == Kind.FLIP_PAD else Palette.bricks(level)
	# A ghost lives in the other plane: visible, but not solid. `next` is
	# deliberately not passed on — a slab says where the jump lands with its
	# dashes, not by pretending to be more solid than it is.
	return Palette.ghost(base, _active or Engine.is_editor_hint())


# ----- Plane -----------------------------------------------------------------

func _on_plane_changed(current: Planes.Kind) -> void:
	_active = Planes.is_active(plane, current)
	# An inactive solid sits on no layer: the player passes through it.
	collision_layer = Layers.SOLID if _active else 0
	_pad_detector.monitoring = _active and kind == Kind.FLIP_PAD
	_aim_marker()
	queue_redraw()


func _on_next_plane_changed(next: Planes.Kind) -> void:
	_next = plane == next
	_aim_marker()
	queue_redraw()


func _aim_marker() -> void:
	_marker.aim(plane != Planes.Kind.BOTH, _active, _next)


func _on_pad_body_entered(body: Node2D) -> void:
	# `body_entered` fires on entry only: standing on a pad does not re-refuel.
	if body is Player:
		Game.pad_flip()
		Audio.sfx("flip_pad")


# ----- Setters (live update in the editor) -----------------------------------

func _set_size(value: Vector2) -> void:
	size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
	_apply_size()


func _set_plane(value: Planes.Kind) -> void:
	plane = value
	queue_redraw()


func _set_kind(value: Kind) -> void:
	kind = value
	_apply_kind()


func _apply_size() -> void:
	queue_redraw()
	if not is_node_ready():
		return
	# The shape is `resource_local_to_scene`, so it belongs to this instance.
	var rect := _shape.shape as RectangleShape2D
	rect.size = size
	_shape.position = size / 2.0
	var det := _pad_detector_shape.shape as RectangleShape2D
	det.size = Vector2(size.x, PAD_DETECT_HEIGHT)
	_pad_detector_shape.position = Vector2(size.x / 2.0, 0.0)


## `monitoring` is NOT set here: it depends on plane, so `_on_plane_changed` owns it.
func _apply_kind() -> void:
	queue_redraw()
