@tool
## The contract every plane-aware trigger in the game obeys, as a type rather
## than as a comment.
##
## A door, a spring, a spike and a monster all answer the same three questions
## the same way — how big am I, which plane do I live in, and am I the plane the
## player is standing in right now — and each one used to answer them with its
## own copy of the same forty lines. Copies drift: the ghost-alpha slider on the
## tuning panel moved platforms and nothing else, because only one of the five
## had remembered to redraw on `Tuning.changed`.
##
## What a subclass still owns is what actually makes it that entity: its `_draw`,
## what happens when the player touches it, and the light it gives off. Anything
## it does not set, it inherits — and when the contract grows a term, it grows in
## one file.
##
## The node's origin is the TOP-LEFT corner of `size`, like every other solid.
class_name PlaneArea
extends Area2D

@export var size := Vector2(32.0, 32.0): set = _set_size
@export var plane: Planes.Kind = Planes.Kind.BOTH: set = _set_plane

## The light this entity carries. A subclass sets these in `_init`; left at
## radius 0 it carries none.
var light_tint := Color.WHITE
var light_radius := 0.0
var light_energy := 1.0
## Optional breathing, handed straight to the light. See [EntityLight].
var light_pulse_rate := 0.0
var light_pulse_depth := 0.0

@onready var _shape: CollisionShape2D = $CollisionShape2D

## True while the player is in a plane this entity can reach. A ghost is drawn
## faintly, triggers nothing, and lights nothing.
var _active := true


func _ready() -> void:
	_apply_size()
	collision_mask = Layers.PLAYER
	if Engine.is_editor_hint():
		return
	Game.plane_changed.connect(_on_plane_changed)
	# Ghost alpha is read inside `_draw`, so a slider that moves it has to be
	# able to ask for a new frame. Missing this is invisible until someone drags
	# the slider and half the game ignores it.
	Tuning.changed.connect(queue_redraw)
	body_entered.connect(_on_body_entered)
	if light_radius > 0.0:
		EntityLight.attach(self, plane, size, light_tint, light_radius, light_energy,
			light_pulse_rate, light_pulse_depth)
	_on_plane_changed(Game.plane)


## What this entity does to the player who walked into it. Only ever called for
## a real player, and only while this entity is in the active plane.
func _touched(_player: Player) -> void:
	pass


## `base` as it should be drawn right now: solid in this plane, a ghost in the
## other. Editor previews are always solid — a level author needs to see what
## they are placing, not what it looks like from the other side.
func _shade(base: Color) -> Color:
	return Palette.ghost(base, _active or Engine.is_editor_hint())


func _on_body_entered(body: Node2D) -> void:
	if _active and body is Player:
		_touched(body as Player)


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


## The hitbox, refitted to `size`. Overridden by anything whose lethal part is
## not its whole rectangle.
func _apply_size() -> void:
	queue_redraw()
	if not is_node_ready():
		return
	var rect := _shape.shape as RectangleShape2D
	rect.size = size
	_shape.position = size / 2.0
