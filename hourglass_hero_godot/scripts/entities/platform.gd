@tool
## A solid: floor, wall, platform, static or moving, plus the flip-pad variant.
##
## Authoring in Godot: drag `platform.tscn` into a level, set `size` and `plane`
## in the Inspector. The rectangle and its collision update live in the editor —
## what you see is what you play.
##
## The node's origin is the TOP-LEFT corner of the rectangle (matching the JS
## prototype's data), not its centre.
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
## Travel of the back-and-forth, in px, from where you placed it in the editor.
@export_range(0.0, 800.0, 1.0) var move_distance := 0.0
## Speed of the back-and-forth, in px/s.
@export_range(0.0, 400.0, 1.0) var move_speed := 0.0
## Where in the cycle it starts, as a fraction of a full there-and-back. Movers
## share one clock, so two of equal period sit in lockstep at 0 — set this to
## spread them into a wave.
@export_range(0.0, 1.0, 0.05) var move_phase := 0.0

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _pad_detector: Area2D = $PadDetector
@onready var _pad_detector_shape: CollisionShape2D = $PadDetector/CollisionShape2D

var _origin := Vector2.ZERO
var _elapsed := 0.0
var _active := true


func _ready() -> void:
	_origin = position
	_apply_size()
	_apply_kind()
	if Engine.is_editor_hint():
		return
	Game.plane_changed.connect(_on_plane_changed)
	Tuning.changed.connect(queue_redraw)
	_pad_detector.body_entered.connect(_on_pad_body_entered)
	EntityOccluder.attach(self, plane, size)
	if kind == Kind.FLIP_PAD:
		EntityLight.attach(self, plane, size, Palette.FLIP_PAD, 150.0, 1.0)
	_on_plane_changed(Game.plane)


func _physics_process(delta: float) -> void:
	# Otherwise platforms would drift around while you edit the level.
	if Engine.is_editor_hint():
		return
	if move_axis == PingPong.Axis.NONE or move_speed <= 0.0:
		return
	_elapsed += delta
	position = _origin + PingPong.offset_vector(
		move_axis, _elapsed, move_distance, move_speed, move_phase)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, _colour())
	# A light lip along the top face: you can read where your feet will land,
	# even on a thin platform.
	if size.y >= 6.0:
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 3.0)), _colour().lightened(0.35))


func _colour() -> Color:
	var current := Game.plane if not Engine.is_editor_hint() else Planes.Kind.FRONT
	var base := Palette.FLIP_PAD if kind == Kind.FLIP_PAD else Palette.solid(plane, current)
	if _active or Engine.is_editor_hint():
		return base
	# Ghost: it lives in the other plane — visible, but you fall right through.
	return Color(base.r, base.g, base.b, Tuning.cfg.ghost_alpha)


# ----- Plane -----------------------------------------------------------------

func _on_plane_changed(current: Planes.Kind) -> void:
	_active = Planes.is_active(plane, current)
	# An inactive solid sits on no layer at all: the player passes through it.
	collision_layer = Layers.SOLID if _active else 0
	_pad_detector.monitoring = _active and kind == Kind.FLIP_PAD
	queue_redraw()


func _on_pad_body_entered(body: Node2D) -> void:
	# `body_entered` only fires on entry: standing on a pad does not refuel on
	# loop, you have to leave and come back.
	if body is Player:
		Game.pad_flip()


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
	# Detection strip flush with the pad's top face.
	var det := _pad_detector_shape.shape as RectangleShape2D
	det.size = Vector2(size.x, PAD_DETECT_HEIGHT)
	_pad_detector_shape.position = Vector2(size.x / 2.0, 0.0)


func _apply_kind() -> void:
	queue_redraw()
	if not is_node_ready():
		return
	_pad_detector.monitoring = kind == Kind.FLIP_PAD
